# [BUG] [v0.1.0] CLI Panics on Short Hotkey Input in Status Command

## Description

The `bounty status` command crashes with a panic when provided with a hotkey shorter than 8 characters. The code attempts to slice the hotkey string without validating its length first, causing an out-of-bounds panic that terminates the application.

This is a critical denial-of-service vulnerability in the CLI that affects all users who mistype their hotkey or accidentally provide invalid input.

## Steps to Reproduce

1. Build the bounty CLI:
```bash
git clone https://github.com/PlatformNetwork/bounty-challenge.git
cd bounty-challenge
cargo build --release
export PATH="$PWD/target/release:$PATH"
```

2. Run the status command with a short hotkey:
```bash
bounty status --hotkey "short"
```

3. Observe the panic:
```
[1mMiner Status[0m
────────────

thread 'main' panicked at src/bin/bounty/commands/status.rs:9:40:
byte index 8 is out of bounds of `short`
```

## Expected Behavior

The CLI should validate the hotkey format and length before attempting to use it, displaying a helpful error message like:
```
Error: Invalid hotkey format. Expected SS58-encoded address (47-48 characters).
```

## Actual Behavior

The CLI panics with an unhandled error:
```
thread 'main' panicked at src/bin/bounty/commands/status.rs:9:40:
byte index 8 is out of bounds of `short`
stack backtrace:
   0: __rustc::rust_begin_unwind
   1: core::panicking::panic_fmt
   2: core::str::slice_error_fail_rt
   3: core::str::slice_error_fail
   4: bounty::main::{{closure}}
```

The application terminates with exit code 101.

## System Information

- **OS**: Ubuntu 22.04 LTS
- **Architecture**: x86_64
- **Rust Version**: rustc 1.75.0
- **Bounty CLI Version**: v0.1.0

## Impact

- **Severity**: High
- Any user who accidentally provides a malformed or short hotkey will experience an unexpected crash
- Poor user experience - panics are confusing for non-technical users
- The panic message exposes internal file paths and stack traces
- No graceful error recovery possible

## Suggested Fix

Add length validation before slicing the hotkey string in `src/bin/bounty/commands/status.rs`:

```rust
pub async fn run(rpc: &str, hotkey: &str) -> Result<()> {
    print_header("Miner Status");

    // Validate hotkey length before slicing
    if hotkey.len() < 12 {
        anyhow::bail!("Invalid hotkey format. Expected SS58-encoded address (47-48 characters), got {} characters.", hotkey.len());
    }

    // Also validate it's a proper SS58 address
    if !crate::auth::is_valid_ss58_hotkey(hotkey) {
        anyhow::bail!("Invalid hotkey format. Expected valid SS58-encoded sr25519 public key.");
    }

    println!("Hotkey: {}...{}", &hotkey[..8], &hotkey[hotkey.len() - 4..]);
    // ... rest of function
}
```

The `auth.rs` module already has an `is_valid_ss58_hotkey()` function that should be used for validation.

## References

- Vulnerable code: `src/bin/bounty/commands/status.rs:9`
- Existing validation helper: `src/auth.rs:12-17` (`is_valid_ss58_hotkey`)
- Similar safe slicing in `leaderboard.rs:46-49` (checks length first)
