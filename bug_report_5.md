# [BUG] [v0.0.5] Installation to ~/.local/bin Fails Without PATH Configuration Instructions

## Description
The README.md documents an alternative installation path (`~/.local/bin`) for users without sudo access, but provides no instructions for adding this directory to the user's PATH. On most Linux distributions and macOS, `~/.local/bin` is NOT in the default PATH, causing the `cortex` command to be unavailable after installation.

Users who install without sudo will complete the installation process successfully, but then receive "command not found" when attempting to run `cortex`. The documentation assumes PATH configuration that doesn't exist on most systems, leaving users unable to use the tool they just installed.

## Steps to Reproduce
1. Install Cortex without sudo (to `~/.local/bin`):
   ```bash
   # Simulate non-sudo installation or explicit user-local install
   mkdir -p ~/.local/bin
   # (Installation script would place binary here)
   cp cortex ~/.local/bin/
   ```

2. Open a new terminal session

3. Attempt to run Cortex:
   ```bash
   cortex
   ```

4. Observe the error: `command not found: cortex`

5. Check if `~/.local/bin` is in PATH:
   ```bash
   echo $PATH | grep -q "$HOME/.local/bin" && echo "In PATH" || echo "NOT in PATH"
   # Output: NOT in PATH (on most systems)
   ```

## Expected Behavior
After installation, running `cortex` should work in any new terminal:
```bash
$ cortex
Welcome to Cortex CLI v0.0.5
Type 'help' for available commands.
>
```

Or, the installation process/documentation should:
1. Automatically add `~/.local/bin` to PATH in shell profile
2. Provide clear instructions for manual PATH configuration
3. Show a post-install message with required PATH setup

## Actual Behavior
```bash
$ cortex
bash: cortex: command not found

$ which cortex
cortex not found

$ ls ~/.local/bin/cortex
/home/user/.local/bin/cortex  # Binary exists but isn't in PATH

$ echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Note: ~/.local/bin is NOT included
```

The README uninstall section acknowledges this path exists:
```markdown
# Or if installed to ~/.local/bin
rm ~/.local/bin/Cortex
```

But never explains how to configure PATH for this location.

## System Information
- **OS**: Ubuntu 22.04 LTS, Debian 12, Fedora 39, macOS 14.x (systems where ~/.local/bin isn't in default PATH)
- **Architecture**: x86_64, ARM64
- **Shell**: bash 5.x (default ~/.bashrc doesn't include ~/.local/bin), zsh 5.9
- **Cortex Version**: v0.0.5
- **Installation Method**: Non-sudo installation to ~/.local/bin

## Impact
- **Severity**: Medium
- **Affected Users**: All users installing without sudo privileges, including:
  - Users on shared servers without admin access
  - Users following security best practices (avoiding sudo for user tools)
  - Users in corporate environments with restricted permissions
  - macOS users who prefer user-local installations
- **Consequences**:
  - Installation appears successful but tool is unusable
  - Users unfamiliar with PATH configuration are stuck
  - Creates poor first-time experience
  - Increases support requests for "cortex not found" issues
  - Users may incorrectly assume installation failed

## Suggested Fix

### 1. Update README with PATH Instructions

Add a section after installation instructions:

```markdown
### PATH Configuration

If you installed to `~/.local/bin` (non-sudo installation), add it to your PATH:

**Bash** (~/.bashrc):
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Zsh** (~/.zshrc):
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Fish** (~/.config/fish/config.fish):
```fish
fish_add_path ~/.local/bin
```

Verify installation:
```bash
cortex --version
```
```

### 2. Update Installation Script to Handle PATH

The install.sh should automatically configure PATH or provide guidance:

```bash
#!/bin/bash
# ... installation logic ...

INSTALL_DIR="$HOME/.local/bin"

# Install binary
mkdir -p "$INSTALL_DIR"
cp cortex "$INSTALL_DIR/"

# Check if INSTALL_DIR is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "NOTE: $INSTALL_DIR is not in your PATH."
    echo ""
    echo "Add it to your shell profile:"
    echo ""

    if [[ -n "$BASH_VERSION" ]]; then
        echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
        echo "  source ~/.bashrc"
    elif [[ -n "$ZSH_VERSION" ]]; then
        echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
        echo "  source ~/.zshrc"
    else
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    echo ""
fi

echo "Installation complete!"
```

### 3. Add Automatic PATH Configuration (Optional)

For a better user experience, offer to auto-configure:

```bash
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    read -p "Add $INSTALL_DIR to PATH automatically? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        SHELL_PROFILE=""
        if [[ -f "$HOME/.bashrc" ]]; then
            SHELL_PROFILE="$HOME/.bashrc"
        elif [[ -f "$HOME/.zshrc" ]]; then
            SHELL_PROFILE="$HOME/.zshrc"
        elif [[ -f "$HOME/.profile" ]]; then
            SHELL_PROFILE="$HOME/.profile"
        fi

        if [[ -n "$SHELL_PROFILE" ]]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_PROFILE"
            echo "Added to $SHELL_PROFILE. Restart your terminal or run: source $SHELL_PROFILE"
        fi
    fi
fi
```

## Additional Context

### Default PATH Behavior by System

| System | ~/.local/bin in PATH by Default |
|--------|--------------------------------|
| Ubuntu 22.04+ | Sometimes (if directory exists at login) |
| Debian 12 | No |
| Fedora 39 | No |
| Arch Linux | No |
| macOS | No |
| CentOS/RHEL | No |

### Related XDG Base Directory Standard

The `~/.local/bin` directory follows the XDG Base Directory Specification, but adoption of this path in default PATH varies widely. The installation documentation should not assume its presence.

### Why This Matters

Modern CLI tools like Rust's `cargo`, Haskell's `stack`, and Python's `pipx` all handle PATH configuration gracefully:
- Cargo: Adds `~/.cargo/bin` to PATH and shows post-install message
- pipx: Runs `pipx ensurepath` to configure PATH automatically
- Homebrew: Shows post-install PATH instructions

Cortex should follow these established patterns.

## References
- README.md Uninstall Section (acknowledges ~/.local/bin): https://github.com/CortexLM/cortex#uninstall
- XDG Base Directory Specification: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
- Cargo PATH handling: https://doc.rust-lang.org/cargo/getting-started/installation.html
- pipx ensurepath: https://pypa.github.io/pipx/
