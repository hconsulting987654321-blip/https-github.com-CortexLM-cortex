# [BUG] [v0.0.5] Critical Version Inconsistency Between README and CHANGELOG

## Description
The Cortex CLI documentation contains a critical version mismatch that causes significant user confusion and potential installation failures. The README.md references version `0.0.1c` in the version-specific installation examples, while the CHANGELOG.md documents version `0.0.5` as the current release. This inconsistency means:

- Users following the README will attempt to install an outdated or non-existent version
- New contributors cannot determine the actual current version
- The version-specific installation command will fail or install wrong version
- Trust in the project's documentation is undermined

## Steps to Reproduce
1. Navigate to the Cortex GitHub repository: https://github.com/CortexLM/cortex
2. Open the README.md file and locate the "Version-Specific Installation" section
3. Note the version shown: `CORTEX_VERSION=0.0.1c`
4. Open the CHANGELOG.md file
5. Note the documented version: `## [0.0.5]`
6. Observe the version mismatch between the two files

## Expected Behavior
The README.md version-specific installation example should reference the same version documented in CHANGELOG.md. Both files should consistently show:
```bash
CORTEX_VERSION=0.0.5 curl -fsSL https://software.cortex.foundation/install.sh | sh
```

## Actual Behavior
README.md shows outdated version in example:
```bash
# What README.md currently shows:
CORTEX_VERSION=0.0.1c curl -fsSL https://software.cortex.foundation/install.sh | sh

# What CHANGELOG.md documents as current:
## [0.0.5]
```

Users attempting version-specific installation with `0.0.1c` may:
- Download an outdated build
- Receive a 404 error if 0.0.1c assets don't exist
- Miss all features and fixes documented in v0.0.5 CHANGELOG

## System Information
- **OS**: All platforms (Linux, macOS, Windows)
- **Architecture**: All architectures (x86_64, ARM64, Apple Silicon)
- **Shell**: All shells (bash, zsh, PowerShell)
- **Cortex Version**: v0.0.5 (documented) vs v0.0.1c (README example)
- **Installation Method**: Version-specific curl/wget installation

## Impact
- **Severity**: High
- **Affected Users**: All users attempting version-specific installation
- **Consequences**:
  - New users may install outdated version missing 25+ features and 30+ bug fixes
  - Version-specific installation may fail entirely if 0.0.1c assets are removed
  - Contributors cannot reliably determine which version to test against
  - Documentation credibility is compromised
  - Bug reports may reference wrong versions, complicating triage

## Suggested Fix
Update README.md version-specific installation section to reference v0.0.5:

```diff
### Version-Specific Installation
-CORTEX_VERSION=0.0.1c curl -fsSL https://software.cortex.foundation/install.sh | sh
+CORTEX_VERSION=0.0.5 curl -fsSL https://software.cortex.foundation/install.sh | sh

# Windows PowerShell
-$env:CORTEX_VERSION="0.0.1c"; irm https://software.cortex.foundation/install.ps1 | iex
+$env:CORTEX_VERSION="0.0.5"; irm https://software.cortex.foundation/install.ps1 | iex
```

Additionally, consider:
1. Adding a VERSION file at repository root for single source of truth
2. Implementing CI checks to validate version consistency across docs
3. Using variable substitution in docs to auto-update version references

## Additional Context
The version jump from 0.0.1c to 0.0.5 suggests several intermediate versions may have existed but aren't documented. The CHANGELOG only documents v0.0.5 with no history of previous releases. This lack of version history compounds the confusion.

The README also shows copyright "2025 Cortex Foundation" while the CLAUDE.md shows "Last updated: 2026-01-29", suggesting documentation may be from different time periods without proper synchronization.

## References
- README.md: https://github.com/CortexLM/cortex/blob/main/README.md
- CHANGELOG.md: https://github.com/CortexLM/cortex/blob/main/CHANGELOG.md
- Semantic Versioning specification: https://semver.org/
