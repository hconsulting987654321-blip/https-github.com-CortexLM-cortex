# [BUG] [v0.0.7] ApprovalRequest is_expired() method exists but is never called - expired requests accumulate in pending queue

## Description
The `ApprovalRequest` struct in `cortex-engine/src/approval.rs` defines an `is_expired()` method that checks if a request has timed out, but this method is never called anywhere in the codebase. Expired approval requests remain in the `pending` HashMap indefinitely, causing:
1. Memory leak from accumulated stale requests
2. Potential confusion when listing pending approvals
3. Risk of expired requests being processed if IDs are reused

## Location
- **File**: src/cortex-engine/src/approval.rs
- **Struct**: `ApprovalRequest`
- **Method**: `is_expired()`
- **Line**: Approximately lines 45-55

## Steps to Reproduce
1. Trigger an operation that requires approval
2. Don't respond to the approval prompt
3. Wait for the timeout period (e.g., 60 seconds)
4. Trigger another operation requiring approval
5. List pending approvals
6. Observe: Both requests appear in the list, even though the first is expired
7. Check memory usage over time
8. Observe: Memory grows with each unacknowledged approval request

## Expected Behavior
Expired requests should be automatically cleaned up:
```rust
impl ApprovalManager {
    pub fn list_pending(&self) -> Vec<&ApprovalRequest> {
        self.pending
            .values()
            .filter(|req| !req.is_expired())  // <-- Filter expired
            .collect()
    }

    /// Periodically clean up expired requests
    pub fn cleanup_expired(&mut self) {
        self.pending.retain(|_, req| !req.is_expired());
    }
}
```

## Actual Behavior
The `is_expired()` method is defined but never used:
```rust
impl ApprovalRequest {
    /// Check if this request has expired
    pub fn is_expired(&self) -> bool {
        self.created_at.elapsed() > self.timeout
    }
}

impl ApprovalManager {
    pub fn list_pending(&self) -> Vec<&ApprovalRequest> {
        self.pending.values().collect()  // <-- No filtering!
    }

    // No cleanup method exists
}
```

Search for `is_expired` in the codebase shows:
- Defined in `ApprovalRequest` struct
- Never called anywhere else

## System Information
- **Cortex Version**: v0.0.7
- **File**: src/cortex-engine/src/approval.rs
- **Affected Functionality**: Approval request management

## Impact
- **Severity**: Low-Medium
- **Affected Users**: Users in long-running sessions with approval prompts
- **Consequence**:
  - Memory leak from accumulated expired requests
  - Stale requests appear in pending list
  - Confusing UX when old requests are shown
  - Potential for processing stale/outdated approval contexts
  - In extreme cases (many unanswered approvals), OOM possible

## Suggested Fix
Add cleanup logic to the approval manager:

```rust
impl ApprovalManager {
    /// Remove expired requests from the pending queue
    pub fn cleanup_expired(&mut self) {
        let before = self.pending.len();
        self.pending.retain(|_, req| !req.is_expired());
        let removed = before - self.pending.len();
        if removed > 0 {
            tracing::debug!("Cleaned up {} expired approval requests", removed);
        }
    }

    /// Get pending requests, filtering out expired ones
    pub fn list_pending(&self) -> Vec<&ApprovalRequest> {
        self.pending
            .values()
            .filter(|req| !req.is_expired())
            .collect()
    }

    /// Get a pending request by ID, returning None if expired
    pub fn get_pending(&self, id: &str) -> Option<&ApprovalRequest> {
        self.pending.get(id).filter(|req| !req.is_expired())
    }
}
```

And call `cleanup_expired()` periodically or before listing pending requests.

## Evidence
The `is_expired()` method is defined:
```rust
impl ApprovalRequest {
    pub fn is_expired(&self) -> bool {
        self.created_at.elapsed() > self.timeout
    }
}
```

But grep shows no callers:
```bash
$ grep -r "is_expired" src/
src/cortex-engine/src/approval.rs:    pub fn is_expired(&self) -> bool {
# No other results - method is never called
```

## References
- https://github.com/CortexLM/cortex/blob/main/src/cortex-engine/src/approval.rs
