# [BUG] [v0.0.7] `read_file` metadata `truncated` field is incorrect when `offset > 0` -- always reports truncation even when all remaining lines are returned

## Description
In `read_file()` in `src/cortex-app-server/src/tools/filesystem.rs`, the `truncated` metadata field is computed as `shown_lines < total_lines`. This comparison does not account for the `offset` parameter. When `offset > 0`, `shown_lines` is always less than `total_lines` (because lines before the offset are excluded from `selected`), so `truncated` is always `true` -- even when every line from the offset onward was successfully returned without any truncation.

## Location
- **File**: `src/cortex-app-server/src/tools/filesystem.rs`
- **Function**: `read_file()`
- **Expression**: `"truncated": shown_lines < total_lines` (in the metadata JSON)

## Buggy Code
```rust
pub async fn read_file(cwd: &Path, args: Value) -> ToolResult {
    // ...
    let offset = args.get("offset").and_then(Value::as_u64).unwrap_or(0) as usize;
    let limit = args.get("limit").and_then(Value::as_u64).map(|l| l as usize);

    match tokio::fs::read_to_string(&full_path).await {
        Ok(content) => {
            let lines: Vec<&str> = content.lines().collect();
            let total_lines = lines.len();
            let selected: Vec<&str> = lines
                .into_iter()
                .skip(offset)
                .take(limit.unwrap_or(usize::MAX))
                .collect();
            let shown_lines = selected.len();

            ToolResult {
                success: true,
                output: selected.join("\n"),
                metadata: Some(json!({
                    "total_lines": total_lines,
                    "shown_lines": shown_lines,
                    "offset": offset,
                    "truncated": shown_lines < total_lines  // <-- BUG
                })),
                // ...
            }
        }
        // ...
    }
}
```

The `truncated` field should indicate whether the output was cut short by the `limit` parameter (i.e., there are more lines available after the returned range). The correct check is:

```rust
"truncated": offset + shown_lines < total_lines
```

## Steps to Reproduce
1. Create a file with 100 lines
2. Call `read_file` with `{"file_path": "test.txt", "offset": 50}` (no limit)
3. All 50 remaining lines (lines 51-100) are returned correctly
4. `shown_lines = 50`, `total_lines = 100`
5. `truncated` = `50 < 100` = `true` **INCORRECT**
6. The LLM sees `truncated: true` and believes there are more lines to fetch
7. It calls `read_file` again with `offset: 100` to get the "remaining" lines
8. Returns 0 lines with `truncated: true` again (0 < 100)
9. Infinite loop: the LLM keeps requesting more data that doesn't exist

Another example:
1. File has 10 lines
2. Call with `{"file_path": "test.txt", "offset": 5, "limit": 5}`
3. Returns lines 6-10 (all remaining lines), `shown_lines = 5`
4. `truncated` = `5 < 10` = `true` **INCORRECT** -- no lines were actually truncated

## Expected Behavior
`truncated` should be `true` only when the `limit` parameter caused lines to be excluded:
```rust
"truncated": offset + shown_lines < total_lines
```

With this fix:
- `offset=50`, no limit, 100-line file: `50 + 50 < 100` = `false` (correct -- all remaining lines returned)
- `offset=0`, `limit=50`, 100-line file: `0 + 50 < 100` = `true` (correct -- 50 lines were truncated)
- `offset=5`, `limit=5`, 10-line file: `5 + 5 < 10` = `false` (correct -- all remaining lines returned)

## Actual Behavior
`truncated` is `true` whenever `offset > 0`, regardless of whether any lines were actually truncated. This causes:
- The LLM to unnecessarily re-request file content
- Potential infinite request loops when offset > 0 and no limit
- Wasted tokens and API calls on phantom "remaining" content

## Impact
- **Severity**: Medium
- **Consequence**: The `truncated` flag provides incorrect information to the LLM, causing it to believe there is more content to read when there isn't. With `offset > 0`, this can trigger repeated unnecessary read_file calls or infinite loops as the LLM tries to fetch "truncated" content that was already fully returned.
