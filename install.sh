#!/bin/bash
# WakaTerm NG Installation Script
# Modularized version - sources modules from modules/ directory

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

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# Global auto-yes control. Honor -y/--yes or WAKATERM_AUTO_INSTALL=1 env var.
FORCE_YES=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            FORCE_YES=1
            ;;
    esac
done

# Source all module files
if [[ -d "$MODULES_DIR" ]]; then
    # Source modules in the correct order to handle deps
    source "$MODULES_DIR/core_utils.sh"
    source "$MODULES_DIR/state_tracking.sh"
    source "$MODULES_DIR/wakatime_cli.sh"
    source "$MODULES_DIR/shell_integration.sh"
    source "$MODULES_DIR/installation.sh"
else
    printf "\033[0;31m[ERROR]\033[0m Modules directory not found at: $MODULES_DIR\n"
    printf "Please ensure all module files are present in the modules/ directory.\n"
    exit 1
fi

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
    
    case "$action" in
        "install")
            echo "=== WakaTerm NG Installation ==="
            check_dependencies
            check_wakatime_config
            install_wakaterm
            setup_shell_integration "$(detect_shell)"
            test_installation
            echo ""
            success "Installation complete!"
            log "WakaTerm NG will now track your terminal commands and send them to Wakatime."
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

# Run main function with all arguments
main "$@"