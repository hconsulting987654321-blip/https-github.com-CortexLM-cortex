# [BUG] [v0.0.6] Uninstall Instructions Use Wrong Binary Name (Capital C Instead of Lowercase)

## Description
The uninstall instructions in the README.md use incorrect capitalization for the binary name. The documentation specifies `Cortex` (with capital C) but the actual installed binary is `cortex` (all lowercase). This causes the uninstall commands to fail silently, leaving the binary installed on the user's system.

## Location
- **File**: README.md
- **Section**: Uninstall > Linux & macOS
- **Line**: Approximately line 65-70 (Uninstall section)

## Steps to Reproduce
1. Install Cortex CLI using the documented installation method
2. Verify installation with `cortex --version`
3. Attempt to uninstall using the documented command:
   ```bash
   sudo rm /usr/local/bin/Cortex
   ```
4. Observe that the command completes without removing the actual binary

## Expected Behavior
The uninstall documentation should use the correct lowercase binary name:
```bash
sudo rm /usr/local/bin/cortex
# Or if installed to ~/.local/bin
rm ~/.local/bin/cortex
```

## Actual Behavior
The documentation incorrectly states:
```bash
sudo rm /usr/local/bin/Cortex
# Or if installed to ~/.local/bin
rm ~/.local/bin/Cortex
```

The `rm` command silently fails because the file `Cortex` (capital C) does not exist - only `cortex` (lowercase) exists.

## System Information
- **Documentation Version**: Current main branch (commit as of 2026-01-29)
- **Date Checked**: 2026-01-29
- **Cortex CLI Version**: v0.0.6
- **Platforms Affected**: Linux, macOS

## Impact
- **Severity**: Medium
- **Affected Users**: All Linux and macOS users attempting to uninstall
- **Consequence**: Users cannot uninstall the CLI using documented instructions. The binary remains on the system, potentially causing confusion and wasted disk space. Users may think uninstall succeeded when it did not.

## Suggested Fix
Update the README.md uninstall section:

```diff
### Linux & macOS

```bash
- sudo rm /usr/local/bin/Cortex
+ sudo rm /usr/local/bin/cortex
# Or if installed to ~/.local/bin
- rm ~/.local/bin/Cortex
+ rm ~/.local/bin/cortex
```

## Evidence
From the README.md:
> ```bash
> sudo rm /usr/local/bin/Cortex
> # Or if installed to ~/.local/bin
> rm ~/.local/bin/Cortex
> ```

Actual binary name after installation:
```
$ which cortex
/home/user/.local/bin/cortex

$ ls -la ~/.local/bin/cortex
-rwxr-xr-x 1 user user 12345678 Jan 29 18:00 /home/user/.local/bin/cortex
```

Note: Linux/macOS filesystems are case-sensitive, so `Cortex` and `cortex` are different files.

## References
- https://github.com/CortexLM/cortex/blob/main/README.md#uninstall
- Linux filesystem case sensitivity: https://en.wikipedia.org/wiki/Case_sensitivity#In_filesystems
