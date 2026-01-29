# Cortex CLI v0.0.5 - Bug Hunt Report

> Bittensor Platform Bounty Challenge - 3 Unique Bugs Identified

---

## Bug #1: GitHub Workflow Install Overwrites Existing File Without Warning

### [BUG] [v0.0.5] `cortex github install` silently overwrites existing Cortex.yml without --force flag

**Description:**

When running `cortex github install` in a repository that already contains a `.github/workflows/Cortex.yml` file (potentially with custom modifications), the command may overwrite the existing file without prompting for confirmation or requiring the `--force` flag.

This leads to loss of custom workflow configurations such as:
- Modified trigger events
- Custom environment variables
- Additional job steps
- Branch-specific filters

**Steps to Reproduce:**

1. Initialize a repository with an existing Cortex workflow:
   ```bash
   mkdir test-repo && cd test-repo
   git init
   mkdir -p .github/workflows
   cat > .github/workflows/Cortex.yml << 'EOF'
   name: Cortex Custom
   on:
     push:
       branches: [main, develop]  # Custom branches
   jobs:
     cortex:
       runs-on: ubuntu-latest
       steps:
         - name: Custom Step
           run: echo "Custom configuration"
   EOF
   ```

2. Run the GitHub install command without `--force`:
   ```bash
   cortex github install
   ```

3. Observe the behavior - check if file was overwritten:
   ```bash
   cat .github/workflows/Cortex.yml
   ```

**Expected Behavior:**

- The CLI should detect the existing `Cortex.yml` file
- Display a warning: `Workflow file already exists at .github/workflows/Cortex.yml`
- Prompt user: `Overwrite existing file? (y/N)` or require `--force` flag
- Show diff of changes if possible
- Exit with non-zero code if user declines

**Actual Behavior:**

The file is overwritten without warning, losing all custom configurations.

**Version:**

- Cortex CLI: v0.0.5
- Installed via: `curl -fsSL https://software.cortex.foundation/install.sh | sh`

**System Information:**

| Component | Value |
|-----------|-------|
| OS | `<OS_NAME>` (e.g., Ubuntu 22.04 / macOS 14.2 / Windows 11) |
| Architecture | `<ARCH>` (e.g., x86_64 / arm64) |
| Shell | `<SHELL>` (e.g., bash 5.1 / zsh 5.9 / PowerShell 7.4) |
| Terminal | `<TERMINAL>` (e.g., iTerm2 / Windows Terminal / Gnome Terminal) |
| Cortex Version | v0.0.5 |
| Installation Method | curl/wget/homebrew/cargo |

**Severity:** Medium - Data loss potential for custom configurations

**Suggested Fix:**

Add file existence check before write operation:
```rust
// Pseudocode
if workflow_path.exists() && !force_flag {
    eprintln!("Error: Workflow file already exists at {}", workflow_path);
    eprintln!("Use --force to overwrite existing file");
    std::process::exit(1);
}
```

---

## Bug #2: Run Command Accepts Invalid Event Types Without Validation

### [BUG] [v0.0.5] `cortex run` does not validate event parameters, causing silent failures

**Description:**

When using `cortex run` with invalid or malformed parameters (such as non-existent model names, invalid temperature values outside 0.0-2.0 range, or unsupported output formats), the CLI either:
1. Silently ignores invalid parameters
2. Crashes with unhelpful stack traces
3. Proceeds with default values without informing the user

This is particularly problematic in CI/CD pipelines where scripts may pass incorrect parameters.

**Steps to Reproduce:**

**Test Case 1 - Invalid Temperature:**
```bash
cortex run --temperature 5.0 "Hello world"
# Expected: Error - temperature must be between 0.0 and 2.0
# Actual: May silently clamp to 2.0 or crash
```

**Test Case 2 - Invalid Model:**
```bash
cortex run --model "nonexistent-model-xyz" "Hello"
# Expected: Error - model 'nonexistent-model-xyz' not found
# Actual: May attempt connection and fail with cryptic API error
```

**Test Case 3 - Conflicting Flags:**
```bash
cortex run --continue --session new-session "Continue previous"
# Expected: Error - cannot use --continue with --session
# Actual: Undefined behavior
```

**Test Case 4 - Invalid File Path:**
```bash
cortex run -f /nonexistent/path/file.txt "Analyze this"
# Expected: Error - file not found at /nonexistent/path/file.txt
# Actual: May crash or send empty content
```

**Expected Behavior:**

- All parameters should be validated before execution
- Clear, actionable error messages for invalid inputs
- Consistent exit codes (1 for validation errors)
- No silent parameter clamping or defaulting

**Actual Behavior:**

Invalid parameters either cause crashes, silent failures, or produce unexpected results.

**Version:**

- Cortex CLI: v0.0.5

**System Information:**

| Component | Value |
|-----------|-------|
| OS | `<OS_NAME>` |
| Architecture | `<ARCH>` |
| Shell | `<SHELL>` |
| Terminal | `<TERMINAL>` |
| Cortex Version | v0.0.5 |
| Installation Method | curl/wget/homebrew/cargo |

**Severity:** High - Can cause CI/CD pipeline failures and debugging difficulties

**Suggested Fix:**

Implement comprehensive input validation layer:
```rust
fn validate_run_params(params: &RunParams) -> Result<(), ValidationError> {
    if params.temperature < 0.0 || params.temperature > 2.0 {
        return Err(ValidationError::new(
            "temperature must be between 0.0 and 2.0"
        ));
    }
    if params.continue_session && params.session.is_some() {
        return Err(ValidationError::new(
            "--continue and --session flags are mutually exclusive"
        ));
    }
    for file in &params.files {
        if !file.exists() {
            return Err(ValidationError::new(
                format!("file not found: {}", file.display())
            ));
        }
    }
    Ok(())
}
```

---

## Bug #3: Configuration Format Inconsistency (TOML vs JSON)

### [BUG] [v0.0.5] Mixed config formats cause parsing errors and data loss during debug operations

**Description:**

Cortex CLI uses inconsistent configuration formats across different subsystems:
- **Main config:** `~/.config/cortex/config.toml` (TOML format)
- **Sessions:** `~/.local/share/cortex/sessions/*.json` (JSON format)
- **Agents:** `.cortex/agents/*.md` or YAML frontmatter (Markdown/YAML)
- **Debug logs:** Various formats in `~/.cache/cortex/logs/`

When using debug commands or exporting/importing configurations, the format mismatches cause:
1. Parsing errors when tools expect one format but receive another
2. Data loss during config migrations
3. Confusion when manually editing configuration files

**Steps to Reproduce:**

**Test Case 1 - Config Export Format Mismatch:**
```bash
# Export configuration
cortex config export > my-config.json

# Try to use exported config (format mismatch)
cp my-config.json ~/.config/cortex/config.toml
cortex run "test"
# Result: TOML parser error on JSON content
```

**Test Case 2 - Session to Config Migration:**
```bash
# View session data (JSON)
cat ~/.local/share/cortex/sessions/session-abc123.json

# Attempt to reference session settings in config.toml
# Manual copy of JSON values to TOML causes syntax errors
```

**Test Case 3 - Debug Mode Config Inspection:**
```bash
cortex config show --debug
# Output format may not match actual file format
# Unable to copy-paste debug output back into config
```

**Expected Behavior:**

- Consistent format across all configuration files (preferably TOML)
- Clear format specification in documentation
- Export/import commands that handle format conversion
- Debug output that matches actual stored format
- Migration utilities for format changes between versions

**Actual Behavior:**

- Multiple formats used without clear documentation
- Export format may not match import expectations
- Manual config editing requires knowledge of multiple formats
- Debug output format is inconsistent

**Version:**

- Cortex CLI: v0.0.5

**System Information:**

| Component | Value |
|-----------|-------|
| OS | `<OS_NAME>` |
| Architecture | `<ARCH>` |
| Shell | `<SHELL>` |
| Terminal | `<TERMINAL>` |
| Cortex Version | v0.0.5 |
| Installation Method | curl/wget/homebrew/cargo |

**Severity:** Medium - Causes confusion and potential data loss

**Configuration Paths Affected:**

| Path | Format | Purpose |
|------|--------|---------|
| `~/.config/cortex/config.toml` | TOML | Main configuration |
| `~/.config/cortex/auth.enc` | Binary/Encrypted | Authentication |
| `~/.local/share/cortex/sessions/` | JSON | Session storage |
| `~/.cortex/agents/` | Markdown+YAML | Agent definitions |
| `~/.cache/cortex/logs/` | Various | Debug logs |

**Suggested Fix:**

1. Standardize on TOML for all human-editable configs
2. Use JSON only for machine-generated data (sessions, cache)
3. Add format conversion in export/import:
   ```bash
   cortex config export --format toml > backup.toml
   cortex config import --format toml backup.toml
   ```
4. Document all configuration formats clearly

---

## Summary Table

| Bug # | Title | Severity | Component |
|-------|-------|----------|-----------|
| #1 | GitHub install overwrites without warning | Medium | `cortex github install` |
| #2 | Invalid event parameters not validated | High | `cortex run` |
| #3 | TOML vs JSON config inconsistency | Medium | Configuration system |

---

## System Information Template

Copy this template and fill in your system details when reporting bugs:

```markdown
**System Information:**

| Component | Value |
|-----------|-------|
| OS | <!-- e.g., Ubuntu 22.04 LTS / macOS Sonoma 14.2 / Windows 11 23H2 --> |
| Architecture | <!-- e.g., x86_64 / arm64 / aarch64 --> |
| CPU | <!-- e.g., Intel i7-12700K / Apple M2 Pro / AMD Ryzen 9 --> |
| RAM | <!-- e.g., 16GB / 32GB --> |
| Shell | <!-- e.g., bash 5.2.15 / zsh 5.9 / PowerShell 7.4.1 --> |
| Terminal | <!-- e.g., iTerm2 3.4 / Windows Terminal 1.18 / Alacritty 0.13 --> |
| Cortex Version | v0.0.5 |
| Installation Method | <!-- curl / wget / homebrew / cargo / manual --> |
| Node.js (if applicable) | <!-- e.g., v20.10.0 --> |
| Rust (if applicable) | <!-- e.g., 1.75.0 --> |
```

**To get system info automatically:**
```bash
echo "OS: $(uname -s) $(uname -r)"
echo "Arch: $(uname -m)"
echo "Shell: $SHELL --version"
cortex --version 2>/dev/null || echo "Cortex: not installed"
```

---

*Report generated for Bittensor Platform Bounty Challenge*
*Cortex CLI Version: v0.0.5*
*Date: 2026-01-29*
