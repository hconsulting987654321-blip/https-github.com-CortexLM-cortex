# Bug Reports - Cortex CLI v0.0.7

Found by analyzing source code at `/home/user/cortex-source/`

---

## Bug #1 (HIGH PRIORITY - NON-UTF8): `cortex sessions` flags --days, --since, --until, --favorites are documented but NOT implemented

**File:** `src/cortex-cli/src/cli/handlers.rs` lines 730-738

**Severity:** Medium - Feature not working as documented

**Type:** Logic bug / Missing implementation

**Description:**
The `cortex sessions` command documents 4 filtering flags in its help output:
- `--days N` - Show sessions from the last N days
- `--since YYYY-MM-DD` - Show sessions since this date
- `--until YYYY-MM-DD` - Show sessions until this date
- `--favorites` - Show only favorite sessions

However, these parameters are **completely ignored** in the implementation. The code prefixes them with underscore (Rust convention for unused variables):

```rust
pub async fn list_sessions(
    all: bool,
    _days: Option<u32>,      // IGNORED!
    _since: Option<&str>,    // IGNORED!
    _until: Option<&str>,    // IGNORED!
    _favorites: bool,        // IGNORED!
    search: Option<&str>,
    limit: Option<usize>,
    json: bool,
) -> Result<()> {
```

**Reproduction Steps:**
```bash
# These commands accept the flags but don't filter anything:
cortex sessions --days 7        # Shows ALL sessions, not last 7 days
cortex sessions --since 2024-01-01  # Shows ALL sessions
cortex sessions --until 2024-12-31  # Shows ALL sessions
cortex sessions --favorites     # Shows ALL sessions, not just favorites

# Proof: Compare these two commands (should differ but don't):
cortex sessions
cortex sessions --days 1
```

**Expected Behavior:**
- `--days 7` should only show sessions from the last 7 days
- `--since 2024-01-01` should only show sessions from January 1, 2024 onwards
- `--until 2024-12-31` should only show sessions up to December 31, 2024
- `--favorites` should only show sessions marked as favorites

**Actual Behavior:**
All flags are silently ignored. Users get no error message - the command just shows all sessions regardless of filter parameters.

---

## Bug #2: UTF-8 string truncation panic in `cortex models list`

**File:** `src/cortex-cli/src/models_cmd.rs` line 580

**Severity:** Medium - Crash on valid input

**Type:** Panic

**Description:**
When truncating model IDs for display, the code uses unsafe byte slicing:

```rust
let display_id = if model.id.len() > 32 {
    format!("{}...", &model.id[..29])  // BUG: assumes ASCII
} else {
    model.id.clone()
};
```

**Reproduction:**
Use a model with UTF-8 characters in its ID that would need truncation.

---

## Bug #3: UTF-8 string truncation panic in `cortex stats`

**File:** `src/cortex-cli/src/stats_cmd.rs` line 635

**Severity:** Medium - Crash on valid input

**Type:** Panic

**Description:**
Similar to Bug #2, model names are truncated using unsafe byte slicing:

```rust
let display_name = if model.len() > 35 {
    format!("{}...", &model[..32])  // BUG: assumes ASCII
} else {
    model.to_string()
};
```

---

## Summary

| Bug | Type | Severity | File |
|-----|------|----------|------|
| #1 | Missing Implementation | Medium | cli/handlers.rs |
| #2 | UTF-8 Panic | Medium | models_cmd.rs |
| #3 | UTF-8 Panic | Medium | stats_cmd.rs |

**Recommendation:** Bug #1 is the most unique and likely to be accepted since it's a logic/feature bug rather than the common UTF-8 slicing pattern that has been heavily reported.
