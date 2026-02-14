# [BUG] [v0.0.7] `glob_match` in glob.rs treats `*` as matching path separators, making single-directory-level matching impossible

## Description
The `glob_match()` function in `src/cortex-engine/src/tools/handlers/glob.rs` implements `*` as matching any sequence of characters including `/` (the path separator). In standard glob semantics, `*` matches any characters *except* `/`, while `**` matches across directory boundaries. Because this implementation makes `*` equivalent to `**`, users cannot write patterns that match files in a single directory level only.

Furthermore, the function strips the `**/` prefix from patterns (line 136: `pattern.trim_start_matches("**/")`), but since `*` already matches `/`, this stripping is redundant and further conflates the two distinct glob operations.

## Location
- **File**: `src/cortex-engine/src/tools/handlers/glob.rs`
- **Function**: `glob_match()`
- **Lines**: 134-156

## Buggy Code
```rust
fn glob_match(pattern: &str, text: &str) -> bool {
    let pattern = pattern.trim_start_matches("**/");
    let pattern_chars: Vec<char> = pattern.chars().collect();
    let text_chars: Vec<char> = text.chars().collect();

    fn match_helper(pattern: &[char], text: &[char]) -> bool {
        match (pattern.first(), text.first()) {
            (None, None) => true,
            (Some('*'), _) => {
                // BUG: '*' matches ANY character including '/'
                match_helper(&pattern[1..], text)
                    || (!text.is_empty() && match_helper(pattern, &text[1..]))
            }
            (Some('?'), Some(_)) => match_helper(&pattern[1..], &text[1..]),
            (Some(p), Some(t)) if p == t => match_helper(&pattern[1..], &text[1..]),
            _ => false,
        }
    }

    match_helper(&pattern_chars, &text_chars)
}
```

The `*` wildcard recursively consumes any character via `match_helper(pattern, &text[1..])` without checking if the consumed character is `/`.

## Steps to Reproduce
Consider a directory structure:
```
src/
  main.rs
  lib.rs
  utils/
    helpers.rs
    deep/
      nested.rs
```

Using the Glob tool with pattern `src/*.rs` against relative paths:
- `glob_match("src/*.rs", "src/main.rs")` returns `true` (correct)
- `glob_match("src/*.rs", "src/utils/helpers.rs")` returns `true` (**incorrect** -- `*` should not match `utils/`)
- `glob_match("src/*.rs", "src/utils/deep/nested.rs")` returns `true` (**incorrect** -- `*` should not match `utils/deep/`)

The pattern `src/*.rs` should only match `.rs` files directly under `src/`, not in subdirectories.

## Expected Behavior
`*` should not match the `/` character. The match helper should be:
```rust
(Some('*'), _) => {
    match_helper(&pattern[1..], text)
        || (!text.is_empty() && text[0] != '/' && match_helper(pattern, &text[1..]))
}
```

## Actual Behavior
`*` matches all characters including `/`, making it impossible to restrict matches to a single directory level. Any pattern using `*` behaves identically to `**`.

## Impact
- **Severity**: Medium
- **Consequence**: The Glob tool returns over-broad results, including files from subdirectories that should be excluded. Users cannot use standard glob patterns like `src/*.rs` to match only immediate children. This causes confusion and potentially incorrect file operations when the glob results are used as input to other tools (e.g., batch editing files matching a pattern). The same bug exists in the `glob_match` copies in `grep.rs` and `file_ops.rs`.
