# [BUG] [v0.0.5] No GitHub Releases Despite CHANGELOG Documenting Version 0.0.5

## Description
The Cortex repository has a detailed CHANGELOG.md documenting version 0.0.5 with 25+ added features, 30+ bug fixes, and multiple changes, yet the GitHub Releases page shows "There aren't any releases here." This creates a significant disconnect between documented versions and actual distributable releases.

This bug prevents users from:
- Downloading verified, tagged release assets
- Accessing release notes through GitHub's standard interface
- Comparing changes between versions
- Installing specific versions with confidence
- Verifying the authenticity of downloaded binaries

## Steps to Reproduce
1. Navigate to the Cortex GitHub repository: https://github.com/CortexLM/cortex
2. Click on "Releases" in the right sidebar (or navigate to /releases)
3. Observe the message: "There aren't any releases here"
4. Navigate to CHANGELOG.md: https://github.com/CortexLM/cortex/blob/main/CHANGELOG.md
5. Observe detailed documentation for version 0.0.5
6. Note the contradiction: documented releases exist, but no actual GitHub releases

## Expected Behavior
For each version documented in CHANGELOG.md, there should be a corresponding GitHub Release containing:
- Git tag matching the version (e.g., `v0.0.5`)
- Release notes (can mirror CHANGELOG content)
- Binary assets for all supported platforms:
  - Linux x86_64
  - Linux ARM64
  - macOS Intel
  - macOS Apple Silicon
  - Windows x86_64
  - Windows ARM64
- SHA256 checksums for verification

Example of expected release structure:
```
v0.0.5
  - cortex-linux-x86_64.tar.gz
  - cortex-linux-aarch64.tar.gz
  - cortex-darwin-x86_64.tar.gz
  - cortex-darwin-aarch64.tar.gz
  - cortex-windows-x86_64.zip
  - cortex-windows-aarch64.zip
  - checksums.txt
```

## Actual Behavior
GitHub Releases page displays:
```
There aren't any releases here
You can create a release to package software, along with release notes
and links to binary files, for other people to use.
```

Meanwhile, CHANGELOG.md documents an extensive v0.0.5 release:
```markdown
## [0.0.5]

### Added
- interactive /agents command for agent management with full TUI support
- interactive /mcp panel for centralized MCP server management
- multi-step wizard for adding MCP servers
[... 25+ more features ...]

### Fixed
- agent creation automation with --generate flag
- subagent iteration limit increased from 10 to 500
[... 30+ more fixes ...]

### Changed
- MCP management converted from popup modal to inline card UI
[... multiple changes ...]
```

## System Information
- **OS**: All platforms (issue affects GitHub web interface)
- **Architecture**: All architectures
- **Shell**: N/A (browser-based issue)
- **Cortex Version**: v0.0.5 (documented but not released)
- **Installation Method**: Users cannot use GitHub Releases (forced to use external CDN)

## Impact
- **Severity**: High
- **Affected Users**: All users, especially enterprise/security-conscious users
- **Consequences**:
  - **No version verification**: Users cannot verify downloaded binary authenticity
  - **No rollback capability**: Cannot easily download previous versions
  - **Security concerns**: Binaries only available from external CDN without GitHub's trust anchor
  - **Enterprise blockers**: Many organizations require GitHub Releases for audit trails
  - **CI/CD complications**: Automated deployment pipelines cannot reference stable releases
  - **No git tags**: Cannot checkout specific versions of the source code
  - **Contributor confusion**: Cannot determine which commit corresponds to v0.0.5

## Suggested Fix

### 1. Create GitHub Release for v0.0.5
```bash
# Tag the release commit
git tag -a v0.0.5 -m "Release v0.0.5"

# Push tag to GitHub
git push origin v0.0.5
```

### 2. Create Release with Assets
Use GitHub CLI or web interface:
```bash
gh release create v0.0.5 \
  --title "Cortex CLI v0.0.5" \
  --notes-file CHANGELOG.md \
  ./dist/cortex-linux-x86_64.tar.gz \
  ./dist/cortex-linux-aarch64.tar.gz \
  ./dist/cortex-darwin-x86_64.tar.gz \
  ./dist/cortex-darwin-aarch64.tar.gz \
  ./dist/cortex-windows-x86_64.zip \
  ./dist/cortex-windows-aarch64.zip \
  ./dist/checksums.txt
```

### 3. Add Release Automation
Create `.github/workflows/release.yml`:
```yaml
name: Release
on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            dist/*
          generate_release_notes: true
```

### 4. Update README to Reference GitHub Releases
Add download links pointing to GitHub Releases in addition to CDN:
```markdown
## Download
- [GitHub Releases](https://github.com/CortexLM/cortex/releases/latest)
- [Direct Downloads](https://software.cortex.foundation/...)
```

## Additional Context
The README directs users to download binaries from `software.cortex.foundation`, which is an external CDN. While CDNs are useful for fast downloads, GitHub Releases provide:

1. **Trust anchor**: GitHub-verified releases tied to repository
2. **Immutability**: Released assets cannot be silently modified
3. **Transparency**: Public audit trail of all releases
4. **Integration**: Works with `gh` CLI, package managers, and CI/CD tools
5. **Discovery**: Users expect to find releases on GitHub

The absence of GitHub Releases while maintaining a detailed CHANGELOG suggests a process gap in the release workflow.

## References
- GitHub Releases page: https://github.com/CortexLM/cortex/releases
- CHANGELOG.md: https://github.com/CortexLM/cortex/blob/main/CHANGELOG.md
- GitHub Release documentation: https://docs.github.com/en/repositories/releasing-projects-on-github
- GitHub Actions release workflow: https://github.com/softprops/action-gh-release
