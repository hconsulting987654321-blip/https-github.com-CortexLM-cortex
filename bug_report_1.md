# [BUG] [v0.0.7] Skill tool handler always passes empty HashMap for arguments - skills with required args cannot receive parameters

## Description
The `SkillHandler` in `cortex-engine/src/tools/handlers/skill.rs` always passes an empty `HashMap` to `load_skill()`, preventing skills with required arguments from receiving any parameters. Additionally, the tool schema sets `additionalProperties: false`, which prevents the LLM from even including skill-specific arguments in the request.

This makes skills with required arguments (like `$1`, `$2`, or named parameters) completely non-functional.

## Location
- **File**: src/cortex-engine/src/tools/handlers/skill.rs
- **Function**: `SkillHandler::execute()`
- **Line**: Approximately lines 45-60

## Steps to Reproduce
1. Create a skill with required arguments in `~/.cortex/skills/my-skill/SKILL.md`:
```markdown
---
name: my-skill
arguments:
  - name: target
    required: true
---
Run: echo "Target is: $target"
```
2. Invoke the skill via the Skill tool
3. Observe: The skill receives no arguments, `$target` is empty

## Expected Behavior
The skill tool should accept additional properties in its schema and pass them to `load_skill()`:
```rust
async fn execute(&self, arguments: Value, _context: &ToolContext)
    -> Result<ToolResult> {
    let skill = arguments.get("skill").and_then(|v| v.as_str())
        .ok_or_else(|| anyhow::anyhow!("skill name required"))?;

    // Extract additional arguments beyond "skill"
    let mut args = HashMap::new();
    if let Value::Object(map) = &arguments {
        for (key, value) in map {
            if key != "skill" {
                if let Some(s) = value.as_str() {
                    args.insert(key.clone(), s.to_string());
                }
            }
        }
    }

    self.load_skill(skill, args).await
}
```

## Actual Behavior
The code always passes an empty HashMap:
```rust
async fn execute(&self, arguments: Value, _context: &ToolContext)
    -> Result<ToolResult> {
    let skill = arguments.get("skill").and_then(|v| v.as_str())
        .ok_or_else(|| anyhow::anyhow!("skill name required"))?;

    self.load_skill(skill, HashMap::new()).await  // <-- Always empty!
}
```

The tool definition also prevents any additional arguments:
```rust
fn definition(&self) -> ToolDefinition {
    ToolDefinition {
        name: "UseSkill".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "skill": {
                    "type": "string",
                    "description": "Name of the skill to execute..."
                }
            },
            "required": ["skill"],
            "additionalProperties": false  // <-- Blocks skill args!
        }),
        // ...
    }
}
```

## System Information
- **Cortex Version**: v0.0.7
- **File**: src/cortex-engine/src/tools/handlers/skill.rs
- **Affected Functionality**: Skill invocation with arguments

## Impact
- **Severity**: High
- **Affected Users**: Anyone creating skills with required arguments
- **Consequence**:
  - Skills with required arguments silently fail validation
  - Arguments like `$1`, `$target` remain unsubstituted
  - Skill documentation shows argument support but it doesn't work
  - Users cannot create parameterized skills

## Evidence
From skill.rs tool definition:
```rust
"additionalProperties": false  // Prevents passing skill-specific args
```

From skill.rs execute method:
```rust
self.load_skill(skill, HashMap::new())  // Args never populated
```

The `LoadedSkill::render()` method expects a HashMap of arguments for substitution, but it always receives an empty one.

## References
- https://github.com/CortexLM/cortex/blob/main/src/cortex-engine/src/tools/handlers/skill.rs
- Skill documentation shows `$ARGUMENTS`, `$1`, `$2` substitution which requires arguments to be passed
