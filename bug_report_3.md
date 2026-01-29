# [BUG] [v0.1.0] Authentication Message Format Mismatch - Username Lowercase Inconsistency

## Description

There is a critical inconsistency between how the registration message is created in two different parts of the codebase. The `register_wizard.rs` lowercases the GitHub username when creating the signature message, but the helper function `create_register_message()` in `auth.rs` does NOT lowercase it.

This means if any external integration or future code uses the `auth.rs` helper function, signature verification will fail because the messages won't match.

## Steps to Reproduce

1. Review the wizard implementation in `src/bin/bounty/wizard/register_wizard.rs` line 122:
```rust
let message = format!("register_github:{}:{}", github_username.to_lowercase(), timestamp);
```

2. Review the helper function in `src/auth.rs` line 59-61:
```rust
pub fn create_register_message(github_username: &str, timestamp: i64) -> String {
    format!("register_github:{}:{}", github_username, timestamp)  // NO .to_lowercase()
}
```

3. If a developer uses the `create_register_message` helper with a mixed-case username like "JohnDoe":
```rust
let message = auth::create_register_message("JohnDoe", timestamp);
// Returns: "register_github:JohnDoe:1706540000"
```

4. But the server expects (based on wizard behavior):
```
"register_github:johndoe:1706540000"
```

5. Signature verification fails because messages don't match.

## Expected Behavior

Both code paths should produce identical message formats. The `create_register_message` helper should lowercase the username to match the wizard behavior:

```rust
pub fn create_register_message(github_username: &str, timestamp: i64) -> String {
    format!("register_github:{}:{}", github_username.to_lowercase(), timestamp)
}
```

## Actual Behavior

- `register_wizard.rs` lowercases username: `github_username.to_lowercase()`
- `auth.rs` helper does NOT lowercase username
- Any code using the helper function will generate incompatible signatures
- This is a latent bug waiting to cause authentication failures

## System Information

- **OS**: Ubuntu 22.04 LTS
- **Architecture**: x86_64
- **Rust Version**: rustc 1.75.0
- **Bounty CLI Version**: v0.1.0

## Impact

- **Severity**: High
- Any integration using `create_register_message()` will fail to register
- The helper function is dead code currently (not used), but it's a trap for future developers
- Violates the principle of least surprise - a helper named `create_register_message` should create valid messages
- Security risk: inconsistent message formatting is a common source of signature bypass vulnerabilities

## Suggested Fix

**Option 1: Fix the helper function** (Recommended)
```rust
// src/auth.rs line 59-61
pub fn create_register_message(github_username: &str, timestamp: i64) -> String {
    format!("register_github:{}:{}", github_username.to_lowercase(), timestamp)
}
```

**Option 2: Use the helper function in the wizard**
```rust
// src/bin/bounty/wizard/register_wizard.rs line 122
let message = crate::auth::create_register_message(&github_username, timestamp);
```

Option 1 is preferred because it fixes the helper function to match the expected behavior documented implicitly by the working wizard code.

**Additionally**, add a unit test to prevent regression:
```rust
#[test]
fn test_create_register_message_lowercase() {
    let msg1 = create_register_message("JohnDoe", 12345);
    let msg2 = create_register_message("johndoe", 12345);
    assert_eq!(msg1, msg2, "Username should be lowercased");
    assert_eq!(msg1, "register_github:johndoe:12345");
}
```

## References

- `src/bin/bounty/wizard/register_wizard.rs:122` - Lowercases username (correct behavior)
- `src/auth.rs:59-61` - Does NOT lowercase username (bug)
- `src/server.rs:241-245` - Server also lowercases for verification
