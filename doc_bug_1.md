# [BUG] [v0.0.7] compare_versions() incorrectly orders prerelease vs release versions - 1.0.0-alpha treated as newer than 1.0.0

## Description
The `compare_versions()` function in `cortex-update/src/version.rs` incorrectly compares versions with prerelease suffixes. According to semver specification, a version without prerelease (1.0.0) should be NEWER than a version with prerelease (1.0.0-alpha). However, the current implementation reverses this, treating prerelease versions as newer than their release counterparts.

This causes the update system to potentially skip valid release versions if the user is on a prerelease, or incorrectly suggest downgrading from a release to a prerelease.

## Location
- **File**: src/cortex-update/src/version.rs
- **Function**: `parse_version()` and `compare_versions()`
- **Line**: Approximately lines 70-95

## Steps to Reproduce
1. Have Cortex CLI v1.0.0-alpha installed
2. Cortex releases v1.0.0 (stable)
3. Run `cortex upgrade` to check for updates
4. Observe: No update is offered because 1.0.0-alpha is considered "newer" than 1.0.0

Or conversely:
1. Have Cortex CLI v1.0.0 installed
2. A prerelease v1.0.1-beta is published
3. User expects no update prompt on stable channel
4. Observe: User may be incorrectly prompted to "downgrade" to 1.0.0

## Expected Behavior
According to SemVer 2.0.0 specification (https://semver.org/#spec-item-11):
- 1.0.0 > 1.0.0-alpha
- 1.0.0 > 1.0.0-rc.1
- 1.0.0-beta > 1.0.0-alpha

The update checker should correctly identify that `1.0.0` is NEWER than `1.0.0-alpha`.

## Actual Behavior
The code returns:
```rust
fn parse_version(version: &str) -> (u32, u32, u32, String) {
    // ...
    (major, minor, patch, prerelease)
}
```

When comparing tuples in Rust, the comparison is lexicographic. For the prerelease string:
- `("1", "0", "0", "")` vs `("1", "0", "0", "alpha")`
- Since `"" < "alpha"` lexicographically, `1.0.0 < 1.0.0-alpha`

This is the OPPOSITE of semver specification.

## System Information
- **Cortex Version**: v0.0.7
- **File**: src/cortex-update/src/version.rs
- **Affected Functionality**: `cortex upgrade`, automatic update checking

## Impact
- **Severity**: High
- **Affected Users**: All users using prerelease versions or when prereleases are published
- **Consequence**:
  - Users on prerelease may never receive update notifications for stable releases
  - Update version comparison gives incorrect results
  - Could lead to users staying on unstable prereleases indefinitely

## Suggested Fix
The prerelease comparison needs to be inverted. A version WITHOUT a prerelease should be considered newer than the same version WITH a prerelease:

```rust
/// Compare two semver version strings.
pub fn compare_versions(current: &str, target: &str) -> VersionComparison {
    let (cur_major, cur_minor, cur_patch, cur_pre) = parse_version(current);
    let (tgt_major, tgt_minor, tgt_patch, tgt_pre) = parse_version(target);

    // Compare major.minor.patch first
    match (cur_major, cur_minor, cur_patch).cmp(&(tgt_major, tgt_minor, tgt_patch)) {
        std::cmp::Ordering::Less => return VersionComparison::Older,
        std::cmp::Ordering::Greater => return VersionComparison::Newer,
        std::cmp::Ordering::Equal => {}
    }

    // Same version numbers - compare prerelease
    // Per semver: version without prerelease > version with prerelease
    match (&cur_pre.is_empty(), &tgt_pre.is_empty()) {
        (true, false) => VersionComparison::Newer,   // 1.0.0 > 1.0.0-alpha
        (false, true) => VersionComparison::Older,   // 1.0.0-alpha < 1.0.0
        (true, true) => VersionComparison::Equal,    // 1.0.0 == 1.0.0
        (false, false) => {
            // Both have prerelease - compare alphabetically
            match cur_pre.cmp(&tgt_pre) {
                std::cmp::Ordering::Less => VersionComparison::Older,
                std::cmp::Ordering::Equal => VersionComparison::Equal,
                std::cmp::Ordering::Greater => VersionComparison::Newer,
            }
        }
    }
}
```

## Evidence
From version.rs:
```rust
fn parse_version(version: &str) -> (u32, u32, u32, String) {
    // ...
    (major, minor, patch, prerelease)
}

pub fn compare_versions(current: &str, target: &str) -> VersionComparison {
    let current = parse_version(current);
    let target = parse_version(target);

    match current.cmp(&target) {  // <-- Tuple comparison is wrong for prerelease
        std::cmp::Ordering::Less => VersionComparison::Older,
        std::cmp::Ordering::Equal => VersionComparison::Equal,
        std::cmp::Ordering::Greater => VersionComparison::Newer,
    }
}
```

The existing tests don't cover prerelease comparison:
```rust
#[test]
fn test_compare_versions() {
    assert_eq!(compare_versions("0.1.0", "0.2.0"), VersionComparison::Older);
    // No test for: compare_versions("1.0.0-alpha", "1.0.0")
}
```

## References
- https://github.com/CortexLM/cortex/blob/main/src/cortex-update/src/version.rs
- SemVer 2.0.0 Specification: https://semver.org/#spec-item-11
- Rust tuple comparison: https://doc.rust-lang.org/std/cmp/trait.Ord.html#impl-Ord-for-(T,)
