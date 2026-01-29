# [BUG] [v0.0.6] Installation Documentation Missing PATH Persistence Instructions

## Description
The installation script outputs instructions to add the binary to PATH using `export PATH="$HOME/.local/bin:$PATH"`, but the README.md does not document that this export is temporary and only applies to the current shell session. Users who follow the installation and add the PATH export will lose access to the `cortex` command after closing their terminal, leading to confusion about why the command suddenly doesn't work.

## Location
- **File**: README.md
- **Section**: Installation (entire section)
- **Line**: N/A - Information is missing entirely

## Steps to Reproduce
1. Follow the Linux installation instructions:
   ```bash
   curl -fsSL https://software.cortex.foundation/install.sh | sh
   ```
2. If prompted, run the suggested export command:
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```
3. Verify `cortex --version` works
4. Close the terminal and open a new one
5. Try `cortex --version` again
6. Observe: `command not found: cortex`

## Expected Behavior
The documentation should include one of the following:
1. A note explaining that the PATH export is temporary
2. Instructions for making the PATH change permanent
3. Information about which shell profile file to modify (`.bashrc`, `.zshrc`, etc.)

Example of what should be documented:
```bash
# Add to your shell profile for permanent access
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Or for Zsh users:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Actual Behavior
The README.md Installation section shows:
```bash
curl -fsSL https://software.cortex.foundation/install.sh | sh
```

There is no mention of:
- PATH configuration requirements
- The temporary nature of shell exports
- How to persist the PATH change
- Which shell configuration file to modify
- Troubleshooting if `cortex` command is not found

## System Information
- **Documentation Version**: Current main branch (commit as of 2026-01-29)
- **Date Checked**: 2026-01-29
- **Platforms Affected**: Linux, macOS (any Unix-like system)
- **Shells Affected**: Bash, Zsh, Fish, and others

## Impact
- **Severity**: Medium
- **Affected Users**: New users on Linux/macOS, especially those unfamiliar with shell PATH configuration
- **Consequence**:
  - Users successfully install but cannot use the tool after restarting terminal
  - Creates confusion: "It worked yesterday, why doesn't it work now?"
  - Users may think installation is broken and reinstall unnecessarily
  - Poor first-time user experience
  - Increased support burden for common "command not found" issues

## Suggested Fix
Add a "Post-Installation" or "PATH Configuration" section to the README:

```diff
### Linux & macOS

```bash
curl -fsSL https://software.cortex.foundation/install.sh | sh
```

+ #### Making Cortex Available in New Terminals
+
+ The installer places the binary in `~/.local/bin`. To use `cortex` in all terminal sessions, add this directory to your PATH permanently:
+
+ **For Bash users** (most Linux distributions):
+ ```bash
+ echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
+ source ~/.bashrc
+ ```
+
+ **For Zsh users** (macOS default, some Linux):
+ ```bash
+ echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
+ source ~/.zshrc
+ ```
+
+ **For Fish users**:
+ ```fish
+ fish_add_path ~/.local/bin
+ ```
+
+ > **Note**: If you used `sudo` during installation, the binary may be in `/usr/local/bin` which is typically already in your PATH.
```

## Evidence
The installer output shows:
```
==> Installing to /home/user/.local/bin...
==> Cortex CLI v0.0.6 installed successfully!

Run 'cortex --help' to get started
```

But does not mention PATH configuration. The README also lacks this information.

Common user experience:
```bash
# Right after installation - works
$ cortex --version
cortex 0.0.6

# After opening new terminal - fails
$ cortex --version
bash: cortex: command not found

# User confusion: "But I just installed it!"
```

## Additional Context
This is a common documentation gap in CLI tools. Well-documented projects typically include:
1. Default installation path
2. PATH requirements
3. Shell-specific instructions for common shells
4. Troubleshooting for "command not found"

## References
- https://github.com/CortexLM/cortex/blob/main/README.md#installation
- Bash manual on startup files: https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html
- Zsh startup files: https://zsh.sourceforge.io/Doc/Release/Files.html
- XDG Base Directory Specification (for ~/.local/bin): https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
