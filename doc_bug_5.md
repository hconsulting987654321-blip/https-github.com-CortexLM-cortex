# [BUG] [v0.0.7] ResumePicker filter destroys original sessions list - cannot restore after clearing filter

## Description
The `apply_filter()` method in `cortex-resume/src/resume_picker.rs` uses `retain()` on `self.sessions` which destructively modifies the original list. When a user clears the filter, the filtered-out sessions are permanently lost from the picker until `load()` is called again. This breaks the expected filter/unfilter UX pattern.

Note: This is different from #6928 which covers `selected_index` not being reset. This bug is about the sessions data itself being destroyed.

## Location
- **File**: src/cortex-resume/src/resume_picker.rs
- **Function**: `apply_filter()`
- **Line**: Approximately lines 36-45

## Steps to Reproduce
1. Open resume picker with 10 sessions
2. Type a filter that matches 3 sessions
3. Observe: 3 sessions displayed (correct)
4. Clear the filter (backspace to empty)
5. Observe: Still only 3 sessions displayed (BUG - should show all 10)
6. Must reload sessions to see all 10 again

## Expected Behavior
Clearing the filter should restore all original sessions. The filter should work on a filtered view, not the source data:

```rust
pub struct ResumePicker {
    store: SessionStore,
    all_sessions: Vec<SessionSummary>,     // Original unfiltered list
    filtered_sessions: Vec<usize>,          // Indices into all_sessions
    selected_index: usize,
    filter: Option<String>,
}
```

## Actual Behavior
The code destructively modifies `self.sessions`:

```rust
fn apply_filter(&mut self) {
    if let Some(ref filter) = self.filter {
        let filter_lower = filter.to_lowercase();
        self.sessions.retain(|s| {   // <-- DESTROYS original list
            s.title.to_lowercase().contains(&filter_lower)
                || s.id.to_lowercase().contains(&filter_lower)
                || s.preview
                    .as_ref()
                    .map(|p| p.to_lowercase().contains(&filter_lower))
                    .unwrap_or(false)
        });
    }
}
```

Once `retain()` removes sessions, they're gone until the next `load()` call.

## System Information
- **Cortex Version**: v0.0.7
- **File**: src/cortex-resume/src/resume_picker.rs
- **Affected Functionality**: Session resume picker filtering

## Impact
- **Severity**: Medium
- **Affected Users**: All users who use the session filter and then clear it
- **Consequence**:
  - Sessions "disappear" when user clears filter
  - Users must exit and re-enter resume picker to see all sessions
  - Confusing UX - users may think sessions were deleted
  - Progressive filtering narrows results with no way to widen

## Suggested Fix
Store original sessions separately and filter into a separate indices list:

```rust
pub struct ResumePicker {
    store: SessionStore,
    all_sessions: Vec<SessionSummary>,
    visible_indices: Vec<usize>,
    selected_index: usize,
    filter: Option<String>,
}

impl ResumePicker {
    pub async fn load(&mut self, include_archived: bool) -> Result<()> {
        self.all_sessions = self.store.list_sessions(include_archived).await?;
        self.selected_index = 0;
        self.apply_filter();
        Ok(())
    }

    pub fn set_filter(&mut self, filter: Option<String>) {
        self.filter = filter;
        self.apply_filter();
    }

    fn apply_filter(&mut self) {
        self.visible_indices = if let Some(ref filter) = self.filter {
            let filter_lower = filter.to_lowercase();
            self.all_sessions
                .iter()
                .enumerate()
                .filter(|(_, s)| {
                    s.title.to_lowercase().contains(&filter_lower)
                        || s.id.to_lowercase().contains(&filter_lower)
                        || s.preview
                            .as_ref()
                            .map(|p| p.to_lowercase().contains(&filter_lower))
                            .unwrap_or(false)
                })
                .map(|(i, _)| i)
                .collect()
        } else {
            (0..self.all_sessions.len()).collect()
        };

        // Reset selection if out of bounds
        if self.selected_index >= self.visible_indices.len() {
            self.selected_index = 0;
        }
    }

    pub fn sessions(&self) -> impl Iterator<Item = &SessionSummary> {
        self.visible_indices.iter().map(|&i| &self.all_sessions[i])
    }
}
```

## Evidence
From resume_picker.rs:
```rust
pub struct ResumePicker {
    store: SessionStore,
    sessions: Vec<SessionSummary>,  // <-- Only one list, gets modified
    selected_index: usize,
    filter: Option<String>,
}

fn apply_filter(&mut self) {
    if let Some(ref filter) = self.filter {
        let filter_lower = filter.to_lowercase();
        self.sessions.retain(|s| {   // <-- Destructive modification
            s.title.to_lowercase().contains(&filter_lower)
            // ...
        });
    }
}

pub fn set_filter(&mut self, filter: Option<String>) {
    self.filter = filter;
    self.apply_filter();  // <-- Destroys sessions each time
}
```

The `set_filter` method is the public API for changing filters, and each call permanently removes non-matching sessions.

## References
- https://github.com/CortexLM/cortex/blob/main/src/cortex-resume/src/resume_picker.rs
- Related issue: #6928 (selected_index not reset) - different aspect of same function
- Vec::retain documentation: https://doc.rust-lang.org/std/vec/struct.Vec.html#method.retain
