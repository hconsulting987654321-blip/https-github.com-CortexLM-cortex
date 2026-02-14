# [BUG] [v0.0.7] `grep.rs` `max_results` truncates output lines instead of match count in content mode, producing partial file results

## Description
In `GrepHandler::execute()` in `src/cortex-engine/src/tools/handlers/grep.rs`, the `max_results` limit is applied by calling `results.truncate(limit)` on the `results` vector after searching is complete (line 122). However, in `content` output mode, each matching line (including its context lines) is pushed as a separate entry into `results`. This means `max_results` limits the number of *output lines* rather than the number of *file matches* or *pattern matches*.

For example, if a user sets `max_results: 5` expecting 5 matching files or 5 matching lines, they might get results from only a single file if that file has many context lines, because each context line counts as one result entry.

## Location
- **File**: `src/cortex-engine/src/tools/handlers/grep.rs`
- **Function**: `execute()` and `search_file()`
- **Lines**: 121-123 (truncation applied), 244-264 (content lines pushed individually)

## Buggy Code
```rust
// In execute():
// Apply max_results limit
if let Some(limit) = args.max_results {
    results.truncate(limit);  // <-- Truncates output LINES, not matches
}
```

```rust
// In search_file() content mode:
for (i, line) in match_lines {
    let prefix = if line_numbers {
        format!("{}:{}:", path.display(), i + 1)
    } else {
        format!("{}:", path.display())
    };
    results.push(format!("{prefix}{line}"));  // <-- Each context/match line is a separate entry
}
```

## Steps to Reproduce
1. Search with `max_results: 10`, `output_mode: "content"`, `context_before: 3`, `context_after: 3`
2. Suppose the first matching file has 2 matches with 7 context lines each = 14 entries from one file
3. Result: `results.truncate(10)` cuts to 10 lines, all from the first file
4. No results from any other files are shown, even though the user expected 10 *matches*

Concrete example:
```json
{
    "pattern": "TODO",
    "path": "/project",
    "output_mode": "content",
    "context_before": 5,
    "context_after": 5,
    "max_results": 3
}
```

If the first file has one `TODO` match, the context window produces up to 11 lines (5 before + match + 5 after). With `max_results: 3`, only the first 3 of those 11 context lines are returned. The output shows a partial, misleading snippet without even the matching line itself (if it was beyond the 3rd context line).

## Expected Behavior
`max_results` should limit the number of *matches* (or matched files), not the number of output lines. In file_paths mode, this happens to work correctly because each file contributes one entry. In content mode, the counting unit changes unexpectedly.

## Actual Behavior
In content mode, `max_results` truncates individual output lines, leading to partial context windows from a single file and completely missing results from other files. The semantic meaning of `max_results` changes depending on output mode.

## Impact
- **Severity**: Medium
- **Consequence**: Users get misleading, incomplete search results. A search with `max_results: 10` in content mode might return 10 lines of context from a single match in a single file, hiding all other matches across the codebase. This is especially problematic when using grep results to understand code patterns or find all occurrences of a bug.
