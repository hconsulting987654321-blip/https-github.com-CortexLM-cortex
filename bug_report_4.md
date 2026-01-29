# [BUG] [v0.0.5] Registration Wizard Uses Unsafe unwrap() on Progress Bar Template That Can Panic

## Description
The registration wizard in `src/bin/bounty/wizard/register_wizard.rs` uses `.unwrap()` on a `ProgressStyle::template()` call at line 115. While the current template string is valid, this pattern is unsafe because:

1. If the template format ever changes or gets corrupted, the application will panic
2. The `unwrap()` provides no context about what went wrong
3. This occurs during a critical user flow (registration), making it especially disruptive
4. The pattern violates Rust best practices for error handling in user-facing applications

Additionally, the code performs multiple unsafe hotkey slicing operations (lines 44-45, 92-93, 170) that assume the hotkey is at least 16 characters without validation.

## Steps to Reproduce

### For Progress Bar Issue:
The current template is valid, so the panic won't occur under normal circumstances. However, the bug can be demonstrated by:

1. Modify the template string to be invalid:
   ```rust
   // In register_wizard.rs line 114
   .template("  {invalid_placeholder} {msg}")  // Invalid placeholder
   .unwrap()  // Will panic
   ```

2. Run the wizard:
   ```bash
   bounty wizard
   ```

3. Observe panic when progress bar is created

### For Hotkey Slicing Issue:
1. The wizard derives the hotkey from the secret key, so direct testing is harder
2. However, if key parsing produces a shorter-than-expected SS58 address, it will panic

## Expected Behavior
The application should handle template errors gracefully:

```rust
// Use expect() with context or proper error handling
let style = ProgressStyle::default_spinner()
    .template("  {spinner:.cyan} {msg}")
    .expect("Built-in progress bar template should be valid");

// Or use ? operator with proper error context
let style = ProgressStyle::default_spinner()
    .template("  {spinner:.cyan} {msg}")
    .context("Failed to create progress bar template")?;
```

For hotkey display, validate before slicing:
```rust
if hotkey.len() >= 12 {
    println!("Hotkey: {}...{}", &hotkey[..8], &hotkey[hotkey.len() - 4..]);
} else {
    println!("Hotkey: {} (invalid format)", hotkey);
}
```

## Actual Behavior
The code at `src/bin/bounty/wizard/register_wizard.rs:111-116`:

```rust
let pb = ProgressBar::new_spinner();
pb.set_style(
    ProgressStyle::default_spinner()
        .template("  {spinner:.cyan} {msg}")
        .unwrap(),  // <-- Panic point if template is invalid
);
```

Additional unsafe slicing at lines 44-45:
```rust
style(&hotkey[..8]).cyan(),      // Panics if hotkey < 8 chars
style(&hotkey[hotkey.len() - 4..]).cyan()  // Panics if hotkey < 4 chars
```

At lines 92-93:
```rust
&hotkey[..12],           // Panics if hotkey < 12 chars
&hotkey[hotkey.len() - 4..]  // Panics if hotkey < 4 chars
```

At line 170:
```rust
&hotkey[..16]  // Panics if hotkey < 16 chars
```

## System Information
- **OS**: Ubuntu 22.04 LTS
- **Architecture**: x86_64
- **Rust Version**: rustc 1.75.0
- **Bounty CLI Version**: v0.0.5
- **Shell**: bash 5.1

## Impact
- **Severity**: Medium (Progress Bar) / High (Hotkey Slicing)
- **Affected Users**: All users going through registration wizard
- **Consequences**:
  - **Immediate crash** if template validation fails
  - **Lost registration progress** - users must restart the wizard
  - **Poor error messages** - panic backtraces are not user-friendly
  - **Maintenance risk** - future template changes could introduce crashes
  - **Security concern** - predictable panics can be exploited for DoS

## Suggested Fix

### Fix 1: Use expect() with Meaningful Message
```rust
let pb = ProgressBar::new_spinner();
pb.set_style(
    ProgressStyle::default_spinner()
        .template("  {spinner:.cyan} {msg}")
        .expect("Internal error: invalid progress bar template"),
);
```

### Fix 2: Use Proper Error Handling with ?
```rust
let pb = ProgressBar::new_spinner();
let style = ProgressStyle::default_spinner()
    .template("  {spinner:.cyan} {msg}")
    .map_err(|e| anyhow::anyhow!("Failed to create progress bar: {}", e))?;
pb.set_style(style);
```

### Fix 3: Use Default Fallback
```rust
let pb = ProgressBar::new_spinner();
let style = ProgressStyle::default_spinner()
    .template("  {spinner:.cyan} {msg}")
    .unwrap_or_else(|_| ProgressStyle::default_spinner());
pb.set_style(style);
```

### Fix 4: Create Safe Hotkey Display Helper
```rust
fn safe_hotkey_display(hotkey: &str, prefix_len: usize, suffix_len: usize) -> String {
    let min_len = prefix_len + suffix_len;
    if hotkey.len() >= min_len {
        format!("{}...{}",
            &hotkey[..prefix_len],
            &hotkey[hotkey.len() - suffix_len..])
    } else {
        format!("{} (invalid)", hotkey)
    }
}

// Usage:
println!("Hotkey: {}", safe_hotkey_display(&hotkey, 8, 4));
```

### Fix 5: Comprehensive Fix for register_wizard.rs
```rust
// At the top of the file, add helper
fn display_hotkey(hotkey: &str) -> String {
    if hotkey.len() >= 16 {
        format!("{}...{}", &hotkey[..8], &hotkey[hotkey.len() - 4..])
    } else {
        hotkey.to_string()
    }
}

// Line 44-45: Replace with
style(&display_hotkey(&hotkey)).cyan()

// Line 92-93: Replace with
println!("  Hotkey:   {}", display_hotkey(&hotkey));

// Line 170: Replace with
style(format!("bounty status --hotkey {}",
    if hotkey.len() >= 16 { &hotkey[..16] } else { &hotkey }
)).yellow()
```

## Additional Context

### Why This Matters for Production Code

1. **Rust's `unwrap()` is a code smell in user-facing code**
   - It signals "I don't care if this fails" which is inappropriate for production
   - The Rust community recommends `expect()` at minimum for documentation

2. **The indicatif crate's template system**
   - Templates can fail if placeholders are misspelled
   - Template syntax may change between versions
   - Custom templates are more prone to errors

3. **Defense in Depth**
   - Even if the template is currently valid, defensive coding prevents future bugs
   - Code review and refactoring can inadvertently break templates

### Audit of All unwrap() Calls in register_wizard.rs

| Line | Code | Risk |
|------|------|------|
| 115 | `.template(...).unwrap()` | Medium - template validation |
| 44 | `&hotkey[..8]` | High - bounds check |
| 45 | `&hotkey[hotkey.len() - 4..]` | High - bounds check |
| 92 | `&hotkey[..12]` | High - bounds check |
| 93 | `&hotkey[hotkey.len() - 4..]` | High - bounds check |
| 170 | `&hotkey[..16]` | High - bounds check |

### Related Clippy Lints
- `clippy::unwrap_used` - Warns on unwrap() usage
- `clippy::expect_used` - Warns on expect() in library code
- Consider adding `#![deny(clippy::unwrap_used)]` to enforce this

## References
- Affected file: `src/bin/bounty/wizard/register_wizard.rs:115`
- indicatif template documentation: https://docs.rs/indicatif/latest/indicatif/style/struct.ProgressStyle.html
- Rust error handling best practices: https://doc.rust-lang.org/book/ch09-00-error-handling.html
- Clippy unwrap lint: https://rust-lang.github.io/rust-clippy/master/index.html#unwrap_used
