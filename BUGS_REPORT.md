# Bug Reports - Cortex Repository

---

## BUG 1

### Title
[BUG] Broken link to non-existent docs/ directory in CLAUDE.md

### Description
The documentation contains a link to `./docs/` directory that does not exist in the repository.

### File Location
`CLAUDE.md` - Line 208

### Steps to Reproduce
1. Open `CLAUDE.md` on GitHub
2. Navigate to the "Resources" section
3. Click on the "Project Documentation" link
4. Observe 404 error

### Current Behavior
```markdown
- [Project Documentation](./docs/) [TBD]
```
Link returns 404 - directory does not exist.

### Expected Behavior
The link should either point to an existing resource or be removed until the directory is created.

### Severity
High

---

## BUG 2

### Title
[BUG] Documentation references non-existent `main` branch

### Description
The PR process documentation instructs users to "Create a feature branch from `main`" but no `main` branch exists in the repository.

### File Location
`CLAUDE.md` - Line 54

### Steps to Reproduce
1. Clone the repository
2. Run `git branch -a`
3. Observe no `main` branch exists
4. Try `git checkout main`

### Current Behavior
```
$ git checkout main
error: pathspec 'main' did not match any file(s) known to git
```

### Expected Behavior
Either create a `main` branch or update documentation to reference the actual default branch.

### Severity
Critical

---

## BUG 3

### Title
[BUG] Repository structure diagram shows non-existent files and directories

### Description
The repository structure section documents multiple directories (`src/`, `tests/`, `docs/`, `scripts/`) and files (`README.md`) that do not exist.

### File Location
`CLAUDE.md` - Lines 13-21

### Steps to Reproduce
1. Clone the repository
2. Run `ls -la`
3. Compare actual structure with documented structure

### Current Behavior
Documentation shows:
```
cortex/
├── CLAUDE.md           # EXISTS
├── README.md           # DOES NOT EXIST
├── src/                # DOES NOT EXIST
├── tests/              # DOES NOT EXIST
├── docs/               # DOES NOT EXIST
└── scripts/            # DOES NOT EXIST
```

### Expected Behavior
Documentation should reflect actual repository state or missing directories should be created.

### Severity
High

---

## BUG 4

### Title
[BUG] Invalid relative GitHub links for Issues and Pull Requests

### Description
The links to Issue Tracker and Pull Requests use incorrect relative paths (`../../issues` and `../../pulls`) that don't resolve properly on GitHub.

### File Location
`CLAUDE.md` - Lines 209-210

### Steps to Reproduce
1. Open `CLAUDE.md` on GitHub
2. Click on "Issue Tracker" link
3. Click on "Pull Requests" link
4. Observe both links fail to navigate to correct pages

### Current Behavior
```markdown
- [Issue Tracker](../../issues)
- [Pull Requests](../../pulls)
```
Links do not resolve to the repository's Issues/PR pages.

### Expected Behavior
Use proper GitHub repository links or correct relative path format.

### Severity
Medium

---

## BUG 5

### Title
[BUG] README.md listed as key file but does not exist

### Description
The "Key Files & Locations" table lists `README.md` as project documentation, but this file does not exist in the repository.

### File Location
`CLAUDE.md` - Line 177

### Steps to Reproduce
1. Open `CLAUDE.md`
2. Navigate to "Key Files & Locations" section
3. Note that `README.md` is listed
4. Check repository root - file does not exist

### Current Behavior
```markdown
| File/Directory | Purpose |
|----------------|---------|
| `CLAUDE.md` | AI assistant guidance (this file) |
| `README.md` | Project documentation |
```
`README.md` is documented but missing.

### Expected Behavior
Only list files that actually exist, or create the missing README.md.

### Severity
Medium

---

## BUG 6

### Title
[BUG] Environment Variables table contains invalid placeholder row

### Description
The Environment Variables table contains a placeholder row with `[TBD]` values that provides no useful information and breaks semantic meaning.

### File Location
`CLAUDE.md` - Lines 184-186

### Steps to Reproduce
1. Open `CLAUDE.md`
2. Navigate to "Environment Variables" section
3. Observe placeholder content

### Current Behavior
```markdown
| Variable | Description | Required |
|----------|-------------|----------|
| [TBD] | [TBD] | [TBD] |
```

### Expected Behavior
Either document actual environment variables, remove the placeholder row, or add a clear message like "No environment variables required at this time."

### Severity
Low

---

## BUG 7

### Title
[BUG] Local Development Setup contains incomplete placeholder instructions

### Description
The "Local Development Setup" section contains commented-out placeholder instructions instead of actual setup steps.

### File Location
`CLAUDE.md` - Lines 117-123

### Steps to Reproduce
1. Open `CLAUDE.md`
2. Navigate to "Local Development Setup" section
3. Attempt to follow instructions

### Current Behavior
```bash
# Example setup (update as needed)
git clone <repository-url>
cd cortex
# Install dependencies
# Configure environment
```
Instructions are incomplete - only comments provided.

### Expected Behavior
Provide complete, actionable setup instructions or clearly indicate the section is not yet available.

### Severity
High

---

## BUG 8

### Title
[BUG] Test commands are commented out and non-functional

### Description
The "Running Tests" section shows commented-out test commands that cannot be executed and don't correspond to any configured testing framework.

### File Location
`CLAUDE.md` - Lines 97-102

### Steps to Reproduce
1. Open `CLAUDE.md`
2. Navigate to "Running Tests" section
3. Attempt to run any of the listed commands
4. All commands fail - no test framework is configured

### Current Behavior
```bash
# Example commands (update as needed)
# npm test
# pytest
# cargo test
```
All commands are comments. No package.json, requirements.txt, or Cargo.toml exists.

### Expected Behavior
Document actual test commands or clearly indicate testing is not yet configured.

### Severity
Medium

---

## BUG 9

### Title
[BUG] Key Files table contains uninformative placeholder row

### Description
The "Key Files & Locations" table contains a row with `[TBD]` placeholders that adds no value and clutters the documentation.

### File Location
`CLAUDE.md` - Line 178

### Steps to Reproduce
1. Open `CLAUDE.md`
2. Navigate to "Key Files & Locations" section
3. Observe the placeholder row

### Current Behavior
```markdown
| [TBD] | [TBD] |
```

### Expected Behavior
Remove placeholder rows or replace with actual content when available.

### Severity
Low

---

## BUG 10

### Title
[BUG] Documentation shows incorrect project folder name

### Description
The repository structure shows `cortex/` as the root folder name, but the actual cloned repository has a different name, causing confusion.

### File Location
`CLAUDE.md` - Line 14

### Steps to Reproduce
1. Clone the repository
2. Note the actual folder name
3. Compare with documented structure showing `cortex/`

### Current Behavior
```markdown
cortex/
├── CLAUDE.md
```
Documentation assumes folder is named `cortex/` but actual repository clone name differs.

### Expected Behavior
Use a generic reference like `<project-root>/` or `./ ` or clarify the expected folder name after cloning.

### Severity
Low

---

# Summary

| Bug # | Title | Severity | Line(s) |
|-------|-------|----------|---------|
| 1 | Broken link to docs/ directory | High | 208 |
| 2 | Non-existent main branch referenced | Critical | 54 |
| 3 | Repository structure shows non-existent files | High | 13-21 |
| 4 | Invalid relative GitHub links | Medium | 209-210 |
| 5 | README.md listed but does not exist | Medium | 177 |
| 6 | Environment Variables placeholder row | Low | 184-186 |
| 7 | Incomplete setup instructions | High | 117-123 |
| 8 | Commented-out test commands | Medium | 97-102 |
| 9 | Key Files placeholder row | Low | 178 |
| 10 | Incorrect project folder name | Low | 14 |

**Total Bugs: 10**
- Critical: 1
- High: 3
- Medium: 3
- Low: 3
