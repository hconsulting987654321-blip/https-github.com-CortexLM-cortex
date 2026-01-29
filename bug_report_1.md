# [BUG] [v0.0.5] CLI Panics with Index Out of Bounds on Short Hotkey Input

## Description
The `bounty status` command crashes with a Rust panic when provided a hotkey shorter than 8 characters. The code in `src/bin/bounty/commands/status.rs` performs string slicing (`&hotkey[..8]`) without first validating that the hotkey is at least 8 characters long. This causes an unrecoverable panic instead of a user-friendly error message.

This is a critical usability bug because:
- Users who mistype or paste partial hotkeys will crash the CLI
- The panic message is cryptic and unhelpful to non-Rust users
- No graceful error handling or recovery is possible

## Steps to Reproduce
1. Build the bounty CLI:
   ```bash
   cd bounty-challenge
   cargo build --release
   export PATH="$PWD/target/release:$PATH"
   ```

2. Run the status command with a short hotkey (less than 8 characters):
   ```bash
   bounty status --hotkey "abc"
   ```

3. Observe the panic

## Expected Behavior
The CLI should validate the hotkey length before attempting to slice it and display a friendly error message:
```bash
$ bounty status --hotkey "abc"
Error: Invalid hotkey format. Hotkey must be a valid SS58 address (48 characters).
```

## Actual Behavior
The CLI crashes with a Rust panic:
```bash
$ bounty status --hotkey "abc"
thread 'main' panicked at 'byte index 8 is out of bounds of `abc`', src/bin/bounty/commands/status.rs:9:42
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

The problematic code at `src/bin/bounty/commands/status.rs:9`:
```rust
println!("Hotkey: {}...{}", &hotkey[..8], &hotkey[hotkey.len() - 4..]);
```

This line assumes `hotkey` is at least 8 characters, but no validation occurs before this point.

## System Information
- **OS**: Ubuntu 22.04 LTS
- **Architecture**: x86_64
- **Rust Version**: rustc 1.75.0
- **Bounty CLI Version**: v0.0.5
- **Shell**: bash 5.1

## Impact
- **Severity**: Critical
- **Affected Users**: All users who provide invalid or partial hotkey inputs
- **Consequences**:
  - CLI crashes without useful error message
  - Poor user experience, especially for new users
  - Users may think the CLI is broken rather than their input being wrong
  - No opportunity to correct the mistake without understanding Rust panics
  - Potential data loss if panic occurs mid-operation in future features

## Suggested Fix

### Option 1: Validate Before Slicing (Recommended)
Add bounds checking before any string slicing operations:

```rust
pub async fn run(rpc: &str, hotkey: &str) -> Result<()> {
    print_header("Miner Status");

    // Validate hotkey length before slicing
    if hotkey.len() < 8 {
        print_error("Invalid hotkey: must be at least 8 characters");
        return Ok(());
    }

    println!("Hotkey: {}...{}", &hotkey[..8], &hotkey[hotkey.len() - 4..]);
    // ... rest of function
}
```

### Option 2: Use Safe Slicing with get()
Use Rust's safe slicing method that returns Option:

```rust
let hotkey_display = match (hotkey.get(..8), hotkey.get(hotkey.len().saturating_sub(4)..)) {
    (Some(start), Some(end)) => format!("{}...{}", start, end),
    _ => hotkey.to_string(), // Fallback for short hotkeys
};
println!("Hotkey: {}", hotkey_display);
```

### Option 3: Full SS58 Validation
Validate the hotkey format properly using the existing `is_valid_ss58_hotkey` function:

```rust
pub async fn run(rpc: &str, hotkey: &str) -> Result<()> {
    print_header("Miner Status");

    // Use existing validation function
    if !bounty_challenge::auth::is_valid_ss58_hotkey(hotkey) {
        print_error("Invalid hotkey format. Must be SS58 encoded.");
        return Ok(());
    }

    // Safe to slice now since SS58 addresses are 48 chars
    println!("Hotkey: {}...{}", &hotkey[..8], &hotkey[hotkey.len() - 4..]);
    // ... rest of function
}
```

## Additional Context

### Same Bug Exists in Multiple Files
This same vulnerability exists in other command files:

| File | Line | Code |
|------|------|------|
| `src/bin/bounty/commands/status.rs` | 9 | `&hotkey[..8]` |
| `src/bin/bounty/commands/validate.rs` | 11 | `&hk[..8]` |
| `src/bin/bounty/wizard/register_wizard.rs` | 44-45 | `&hotkey[..8]` |
| `src/bin/bounty/wizard/register_wizard.rs` | 92-93 | `&hotkey[..12]` |
| `src/bin/bounty/wizard/register_wizard.rs` | 170 | `&hotkey[..16]` |

All of these need to be fixed.

### Test Cases to Add
```rust
#[test]
fn test_status_with_short_hotkey() {
    // Should return error, not panic
    let result = run("http://test", "abc").await;
    assert!(result.is_ok()); // Should handle gracefully
}

#[test]
fn test_status_with_empty_hotkey() {
    let result = run("http://test", "").await;
    assert!(result.is_ok()); // Should handle gracefully
}
```

## References
- Affected file: `src/bin/bounty/commands/status.rs:9`
- Rust string slicing documentation: https://doc.rust-lang.org/std/primitive.str.html#method.get
- SS58 format specification: https://docs.substrate.io/reference/address-formats/
