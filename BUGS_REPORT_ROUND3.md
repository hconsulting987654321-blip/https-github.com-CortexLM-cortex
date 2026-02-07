# Bug Reports - Cortex CLI v0.0.7 (Round 3)

Found by analyzing source code at `/home/user/cortex-source/`

---

## SNAPSHOT/REVERT BUGS

### Bug #11: Non-Atomic Restore Causes Index Corruption

**File:** `src/cortex-snapshot/src/snapshot.rs` lines 328-365

**Severity:** Critical

**Type:** Data corruption

**Description:**
The `restore()` function performs `read-tree` then `checkout-index` as separate operations. If `checkout-index` fails after `read-tree` succeeds, the git index is left corrupted with no recovery mechanism.

```rust
pub async fn restore(&mut self, snapshot: &Snapshot) -> Result<()> {
    // Step 1: Modify git index
    let output = git_command_with_timeout_env(
        &["read-tree", &snapshot.tree_hash],
        &self.root,
        &self.git_dir,
        &self.root,
    ).await?;

    // Step 2: Apply to working tree - if THIS fails, index is corrupted!
    let output = git_command_with_timeout_env(
        &["checkout-index", "-a", "-f"],  // BUG: No rollback if this fails
        &self.root,
        &self.git_dir,
        &self.root,
    ).await?;
}
```

---

### Bug #12: Partial File Restore Leaves Inconsistent State

**File:** `src/cortex-snapshot/src/snapshot.rs` lines 369-404

**Severity:** Critical

**Type:** Partial operation failure

**Description:**
`restore_files()` processes files in a loop without atomicity. If restoration fails mid-loop, workspace is left in an inconsistent state:

```rust
pub async fn restore_files(&mut self, snapshot: &Snapshot, files: &[PathBuf]) -> Result<()> {
    for file in files {
        let output = git_command_with_timeout_env(
            &["checkout", &snapshot.tree_hash, "--", &relative],
            // ...
        ).await?;

        if !output.status.success() {
            // Some files restored, some not - INCONSISTENT STATE
            if stderr.contains("did not match") {
                tokio::fs::remove_file(file).await?;
            } else {
                warn!("Failed to restore file {:?}: {}", file, stderr);
                // Returns after partial restoration!
            }
        }
    }
}
```

---

### Bug #13: Non-Atomic Snapshot Metadata Write

**File:** `src/cortex-snapshot/src/storage.rs` lines 28-36

**Severity:** High

**Type:** Data durability

**Description:**
Snapshot metadata uses simple `fs::write()` without atomic write pattern:

```rust
pub async fn save_snapshot(&self, snapshot: &Snapshot) -> Result<()> {
    let json = serde_json::to_string_pretty(snapshot)?;

    // BUG: Non-atomic - crash during write = corrupted/truncated file
    // Should use write-to-temp-then-atomic-rename pattern
    fs::write(&path, json).await?;
}
```

---

### Bug #14: Race Condition in RevertManager (No Synchronization)

**File:** `src/cortex-snapshot/src/revert.rs` lines 45-56

**Severity:** Critical

**Type:** Data race

**Description:**
`RevertManager` contains mutable state but uses NO synchronization primitives:

```rust
pub struct RevertManager {
    snapshot_manager: SnapshotManager,
    history: VecDeque<RevertPoint>,    // NO MUTEX!
    current_position: usize,            // Data race risk
    redo_stack: Vec<RevertPoint>,       // Data race risk
}

// Concurrent checkpoint + undo will corrupt these fields
```

---

### Bug #15: Unbounded Redo Stack Memory Leak

**File:** `src/cortex-snapshot/src/revert.rs` lines 55, 140-141

**Severity:** High

**Type:** Memory leak

**Description:**
The `redo_stack` has no size limit and grows unbounded:

```rust
pub struct RevertManager {
    redo_stack: Vec<RevertPoint>,  // NO MAX LIMIT!
}

pub async fn undo(&mut self) -> Result<Option<RevertPoint>> {
    let current_snapshot = self.snapshot_manager.create().await?;
    self.redo_stack.push(RevertPoint::new(current_snapshot));
    // Each undo adds to redo_stack with NO cleanup
}
```

---

## DAG EXECUTOR BUGS

### Bug #16: Silent Error Suppression with .ok()

**File:** `src/cortex-cli/src/dag_cmd/scheduler.rs` lines 154, 165, 199, 267

**Severity:** Critical

**Type:** Error handling

**Description:**
Multiple `.ok()` calls suppress errors without logging:

```rust
dag.complete_task(result.task_id, result.output.clone())
    .ok();  // BUG: Error silently suppressed

dag.fail_task(result.task_id, result.error.clone().unwrap_or_default())
    .ok();  // BUG: Error silently suppressed
```

---

### Bug #17: Semaphore Panic Without Recovery

**File:** `src/cortex-cli/src/dag_cmd/scheduler.rs` line 138

**Severity:** High

**Type:** Panic

**Description:**
Semaphore acquisition panics if poisoned:

```rust
let permit = semaphore.clone().acquire_owned().await.unwrap();
// BUG: Panics on Err, no graceful shutdown
```

---

### Bug #18: Lock Held Across Await (Deadlock Risk)

**File:** `src/cortex-cli/src/dag_cmd/scheduler.rs` lines 150-153

**Severity:** High

**Type:** Deadlock

**Description:**
DAG write locks held across `.await` points:

```rust
let mut dag = dag.write().await;  // Write lock acquired
if let Err(e) = dag.start_task(task_id, None) {
    // ... error handling with lock held
}
// BUG: Lock held for entire async block, blocks other tasks
```

---

### Bug #19: Incomplete Dependency State Check

**File:** `src/cortex-cli/src/dag_cmd/scheduler.rs` lines 254-271

**Severity:** High

**Type:** Logic error

**Description:**
Check for failed deps doesn't verify ALL deps are in terminal state:

```rust
let any_failed = deps.iter().any(|&dep_id| {
    dag.get_task(dep_id)
        .map(|t| matches!(t.status, TaskStatus::Failed | TaskStatus::Skipped))
        .unwrap_or(false)
});
// BUG: No check that ALL deps are Completed before proceeding
// Task may start with incomplete dependencies
```

---

## FILE OPERATION SECURITY BUGS

### Bug #20: TOCTOU Race in Backup Operation

**File:** `src/cortex-apply-patch/src/backup.rs` lines 55-66

**Severity:** High

**Type:** Race condition (TOCTOU)

**Description:**
Time-of-check-time-of-use vulnerability in backup:

```rust
if full_path.exists() {  // CHECK
    // ... directory creation ...
    // FILE COULD BE DELETED/CHANGED HERE
    fs::copy(&full_path, &backup_file)?;  // USE - may fail or copy wrong content
}
```

---

### Bug #21: Symlink Following in fs::copy

**File:** `src/cortex-apply-patch/src/backup.rs` lines 66, 94, 160

**Severity:** High

**Type:** Security (symlink attack)

**Description:**
`fs::copy()` follows symlinks, allowing arbitrary file reads/writes:

```rust
fs::copy(&full_path, &backup_file)?;
// BUG: If full_path is symlink, copies LINKED file
// Could backup/restore files outside patch scope
```

---

### Bug #22: Path Validation Bypass in Rename

**File:** `src/cortex-app-server/src/api/files.rs` line 304

**Severity:** High

**Type:** Security (path traversal)

**Description:**
`rename_file()` doesn't validate destination path:

```rust
pub async fn rename_file(Json(req): Json<RenameRequest>) -> AppResult<...> {
    let old_path = std::path::Path::new(&req.old_path);
    if !old_path.exists() {
        return Err(AppError::NotFound(...));
    }
    // NO VALIDATION OF new_path!
    fs::rename(&req.old_path, &req.new_path)?;  // BUG: Can traverse outside allowed dirs
}
```

**Note:** `write_file()` on line 225 correctly calls `validate_path_for_write()`, but `rename_file()` does not.

---

### Bug #23: Missing fsync in File Writes

**File:** `src/cortex-app-server/src/tools/filesystem.rs` lines 112, 185

**Severity:** Medium

**Type:** Data durability

**Description:**
File writes don't ensure data is durable:

```rust
match tokio::fs::write(&full_path, content).await {
    Ok(_) => ToolResult {
        success: true,
        // BUG: No fsync - crash may lose data
```

**Contrast:** `src/cortex-app-server/src/storage.rs:188` correctly calls `file.sync_all()?`

---

### Bug #24: Canonical Path Fallback

**File:** `src/cortex-batch/src/batch_ops.rs` line 24

**Severity:** Medium

**Type:** Security (path traversal)

**Description:**
Fallback to non-canonical path on error:

```rust
let canonical = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
// BUG: If canonicalize fails, path may contain ../
// Defeats symlink attack prevention
```

---

## Summary

| Bug # | Category | Severity | File | Lines |
|-------|----------|----------|------|-------|
| 11 | Snapshot | Critical | snapshot.rs | 328-365 |
| 12 | Snapshot | Critical | snapshot.rs | 369-404 |
| 13 | Snapshot | High | storage.rs | 28-36 |
| 14 | Snapshot | Critical | revert.rs | 45-56 |
| 15 | Snapshot | High | revert.rs | 55, 140 |
| 16 | DAG | Critical | scheduler.rs | 154, 165 |
| 17 | DAG | High | scheduler.rs | 138 |
| 18 | DAG | High | scheduler.rs | 150-153 |
| 19 | DAG | High | scheduler.rs | 254-271 |
| 20 | File Ops | High | backup.rs | 55-66 |
| 21 | File Ops | High | backup.rs | 66, 94, 160 |
| 22 | File Ops | High | files.rs | 304 |
| 23 | File Ops | Medium | filesystem.rs | 112, 185 |
| 24 | File Ops | Medium | batch_ops.rs | 24 |

**Total Round 3: 14 bugs**
- Critical: 4
- High: 8
- Medium: 2
