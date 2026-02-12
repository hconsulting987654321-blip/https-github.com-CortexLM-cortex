# [BUG] [v0.0.7] ApprovalManager reset_counter() method exists but is never called - counter never resets in practice

## Description
The `ApprovalManager` in `cortex-engine/src/approval.rs` has a `reset_counter()` method defined (line 506), but this method is never called anywhere in the codebase. This means the `auto_approval_count` only ever increments and never resets, even though the reset functionality was clearly intended.

Once the count reaches `max_auto_approvals`, all subsequent operations require manual approval indefinitely. The reset mechanism exists but is dead code - creating a "one-way ratchet" where the system becomes increasingly restrictive over time.

## Location
- **File**: src/cortex-engine/src/approval.rs
- **Function**: `reset_counter()` method (never called)
- **Line**: Line 506 (reset_counter definition), lines 318, 391, 466 (auto_approval_count usage)

## Steps to Reproduce
1. Configure Cortex with `max_auto_approvals = 10`
2. Perform 10 operations that trigger auto-approval (e.g., file reads in trusted directories)
3. Attempt an 11th auto-approvable operation
4. Observe: Requires manual approval
5. Wait any amount of time (hours, days)
6. Attempt another auto-approvable operation
7. Observe: Still requires manual approval - counter never reset

## Expected Behavior
The auto_approval_count should have a reset mechanism:
```rust
impl ApprovalManager {
    pub fn try_auto_approve(&mut self, request: &ApprovalRequest) -> Option<ApprovalResponse> {
        // Reset counter if enough time has passed
        if self.last_reset.elapsed() > Duration::from_secs(3600) {
            self.auto_approval_count = 0;
            self.last_reset = Instant::now();
        }

        if self.auto_approval_count >= self.config.max_auto_approvals {
            return None;  // Limit reached for this window
        }

        if !self.requires_approval(request).await {
            self.auto_approval_count += 1;
            Some(ApprovalResponse::auto_approve(&request.id))
        } else {
            None
        }
    }
}
```

Or reset on session start, configuration change, or explicit user action.

## Actual Behavior
The `reset_counter()` method exists but is never called anywhere:
```rust
impl ApprovalManager {
    /// Reset auto-approval counter.
    pub async fn reset_counter(&self) {
        *self.auto_approval_count.write().await = 0;
    }
    // This method is NEVER called anywhere in the codebase!
}
```

Search for `reset_counter` callers:
```bash
$ grep -rn "reset_counter" src/
src/cortex-engine/src/approval.rs:506:    pub async fn reset_counter(&self) {
# Only the definition - no callers found!
```

The counter only increments (line 466) and is checked (line 391), but `reset_counter()` is dead code.

## System Information
- **Cortex Version**: v0.0.7
- **File**: src/cortex-engine/src/approval.rs
- **Affected Functionality**: Auto-approval system

## Impact
- **Severity**: Medium
- **Affected Users**: All users with max_auto_approvals configured
- **Consequence**:
  - Auto-approval permanently disabled after limit reached
  - Users forced into manual approval for every operation
  - No way to restore auto-approval without restarting the process
  - Long-running sessions become unusable with constant approval prompts
  - Security feature becomes a usability nightmare

## Suggested Fix
Add a time-windowed reset mechanism:
```rust
pub struct ApprovalManager {
    auto_approval_count: u32,
    window_start: Instant,
    config: ApprovalConfig,
}

impl ApprovalManager {
    fn reset_if_window_expired(&mut self) {
        let window_duration = Duration::from_secs(
            self.config.auto_approval_window_secs.unwrap_or(3600)
        );
        if self.window_start.elapsed() > window_duration {
            self.auto_approval_count = 0;
            self.window_start = Instant::now();
        }
    }

    pub fn try_auto_approve(&mut self, request: &ApprovalRequest) -> Option<ApprovalResponse> {
        self.reset_if_window_expired();
        // ... rest of logic
    }
}
```

## Evidence
The `reset_counter()` method is defined at line 506:
```rust
/// Reset auto-approval counter.
pub async fn reset_counter(&self) {
    *self.auto_approval_count.write().await = 0;
}
```

But searching for callers shows ONLY the definition, no actual calls:
```bash
$ grep -rn "reset_counter" .
src/cortex-engine/src/approval.rs:506:    pub async fn reset_counter(&self) {
# No other results - method is never called!
```

The `auto_approval_count` is:
- Defined at line 318
- Read at line 391 (to check against max)
- Incremented at line 466
- Has reset method at line 506 - BUT NEVER CALLED

This follows the same dead code pattern as `is_expired()` - functionality exists but is never used.

## References
- https://github.com/CortexLM/cortex/blob/main/src/cortex-engine/src/approval.rs
