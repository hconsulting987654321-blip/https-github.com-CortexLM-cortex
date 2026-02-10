# [BUG] [v0.0.7] ApprovalManager auto_approval_count never resets - once limit reached, all operations require manual approval forever

## Description
The `ApprovalManager` in `cortex-engine/src/approval.rs` tracks `auto_approval_count` to enforce `max_auto_approvals`, but this counter never resets. Once the count reaches the maximum, all subsequent operations require manual approval indefinitely - there's no time-based decay, session boundary reset, or any mechanism to restore auto-approval capability.

This creates a "one-way ratchet" where the system becomes increasingly restrictive over time until it essentially disables auto-approval entirely.

## Location
- **File**: src/cortex-engine/src/approval.rs
- **Function**: `try_auto_approve()` and `ApprovalManager` state
- **Line**: Approximately lines 85-120

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
The counter only increments and never resets:
```rust
pub struct ApprovalManager {
    auto_approval_count: u32,
    config: ApprovalConfig,
    // ... no reset timestamp or mechanism
}

impl ApprovalManager {
    pub fn try_auto_approve(&mut self, request: &ApprovalRequest) -> Option<ApprovalResponse> {
        if self.auto_approval_count >= self.config.max_auto_approvals {
            return None;  // Once limit reached, forever blocked
        }

        if !self.requires_approval(request).await {
            self.auto_approval_count += 1;  // Only ever increments
            Some(ApprovalResponse::auto_approve(&request.id))
        } else {
            None
        }
    }
}
```

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
The `ApprovalManager` struct has no fields for tracking reset timing:
```rust
pub struct ApprovalManager {
    pending: HashMap<String, ApprovalRequest>,
    auto_approval_count: u32,  // Only increments
    config: ApprovalConfig,
    trusted_paths: HashSet<PathBuf>,
}
```

The only place `auto_approval_count` is modified is in `try_auto_approve()` where it's incremented. There is no decrement, reset, or time-based decay anywhere in the codebase.

## References
- https://github.com/CortexLM/cortex/blob/main/src/cortex-engine/src/approval.rs
