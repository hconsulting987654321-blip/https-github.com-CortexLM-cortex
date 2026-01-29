# [BUG] [v0.0.5] Validate Command Panics on Optional Short Hotkey Without Graceful Handling

## Description
The `bounty validate` command accepts an optional `--hotkey` parameter but immediately performs unsafe string slicing on line 11 without validating the hotkey length. When a user provides a hotkey shorter than 8 characters, the application panics with an index out of bounds error instead of providing a helpful error message.

This is particularly problematic because:
- The hotkey is an **optional** parameter, yet when provided, it's not validated
- Users may provide partial hotkeys when testing or copying from clipboard
- The panic occurs before any useful validation logic can run
- The error message is technical and unhelpful

## Steps to Reproduce
1. Build the bounty CLI:
   ```bash
   cd bounty-challenge
   cargo build --release
   export PATH="$PWD/target/release:$PATH"
   ```

2. Run the validate command with a short hotkey:
   ```bash
   bounty validate --hotkey "short"
   ```

3. Observe the panic

4. Also test with an empty hotkey:
   ```bash
   bounty validate --hotkey ""
   ```

## Expected Behavior
The CLI should validate the hotkey format before using it:
```bash
$ bounty validate --hotkey "short"
Error: Invalid hotkey format. SS58 addresses must be 48 characters.
Hint: Run 'bounty validate' without --hotkey to skip hotkey-specific checks.
```

Or for empty input:
```bash
$ bounty validate --hotkey ""
Error: Hotkey cannot be empty. Please provide a valid SS58 address.
```

## Actual Behavior
The CLI crashes with a Rust panic:
```bash
$ bounty validate --hotkey "short"
thread 'main' panicked at 'byte index 8 is out of bounds of `short`', src/bin/bounty/commands/validate.rs:11:44
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

The problematic code at `src/bin/bounty/commands/validate.rs:10-11`:
```rust
if let Some(ref hk) = hotkey {
    println!("Hotkey:    {}...{}", &hk[..8], &hk[hk.len() - 4..]);
}
```

The code checks if the hotkey `Option` is `Some`, but doesn't validate the string length before slicing.

## System Information
- **OS**: Ubuntu 22.04 LTS
- **Architecture**: x86_64
- **Rust Version**: rustc 1.75.0
- **Bounty CLI Version**: v0.0.5
- **Shell**: bash 5.1

## Impact
- **Severity**: High
- **Affected Users**: Users running validator mode with custom hotkey parameter
- **Consequences**:
  - CLI crashes with cryptic error message
  - Validator mode cannot be tested with arbitrary hotkeys
  - Users cannot debug hotkey-related issues
  - Poor user experience undermines trust in the tooling
  - Potential security concern: panics can be used to crash validator services

## Suggested Fix

### Option 1: Validate Length Before Slicing
```rust
pub async fn run(platform_url: &str, hotkey: Option<String>) -> Result<()> {
    print_header("Validator Mode");

    println!("Platform:  {}", platform_url);
    if let Some(ref hk) = hotkey {
        // Validate hotkey length before slicing
        if hk.len() < 12 {  // Need at least 12 chars for 8 prefix + 4 suffix
            print_error(&format!("Invalid hotkey '{}': too short (need 48 characters)", hk));
            return Ok(());
        }
        println!("Hotkey:    {}...{}", &hk[..8], &hk[hk.len() - 4..]);
    }
    // ... rest of function
}
```

### Option 2: Use Safe Slicing with Fallback
```rust
if let Some(ref hk) = hotkey {
    let display = if hk.len() >= 12 {
        format!("{}...{}", &hk[..8], &hk[hk.len() - 4..])
    } else {
        format!("{} (invalid format)", hk)
    };
    println!("Hotkey:    {}", display);
}
```

### Option 3: Use SS58 Validation Function
```rust
if let Some(ref hk) = hotkey {
    if !bounty_challenge::auth::is_valid_ss58_hotkey(hk) {
        print_error("Invalid hotkey format. Must be a valid SS58 address.");
        println!("  Provided: {}", hk);
        println!("  Expected: 48-character SS58 encoded address");
        return Ok(());
    }
    println!("Hotkey:    {}...{}", &hk[..8], &hk[hk.len() - 4..]);
}
```

### Option 4: Create Reusable Helper Function
Since this pattern exists in multiple files, create a helper:

```rust
// src/bin/bounty/utils.rs
pub fn format_hotkey_short(hotkey: &str) -> String {
    if hotkey.len() >= 12 {
        format!("{}...{}", &hotkey[..8], &hotkey[hotkey.len() - 4..])
    } else if hotkey.is_empty() {
        "(empty)".to_string()
    } else {
        format!("{} (invalid)", hotkey)
    }
}

pub fn validate_hotkey(hotkey: &str) -> Result<(), String> {
    if hotkey.is_empty() {
        return Err("Hotkey cannot be empty".to_string());
    }
    if hotkey.len() < 48 {
        return Err(format!("Hotkey too short: {} chars (need 48)", hotkey.len()));
    }
    if !bounty_challenge::auth::is_valid_ss58_hotkey(hotkey) {
        return Err("Invalid SS58 format".to_string());
    }
    Ok(())
}
```

## Additional Context

### Why This Bug is Different from Bug #1
While similar to the `status.rs` bug, this one has unique characteristics:
- The hotkey is **optional** (`Option<String>`), making the edge case more likely
- Users may intentionally omit or provide partial hotkeys for testing
- The validate command is specifically for checking configurations, so it should be more forgiving

### Edge Cases Not Handled

| Input | Expected Behavior | Actual Behavior |
|-------|-------------------|-----------------|
| `""` (empty) | Error message | Panic (or no output if Option::None) |
| `"abc"` | Error message | Panic |
| `"12345678"` | Error message (still invalid) | Panic on suffix slice |
| `"5GrwvaEF..."` (valid) | Show truncated | Works correctly |

### Full Validate.rs Code Review

```rust
// Line 6-12 of validate.rs
pub async fn run(platform_url: &str, hotkey: Option<String>) -> Result<()> {
    print_header("Validator Mode");

    println!("Platform:  {}", platform_url);
    if let Some(ref hk) = hotkey {
        println!("Hotkey:    {}...{}", &hk[..8], &hk[hk.len() - 4..]);  // BUG HERE
    }
    // ...
}
```

The pattern `&hk[hk.len() - 4..]` will also panic if the hotkey is between 1-3 characters because:
- `"abc".len() - 4` underflows (0 - 4 in usize = huge number)
- Actually in Rust this will panic before that due to the first slice

## References
- Affected file: `src/bin/bounty/commands/validate.rs:11`
- Related bug in status.rs: Bug Report #1
- Rust safe slicing: https://doc.rust-lang.org/std/primitive.str.html#method.get
- SS58 address format: https://docs.substrate.io/reference/address-formats/
