# [BUG] [v0.0.6] Release Badge Displayed But No GitHub Releases Published

## Description
The README.md displays a GitHub release badge that links to the releases page and shows version information, but the repository has no actual GitHub releases published. This creates a misleading impression that formal releases exist when they do not, confusing users who click the badge expecting to find downloadable release assets or release notes.

## Location
- **File**: README.md
- **Section**: Header badges (top of file)
- **Line**: Approximately line 10-12

## Steps to Reproduce
1. Visit the repository README at https://github.com/CortexLM/cortex
2. Observe the release badge in the header showing a version number
3. Click on the release badge
4. Observe that the releases page shows "No releases published"

## Expected Behavior
Either:
- A) The release badge should not be displayed until actual GitHub releases are published, OR
- B) GitHub releases should be created to match the badge, OR
- C) The badge should link to CHANGELOG.md instead of the empty releases page

## Actual Behavior
The README contains:
```html
<a href="https://github.com/CortexLM/cortex/releases">
  <img src="https://img.shields.io/github/v/release/CortexLM/cortex?style=flat-square&color=blue" alt="Release">
</a>
```

When users click this badge, they are taken to https://github.com/CortexLM/cortex/releases which shows:
> "No releases published"
> "Create a new release"

## System Information
- **Documentation Version**: Current main branch (commit as of 2026-01-29)
- **Date Checked**: 2026-01-29
- **Browser**: Any (documentation issue)

## Impact
- **Severity**: Low
- **Affected Users**: All users viewing the README
- **Consequence**:
  - Users may be confused about where to find release information
  - The badge may display an error or placeholder since no releases exist
  - Creates a false impression of project maturity/release management
  - Users looking for release notes or changelogs will find nothing

## Suggested Fix

### Option 1: Remove the badge until releases are published
```diff
<p align="center">
-  <a href="https://github.com/CortexLM/cortex/releases"><img src="https://img.shields.io/github/v/release/CortexLM/cortex?style=flat-square&color=blue" alt="Release"></a>
  <a href="https://discord.gg/cortexfoundation"><img src="https://img.shields.io/discord/1234567890?style=flat-square&logo=discord&logoColor=white&color=5865F2" alt="Discord"></a>
```

### Option 2: Link to CHANGELOG.md instead
```diff
<p align="center">
-  <a href="https://github.com/CortexLM/cortex/releases"><img src="https://img.shields.io/github/v/release/CortexLM/cortex?style=flat-square&color=blue" alt="Release"></a>
+  <a href="./CHANGELOG.md"><img src="https://img.shields.io/badge/version-0.0.6-blue?style=flat-square" alt="Version"></a>
```

### Option 3: Create actual GitHub releases
Publish GitHub releases for versions mentioned in CHANGELOG.md (0.0.5, etc.) with proper release notes and assets.

## Evidence
GitHub API response for releases:
```bash
$ curl -s https://api.github.com/repos/CortexLM/cortex/releases
[]
```

The empty array `[]` confirms no releases are published.

Screenshot equivalent - visiting https://github.com/CortexLM/cortex/releases shows:
> "Releases"
> "No releases published"

## References
- https://github.com/CortexLM/cortex/releases (empty)
- https://github.com/CortexLM/cortex/blob/main/README.md (badge location)
- https://github.com/CortexLM/cortex/blob/main/CHANGELOG.md (actual version history)
- shields.io badge documentation: https://shields.io/
