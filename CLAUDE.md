# CLAUDE.md - AI Assistant Guide for Cortex

This file provides guidance for AI assistants working with the Cortex codebase. It describes the project structure, development workflows, and key conventions to follow.

## Project Overview

**Cortex** is a language model project under the CortexLM organization. This repository serves as the core codebase for the Cortex platform.

> **Note:** This is a new repository. Sections marked with `[TBD]` should be updated as the codebase develops.

## Repository Structure

```
cortex/
├── CLAUDE.md           # This file - AI assistant guidance
├── README.md           # Project documentation [TBD]
├── src/                # Source code [TBD]
├── tests/              # Test files [TBD]
├── docs/               # Documentation [TBD]
└── scripts/            # Build and utility scripts [TBD]
```

## Development Workflow

### Branch Naming Convention

- Feature branches: `feature/<description>`
- Bug fixes: `fix/<description>`
- Documentation: `docs/<description>`
- AI-assisted development: `claude/<session-id>` (auto-generated)

### Commit Message Format

Use conventional commit format:
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Pull Request Process

1. Create a feature branch from `main`
2. Make changes with clear, atomic commits
3. Ensure all tests pass
4. Submit PR with descriptive title and body
5. Address review feedback
6. Squash and merge when approved

## Code Style & Conventions

### General Principles

1. **Clarity over cleverness**: Write readable, self-documenting code
2. **DRY (Don't Repeat Yourself)**: Extract common patterns into reusable components
3. **KISS (Keep It Simple, Stupid)**: Avoid over-engineering
4. **Single Responsibility**: Each function/class should do one thing well

### Language-Specific Guidelines

[TBD - Update based on primary languages used in the project]

### Error Handling

- Use explicit error handling rather than silent failures
- Provide meaningful error messages
- Log errors appropriately for debugging

### Security Considerations

- Never commit secrets, API keys, or credentials
- Use environment variables for sensitive configuration
- Validate and sanitize all user inputs
- Follow OWASP security guidelines

## Testing

### Test Organization

[TBD - Update based on testing framework chosen]

### Running Tests

[TBD - Update with actual test commands]

```bash
# Example commands (update as needed)
# npm test
# pytest
# cargo test
```

### Test Coverage

- Aim for meaningful test coverage on critical paths
- Unit tests for individual functions/methods
- Integration tests for component interactions
- End-to-end tests for user workflows

## Build & Deployment

### Local Development Setup

[TBD - Update with setup instructions]

```bash
# Example setup (update as needed)
git clone <repository-url>
cd cortex
# Install dependencies
# Configure environment
```

### Build Commands

[TBD - Update with actual build commands]

### Deployment

[TBD - Update with deployment procedures]

## AI Assistant Guidelines

### When Working on This Codebase

1. **Read before modifying**: Always read existing code before suggesting changes
2. **Understand context**: Use exploration tools to understand the codebase structure
3. **Preserve style**: Match existing code style and conventions
4. **Test changes**: Ensure modifications don't break existing functionality
5. **Document appropriately**: Update documentation for significant changes

### Common Tasks

#### Exploring the Codebase
- Use `Glob` to find files by pattern
- Use `Grep` to search for code patterns
- Use the `Task` tool with `Explore` agent for complex searches

#### Making Changes
- Read relevant files before editing
- Make focused, minimal changes
- Avoid introducing unnecessary dependencies
- Test changes before committing

#### Debugging
- Read error messages carefully
- Trace the code path to understand the issue
- Use logging/debugging tools as appropriate
- Document the root cause and fix

### Things to Avoid

- Don't make changes without understanding existing code
- Don't over-engineer solutions
- Don't add features beyond what's requested
- Don't commit sensitive information
- Don't break existing functionality

## Key Files & Locations

[TBD - Update as the codebase develops]

| File/Directory | Purpose |
|----------------|---------|
| `CLAUDE.md` | AI assistant guidance (this file) |
| `README.md` | Project documentation |
| [TBD] | [TBD] |

## Environment Variables

[TBD - Document required environment variables]

| Variable | Description | Required |
|----------|-------------|----------|
| [TBD] | [TBD] | [TBD] |

## Dependencies

[TBD - Document key dependencies]

## Troubleshooting

### Common Issues

[TBD - Document common issues and solutions]

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request
5. Respond to review feedback

## Resources

- [Project Documentation](./docs/) [TBD]
- [Issue Tracker](../../issues)
- [Pull Requests](../../pulls)

---

*Last updated: 2026-01-29*

*This file should be updated as the project evolves. When making significant changes to the codebase structure, workflows, or conventions, please update this guide accordingly.*
