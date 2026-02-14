# [BUG] [v0.0.7] `truncate_preserve_code` silently discards all content inside unclosed code blocks

## Description
In `truncate_preserve_code()` in `src/cortex-engine/src/truncate.rs`, the function buffers lines inside code blocks (delimited by `` ``` ``) into a `code_block_content` string and only appends them to the output when the closing `` ``` `` fence is found. If the input text ends while inside an unclosed code block (i.e., the opening `` ``` `` was found but no closing `` ``` ``), the entire buffered content is silently discarded. No partial content is output, no synthetic closing fence is added, and no indication of data loss is provided.

Additionally, complete code blocks that exceed the remaining character budget are also entirely dropped with no indication -- they simply vanish from the output.

## Location
- **File**: `src/cortex-engine/src/truncate.rs`
- **Function**: `truncate_preserve_code()`

## Buggy Code
```rust
fn truncate_preserve_code(text: &str, config: &TruncateConfig) -> String {
    let mut result = String::new();
    let mut remaining = config.max_chars;
    let mut in_code_block = false;
    let mut code_block_content = String::new();

    for line in text.lines() {
        if line.starts_with("```") {
            if in_code_block {
                // End of code block - add it if it fits
                code_block_content.push_str(line);
                code_block_content.push('\n');

                if code_block_content.len() <= remaining {
                    result.push_str(&code_block_content);
                    remaining -= code_block_content.len();
                }
                // If it doesn't fit, entire code block is silently dropped
                code_block_content.clear();
                in_code_block = false;
            } else {
                // Start of code block
                in_code_block = true;
                code_block_content.push_str(line);
                code_block_content.push('\n');
            }
        } else if in_code_block {
            code_block_content.push_str(line);
            code_block_content.push('\n');
        } else {
            let line_len = line.len() + 1;
            if line_len <= remaining {
                result.push_str(line);
                result.push('\n');
                remaining -= line_len;
            } else {
                break;
            }
        }
    }
    // BUG: If in_code_block is still true here, code_block_content is never
    // appended to result -- all buffered content is silently lost

    if result.len() < text.len() {
        result.push_str(&config.suffix);
    }

    result
}
```

## Steps to Reproduce

### Scenario 1: Unclosed code block at end of input
Input text (e.g., from an LLM response being truncated):
````
Here is the explanation:

The function works like this:

```rust
fn main() {
    let x = compute_value();
    println!("Result: {}", x);
    // More code follows...
````

With `max_chars = 500` (plenty of room for all this content):
1. Lines "Here is the explanation:" and blank line are added to `result`
2. "The function works like this:" is added to `result`
3. `` ```rust `` triggers `in_code_block = true`, starts buffering into `code_block_content`
4. All code lines are buffered into `code_block_content`
5. Input ends -- loop finishes with `in_code_block = true`
6. `code_block_content` (containing 4+ lines of code) is **never appended** to `result`
7. Output: just "Here is the explanation:\n\nThe function works like this:\n" -- all code is gone

### Scenario 2: Code block exceeds budget
Input with a large code block followed by important text:
````
Summary: The fix is simple.

```python
# 200 lines of code...
```

IMPORTANT: Apply this fix to production immediately.
````

With `max_chars = 100`:
1. "Summary: The fix is simple." is added to result
2. The code block is buffered, but it's 200+ lines and exceeds remaining budget
3. The entire code block is silently dropped (no placeholder, no "[code block truncated]")
4. "IMPORTANT: Apply this fix to production immediately." is added to result
5. Output appears to jump from summary directly to the importance note, with no indication that a code block existed

## Expected Behavior
1. When input ends with an unclosed code block, the buffered content should be flushed to the output (at least partially, up to the remaining budget), possibly with a synthetic closing fence
2. When a complete code block exceeds the budget, a placeholder like `[code block truncated]` should indicate that content was removed
3. At minimum, the function should not silently discard content that fits within the character budget

## Actual Behavior
- Unclosed code blocks: all buffered content is silently discarded regardless of available space
- Oversized code blocks: entire block is silently dropped with no trace

## Impact
- **Severity**: Medium-High
- **Consequence**: Silent data loss during text truncation. LLM responses containing code blocks may lose all code content when truncated, even if the code fits within the character budget. This is especially problematic for:
  - Streaming responses that get truncated mid-code-block
  - Long responses where the last section is a code block
  - Any content where unclosed fences are common (partial markdown, chat messages)
  - The LLM or user sees truncated text with code sections mysteriously missing, with no indication that content was removed
