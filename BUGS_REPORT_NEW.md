# Bug Reports - Cortex CLI v0.0.7 (Round 2)

Found by analyzing source code at `/home/user/cortex-source/`

---

## Bug #1: Active Count Never Decremented on Agent Shutdown (CRITICAL - Memory Leak + Resource Exhaustion)

**File:** `src/cortex-agents/src/control.rs` lines 325-334

**Severity:** Critical - Permanent resource exhaustion

**Type:** Resource leak / Logic error

**Description:**
The `active_count` is incremented when agents are inserted (line 188) but NEVER decremented when agents shutdown. This causes:
1. Permanent memory leak (agents stay in registry)
2. Spawn limit blockage (once limit reached, no new agents can spawn)

```rust
pub async fn shutdown_agent(&self, id: AgentThreadId) -> Result<(), AgentControlError> {
    if let Some(thread) = self.state.get_thread(id).await {
        thread.set_status(AgentThreadStatus::Shutdown);
        // Keep in registry for status queries
        // BUG: Never calls self.state.active_count.fetch_sub(1)!
        Ok(())
    } else {
        Err(AgentControlError::AgentNotFound(id))
    }
}
```

**Compare with insert_thread (line 188):**
```rust
pub async fn insert_thread(&self, thread: AgentThread) {
    // ...
    self.active_count.fetch_add(1, Ordering::AcqRel);  // Incremented here
}
```

**Expected Behavior:**
`shutdown_agent()` should decrement `active_count` to allow new agents to spawn.

---

## Bug #2: TOCTOU Race Condition in Spawn Slot Reservation

**File:** `src/cortex-collab/src/guards.rs` lines 53-70

**Severity:** High - Concurrency limit bypass

**Type:** Race condition (TOCTOU)

**Description:**
The spawn slot reservation has a time-of-check to time-of-use race condition. The lock is released before the atomic increment:

```rust
pub async fn reserve_spawn_slot(self: &Arc<Self>) -> Option<SpawnReservation> {
    let threads = self.threads_set.lock().await;     // Line 54: Lock acquired
    let current_count = threads.len();
    let pending = self.pending_count.load(Ordering::Acquire);

    if current_count + pending >= self.max_threads {  // Line 58: Check
        return None;
    }
    // Lock IMPLICITLY RELEASED here!

    // Another thread can now acquire the lock and pass the check

    self.pending_count.fetch_add(1, Ordering::AcqRel);  // Line 63: Increment (too late!)
    self.total_count.fetch_add(1, Ordering::AcqRel);
```

**Race Scenario:**
1. Thread A: reads count=9, pending=0, check passes (9+0 < 10), releases lock
2. Thread B: reads count=9, pending=0, check passes, releases lock
3. Thread A: increments pending → 1
4. Thread B: increments pending → 2 (NOW count + pending = 11 > 10!)

**Expected Behavior:**
The check and increment should be atomic (hold lock during increment).

---

## Bug #3: Blocking Synchronous I/O in Async MCP Client

**File:** `src/cortex-engine/src/mcp/client.rs` lines 388-392

**Severity:** High - Blocks tokio runtime

**Type:** Blocking I/O in async context

**Description:**
Using synchronous `std::io::BufReader::read_line()` inside an async function blocks the entire tokio runtime thread:

```rust
async fn send_stdio_request(&self, request: &JsonRpcRequest) -> Result<JsonRpcResponse> {
    // ...
    let mut reader = BufReader::new(stdout);  // std::io::BufReader (SYNCHRONOUS!)
    let mut line = String::new();
    reader.read_line(&mut line)?;  // BLOCKING CALL in async fn!
    serde_json::from_str(&line).context("Failed to parse JSON-RPC response")
}
```

**Expected Behavior:**
Use `tokio::io::AsyncBufReadExt` with `tokio::io::BufReader` for async I/O.

---

## Bug #4: Network Access Logic Bug in Autonomy Levels

**File:** `src/cortex-cli/src/exec_cmd/autonomy.rs` lines 61-66

**Severity:** High - Security/Functionality bug

**Type:** Logic error

**Description:**
The network access policy uses exact equality which creates inconsistent behavior:

```rust
AutonomyLevel::Low | AutonomyLevel::Medium => SandboxPolicy::WorkspaceWrite {
    writable_roots: vec![cwd.to_path_buf()],
    network_access: *self == AutonomyLevel::Medium,  // BUG: Only Medium gets network
    ...
},
AutonomyLevel::High => SandboxPolicy::WorkspaceWrite {
    writable_roots: vec![cwd.to_path_buf()],
    network_access: true,  // High also needs network!
    ...
},
```

**Issue:** Both Low and Medium match the same arm, but only Medium gets network access. The pattern match structure is confusing and the condition should be `*self >= AutonomyLevel::Medium`.

---

## Bug #5: TOCTOU Race in MCP Server State Validation

**File:** `src/cortex-mcp-server/src/server.rs` lines 226-231

**Severity:** High - Double initialization possible

**Type:** Race condition (TOCTOU)

**Description:**
The state check and state update use separate lock acquisitions:

```rust
async fn handle_initialize(&self, params: Option<Value>) -> Result<Value, JsonRpcError> {
    let current_state = *self.state.read().await;  // READ lock (released after)
    if current_state != ServerState::Uninitialized {
        return Err(JsonRpcError::invalid_request("Server already initialized"));
    }
    // Lock released here!
    // Another thread can check and also pass here

    *self.state.write().await = ServerState::Initializing;  // WRITE lock (new lock)
```

**Race Scenario:**
1. Thread A: reads state = Uninitialized, check passes, releases lock
2. Thread B: reads state = Uninitialized, check passes
3. Thread A: acquires write lock, sets Initializing
4. Thread B: waits, then sets Initializing again (double init!)

**Expected Behavior:**
Use a single write lock or compare-and-swap for atomicity.

---

## Bug #6: Spinner Widget Width Miscalculation (6+ files affected)

**Files affected:**
- `src/cortex-core/src/widgets/spinner/streaming.rs:96`
- `src/cortex-core/src/widgets/spinner/progress.rs:66, 75`
- `src/cortex-core/src/widgets/spinner/status.rs:100`
- `src/cortex-core/src/widgets/spinner/tool.rs:80, 89`
- `src/cortex-core/src/widgets/spinner/approval.rs:89`

**Severity:** Medium - TUI corruption

**Type:** Unicode width calculation error

**Description:**
All spinner widgets use `chars().count()` for display width calculation instead of proper Unicode display width:

```rust
let spinner_char = self.spinner.frame();
buf.set_string(x, area.y, spinner_char, spinner_style);
x += spinner_char.chars().count() as u16;  // BUG: counts code points, not display width

let streaming_text = " Streaming...";
buf.set_string(x, area.y, streaming_text, text_style);
x += streaming_text.len() as u16;  // BUG: mixing byte length with code point count
```

**Issue:**
- `chars().count()` counts Unicode code points, not terminal display width
- Wide characters (emoji 🔄, CJK 日本) are 2 cells wide but `chars().count()` returns 1
- Results in overlapping/misaligned TUI output

**Expected Behavior:**
Use `unicode-width` crate's `UnicodeWidthStr::width()` for proper display width.

---

## Bug #7: All Environment Variables Collected Including Secrets

**File:** `src/cortex-engine/src/agent/state.rs` line 48

**Severity:** High - Security vulnerability

**Type:** Sensitive data exposure

**Description:**
The agent state copies ALL environment variables without filtering:

```rust
env: std::env::vars().collect(),  // Copies EVERYTHING including secrets!
```

**Exposed Data:**
- API_KEY, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
- DB_PASSWORD, DATABASE_URL with credentials
- GITHUB_TOKEN, GITLAB_TOKEN, NPM_TOKEN
- SSH_KEY, PRIVATE_KEY
- Any OAuth tokens or credentials

This state can be:
- Logged
- Serialized to disk
- Sent to LLM APIs
- Exposed in error messages

**Expected Behavior:**
Filter environment variables to a safe allowlist or explicitly exclude sensitive patterns.

---

## Bug #8: Missing HTTP Timeout in MCP Transport

**File:** `src/cortex-mcp-client/src/transport.rs` lines 493-512

**Severity:** High - Potential hang

**Type:** Missing timeout

**Description:**
HTTP transport sends requests without any timeout configuration:

```rust
async fn send_request(&self, request: JsonRpcRequest) -> Result<JsonRpcResponse> {
    let mut req = self.client.post(self.base_url.clone()).json(&request);

    for (key, value) in &self.headers {
        req = req.header(key, value);
    }

    let response = req.send().await.context("HTTP request failed")?;
    // No timeout! Server can hang indefinitely
```

**Expected Behavior:**
Set request timeout: `self.client.post(...).timeout(Duration::from_secs(30))`.

---

## Bug #9: styled_output Builds String But Never Uses It

**File:** `src/cortex-cli/src/styled_output.rs` lines 163-187

**Severity:** Medium - Wasted computation + missing flush

**Type:** Logic error

**Description:**
The function builds a `formatted` string but then ignores it:

```rust
fn print_styled_internal(msg_type: MessageType, message: &str, to_stderr: bool, bold: bool) {
    let formatted = if use_colors {
        if bold {
            format!("{}{} {}{}", color, icon, message, reset)
        } else {
            format!("{}{}{} {}", color, bold_code, icon, message)
                .replace(bold_code, "")  // Built but NEVER USED!
                + reset
        }
    } else {
        format!("{} {}", icon, message)
    };

    // Then IGNORES `formatted` and rebuilds the same thing:
    if use_colors {
        if to_stderr {
            let _ = write!(std::io::stderr(), "{}{} {}{}", color, icon, message, reset);
            let _ = writeln!(std::io::stderr());  // Also missing flush!
```

**Issues:**
1. `formatted` variable is never used (wasted CPU)
2. Stream is never flushed after write
3. ANSI escape sequences may not appear immediately

---

## Bug #10: Untracked Spawned Task in MCP Server Builder

**File:** `src/cortex-mcp-server/src/builder.rs` lines 141-145

**Severity:** Medium - Fire-and-forget with no error handling

**Type:** Missing error handling

**Description:**
Tool registration is spawned as a fire-and-forget task:

```rust
pub fn build(self) -> Result<Arc<McpServer>> {
    // ...
    tokio::spawn(async move {  // Fire-and-forget!
        for handler in tools {
            server_clone.register_tool(handler).await;
        }
    });
    Ok(server)  // Returns immediately, registration may fail silently
}
```

**Issue:** If tool registration fails, the error is silently dropped. The caller has no way to know if tools were actually registered.

**Expected Behavior:**
Await the task or return a handle for the caller to check.

---

## Summary

| Bug # | Title | Severity | Type | File |
|-------|-------|----------|------|------|
| 1 | Active count never decremented | Critical | Resource leak | control.rs |
| 2 | TOCTOU in spawn slot reservation | High | Race condition | guards.rs |
| 3 | Blocking I/O in async MCP client | High | Blocking I/O | client.rs |
| 4 | Network access logic bug | High | Logic error | autonomy.rs |
| 5 | TOCTOU in MCP server state | High | Race condition | server.rs |
| 6 | Spinner width miscalculation | Medium | Unicode bug | 6 files |
| 7 | Environment secrets exposed | High | Security | state.rs |
| 8 | Missing HTTP timeout | High | Missing timeout | transport.rs |
| 9 | styled_output builds unused string | Medium | Logic error | styled_output.rs |
| 10 | Untracked spawned task | Medium | Missing error handling | builder.rs |

**Total: 10 unique bugs (non-duplicates)**
- Critical: 1
- High: 6
- Medium: 3
