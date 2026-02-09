# [BUG] [v0.0.7] TextInput cursor position cast to u16 causes overflow/panic for inputs longer than 65535 characters

## Description
The `TextInput` widget in `cortex-tui-components/src/input.rs` casts the cursor position from `usize` to `u16` without bounds checking when calculating the render position. For text inputs longer than 65,535 characters (the maximum value for u16), this will cause an integer overflow, rendering the cursor at the wrong position or potentially causing a panic in debug builds.

## Location
- **File**: src/cortex-tui-components/src/input.rs
- **Function**: `impl Widget for TextInput::render()`
- **Line**: Approximately line 175

## Steps to Reproduce
1. Create a text input component
2. Paste or type more than 65,535 characters
3. Move cursor to position beyond 65535
4. Observe cursor renders at wrong position (wraps around due to overflow)

```rust
let mut state = InputState::new().with_value("A".repeat(70000));
state.move_end(); // cursor = 70000
// When rendering, cursor_x = x + 70000 as u16 = x + 4464 (overflow!)
```

## Expected Behavior
The cursor should either:
1. Be clamped to the visible area, or
2. Use `saturating_cast` or bounds checking to prevent overflow, or
3. Use a larger integer type that can accommodate very long inputs

## Actual Behavior
The code performs an unchecked cast:
```rust
// Cursor
if self.focused {
    let cursor_x = x + self.state.cursor as u16;  // <-- Overflow if cursor > 65535
    if cursor_x < area.right()
        && let Some(cell) = buf.cell_mut((cursor_x, area.y))
    {
        cell.set_bg(CYAN_PRIMARY).set_fg(SURFACE_1);
    }
}
```

When `self.state.cursor` is 70,000:
- `70000 as u16` = 4464 (truncated, wraps around)
- Cursor renders at completely wrong position

## System Information
- **Cortex Version**: v0.0.7
- **File**: src/cortex-tui-components/src/input.rs
- **Affected Functionality**: Text input cursor rendering in TUI

## Impact
- **Severity**: Low
- **Affected Users**: Users who paste very large content into text inputs
- **Consequence**:
  - Cursor displays at wrong position
  - Visual confusion about where text will be inserted
  - In debug builds, may panic on overflow
  - Edge case but demonstrates missing bounds checking

## Suggested Fix
Use saturating arithmetic or explicit bounds checking:

```rust
// Cursor
if self.focused {
    // Safely calculate cursor position, clamping to u16::MAX
    let cursor_offset = self.state.cursor.min(u16::MAX as usize) as u16;
    let cursor_x = x.saturating_add(cursor_offset);

    if cursor_x < area.right() {
        if let Some(cell) = buf.cell_mut((cursor_x, area.y)) {
            cell.set_bg(CYAN_PRIMARY).set_fg(SURFACE_1);
        }
    }
}
```

Or better, handle horizontal scrolling for very long inputs:
```rust
// Calculate visible offset for long text
let visible_width = area.width.saturating_sub(label_width + 2) as usize;
let scroll_offset = if self.state.cursor > visible_width {
    self.state.cursor - visible_width + 1
} else {
    0
};
let visible_cursor = self.state.cursor - scroll_offset;
let cursor_x = x + visible_cursor as u16;
```

## Evidence
From input.rs:
```rust
impl Widget for TextInput<'_> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        // ... label rendering ...

        // Cursor
        if self.focused {
            let cursor_x = x + self.state.cursor as u16;  // OVERFLOW HERE
            if cursor_x < area.right()
                && let Some(cell) = buf.cell_mut((cursor_x, area.y))
            {
                cell.set_bg(CYAN_PRIMARY).set_fg(SURFACE_1);
            }
        }
    }
}
```

The `InputState` uses `usize` for cursor:
```rust
pub struct InputState {
    pub value: String,
    pub cursor: usize,  // <-- Can be > 65535
    // ...
}
```

## References
- https://github.com/CortexLM/cortex/blob/main/src/cortex-tui-components/src/input.rs
- Rust integer overflow behavior: https://doc.rust-lang.org/book/ch03-02-data-types.html#integer-overflow
- u16::MAX = 65535: https://doc.rust-lang.org/std/primitive.u16.html#associatedconstant.MAX
