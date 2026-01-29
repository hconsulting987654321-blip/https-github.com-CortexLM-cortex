# [BUG] [v0.0.6] Version Examples Use Outdated Version Number (0.0.1c vs Current 0.0.6)

## Description
The README.md documentation shows `0.0.1c` as the example version for specific version installation, but the current released version is `0.0.6`. This creates confusion for users who may think `0.0.1c` is the latest or recommended version, or wonder why the example uses such an old version number with an unusual suffix format (`c`).

## Location
- **File**: README.md
- **Section**: Installation > Install a specific version
- **Line**: Approximately line 30-38

## Steps to Reproduce
1. Read the README.md "Install a specific version" section
2. Note the example uses `CORTEX_VERSION=0.0.1c`
3. Run the installation script normally
4. Observe that version `0.0.6` is installed (not `0.0.1c`)
5. Check CHANGELOG.md which shows versions `0.0.5` with no mention of `0.0.1c`

## Expected Behavior
The documentation should use a recent, valid version number in examples that:
- Matches an actual released version
- Is close to the current version
- Uses consistent versioning format (semantic versioning without letter suffixes)

Example with current version:
```bash
CORTEX_VERSION=0.0.5 curl -fsSL https://software.cortex.foundation/install.sh | sh
```

## Actual Behavior
The documentation shows:
```bash
# Linux & macOS
CORTEX_VERSION=0.0.1c curl -fsSL https://software.cortex.foundation/install.sh | sh

# Windows PowerShell
$env:CORTEX_VERSION="0.0.1c"; irm https://software.cortex.foundation/install.ps1 | iex
```

Issues with this:
1. Version `0.0.1c` is significantly older than current `0.0.6`
2. The `c` suffix is unusual and doesn't appear in CHANGELOG.md
3. Users may accidentally install an outdated version by copying the example
4. Creates inconsistency between documentation and actual releases

## System Information
- **Documentation Version**: Current main branch (commit as of 2026-01-29)
- **Date Checked**: 2026-01-29
- **Current CLI Version**: v0.0.6 (from installer)
- **CHANGELOG Latest Version**: 0.0.5

## Impact
- **Severity**: Medium
- **Affected Users**: Users who want to install a specific version
- **Consequence**:
  - Users may install severely outdated version by copying the example
  - Confusion about versioning scheme (what does `c` suffix mean?)
  - Version mismatch between README example and CHANGELOG
  - Poor user experience when example doesn't reflect current state

## Suggested Fix
Update the version examples to use a recent valid version:

```diff
### Install a specific version

```bash
# Linux & macOS
- CORTEX_VERSION=0.0.1c curl -fsSL https://software.cortex.foundation/install.sh | sh
+ CORTEX_VERSION=0.0.5 curl -fsSL https://software.cortex.foundation/install.sh | sh

# Windows PowerShell
- $env:CORTEX_VERSION="0.0.1c"; irm https://software.cortex.foundation/install.ps1 | iex
+ $env:CORTEX_VERSION="0.0.5"; irm https://software.cortex.foundation/install.ps1 | iex
```

Alternatively, use a placeholder that indicates it's an example:
```bash
CORTEX_VERSION=<version> curl -fsSL https://software.cortex.foundation/install.sh | sh
# Example: CORTEX_VERSION=0.0.5 curl -fsSL ...
```

## Evidence
From README.md "Install a specific version" section:
> ```bash
> # Linux & macOS
> CORTEX_VERSION=0.0.1c curl -fsSL https://software.cortex.foundation/install.sh | sh
> ```

From CHANGELOG.md (latest entry):
> ## 0.0.5
>
> ### Added
> - Added interactive /agents command...

From actual installation:
```
$ curl -sSL https://software.cortex.foundation/install.sh | bash
...
==> Installing Cortex CLI v0.0.6
...
==> Cortex CLI v0.0.6 installed successfully!
```

Version comparison:
| Source | Version | Notes |
|--------|---------|-------|
| README example | 0.0.1c | Outdated, unusual suffix |
| CHANGELOG latest | 0.0.5 | Documented release |
| Actual installer | 0.0.6 | Current release |

## References
- https://github.com/CortexLM/cortex/blob/main/README.md#install-a-specific-version
- https://github.com/CortexLM/cortex/blob/main/CHANGELOG.md
- Semantic Versioning specification: https://semver.org/
