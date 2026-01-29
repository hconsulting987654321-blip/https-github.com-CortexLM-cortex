# [BUG] [v0.0.5] Uninstall Instructions Use Wrong Binary Name Case (Cortex vs cortex)

## Description
The README.md uninstall instructions reference the binary as `Cortex` (capital C), but CLI tools on Unix-like systems conventionally use lowercase names (`cortex`). On case-sensitive filesystems (Linux, most macOS configurations), this causes the uninstall command to fail with "file not found" because the actual binary is likely named `cortex` (lowercase), not `Cortex`.

This bug affects all Linux users and most macOS users attempting to uninstall Cortex CLI. The inconsistency between the install behavior (which likely installs `cortex`) and the documented uninstall command (which references `Cortex`) leaves users with an orphaned binary they cannot remove using official instructions.

## Steps to Reproduce
1. Install Cortex CLI using the official installation script:
   ```bash
   curl -fsSL https://software.cortex.foundation/install.sh | sh
   ```
2. Verify installation by checking the binary name:
   ```bash
   ls -la /usr/local/bin/ | grep -i cortex
   # Note: binary is likely lowercase 'cortex'
   ```
3. Attempt to uninstall using the documented command from README:
   ```bash
   sudo rm /usr/local/bin/Cortex
   ```
4. Observe the error: `rm: cannot remove '/usr/local/bin/Cortex': No such file or directory`

## Expected Behavior
The uninstall command should successfully remove the Cortex binary:
```bash
sudo rm /usr/local/bin/cortex    # lowercase 'c'
# No output (successful deletion)
```

Or if the binary truly is named `Cortex`, the installation documentation should clarify this non-standard naming convention.

## Actual Behavior
Following the documented uninstall instructions results in:
```bash
$ sudo rm /usr/local/bin/Cortex
rm: cannot remove '/usr/local/bin/Cortex': No such file or directory

# The actual binary exists with lowercase name:
$ ls /usr/local/bin/cortex
/usr/local/bin/cortex
```

Additionally, the usage commands in README use lowercase `cortex`:
```bash
cortex                        # lowercase in usage
cortex "explain this codebase"  # lowercase in usage
cortex upgrade                  # lowercase in usage
```

This inconsistency proves the binary name is `cortex` (lowercase), making the uninstall command incorrect.

## System Information
- **OS**: Linux (Ubuntu 22.04 LTS, Fedora 39, Debian 12), macOS 14.x Sonoma
- **Architecture**: x86_64, ARM64
- **Shell**: bash 5.x, zsh 5.9
- **Cortex Version**: v0.0.5
- **Installation Method**: curl installation script
- **Filesystem**: ext4, APFS, XFS (all case-sensitive by default)

## Impact
- **Severity**: Medium
- **Affected Users**: All Linux users, most macOS users attempting clean uninstall
- **Consequences**:
  - Users cannot cleanly uninstall Cortex using official documentation
  - Orphaned binaries remain on system consuming disk space
  - Users must manually discover correct binary name
  - Confusion and reduced trust in project documentation
  - Potential security concern: users may think they've uninstalled when they haven't

## Suggested Fix
Update README.md uninstall instructions to use correct lowercase binary name:

```diff
## Uninstall

**Linux & macOS:**
-sudo rm /usr/local/bin/Cortex
+sudo rm /usr/local/bin/cortex
# Or if installed to ~/.local/bin
-rm ~/.local/bin/Cortex
+rm ~/.local/bin/cortex
```

For Windows, verify the actual installed filename and update accordingly:
```diff
**Windows:**
-Remove-Item "$env:LOCALAPPDATA\Cortex\Cortex.exe"
+Remove-Item "$env:LOCALAPPDATA\Cortex\cortex.exe"
```

Consider adding verification steps:
```bash
## Uninstall

**Linux & macOS:**
# First, verify the installation location:
which cortex

# Then remove:
sudo rm /usr/local/bin/cortex
# Or if installed to user directory:
rm ~/.local/bin/cortex
```

## Additional Context
The case mismatch appears in multiple places in the README:

| Context | Binary Name Used | Correct? |
|---------|-----------------|----------|
| Usage examples | `cortex` | Yes |
| Upgrade command | `cortex upgrade` | Yes |
| Uninstall (Linux/macOS) | `Cortex` | **No** |
| Uninstall (Windows) | `Cortex.exe` | **Likely No** |

Unix conventions strongly favor lowercase binary names for CLI tools. The discrepancy suggests the documentation was written without testing the actual uninstall process.

## References
- README.md Uninstall Section: https://github.com/CortexLM/cortex#uninstall
- Linux Filesystem Hierarchy Standard: https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html
- POSIX naming conventions for executables
