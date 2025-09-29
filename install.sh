#!/bin/bash
# WakaTerm NG Installation Script
# Installs terminal wakatime plugin with respect to ~/.wakatime.cfg

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/.local/share/wakaterm"
WAKATIME_CONFIG="$HOME/.wakatime.cfg"

# Functions
log() {
    echo -e "\n${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command_exists python3; then
        error "Python 3 is required but not installed."
        exit 1
    fi

    if ! command_exists git; then
        error "Git is required but not installed."
        exit 1
    fi
    
    # Check if wakatime-cli is available
    local wakatime_cli="$HOME/.wakatime/wakatime-cli"
    if [[ ! -f "$wakatime_cli" ]]; then
        warn "wakatime-cli not found at $wakatime_cli"
        warn "Please install wakatime-cli first: https://wakatime.com/terminal"
        warn "Or download from: https://github.com/wakatime/wakatime-cli/releases"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then # if not yes, then
            exit 1
        fi
    else
        # Make sure it's executable
        chmod +x "$wakatime_cli" 2>/dev/null || true
        success "wakatime-cli found and ready"
    fi
    
    success "Dependencies satisfied"
}

# Check wakatime configuration
check_wakatime_config() {
    log "Checking Wakatime configuration..."
    
    if [[ ! -f "$WAKATIME_CONFIG" ]]; then
        warn "Wakatime config file not found at $WAKATIME_CONFIG"
        
        read -p "Would you like to create a basic config file? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            create_wakatime_config
        else
            warn "Continuing without config file. You can create one later."
            warn "You'll need to set WAKATIME_API_KEY environment variable."
        fi
    else
        # Check if API key exists in config
        if grep -q "api_key" "$WAKATIME_CONFIG"; then
            success "Wakatime config found with API key"
        else
            warn "Wakatime config found but no API key detected"
            read -p "Would you like to add your API key now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                add_api_key_to_config
            fi
        fi
    fi
}

# Create basic wakatime config
create_wakatime_config() {
    log "Creating basic Wakatime config..."
    
    read -p "Enter your Wakatime API key: " -s api_key
    echo
    
    if [[ -z "$api_key" ]]; then
        warn "No API key provided. Config not created."
        return 1
    fi
    
    cat > "$WAKATIME_CONFIG" << EOF
[settings]
debug = false
hidefilenames = false
ignore = 
    COMMIT_EDITMSG$
    PULLREQ_EDITMSG$
    MERGE_MSG$
    TAG_EDITMSG$
api_key = $api_key
EOF
    
    chmod 600 "$WAKATIME_CONFIG"
    success "Wakatime config created at $WAKATIME_CONFIG"
}

# Add API key to existing config
add_api_key_to_config() {
    read -p "Enter your Wakatime API key: " -s api_key
    echo
    
    if [[ -z "$api_key" ]]; then
        warn "No API key provided."
        return 1
    fi
    
    # Backup existing config
    cp "$WAKATIME_CONFIG" "$WAKATIME_CONFIG.backup"
    
    # Add or update API key
    if grep -q "api_key" "$WAKATIME_CONFIG"; then
        sed -i "s/api_key = .*/api_key = $api_key/" "$WAKATIME_CONFIG"
    else
        # Add to [settings] section or create it
        if grep -q "\[settings\]" "$WAKATIME_CONFIG"; then
            sed -i "/\[settings\]/a api_key = $api_key" "$WAKATIME_CONFIG"
        else
            echo -e "\n[settings]\napi_key = $api_key" >> "$WAKATIME_CONFIG"
        fi
    fi
    
    success "API key added to config"
}

# Install wakaterm files
install_wakaterm() {
    log "Installing WakaTerm NG..."
    
    # Clone files
    git clone https://github.com/QinCai-rui/WakaTerm-NG.git "$INSTALL_DIR" || {
        error "Failed to clone WakaTerm NG repository. If you have already installed it, consider running '$0 upgrade' instead."
        exit 1
    }
    
    success "WakaTerm NG installed to $INSTALL_DIR"
}

# Setup shell integration
setup_shell_integration() {
    local shell_name="$1"
    log "Setting up $shell_name integration..."
    
    case "$shell_name" in
        "bash")
            setup_bash_integration
            ;;
        "zsh")
            setup_zsh_integration
            ;;
        "fish")
            setup_fish_integration
            ;;
        *)
            warn "Unsupported shell: $shell_name"
            warn "Please manually source the appropriate shell integration file."
            ;;
    esac
}

setup_bash_integration() {
    local bashrc="$HOME/.bashrc"
    local bash_profile="$HOME/.bash_profile"
    local bashrc_local="$HOME/.bashrc.local"
    local source_line="source \"$INSTALL_DIR/shells/bash_wakaterm.sh\""
    
    # Check if .bashrc is writable (not a symlink to read-only file like in NixOS)
    local config_file="$bashrc"
    local is_readonly=false
    
    if [[ -L "$bashrc" ]]; then
        # It's a symlink, check if target is writable
        local target=$(readlink "$bashrc")
        if [[ "$target" =~ /nix/store || ! -w "$target" ]]; then
            is_readonly=true
        fi
    elif [[ -f "$bashrc" && ! -w "$bashrc" ]]; then
        is_readonly=true
    elif [[ ! -f "$bashrc" && -f "$bash_profile" ]]; then
        config_file="$bash_profile"
        if [[ -L "$bash_profile" ]]; then
            local target=$(readlink "$bash_profile")
            if [[ "$target" =~ /nix/store || ! -w "$target" ]]; then
                is_readonly=true
            fi
        elif [[ ! -w "$bash_profile" ]]; then
            is_readonly=true
        fi
    fi
    
    # If config files are read-only (like in NixOS), use alternative approaches
    if [[ "$is_readonly" == "true" ]]; then
        warn "Detected read-only shell configuration (possibly NixOS/home-manager)"
        
        # Try .bashrc.local (sourced by some configurations)
        if [[ -f "$bashrc" ]] && grep -q "bashrc.local\|\.local" "$bashrc" 2>/dev/null; then
            log "Using .bashrc.local for integration"
            config_file="$bashrc_local"
        else
            warn "Cannot automatically integrate with read-only configuration."
            warn "Please manually add the following line to your shell configuration:"
            warn "  $source_line"
            warn ""
            warn "For NixOS users, add this to your home-manager configuration:"
            warn "  programs.bash.initExtra = \"source \\\"$INSTALL_DIR/shells/bash_wakaterm.sh\\\"\";"
            return 1
        fi
    fi
    
    # Check if already added
    if grep -Fq "$source_line" "$config_file" 2>/dev/null; then
        warn "Bash integration already configured"
        return 0
    fi
    
    # Add integration
    if ! echo "" >> "$config_file" 2>/dev/null; then
        error "Failed to write to $config_file"
        warn "Please manually add the following line to your shell configuration:"
        warn "  $source_line"
        return 1
    fi
    
    echo "# WakaTerm NG Integration" >> "$config_file"
    echo "$source_line" >> "$config_file"
    
    success "Bash integration added to $(basename -- "$config_file")"
    log "Please restart your terminal or run: source $config_file"
}

setup_zsh_integration() {
    local zshrc="$HOME/.zshrc"
    local zshrc_local="$HOME/.zshrc.local"
    local source_line="source \"$INSTALL_DIR/shells/zsh_wakaterm.zsh\""
    local config_file="$zshrc"
    local is_readonly=false
    
    # Check if .zshrc is writable (not a symlink to read-only file like in NixOS)
    if [[ -L "$zshrc" ]]; then
        local target=$(readlink "$zshrc")
        if [[ "$target" =~ /nix/store || ! -w "$target" ]]; then
            is_readonly=true
        fi
    elif [[ -f "$zshrc" && ! -w "$zshrc" ]]; then
        is_readonly=true
    fi
    
    # If .zshrc is read-only, try alternative approaches
    if [[ "$is_readonly" == "true" ]]; then
        warn "Detected read-only zsh configuration (possibly NixOS/home-manager)"
        
        # Try .zshrc.local (sourced by some configurations)
        if [[ -f "$zshrc" ]] && grep -q "zshrc.local\|\.local" "$zshrc" 2>/dev/null; then
            log "Using .zshrc.local for integration"
            config_file="$zshrc_local"
        else
            warn "Cannot automatically integrate with read-only configuration."
            warn "Please manually add the following line to your zsh configuration:"
            warn "  $source_line"
            warn ""
            warn "For NixOS users, add this to your home-manager configuration:"
            warn "  programs.zsh.initExtra = \"source \\\"$INSTALL_DIR/shells/zsh_wakaterm.zsh\\\"\";"
            return 1
        fi
    fi
    
    # Check if already added
    if grep -Fq "$source_line" "$config_file" 2>/dev/null; then
        warn "Zsh integration already configured"
        return 0
    fi
    
    # Create config file if it doesn't exist and we can write to it
    if [[ ! -f "$config_file" ]]; then
        if ! touch "$config_file" 2>/dev/null; then
            error "Failed to create $config_file"
            warn "Please manually add the following line to your zsh configuration:"
            warn "  $source_line"
            return 1
        fi
    fi
    
    # Add integration
    if ! echo "" >> "$config_file" 2>/dev/null; then
        error "Failed to write to $config_file"
        warn "Please manually add the following line to your zsh configuration:"
        warn "  $source_line"
        return 1
    fi
    
    echo "# WakaTerm NG Integration" >> "$config_file"
    echo "$source_line" >> "$config_file"
    
    success "Zsh integration added to $(basename -- "$config_file")"
    log "Please restart your terminal or run: source $config_file"
}

setup_fish_integration() {
    local fish_config="$HOME/.config/fish/config.fish"
    local source_line="source \"$INSTALL_DIR/shells/fish_wakaterm.fish\""
    local is_readonly=false
    
    # Create config directory if it doesn't exist
    if ! mkdir -p "$(dirname "$fish_config")" 2>/dev/null; then
        error "Failed to create fish config directory"
        warn "Please manually add the following line to your fish configuration:"
        warn "  $source_line"
        return 1
    fi
    
    # Check if config file is writable (not a symlink to read-only file)
    if [[ -L "$fish_config" ]]; then
        local target=$(readlink "$fish_config")
        if [[ "$target" =~ /nix/store || ! -w "$target" ]]; then
            is_readonly=true
        fi
    elif [[ -f "$fish_config" && ! -w "$fish_config" ]]; then
        is_readonly=true
    fi
    
    # If fish config is read-only, provide manual instructions
    if [[ "$is_readonly" == "true" ]]; then
        warn "Detected read-only fish configuration (possibly NixOS/home-manager)"
        warn "Cannot automatically integrate with read-only configuration."
        warn "Please manually add the following line to your fish configuration:"
        warn "  $source_line"
        warn ""
        warn "For NixOS users, add this to your home-manager configuration:"
        warn "  programs.fish.interactiveShellInit = \"source \\\"$INSTALL_DIR/shells/fish_wakaterm.fish\\\"\";"
        return 1
    fi
    
    # Check if already added
    if grep -Fq "$source_line" "$fish_config" 2>/dev/null; then
        warn "Fish integration already configured"
        return 0
    fi
    
    # Create config file if it doesn't exist
    if [[ ! -f "$fish_config" ]]; then
        if ! touch "$fish_config" 2>/dev/null; then
            error "Failed to create $fish_config"
            warn "Please manually add the following line to your fish configuration:"
            warn "  $source_line"
            return 1
        fi
    fi
    
    # Add integration
    if ! echo "" >> "$fish_config" 2>/dev/null; then
        error "Failed to write to $fish_config"
        warn "Please manually add the following line to your fish configuration:"
        warn "  $source_line"
        return 1
    fi
    
    echo "# WakaTerm NG Integration" >> "$fish_config"
    echo "$source_line" >> "$fish_config"
    
    success "Fish integration added to config.fish"
    log "Please restart your terminal or run: source ~/.config/fish/config.fish"
}

# Uninstall function
uninstall() {
    log "Uninstalling WakaTerm NG..."
    
    # Remove installation directory
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        success "Removed $INSTALL_DIR"
    fi
    
    # Remove shell integrations
    local shell_name=$(detect_shell)
    case "$shell_name" in
        "bash")
            remove_from_file "$HOME/.bashrc" "WakaTerm NG Integration"
            remove_from_file "$HOME/.bash_profile" "WakaTerm NG Integration"
            ;;
        "zsh")
            remove_from_file "$HOME/.zshrc" "WakaTerm NG Integration"
            ;;
        "fish")
            remove_from_file "$HOME/.config/fish/config.fish" "WakaTerm NG Integration"
            ;;
    esac
    
    success "WakaTerm NG uninstalled"
    log "Please restart your terminal to complete removal"
}

# Remove integration from config file
remove_from_file() {
    local file="$1"
    local marker="$2"
    
    if [[ -f "$file" ]] && grep -q "$marker" "$file"; then
        # Create a temporary file without the wakaterm lines
        grep -v "$marker\|wakaterm" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
        success "Removed integration from $(basename -- "$file")"
    fi
}

# Test installation
test_installation() {
    log "Testing installation..."
    
    if [[ -f "$INSTALL_DIR/wakaterm.py" ]]; then
        python3 "$INSTALL_DIR/wakaterm.py" --help >/dev/null 2>&1
        success "WakaTerm NG is working correctly"
    else
        error "Installation test failed"
        exit 1
    fi
}

# Upgrade the installation
upgrade_installation() {
    log "Upgrading WakaTerm NG..."
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"
        git pull origin main || {
            error "Failed to upgrade WakaTerm NG."
            exit 1
        }
        success "WakaTerm NG upgraded to the latest version."
    else
        error "WakaTerm NG is not installed. Cannot upgrade."
        exit 1
    fi
}

# Print usage
usage() {
    cat << EOF
WakaTerm NG Installation Script

Usage: $0 [OPTION]

Options:
    install     Install WakaTerm NG (default)
    uninstall   Remove WakaTerm NG
    upgrade     Upgrade to the latest version
    test        Test current installation
    help        Show this help message

Examples:
    $0              # Install with auto-detected shell
    $0 install      # Explicit install
    $0 uninstall    # Remove installation
    $0 upgrade      # Upgrade to latest version
    $0 test         # Test installation

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