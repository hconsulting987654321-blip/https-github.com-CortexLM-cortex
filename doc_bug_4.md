# [BUG] [v0.0.7] truncate_message() in spawn.rs uses byte slicing causing panic on UTF-8 agent descriptions

## Description
The `truncate_message()` function in `cortex-agents/src/collab/spawn.rs` uses byte slicing (`&message[..max_len]`) to truncate agent task descriptions. This will panic if the truncation point falls within a multi-byte UTF-8 character, as Rust does not allow slicing in the middle of a character boundary.

This is a different instance from the resume summary truncation bug (#7010) - this affects agent spawning when task descriptions contain non-ASCII characters.

## Location
- **File**: src/cortex-agents/src/collab/spawn.rs
- **Function**: `truncate_message()`
- **Line**: Approximately line 165-172

## Steps to Reproduce
1. Spawn a subagent with a task description containing multi-byte UTF-8 characters
2. Make the description longer than 100 characters with a multi-byte char near position 100
3. Observe panic when the byte slice cuts through the character

```rust
// This will panic
let task = "分析这个代码库的架构设计和实现细节，找出所有可能的性能问题和安全漏洞。请特别关注内存管理和并发处理相关的代码。";
// task.len() = 165 bytes, but only 55 characters
// Slicing at byte 100 will likely hit the middle of a Chinese character
```

## Expected Behavior
The function should use character-based truncation that respects UTF-8 boundaries:
```rust
fn truncate_message(message: &str, max_chars: usize) -> String {
    if message.chars().count() <= max_chars {
        message.to_string()
    } else {
        message.chars().take(max_chars).collect::<String>() + "..."
    }
}
```

## Actual Behavior
The current code uses byte slicing:
```rust
fn truncate_message(message: &str, max_len: usize) -> String {
    if message.len() <= max_len {
        message.to_string()
    } else {
        format!("{}...", &message[..max_len])  // <-- PANIC on UTF-8
    }
}
```

When `max_len` (100) falls in the middle of a multi-byte character:
```
thread 'main' panicked at 'byte index 100 is not a char boundary;
it is inside '库' (bytes 99..102) of `分析这个代码库...`'
```

## System Information
- **Cortex Version**: v0.0.7
- **File**: src/cortex-agents/src/collab/spawn.rs
- **Affected Functionality**: Agent spawning with non-ASCII task descriptions

## Impact
- **Severity**: Medium
- **Affected Users**: Users with non-English task descriptions (Chinese, Japanese, Korean, emoji, etc.)
- **Consequence**:
  - Agent spawning crashes when description is truncated mid-character
  - Multi-agent workflows fail unexpectedly
  - Particularly affects users in non-English locales

## Suggested Fix
Replace byte slicing with character-based truncation:

```rust
/// Truncate a message for logging/display purposes.
fn truncate_message(message: &str, max_chars: usize) -> String {
    let char_count = message.chars().count();
    if char_count <= max_chars {
        message.to_string()
    } else {
        let truncated: String = message.chars().take(max_chars).collect();
        format!("{}...", truncated)
    }
}
```

Or use the `unicode-segmentation` crate for proper grapheme cluster handling:
```rust
use unicode_segmentation::UnicodeSegmentation;

fn truncate_message(message: &str, max_graphemes: usize) -> String {
    let graphemes: Vec<&str> = message.graphemes(true).collect();
    if graphemes.len() <= max_graphemes {
        message.to_string()
    } else {
        format!("{}...", graphemes[..max_graphemes].concat())
    }
}
```

## Evidence
From spawn.rs:
```rust
/// Truncate a message for logging/display purposes.
fn truncate_message(message: &str, max_len: usize) -> String {
    if message.len() <= max_len {
        message.to_string()
    } else {
        format!("{}...", &message[..max_len])
    }
}
```

The function is called when creating agent info:
```rust
let mut agent_info = AgentInfo::new(format!("subagent-{}", uuid::Uuid::new_v4()))
    .with_description(format!("Subagent for: {}", truncate_message(message, 100)));
```

Test that would fail:
```rust
#[test]
fn test_truncate_message_utf8() {
    // Chinese text: "Analyze this codebase" repeated
    let msg = "分析这个代码库分析这个代码库分析这个代码库分析这个代码库分析这个代码库分析这个代码库分析这个代码库";
    // Should not panic
    let result = truncate_message(msg, 50);
    assert!(result.ends_with("..."));
}
```

## References
- https://github.com/CortexLM/cortex/blob/main/src/cortex-agents/src/collab/spawn.rs
- Related issue: #7010 (Resume summary truncation panics on UTF-8) - same class of bug, different location
- Rust string slicing: https://doc.rust-lang.org/book/ch08-02-strings.html#indexing-into-strings
- unicode-segmentation crate: https://docs.rs/unicode-segmentation/
