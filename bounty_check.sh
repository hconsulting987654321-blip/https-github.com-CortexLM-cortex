#!/bin/bash
#
# Cortex CLI v0.0.5 - Bounty Bug Hunter Script
# Bittensor Platform Challenge
#
# Usage: ./bounty_check.sh [info|status|test|all]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Cortex version target
TARGET_VERSION="0.0.5"

# Print header
print_header() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           Cortex CLI v0.0.5 - Bounty Bug Hunter              ║"
    echo "║              Bittensor Platform Challenge                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Show bounty information
bounty_info() {
    echo -e "${BLUE}=== BOUNTY INFORMATION ===${NC}\n"

    echo -e "${YELLOW}Target:${NC} Cortex CLI"
    echo -e "${YELLOW}Version:${NC} v${TARGET_VERSION}"
    echo -e "${YELLOW}Repository:${NC} https://github.com/CortexLM/cortex"
    echo -e "${YELLOW}Documentation:${NC} https://docs.cortex.foundation"
    echo ""

    echo -e "${CYAN}Bug Categories:${NC}"
    echo "  1. Installation & Setup Issues"
    echo "  2. Command Execution Bugs"
    echo "  3. Configuration Handling"
    echo "  4. Session Management"
    echo "  5. Authentication/Security"
    echo "  6. UI/TUI Issues"
    echo ""

    echo -e "${CYAN}Issue Template Requirements:${NC}"
    echo "  - Title: [BUG] [v0.0.5] <description>"
    echo "  - Sections: Description, Steps to Reproduce, Expected, Actual"
    echo "  - System Information block"
    echo "  - Version confirmation"
    echo ""

    echo -e "${CYAN}Key Areas to Test:${NC}"
    echo "  - cortex github install (file handling)"
    echo "  - cortex run (parameter validation)"
    echo "  - cortex exec (autonomy levels)"
    echo "  - cortex config (TOML parsing)"
    echo "  - cortex mcp debug (server validation)"
    echo "  - Session persistence and recovery"
}

# Check system status and Cortex installation
status_check() {
    echo -e "${BLUE}=== SYSTEM STATUS CHECK ===${NC}\n"

    # System info
    echo -e "${YELLOW}System Information:${NC}"
    echo "  OS:           $(uname -s) $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Hostname:     $(hostname)"
    echo "  User:         $(whoami)"
    echo "  Shell:        ${SHELL:-unknown}"
    echo ""

    # Check Cortex installation
    echo -e "${YELLOW}Cortex CLI Status:${NC}"

    if command -v cortex &> /dev/null; then
        CORTEX_PATH=$(which cortex)
        echo -e "  ${GREEN}✓${NC} Cortex found at: ${CORTEX_PATH}"

        # Get version
        CORTEX_VERSION=$(cortex --version 2>/dev/null | head -1 || echo "unknown")
        echo "  Version: ${CORTEX_VERSION}"

        # Check if target version
        if [[ "${CORTEX_VERSION}" == *"${TARGET_VERSION}"* ]]; then
            echo -e "  ${GREEN}✓${NC} Target version v${TARGET_VERSION} confirmed"
        else
            echo -e "  ${YELLOW}⚠${NC} Version mismatch (expected v${TARGET_VERSION})"
        fi
    else
        echo -e "  ${RED}✗${NC} Cortex CLI not installed"
        echo ""
        echo "  Install with:"
        echo "    curl -fsSL https://software.cortex.foundation/install.sh | sh"
    fi
    echo ""

    # Check config paths
    echo -e "${YELLOW}Configuration Paths:${NC}"

    CONFIG_PATHS=(
        "$HOME/.config/cortex/config.toml:Main config"
        "$HOME/.config/cortex/auth.enc:Auth credentials"
        "$HOME/.local/share/cortex/sessions:Session storage"
        "$HOME/.cortex/agents:Custom agents"
        "$HOME/.cache/cortex/logs:Debug logs"
    )

    for path_info in "${CONFIG_PATHS[@]}"; do
        IFS=':' read -r path desc <<< "$path_info"
        if [[ -e "$path" ]]; then
            echo -e "  ${GREEN}✓${NC} ${desc}: ${path}"
        else
            echo -e "  ${YELLOW}○${NC} ${desc}: ${path} (not found)"
        fi
    done
    echo ""

    # Check GitHub workflow (if in git repo)
    echo -e "${YELLOW}GitHub Integration:${NC}"
    if [[ -d ".git" ]]; then
        if [[ -f ".github/workflows/Cortex.yml" ]]; then
            echo -e "  ${GREEN}✓${NC} Cortex workflow found"
        else
            echo -e "  ${YELLOW}○${NC} No Cortex workflow (run: cortex github install)"
        fi
    else
        echo "  Not in a git repository"
    fi
}

# Run bug reproduction tests
run_tests() {
    echo -e "${BLUE}=== BUG REPRODUCTION TESTS ===${NC}\n"

    if ! command -v cortex &> /dev/null; then
        echo -e "${RED}Error: Cortex CLI not installed. Cannot run tests.${NC}"
        return 1
    fi

    local tests_passed=0
    local tests_failed=0
    local tests_skipped=0

    # Test 1: GitHub Install File Exists Check
    echo -e "${CYAN}Test #1: GitHub Install File Handling${NC}"
    echo "  Testing if --force flag is required for existing files..."

    if [[ -d ".git" ]]; then
        mkdir -p .github/workflows 2>/dev/null || true

        # Create a test workflow file
        TEST_WORKFLOW=".github/workflows/Cortex.yml"
        if [[ ! -f "$TEST_WORKFLOW" ]]; then
            echo "name: Test" > "$TEST_WORKFLOW"
        fi

        # Check behavior (dry-run style - don't actually run)
        echo -e "  ${YELLOW}⚠${NC} Manual test required:"
        echo "    1. Ensure $TEST_WORKFLOW exists with custom content"
        echo "    2. Run: cortex github install"
        echo "    3. Check if file was overwritten without prompt"
        ((tests_skipped++))
    else
        echo -e "  ${YELLOW}○${NC} Skipped: Not in git repository"
        ((tests_skipped++))
    fi
    echo ""

    # Test 2: Invalid Parameter Validation
    echo -e "${CYAN}Test #2: Invalid Parameter Validation${NC}"
    echo "  Testing parameter validation..."

    # Test invalid temperature (if cortex run exists)
    echo "  - Testing invalid temperature value..."
    if cortex run --help &>/dev/null; then
        # This should fail with validation error
        if cortex run --temperature 99.0 "test" 2>&1 | grep -qi "error\|invalid\|validation"; then
            echo -e "    ${GREEN}✓${NC} Invalid temperature correctly rejected"
            ((tests_passed++))
        else
            echo -e "    ${RED}✗${NC} BUG: Invalid temperature not validated"
            ((tests_failed++))
        fi
    else
        echo -e "    ${YELLOW}○${NC} Skipped: cortex run not available"
        ((tests_skipped++))
    fi
    echo ""

    # Test 3: Config Format Check
    echo -e "${CYAN}Test #3: Configuration Format Consistency${NC}"
    CONFIG_FILE="$HOME/.config/cortex/config.toml"

    if [[ -f "$CONFIG_FILE" ]]; then
        echo "  Checking config file format..."

        # Check if it's valid TOML (basic check)
        if head -5 "$CONFIG_FILE" | grep -E '^\[|^[a-z_]+ ?=' &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Config appears to be TOML format"
            ((tests_passed++))
        elif head -5 "$CONFIG_FILE" | grep -E '^\{|"[a-z]+"' &>/dev/null; then
            echo -e "  ${RED}✗${NC} BUG: Config file is JSON, expected TOML"
            ((tests_failed++))
        else
            echo -e "  ${YELLOW}⚠${NC} Unknown config format"
            ((tests_skipped++))
        fi
    else
        echo -e "  ${YELLOW}○${NC} Config file not found (run cortex to initialize)"
        ((tests_skipped++))
    fi
    echo ""

    # Summary
    echo -e "${BLUE}=== TEST SUMMARY ===${NC}"
    echo -e "  ${GREEN}Passed:${NC}  $tests_passed"
    echo -e "  ${RED}Failed:${NC}  $tests_failed"
    echo -e "  ${YELLOW}Skipped:${NC} $tests_skipped"
    echo ""

    if [[ $tests_failed -gt 0 ]]; then
        echo -e "${RED}Bugs detected! See above for details.${NC}"
        return 1
    else
        echo -e "${GREEN}No bugs detected in automated tests.${NC}"
        echo "Note: Some tests require manual verification."
    fi
}

# Show identified bugs summary
show_bugs() {
    echo -e "${BLUE}=== IDENTIFIED BUGS (v${TARGET_VERSION}) ===${NC}\n"

    echo -e "${RED}Bug #1: GitHub Install Overwrites Without Warning${NC}"
    echo "  Severity: Medium"
    echo "  Command:  cortex github install"
    echo "  Issue:    Existing Cortex.yml overwritten without --force flag"
    echo ""

    echo -e "${RED}Bug #2: Invalid Event Parameters Not Validated${NC}"
    echo "  Severity: High"
    echo "  Command:  cortex run"
    echo "  Issue:    Invalid temperature, model, file paths not validated"
    echo ""

    echo -e "${RED}Bug #3: Config Format Inconsistency${NC}"
    echo "  Severity: Medium"
    echo "  Files:    config.toml vs sessions/*.json"
    echo "  Issue:    Mixed TOML/JSON causes parsing errors"
    echo ""

    echo -e "${CYAN}Full bug reports: ./BOUNTY_BUGS_V0.0.5.md${NC}"
}

# Main function
main() {
    print_header

    case "${1:-all}" in
        info)
            bounty_info
            ;;
        status)
            status_check
            ;;
        test)
            run_tests
            ;;
        bugs)
            show_bugs
            ;;
        all)
            bounty_info
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            status_check
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            show_bugs
            ;;
        help|--help|-h)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  info    Show bounty challenge information"
            echo "  status  Check system and Cortex installation status"
            echo "  test    Run bug reproduction tests"
            echo "  bugs    Show identified bugs summary"
            echo "  all     Run all checks (default)"
            echo "  help    Show this help message"
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

# Run main
main "$@"
