# [BUG] [v0.1.0] Documentation Version Inconsistencies Cause User Confusion

## Description

The README.md documentation contains multiple version inconsistencies that confuse users about which version they are running and what version to include in bug reports. The actual CLI version is `v0.1.0` (from Cargo.toml), but the README references `v0.0.5`, `v0.1.5`, and `v0.2.0` in examples.

Additionally, the command example for checking the version is incorrect.

## Steps to Reproduce

1. Check the actual CLI version:
```bash
bounty --version
```
Output: `bounty 0.1.0`

2. Check Cargo.toml:
```bash
grep "^version" Cargo.toml
```
Output: `version = "0.1.0"`

3. Review README.md examples (lines 209-211):
```markdown
- `[BUG] [v0.1.5] CLI crashes on startup`
- `[FEATURE] [v0.2.0] Add export to JSON`
- `[PERF] [v0.1.5] Slow response time on leaderboard`
```

4. Review README.md line 213:
```markdown
To find your version, run: `[app cli --version]`
```

This command is incorrect - the actual command is `bounty --version`.

## Expected Behavior

Documentation should accurately reflect the current version (`v0.1.0`) and provide correct command examples:
- Issue title examples should use `[v0.1.0]`
- Version check command should be `bounty --version`

## Actual Behavior

- README examples show non-existent versions (`v0.0.5`, `v0.1.5`, `v0.2.0`)
- Version check command is wrong: `[app cli --version]` instead of `bounty --version`
- Users submitting bug reports may use incorrect version numbers
- Maintainers cannot properly triage issues by version

## System Information

- **OS**: Ubuntu 22.04 LTS
- **Architecture**: x86_64
- **Rust Version**: rustc 1.75.0
- **Bounty CLI Version**: v0.1.0

## Impact

- **Severity**: Medium
- Users following documentation will submit issues with wrong version tags
- Issue triage becomes difficult when version numbers are fictional
- Users trying `[app cli --version]` will get "command not found" errors
- Professional credibility of the project is diminished

## Suggested Fix

Update README.md with correct version references:

**Line 209-211 (Issue Title Format examples):**
```markdown
Examples:
- `[BUG] [v0.1.0] CLI crashes on startup`
- `[FEATURE] [v0.1.0] Add export to JSON`
- `[PERF] [v0.1.0] Slow response time on leaderboard`
```

**Line 213 (Version check command):**
```markdown
To find your version, run: `bounty --version`
```

Consider also adding a pre-release workflow that automatically updates version references in documentation when bumping versions.

## References

- README.md lines 209-213: Incorrect version examples
- Cargo.toml line 4: Actual version (`version = "0.1.0"`)
- CLI main.rs line 22: `const VERSION: &str = env!("CARGO_PKG_VERSION");`
