# [BUG] [v0.0.5] Hardcoded Wrong Repository URL Directs Users to Create Issues in Wrong Location

## Description
The CLI registration command and configuration display hardcode the wrong repository URL (`CortexLM/fabric`), directing users to create issues in a repository that doesn't count toward bounty rewards. According to the README, issues MUST be submitted to `PlatformNetwork/bounty-challenge` to receive rewards, but the CLI instructs users to submit to `CortexLM/fabric`.

This is a critical bug because:
- Users following CLI instructions will create issues in the wrong repository
- These issues will NOT count toward their bounty rewards
- Users will waste time and effort with no compensation
- The misdirection undermines the entire bounty system

## Steps to Reproduce
1. Build and install the bounty CLI:
   ```bash
   cd bounty-challenge
   cargo build --release
   export PATH="$PWD/target/release:$PATH"
   ```

2. Run the registration command (or complete registration):
   ```bash
   bounty register --hotkey YOUR_HOTKEY
   ```

3. After successful registration, observe the "Next steps" output

4. Alternatively, run the config command:
   ```bash
   bounty config
   ```

5. Observe the wrong repository URL in the output

## Expected Behavior
After registration, the CLI should direct users to the correct repository:
```
Next steps:
  1. Create issues on https://github.com/PlatformNetwork/bounty-challenge/issues
  2. Wait for maintainers to validate with 'valid' label
  3. Bounties are credited automatically!
```

The config command should show:
```
Target Repository:
  https://github.com/PlatformNetwork/bounty-challenge
```

## Actual Behavior

### In register.rs (lines 99-101):
```
Next steps:
  1. Create issues on https://github.com/CortexLM/fabric/issues  <-- WRONG
  2. Wait for maintainers to validate with 'valid' label
  3. Bounties are credited automatically!
```

### In config.rs (line 57):
```
Target Repository:
  https://github.com/CortexLM/fabric  <-- WRONG
```

### In lib.rs (lines 4, 10):
```rust
//! in the CortexLM/fabric repository.  <-- WRONG in documentation
// ...
//! 2. Miners create issues on CortexLM/fabric  <-- WRONG
```

## System Information
- **OS**: Ubuntu 22.04 LTS
- **Architecture**: x86_64
- **Rust Version**: rustc 1.75.0
- **Bounty CLI Version**: v0.0.5
- **Shell**: bash 5.1

## Impact
- **Severity**: Critical
- **Affected Users**: ALL miners who complete registration and follow CLI instructions
- **Consequences**:
  - **Lost rewards**: Issues created in CortexLM/fabric don't count for bounties
  - **Wasted effort**: Users spend time writing quality bug reports with no compensation
  - **Confusion**: Contradicts README which clearly states correct repository
  - **Trust damage**: Users who discover the error may lose confidence in the project
  - **Support burden**: Influx of "why aren't my issues counting?" questions

### README vs CLI Contradiction

| Source | Repository Shown | Correct? |
|--------|-----------------|----------|
| README.md (line 19) | `PlatformNetwork/bounty-challenge` | Yes |
| README.md (line 154) | `PlatformNetwork/bounty-challenge` | Yes |
| README.md (line 219) | `PlatformNetwork/bounty-challenge` | Yes |
| register.rs (line 101) | `CortexLM/fabric` | **NO** |
| config.rs (line 57) | `CortexLM/fabric` | **NO** |
| lib.rs (line 4) | `CortexLM/fabric` | **NO** |
| register_wizard.rs (line 159) | `PlatformNetwork/bounty-challenge` | Yes |

## Suggested Fix

### Fix 1: Update register.rs (lines 99-101)
```diff
println!("Next steps:");
println!(
    "  1. Create issues on {}",
-   style_cyan("https://github.com/CortexLM/fabric/issues")
+   style_cyan("https://github.com/PlatformNetwork/bounty-challenge/issues")
);
```

### Fix 2: Update config.rs (line 57)
```diff
println!("{}", style_bold("Target Repository:"));
-println!("  https://github.com/CortexLM/fabric");
+println!("  https://github.com/PlatformNetwork/bounty-challenge");
```

### Fix 3: Update lib.rs documentation
```diff
//! This challenge incentivizes the discovery and reporting of valid bugs
-//! in the CortexLM/fabric repository. Miners earn rewards for submitting
+//! in the CortexLM/cortex repository. Issues must be submitted to
+//! PlatformNetwork/bounty-challenge to earn rewards.

// ...

-//! 2. Miners create issues on CortexLM/fabric
+//! 2. Miners analyze CortexLM/cortex and submit issues to PlatformNetwork/bounty-challenge
```

### Fix 4: Centralize Repository Configuration
Create a constants file to avoid future inconsistencies:

```rust
// src/constants.rs
pub const TARGET_REPO: &str = "CortexLM/cortex";
pub const BOUNTY_REPO: &str = "PlatformNetwork/bounty-challenge";
pub const BOUNTY_ISSUES_URL: &str = "https://github.com/PlatformNetwork/bounty-challenge/issues";
```

Then use these constants throughout the codebase instead of hardcoded strings.

## Additional Context

### The Actual Bounty Flow (per README)
1. Analyze bugs in **CortexLM/cortex** (the target repository)
2. Submit bug reports to **PlatformNetwork/bounty-challenge** (this repository)
3. Wait for `valid` label from maintainers
4. Receive TAO rewards

### Why CortexLM/fabric is Wrong
- `CortexLM/fabric` is a different repository entirely
- It may not even have the bounty system configured
- Issues there won't be scanned by the bounty challenge validator
- The maintainers there may not use the `valid` label system

### Affected User Journey
```
User registers successfully
    ↓
CLI shows "Create issues on CortexLM/fabric"
    ↓
User creates quality bug report on CortexLM/fabric
    ↓
Issue may or may not be reviewed (different project)
    ↓
No bounty reward (wrong repo)
    ↓
User checks status: "No valid bounties"
    ↓
User is confused and frustrated
```

## References
- Affected files:
  - `src/bin/bounty/commands/register.rs:101`
  - `src/bin/bounty/commands/config.rs:57`
  - `src/lib.rs:4,10`
- README documentation: https://github.com/PlatformNetwork/bounty-challenge#where-to-submit-issues
- Note: `register_wizard.rs:159` correctly shows `PlatformNetwork/bounty-challenge`
