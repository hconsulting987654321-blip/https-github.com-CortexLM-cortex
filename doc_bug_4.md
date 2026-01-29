# [BUG] [v0.0.6] Windows Uninstall Instructions Use Incorrect Path Capitalization

## Description
The Windows uninstall instructions in README.md specify the path `$env:LOCALAPPDATA\Cortex\Cortex.exe` with capital "C" for both the folder and executable name. However, the actual installation likely uses lowercase naming consistent with the Linux/macOS binary (`cortex`). This causes the Remove-Item command to fail, leaving the application installed.

## Location
- **File**: README.md
- **Section**: Uninstall > Windows
- **Line**: Approximately line 72-75

## Steps to Reproduce
1. Install Cortex CLI on Windows using the PowerShell installation method:
   ```powershell
   irm https://software.cortex.foundation/install.ps1 | iex
   ```
2. Attempt to uninstall using the documented command:
   ```powershell
   Remove-Item "$env:LOCALAPPDATA\Cortex\Cortex.exe"
   ```
3. Observe that the command fails or reports file not found
4. Check the actual installation path to find the correct casing

## Expected Behavior
The uninstall documentation should use the correct path that matches the actual installation:
```powershell
Remove-Item "$env:LOCALAPPDATA\cortex\cortex.exe"
```

Or potentially:
```powershell
Remove-Item "$env:LOCALAPPDATA\Programs\cortex\cortex.exe"
```

## Actual Behavior
The documentation states:
```powershell
Remove-Item "$env:LOCALAPPDATA\Cortex\Cortex.exe"
# Remove from PATH via System Properties > Environment Variables
```

This path uses `Cortex` (capital C) twice, which may not match the actual installation directory structure.

## System Information
- **Documentation Version**: Current main branch (commit as of 2026-01-29)
- **Date Checked**: 2026-01-29
- **Platform**: Windows (x86_64, ARM64)
- **Browser**: N/A (documentation bug)

## Impact
- **Severity**: Medium
- **Affected Users**: All Windows users attempting to uninstall
- **Consequence**:
  - Uninstall command fails, user thinks they cannot remove the software
  - Users must manually search for the correct installation path
  - Inconsistent with Linux/macOS where binary is lowercase `cortex`
  - Creates frustration and wastes user time troubleshooting

## Suggested Fix
Update the Windows uninstall section with the correct path:

```diff
### Windows

```powershell
- Remove-Item "$env:LOCALAPPDATA\Cortex\Cortex.exe"
+ Remove-Item "$env:LOCALAPPDATA\cortex\cortex.exe"
# Remove from PATH via System Properties > Environment Variables
```

Additionally, consider adding more complete uninstall instructions:
```powershell
# Remove the Cortex CLI executable
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\cortex"

# To remove from PATH, run this in an elevated PowerShell:
# [Environment]::SetEnvironmentVariable("Path", ($env:Path -replace [regex]::Escape("$env:LOCALAPPDATA\cortex") + ";?", ""), "User")
```

## Evidence
From README.md Windows uninstall section:
> ```powershell
> Remove-Item "$env:LOCALAPPDATA\Cortex\Cortex.exe"
> # Remove from PATH via System Properties > Environment Variables
> ```

Comparison with Linux/macOS section which also uses incorrect casing:
> ```bash
> sudo rm /usr/local/bin/Cortex
> ```

The pattern of using `Cortex` (capital C) instead of `cortex` (lowercase) is consistent across both platform uninstall instructions, suggesting a systematic documentation error.

## Additional Notes
- While Windows filesystems (NTFS) are case-insensitive by default, using correct casing is still best practice
- The path structure `$env:LOCALAPPDATA\Cortex\` should be verified against actual installer behavior
- The incomplete PATH removal instructions ("via System Properties > Environment Variables") could be expanded with actual steps or a command

## References
- https://github.com/CortexLM/cortex/blob/main/README.md#uninstall
- Windows LOCALAPPDATA documentation: https://docs.microsoft.com/en-us/windows/deployment/usmt/usmt-recognized-environment-variables
- PowerShell Remove-Item documentation: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item
