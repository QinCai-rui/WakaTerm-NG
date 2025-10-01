#!/bin/bash
# WakaTerm NG Installation Script

set -e

# If this script is piped to "sh" (curl | sh), ensure we are running under bash
# because we rely on bash features (read -n, [[ ... ]], local, etc.). If bash
# is available, re-exec under it reading from stdin. This preserves piped input.
if [ -z "${BASH_VERSION:-}" ]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash -s -- "$@"
    else
        printf "\033[0;31m[ERROR]\033[0m This installer requires bash. Please run it with bash.\n"
        exit 1
    fi
fi

# Configuration
INSTALL_DIR="$HOME/.local/share/wakaterm"
WAKATIME_CONFIG="$HOME/.wakatime.cfg"
STATE_FILE="$HOME/.local/share/wakaterm/.install_state.json"
INSTALL_TYPE="binary"  # Can be "binary" (Cython compiled) or "python" (raw Python)

# Global auto-yes control. Honour -y/--yes or WAKATERM_AUTO_INSTALL=1 env var.
FORCE_YES=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            FORCE_YES=1
            ;;
        --python)
            INSTALL_TYPE="python"
            ;;
        --binary|--cython)
            INSTALL_TYPE="binary"
            ;;
    esac
done

# Ask user for installation type preference (if not already set by command line)
ask_installation_type() {
    # Skip prompt if already set via command line
    if [[ "$FORCE_YES" == "1" ]]; then
        # Show selected type when auto-confirming
        case "$INSTALL_TYPE" in
            "binary")
                printf "\033[0;34mSelected: Cython compiled binaries (auto-confirmed)\033[0m\n"
                ;;
            "python")
                printf "\033[0;34mSelected: Python source files (auto-confirmed)\033[0m\n"
                ;;
        esac
        return 0
    fi
    
    # Skip prompt if installation type was set via command line args
    if [[ "$INSTALL_TYPE" != "binary" ]]; then
        printf "\033[0;34mSelected: Python source files (command line option)\033[0m\n"
        return 0
    fi
    
    # Check if we have access to a terminal for interactive input
    # Use /dev/tty if available (works even when script is piped)
    local input_source=""
    if [[ -r /dev/tty ]]; then
        input_source="/dev/tty"
    elif [[ -t 0 ]]; then
        input_source=""  # Use stdin (normal case)
    else
        # No terminal available - use default
        printf "\033[0;34mSelected: Cython compiled binaries (default - no terminal available)\033[0m\n"
        return 0
    fi
    
    printf "\n\033[0;34mChoose your installation type:\033[0m\n"
    printf "  1) Cython compiled binaries (recommended - faster performance, smaller size)\n"
    printf "  2) Python source files (easier to modify, requires Python runtime)\n"
    printf "\n"
    
    while true; do
        if [[ -n "$input_source" ]]; then
            # Read from /dev/tty when piped
            read -p "Enter your choice (1-2) [default: 1]: " -r choice < "$input_source"
        else
            # Read from stdin when running normally
            read -p "Enter your choice (1-2) [default: 1]: " -r choice
        fi
        
        case "${choice:-1}" in
            1)
                INSTALL_TYPE="binary"
                printf "\033[0;34mSelected: Cython compiled binaries\033[0m\n"
                break
                ;;
            2)
                INSTALL_TYPE="python"
                printf "\033[0;34mSelected: Python source files\033[0m\n"
                break
                ;;
            *)
                printf "\033[0;33mInvalid choice. Please enter 1 or 2.\033[0m\n"
                ;;
        esac
    done
}

# Source all module files
# User can override the GitHub raw base URL using GITHUB_RAW_BASE env var.
RAW_BASE="${GITHUB_RAW_BASE:-https://raw.githubusercontent.com/QinCai-rui/WakaTerm-NG/refs/heads/main}"

# Fetch a remote module and source it.
fetch_and_source() {
    local url="$1"
    local name="$2"
    local tmp
    tmp=$(mktemp) || tmp="/tmp/wakaterm_tmp_$$.sh"

    if command -v curl >/dev/null 2>&1; then
        # -sS: silent but show errors, -L to follow redirects, -w '%{http_code}' to capture status
        local http_status
        http_status=$(curl -sS -L -w '%{http_code}' -o "$tmp" "$url" 2>/dev/null || echo "000")
        if [[ "$http_status" == "200" && -s "$tmp" ]]; then
            # shellcheck disable=SC1090
            source "$tmp"
            rm -f "$tmp" >/dev/null 2>&1 || true
            return 0
        else
            rm -f "$tmp" >/dev/null 2>&1 || true
            printf "\n\033[0;31m[ERROR]\033[0m Failed to download %s from %s (HTTP %s).\n" "$name" "$url" "$http_status" >&2
            printf "\033[0;31m[ERROR]\033[0m Please check the repository URL or your network connection.\n" >&2
            return 1
        fi
    fi

    printf "\n\033[0;31m[ERROR]\033[0m curl not found; cannot fetch remote module: %s\n" "$name" >&2
    printf "\033[0;31m[ERROR]\033[0m Please install curl, or run the installer on a machine with network access.\n" >&2
    return 1
}

# Module loading functions
load_core_modules() {
    printf "Loading core utilities...\n"
    fetch_and_source "$RAW_BASE/modules/core_utils.sh" "core_utils.sh" || exit 1
}

load_state_tracking() {
    printf "Loading state tracking...\n"
    fetch_and_source "$RAW_BASE/modules/state_tracking.sh" "state_tracking.sh" || exit 1
}

load_wakatime_cli() {
    printf "Loading wakatime CLI...\n"
    fetch_and_source "$RAW_BASE/modules/wakatime_cli.sh" "wakatime_cli.sh" || exit 1
}

load_shell_integration() {
    printf "Loading shell integration...\n"
    fetch_and_source "$RAW_BASE/modules/shell_integration.sh" "shell_integration.sh" || exit 1
}

load_installation() {
    printf "Loading installation modules (this might take a while)...\n"
    fetch_and_source "$RAW_BASE/modules/binary_installer.sh" "binary_installer.sh" || exit 1
    fetch_and_source "$RAW_BASE/modules/source_installer.sh" "source_installer.sh" || exit 1
    fetch_and_source "$RAW_BASE/modules/testing.sh" "testing.sh" || exit 1
    fetch_and_source "$RAW_BASE/modules/installation_main.sh" "installation_main.sh" || exit 1
}

load_uninstallation() {
    printf "Loading uninstallation module...\n"
    fetch_and_source "$RAW_BASE/modules/uninstaller.sh" "uninstaller.sh" || exit 1
}

# Load modules based on subcommand requirements
load_modules_for_action() {
    local action="$1"
    
    # Always load core utilities first
    printf "(1/?) "; load_core_modules
    
    case "$action" in
        "install")
            printf "(2/5) "; load_state_tracking
            printf "(3/5) "; load_wakatime_cli
            printf "(4/5) "; load_shell_integration
            printf "(5/5) "; load_installation
            ;;
        "uninstall")
            printf "(2/3) "; load_state_tracking
            printf "(3/3) "; load_uninstallation
            ;;
        "upgrade")
            printf "(2/4) "; load_state_tracking
            printf "(3/4) "; load_wakatime_cli
            printf "(4/4) "; load_installation
            ;;
        "setup-integration")
            printf "(2/3) "; load_state_tracking
            printf "(3/3) "; load_shell_integration
            ;;
        "test")
            printf "(2/2) "; load_installation
            ;;
        "status")
            printf "(2/3) "; load_state_tracking
            printf "(3/3) "; load_installation
            ;;
        "help"|"-h"|"--help")
            # Only core utilities needed for help
            ;;
        *)
            # Unknown action - load core for error handling
            ;;
    esac
}

# Print usage
usage() {
    cat << EOF
WakaTerm NG Installation Script

Usage: $0 [OPTION]

Options:
    install             Install WakaTerm NG (default)
    uninstall           Remove WakaTerm NG
    upgrade             Upgrade to the latest version
    setup-integration   (Re)setup shell integration after installation
    test                Test current installation
    status              Show installation status and tracked changes
    help                Show this help message
    -y, --yes           Automatically answer yes to prompts (non-interactive)
    --python            Force Python source installation
    --binary, --cython  Force Cython compiled binary installation (default)

Examples:
    $0                              # Install with auto-detected shell
    $0 install                      # Explicit install
    $0 uninstall                    # Remove installation
    $0 upgrade                      # Upgrade to latest version
    $0 test                         # Test installation
    $0 setup-integration [shell]    # Setup integration for current or specified shell (bash|zsh|fish)

Environment:
    WAKATERM_AUTO_INSTALL=1   # same as -y, auto-accept prompts
    WAKATERM_ARCH=<arch>      # override automatically-detected arch (amd64, arm64, 386, ...)

EOF
}

# Main function
main() {
    local action="${1:-install}"
    
    # Load only the modules needed for this specific action
    load_modules_for_action "$action"
    
    case "$action" in
        "install")
            echo "=== WakaTerm NG Installation ==="
            ask_installation_type
            check_dependencies
            check_wakatime_config
            install_wakaterm
            setup_shell_integration "$(detect_shell)"
            set +e  # Don't fail on test failure
            test_installation
            set -e
            echo ""
            success "Installation complete!"
            log "WakaTerm NG will now track your terminal commands and send them to Wakatime."
            exit 0
            ;;
        "setup-integration")
            echo "=== WakaTerm NG Setup Integration ==="
            # Allow optional shell name in second arg, otherwise auto-detect
            local requested_shell="${2:-}"
            if [[ -n "$requested_shell" ]]; then
                setup_shell_integration "$requested_shell"
            else
                setup_shell_integration "$(detect_shell)"
            fi
            ;;
        "uninstall")
            echo "=== WakaTerm NG Uninstallation ==="
            uninstall
            ;;
        "upgrade")
            echo "=== WakaTerm NG Upgrade ==="
            upgrade_installation
            ;;
        "test")
            test_installation
            ;;
        "status")
            show_status
            ;;
        "help"|"-h"|"--help")
            usage
            ;;
        *)
            error "Unknown action: $action"
            usage
            exit 1
            ;;
    esac
}

main "$@"