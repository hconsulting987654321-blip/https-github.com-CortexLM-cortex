# [BUG] [v0.0.7] Skill check_tool() doesn't support wildcards in denied_tools - denying "Execute*" won't block "ExecuteCommand"

## Description
The `check_tool()` function in `cortex-skills/src/skill.rs` supports wildcard pattern matching for `allowed_tools` but NOT for `denied_tools`. This creates a security inconsistency where an administrator can allow `file*` to match all file tools, but cannot use `Execute*` in denied_tools to block all execution-related tools.

This allows skill configurations to be bypassed when new tools are added that match a pattern the administrator intended to block.

## Location
- **File**: src/cortex-skills/src/skill.rs
- **Function**: `check_tool()`
- **Line**: Approximately lines 85-120

## Steps to Reproduce
1. Create a SKILL.toml with:
```toml
name = "safe-reader"
description = "A skill that should only read files"
denied_tools = ["Execute*"]  # Intent: block all Execute-related tools
allowed_tools = []           # Allow everything except denied
```

2. Try to use tool "ExecuteBash" or "ExecuteCommand" with this skill
3. **Expected**: Tool is denied because it matches `Execute*`
4. **Actual**: Tool is ALLOWED because denied_tools doesn't support wildcards

## Expected Behavior
Wildcard patterns in `denied_tools` should work the same way as in `allowed_tools`:
```rust
// This should block: Execute, ExecuteBash, ExecuteCommand, ExecuteScript, etc.
denied_tools = ["Execute*"]
```

## Actual Behavior
The `check_tool()` function only uses simple case-insensitive string comparison for denied_tools:

```rust
// Only exact match (case-insensitive)
if self.config.denied_tools.iter().any(|t| t.eq_ignore_ascii_case(tool)) {
    return Err(SkillError::ToolDenied { ... });
}

// ... later, wildcard matching is ONLY done for allowed_tools
for pattern in &self.config.allowed_tools {
    if pattern.contains('*') && let Ok(glob) = glob::Pattern::new(...) {
        // Wildcard matching here
    }
}
```

The `denied_tools` check uses `eq_ignore_ascii_case` which only matches exact strings, not glob patterns.

## System Information
- **Cortex Version**: v0.0.7
- **File**: src/cortex-skills/src/skill.rs
- **Affected Functionality**: Skill tool permission system

## Impact
- **Severity**: Medium (Security)
- **Affected Users**: Skill authors who expect wildcard patterns in denied_tools
- **Consequence**:
  - Skills may inadvertently allow dangerous tools
  - Security policies cannot be expressed as patterns
  - Inconsistent behavior between allowed_tools and denied_tools
  - New tools matching a pattern won't be automatically blocked

## Suggested Fix
Add wildcard support to the denied_tools check:

```rust
pub fn check_tool(&self, tool: &str) -> Result<(), crate::SkillError> {
    // Check if explicitly denied (with wildcard support)
    for denied in &self.config.denied_tools {
        // Exact match (case-insensitive)
        if denied.eq_ignore_ascii_case(tool) {
            return Err(crate::SkillError::ToolDenied {
                tool: tool.to_string(),
                skill: self.name.clone(),
            });
        }

        // Wildcard match
        if denied.contains('*') {
            if let Ok(glob) = glob::Pattern::new(&denied.to_lowercase()) {
                if glob.matches(&tool.to_lowercase()) {
                    return Err(crate::SkillError::ToolDenied {
                        tool: tool.to_string(),
                        skill: self.name.clone(),
                    });
                }
            }
        }
    }

    // ... rest of the function
}
```

## Evidence
From skill.rs:
```rust
pub fn check_tool(&self, tool: &str) -> Result<(), crate::SkillError> {
    // Check if explicitly denied
    if self
        .config
        .denied_tools
        .iter()
        .any(|t| t.eq_ignore_ascii_case(tool))  // <-- No wildcard support!
    {
        return Err(crate::SkillError::ToolDenied { ... });
    }

    // ... later ...

    // Check for wildcard pattern matching (only for allowed_tools!)
    for pattern in &self.config.allowed_tools {
        if pattern.contains('*')
            && let Ok(glob) = glob::Pattern::new(&pattern.to_lowercase())
            && glob.matches(&tool.to_lowercase())
        {
            return Ok(());
        }
    }
```

The test only covers exact matches for denied tools:
```rust
#[test]
fn test_check_tool_denied() {
    skill.config.denied_tools = vec!["Execute".to_string()];
    assert!(skill.check_tool("Execute").is_err());
    // No test for: denied_tools = ["Execute*"] blocking "ExecuteBash"
}
```

## References
- https://github.com/CortexLM/cortex/blob/main/src/cortex-skills/src/skill.rs
- glob crate documentation: https://docs.rs/glob/latest/glob/
