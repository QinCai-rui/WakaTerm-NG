#!/bin/bash
# WakaTerm NG Core Utilities Module
# Contains colors, logging functions, and common utilities

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    printf "\n${BLUE}[INFO]${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

# Detect shell (use parent process, not just $SHELL env)
detect_shell() {
    # Try to detect the actual running shell for this process
    local parent_shell
    parent_shell=$(ps -p $PPID -o comm= 2>/dev/null | awk '{print $1}')
    parent_shell=$(basename -- "$parent_shell")
    # Normalise some common shell names
    case "$parent_shell" in
        -bash|bash) echo "bash" ;;
        -zsh|zsh) echo "zsh" ;;
        -fish|fish) echo "fish" ;;
        *)
            # Fallback to $SHELL env if unknown
            if [ -n "$SHELL" ]; then
                # Use basename safely and fall back to 'unknown' if empty
                local shname
                shname=$(basename -- "$SHELL")
                if [ -n "$shname" ]; then
                    echo "$shname"
                else
                    echo "unknown"
                fi
            else
                if [ -n "$parent_shell" ]; then
                    echo "$parent_shell"
                else
                    echo "unknown"
                fi
            fi
            ;;
    esac
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Ask a yes/no question with a default of Yes. ONLY auto-answer when
# requested via -y/--yes flag or WAKATERM_AUTO_INSTALL env var.
ask_confirm_default_yes() {
    local prompt="$1"
    if [[ "$FORCE_YES" -eq 1 || "${WAKATERM_AUTO_INSTALL:-}" == "1" ]]; then
        printf "%s Y (auto-answered)\n" "$prompt"
        REPLY="Y"
        return 0
    fi

    # Force interactive mode (redirect from /dev/tty)
    if [[ ! -t 0 ]]; then
        printf "%s " "$prompt"
        read -r -n 1 REPLY </dev/tty
        echo
    else
        printf "%s " "$prompt"
        read -r -n 1 REPLY
        echo
    fi
}