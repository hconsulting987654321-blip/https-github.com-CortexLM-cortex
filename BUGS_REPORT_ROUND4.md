# Bug Reports - Cortex CLI v0.0.7 (Round 4) - TUI & Multi-Agent

Found by analyzing source code at `/home/user/cortex-source/`

---

## MULTI-AGENT CRITICAL BUGS

### Bug #25: TOCTOU Race Condition in Agent Spawn Limits

**File:** `src/cortex-agents/src/control.rs` lines 272-286

**Severity:** Critical

**Type:** Race condition (TOCTOU)

**Description:**
The spawn limit check and increment are NOT atomic - race condition allows exceeding limits:

```rust
// Line 272: CHECK (loads from atomics)
if !self.state.can_spawn(depth) {
    // error handling...
}

// RACE WINDOW HERE - Another thread can spawn and increment!

let id = AgentThreadId::new();
let thread = AgentThread::new(id, agent_info, parent_id, depth);

// Lines 285-286: USE (increments atomics separately)
self.state.insert_thread(thread).await;  // increments active_count
self.state.record_spawn();                // increments total_spawns
```

The `can_spawn()` function (lines 212-218):
```rust
pub fn can_spawn(&self, depth: u32) -> bool {
    let active = self.active_count();      // load atomic
    let total = self.total_spawns();       // load atomic
    active < self.limits.max_concurrent
        && depth <= self.limits.max_depth
        && total < self.limits.max_total_spawns
}
```

**Race Scenario:**
1. Thread A: can_spawn() returns true (active=9, limit=10)
2. Thread B: can_spawn() returns true (active=9)
3. Thread A: insert_thread() → active=10
4. Thread B: insert_thread() → active=11 (EXCEEDS LIMIT!)

---

### Bug #26: shutdown_agent NEVER Decrements active_count

**File:** `src/cortex-agents/src/control.rs` lines 325-333

**Severity:** Critical

**Type:** Resource leak / Logic error

**Description:**
The `shutdown_agent()` function marks the agent as shutdown but NEVER decrements `active_count`, causing permanent resource exhaustion:

```rust
pub async fn shutdown_agent(&self, id: AgentThreadId) -> Result<(), AgentControlError> {
    if let Some(thread) = self.state.get_thread(id).await {
        thread.set_status(AgentThreadStatus::Shutdown);
        // Keep in registry for status queries
        // BUG: NEVER calls remove_thread() or decrements active_count!
        Ok(())
    } else {
        Err(AgentControlError::AgentNotFound(id))
    }
}
```

**Contrast with `remove_thread()` (lines 191-198) which DOES decrement:**
```rust
pub async fn remove_thread(&self, id: AgentThreadId) -> Option<Arc<AgentThread>> {
    let mut threads = self.threads.write().await;
    let removed = threads.remove(&id);
    if removed.is_some() {
        self.active_count.fetch_sub(1, Ordering::AcqRel);  // Correct!
    }
    removed
}
```

**Impact:** After spawning `max_concurrent` agents and shutting them down, NO NEW AGENTS CAN EVER SPAWN.

---

### Bug #27: TOCTOU in Guards Spawn Slot Reservation (Lock Dropped Too Early)

**File:** `src/cortex-collab/src/guards.rs` lines 53-70

**Severity:** Critical

**Type:** Race condition (TOCTOU)

**Description:**
The Mutex lock is dropped BEFORE the atomic increment, creating a race window:

```rust
pub async fn reserve_spawn_slot(self: &Arc<Self>) -> Option<SpawnReservation> {
    let threads = self.threads_set.lock().await;  // LOCK ACQUIRED
    let current_count = threads.len();
    let pending = self.pending_count.load(Ordering::Acquire);

    if current_count + pending >= self.max_threads {
        return None;
    }
    // LOCK IMPLICITLY DROPPED HERE (end of scope)

    // RACE WINDOW - Another thread can:
    // 1. Acquire the lock
    // 2. Pass the same check
    // 3. Increment pending

    self.pending_count.fetch_add(1, Ordering::AcqRel);  // Line 63
    self.total_count.fetch_add(1, Ordering::AcqRel);    // Line 64
```

**Fix needed:** Hold the lock during the increment, or use compare-and-swap atomics.

---

### Bug #28: ThreadManager shutdown_thread Doesn't Remove Thread

**File:** `src/cortex-collab/src/thread_manager.rs` lines 317-325

**Severity:** High

**Type:** Memory leak

**Description:**
`shutdown_thread()` releases the guard slot but NEVER removes the thread from the HashMap:

```rust
pub async fn shutdown_thread(&self, id: ThreadId) -> super::Result<()> {
    if let Some(thread) = self.state.get_thread(id).await {
        thread.set_status(AgentStatus::Shutdown);
        self.state.guards.release_spawned_thread(id).await;
        // BUG: Thread still in self.state.threads HashMap!
        Ok(())
    } else {
        Err(super::CollabError::AgentNotFound(id))
    }
}
```

**Impact:** Memory grows indefinitely as threads accumulate in the HashMap.

---

### Bug #29: SubagentExecutor TOCTOU in Concurrent Limit Check

**File:** `src/cortex-engine/src/tools/handlers/subagent/executor.rs` lines 84-92

**Severity:** High

**Type:** Race condition (TOCTOU)

**Description:**
The active_count check and increment are separate operations:

```rust
pub async fn execute(&self, config: SubagentConfig, ...) -> Result<SubagentResult> {
    // CHECK (lines 84-92)
    {
        let count = *self.active_count.read().await;
        if count >= self.max_concurrent {
            return Err(CortexError::RateLimit(...));
        }
    }
    // Lock released!

    // ... code in between ...

    // INCREMENT (lines 127-130)
    {
        let mut count = self.active_count.write().await;
        *count += 1;
    }
```

**Race Scenario:** Same as Bug #25 - multiple threads pass check before increment.

---

## TUI BUGS

### Bug #30: visible_progress Uses chars().count() for Width

**File:** `src/cortex-tui/src/bridge/streaming/controller.rs` lines 448-454

**Severity:** Medium

**Type:** Unicode display width error

**Description:**
Using `chars().count()` instead of proper display width:

```rust
pub fn visible_progress(&self) -> (usize, usize) {
    let total = self.committed_buffer.chars().count();  // BUG!
    let visible = self.typewriter
        .as_ref()
        .map_or(total, |tw| tw.visible_char_count());
    (visible, total)
}
```

**Issue:** Wide characters (CJK, emoji) are 2 cells but counted as 1.

---

### Bug #31: close_all Ignores Errors

**File:** `src/cortex-collab/src/thread_manager.rs` lines 339-343

**Severity:** Medium

**Type:** Silent error suppression

**Description:**
All shutdown errors are silently ignored:

```rust
pub async fn close_all(&self) {
    let ids = self.list_threads().await;
    for id in ids {
        let _ = self.shutdown_thread(id).await;  // BUG: Error ignored!
    }
}
```

**Impact:** If any thread fails to shutdown, caller has no idea.

---

### Bug #32: Subagent Broadcast Channel Send Errors Ignored

**File:** `src/cortex-engine/src/tools/handlers/subagent/executor.rs` lines 336, 342, 353, 372, etc.

**Severity:** Medium

**Type:** Silent error suppression

**Description:**
All progress event sends use `let _ = ...` pattern:

```rust
let _ = progress_tx_clone.send(ProgressEvent::Thinking {
    session_id: session_id_clone.clone(),
    turn_number,
});

let _ = progress_tx_clone.send(ProgressEvent::TextOutput {
    session_id: session_id_clone.clone(),
    content: content.clone(),
    is_partial: true,
});
```

**Impact:** If all receivers are dropped, sends fail silently. No logging or metrics.

---

### Bug #33: watch::Sender Error Silently Discarded in set_status

**File:** `src/cortex-collab/src/thread_manager.rs` line 151

**Severity:** Medium

**Type:** Silent error suppression

**Description:**
Status update errors are silently ignored:

```rust
pub fn set_status(&self, status: AgentStatus) {
    let _ = self.status_tx.send(status);  // BUG: Error ignored!
}
```

**Compare with control.rs:117 which logs warnings:**
```rust
if self.status_tx.send(status.clone()).is_err() {
    tracing::warn!(
        "Failed to send status update {:?} for agent {} - all receivers dropped",
        status,
        self.id
    );
}
```

---

### Bug #34: Guard total_count Never Decremented on Release

**File:** `src/cortex-collab/src/guards.rs` lines 79-82

**Severity:** Medium

**Type:** Counter drift

**Description:**
`release_spawned_thread()` removes from the set but doesn't decrement `total_count`:

```rust
pub async fn release_spawned_thread(&self, thread_id: ThreadId) {
    let mut threads = self.threads_set.lock().await;
    threads.remove(&thread_id);
    // BUG: total_count never decremented!
}
```

**Impact:** `total_spawned()` grows forever, eventually blocking all spawns if max_total_spawns limit is hit.

---

## Summary

| Bug # | Category | Severity | Type | File |
|-------|----------|----------|------|------|
| 25 | Multi-Agent | Critical | TOCTOU | control.rs |
| 26 | Multi-Agent | Critical | Resource Leak | control.rs |
| 27 | Multi-Agent | Critical | TOCTOU | guards.rs |
| 28 | Multi-Agent | High | Memory Leak | thread_manager.rs |
| 29 | Multi-Agent | High | TOCTOU | executor.rs |
| 30 | TUI | Medium | Unicode Width | controller.rs |
| 31 | Multi-Agent | Medium | Error Ignored | thread_manager.rs |
| 32 | Subagent | Medium | Error Ignored | executor.rs |
| 33 | Multi-Agent | Medium | Error Ignored | thread_manager.rs |
| 34 | Multi-Agent | Medium | Counter Drift | guards.rs |

**Total Round 4: 10 bugs**
- Critical: 3
- High: 2
- Medium: 5

**All bugs are unique (no duplicates from previous rounds)**
