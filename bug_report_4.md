# [BUG] [v0.1.0] Points Calculation Mismatch - README Promises 20 Issues for 100%, Code Requires 50

## Description

There is a critical discrepancy between the documented reward system in README.md and the actual implementation in `pg_storage.rs`. The README promises miners that 20 valid issues in cortex will give them 100% weight, but the code actually requires 50 issues to reach 100% weight.

This is a **250% discrepancy** that directly affects miner earnings expectations.

## Steps to Reproduce

1. Review README.md points documentation (lines 73-94):
```markdown
| Repository | Points per Issue | Issues for 100% |
|------------|-----------------|-----------------|
| **CortexLM/cortex** | 5 points | 20 issues |

$$W_{user} = \min\left(\frac{points}{100}, 1.0\right)$$

Examples:
| Miner | Issues | Repository | Points | Weight |
|-------|--------|------------|--------|--------|
| C | 20 | cortex | 20 × 5 = 100 | 100% |
```

**README claims:**
- 5 points per issue
- 20 issues = 100 points = 100% weight

2. Review `src/pg_storage.rs` lines 13-17:
```rust
/// Maximum points for full weight (100 points = 100%)
pub const MAX_POINTS_FOR_FULL_WEIGHT: f64 = 50.0;

/// Weight per point (1 point = 2% = 0.02)
pub const WEIGHT_PER_POINT: f64 = 0.02;
```

3. Review the calculation in pg_storage.rs line 1901-1902:
```rust
pub fn calculate_weight_from_points(points: f64) -> f64 {
    (points * WEIGHT_PER_POINT).min(1.0)  // 50 * 0.02 = 1.0
}
```

4. Review tests that confirm 1 point per issue (lines 1941-1955):
```rust
// 7 issues = 7 points = 14%
let issue_points = 7.0;
assert!((calculate_weight_from_points(issue_points) - 0.14).abs() < 0.0001);

// 50 issues = 50 points = 100% (capped)
let issue_points = 50.0;
assert!((calculate_weight_from_points(issue_points) - 1.0).abs() < 0.0001);
```

**Code actually implements:**
- 1 point per issue
- 50 issues = 50 points = 100% weight

## Expected Behavior

Documentation and code should match. Either:
- **Option A**: Update README to reflect actual system (50 issues = 100%)
- **Option B**: Update code to match README (20 issues with 5 points each = 100%)

## Actual Behavior

| Source | Points/Issue | Issues for 100% | Total Points Needed |
|--------|--------------|-----------------|---------------------|
| README | 5 | 20 | 100 |
| Code | 1 | 50 | 50 |

Miners who trust the README will:
1. Expect 100% weight after 20 valid issues
2. Actually receive only 40% weight (20 * 0.02 = 0.40)
3. Need to submit 2.5x more issues than expected to reach 100%

## System Information

- **OS**: Ubuntu 22.04 LTS
- **Architecture**: x86_64
- **Rust Version**: rustc 1.75.0
- **Bounty CLI Version**: v0.1.0

## Impact

- **Severity**: Critical
- Direct financial impact on miners who rely on documented reward rates
- Miners may feel deceived when their actual rewards are 2.5x lower than promised
- Damages trust in the platform
- Could be considered false advertising of reward rates
- May discourage participation when miners realize the discrepancy

## Suggested Fix

**Recommended: Update README to match code implementation**

Update README.md reward table (line 73-76):
```markdown
| Repository | Points per Issue | Issues for 100% |
|------------|-----------------|-----------------|
| **CortexLM/cortex** | 1 point | 50 issues |
```

Update weight formula documentation (line 79-82):
```markdown
$$W_{user} = \min\left(\frac{points}{50}, 1.0\right)$$

Where:
- **50 points = 100% weight** (maximum)
```

Update examples table (lines 89-94):
```markdown
| Miner | Issues | Repository | Points | Weight |
|-------|--------|------------|--------|--------|
| A | 7 | cortex | 7 × 1 = 7 | 14% |
| B | 25 | cortex | 25 × 1 = 25 | 50% |
| C | 50 | cortex | 50 × 1 = 50 | 100% |
```

## References

- README.md lines 73-94: Documented (incorrect) reward system
- `src/pg_storage.rs:13-17`: Actual constants
- `src/pg_storage.rs:1901-1902`: Weight calculation function
- `src/pg_storage.rs:1930-1977`: Unit tests confirming behavior
