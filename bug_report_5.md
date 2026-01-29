# [BUG] [v0.0.5] README Contains Placeholder Text and Incorrect Version Command Instructions

## Description
The README.md documentation contains unresolved placeholder text and incorrect command examples that confuse users trying to follow the bounty submission process. Specifically:

1. **Line 213**: Contains placeholder `[app cli --version]` instead of the actual command `bounty --version`
2. **Line 209**: Shows version format `[v0.1.5]` in example titles, but the actual CLI version and expected format may differ
3. **Version inconsistency**: Examples use `v0.1.5` and `v0.2.0` but the CLI version may be `v0.0.5`

This causes significant user confusion because:
- Users cannot find their version using the documented command
- Issue titles may use wrong version format
- Submissions may be rejected for incorrect formatting

## Steps to Reproduce
1. Clone the repository and build the CLI:
   ```bash
   git clone https://github.com/PlatformNetwork/bounty-challenge.git
   cd bounty-challenge
   cargo build --release
   export PATH="$PWD/target/release:$PATH"
   ```

2. Follow README instructions to find version (line 213):
   ```bash
   [app cli --version]  # This is literally what the README says
   ```

3. Observe the error - this is not a valid command

4. Try to guess the correct command:
   ```bash
   bounty --version
   ```

5. Compare the actual version with the examples in README (v0.1.5, v0.2.0)

## Expected Behavior
The README should contain actual, working commands:

```markdown
To find your version, run: `bounty --version`
```

And examples should use realistic/current version numbers:

```markdown
Examples:
- `[BUG] [v0.0.5] CLI crashes on startup`
- `[FEATURE] [v0.0.5] Add export to JSON`
```

## Actual Behavior
README.md line 213 contains:
```markdown
To find your version, run: `[app cli --version]`
```

This is clearly a placeholder that was never replaced with the actual command.

README.md lines 208-211 show:
```markdown
Examples:
- `[BUG] [v0.1.5] CLI crashes on startup`
- `[FEATURE] [v0.2.0] Add export to JSON`
- `[PERF] [v0.1.5] Slow response time on leaderboard`
```

These version numbers (`v0.1.5`, `v0.2.0`) may not match the actual CLI version.

## System Information
- **OS**: Ubuntu 22.04 LTS
- **Architecture**: x86_64
- **Rust Version**: rustc 1.75.0
- **Bounty CLI Version**: v0.0.5
- **Shell**: bash 5.1

## Impact
- **Severity**: Medium
- **Affected Users**: All new users following the README to submit issues
- **Consequences**:
  - **Command confusion**: Users cannot find their version
  - **Rejected submissions**: Issues with wrong version format may be auto-closed
  - **Lost bounties**: Invalid submissions don't count toward rewards
  - **Unprofessional appearance**: Placeholder text suggests incomplete documentation
  - **Support burden**: Users will ask "what's the version command?"

## Suggested Fix

### Fix 1: Replace Placeholder with Actual Command (Line 213)
```diff
-To find your version, run: `[app cli --version]`
+To find your version, run: `bounty --version`
```

### Fix 2: Update Example Versions to Match Current Release
```diff
Examples:
-- `[BUG] [v0.1.5] CLI crashes on startup`
-- `[FEATURE] [v0.2.0] Add export to JSON`
-- `[PERF] [v0.1.5] Slow response time on leaderboard`
+- `[BUG] [v0.0.5] CLI crashes on startup`
+- `[FEATURE] [v0.0.5] Add export to JSON`
+- `[PERF] [v0.0.5] Slow response time on leaderboard`
```

### Fix 3: Add Version Discovery Section
Add a dedicated section explaining how to find versions:

```markdown
### Finding Your Version

The version should be included in all issue titles. Find your version:

**For bounty CLI:**
```bash
bounty --version
# Output: bounty-challenge 0.0.5
```

**For Cortex CLI (if analyzing Cortex bugs):**
```bash
cortex --version
```

**Format:** Use the format `[v0.0.5]` (lowercase 'v', three-part version number)
```

### Fix 4: Add Version Validation CI
Consider adding a GitHub Action to validate issue titles:

```yaml
# .github/workflows/validate-issue.yml
name: Validate Issue Title
on:
  issues:
    types: [opened, edited]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Check title format
        uses: actions/github-script@v6
        with:
          script: |
            const title = context.payload.issue.title;
            const pattern = /^\[(BUG|FEATURE|PERF|DOCS)\] \[v\d+\.\d+\.\d+\]/;
            if (!pattern.test(title)) {
              core.setFailed('Issue title must match format: [TYPE] [vX.X.X] Description');
            }
```

## Additional Context

### Full Audit of README Documentation Issues

| Line | Issue | Current | Should Be |
|------|-------|---------|-----------|
| 213 | Placeholder text | `[app cli --version]` | `bounty --version` |
| 209 | Version mismatch | `v0.1.5` | Current version |
| 210 | Version mismatch | `v0.2.0` | Current version |
| 211 | Version mismatch | `v0.1.5` | Current version |

### Why This Matters

1. **Issue Validation**: The README states issues without version will be auto-closed:
   > **IMPORTANT**: You MUST include the version in your issue title. Issues without a version will be automatically closed.

2. **User Journey Breakdown**:
   ```
   User reads README
       ↓
   Sees "[app cli --version]"
       ↓
   Types this literally → Error
       ↓
   Guesses "bounty --version" → Maybe works
       ↓
   Uses example version "v0.1.5" → Maybe wrong
       ↓
   Issue rejected or marked invalid
       ↓
   No bounty reward
   ```

3. **Documentation Quality**: Placeholder text suggests the documentation was templated and not fully customized for this project.

### Other Potential Documentation Issues to Review

- [ ] Are all command examples tested and working?
- [ ] Do environment variable names match the code?
- [ ] Are API endpoints documented correctly?
- [ ] Do the mermaid diagrams render correctly?

## References
- Affected file: `README.md:213`
- Issue title format documentation: `README.md:206-211`
- GitHub Actions for issue validation: https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#issues
