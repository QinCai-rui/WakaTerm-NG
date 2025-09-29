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
        printf "${RED}[ERROR]${NC} This installer requires bash. Please run it with bash.\n"
        exit 1
    fi
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/.local/share/wakaterm"
WAKATIME_CONFIG="$HOME/.wakatime.cfg"
STATE_FILE="$HOME/.local/share/wakaterm/.install_state.json"

# Functions
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

# Global auto-yes control. Honor -y/--yes or WAKATERM_AUTO_INSTALL=1 env var.
FORCE_YES=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            FORCE_YES=1
            ;;
    esac
done

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

# State tracking functions
# This is purely created by GitHub Copilot
init_state_file() {
    mkdir -p "$(dirname "$STATE_FILE")"
    cat > "$STATE_FILE" << EOF
{
  "install_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "installer_version": "1.2.0",
  "directories_created": [],
  "files_created": [],
  "files_modified": [],
  "shell_integrations": [],
  "symlinks_created": [],
  "backups_created": [],
  "wakatime_cli_downloads": []
}
EOF
}

# Add entry to state file
track_state() {
    local category="$1"
    local item="$2"
    local backup_path="${3:-}"
    
    if [[ ! -f "$STATE_FILE" ]]; then
        return 0  # Silently skip if state file doesn't exist
    fi
    
    # Use python to safely update JSON (more reliable than sed/awk)
    python3 -c "
import json, sys
try:
    with open('$STATE_FILE', 'r') as f:
        data = json.load(f)
    
    if '$category' not in data:
        data['$category'] = []
    
    entry = '$item'
    if '$backup_path':
        entry = {'path': '$item', 'backup': '$backup_path'}
    
    if entry not in data['$category']:
        data['$category'].append(entry)
    
    with open('$STATE_FILE', 'w') as f:
        json.dump(data, f, indent=2)
except Exception:
    pass  # Silently fail to avoid breaking installation
"
}

# Create backup of file before modification
create_backup() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.wakaterm.backup.$(date +%s)"
        cp "$file" "$backup"
        track_state "backups_created" "$backup"
        echo "$backup"
    fi
}

# Safe file modification with backup
modify_file_with_backup() {
    local file="$1"
    local content="$2"
    local marker="$3"
    
    # Create backup first
    local backup_path=""
    if [[ -f "$file" ]]; then
        backup_path=$(create_backup "$file")
    fi
    
    # Add content to file
    echo "$content" >> "$file"
    
    # Track the modification
    track_state "files_modified" "$file" "$backup_path"
}

# Track directory creation
track_mkdir() {
    local dir="$1"
    mkdir -p "$dir"
    track_state "directories_created" "$dir"
}

# Track file creation
track_file_creation() {
    local file="$1"
    track_state "files_created" "$file"
}

# Track symlink creation
track_symlink() {
    local target="$1"
    local link="$2"
    ln -sf "$target" "$link"
    track_state "symlinks_created" "$link"
}

# Track wakatime-cli download
track_wakatime_cli_download() {
    local method="$1"        # "homebrew", "github_release", or "manual"
    local version="$2"       # version if available
    local download_url="${3:-}"  # URL if downloaded
    local file_path="$4"     # final CLI file path
    
    if [[ ! -f "$STATE_FILE" ]]; then
        return 0  # Silently skip if state file doesn't exist
    fi
    
    # Use python to safely update JSON
    python3 -c "
import json, sys
from datetime import datetime
try:
    with open('$STATE_FILE', 'r') as f:
        data = json.load(f)
    
    if 'wakatime_cli_downloads' not in data:
        data['wakatime_cli_downloads'] = []
    
    entry = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'method': '$method',
        'file_path': '$file_path'
    }
    
    if '$version':
        entry['version'] = '$version'
    if '$download_url':
        entry['download_url'] = '$download_url'
    
    data['wakatime_cli_downloads'].append(entry)
    
    with open('$STATE_FILE', 'w') as f:
        json.dump(data, f, indent=2)
except Exception:
    pass  # Silently fail to avoid breaking installation
"
}

# Read state file
read_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "{}"
    fi
}
# END TRACKING FUNCTIONS

# Install wakatime-cli automatically
install_wakatime_cli() {
    local os=$(detect_os)
    local wakatime_dir="$HOME/.wakatime"
    local wakatime_cli="$wakatime_dir/wakatime-cli"
    
    log "Installing wakatime-cli..."
    
    # Create wakatime directory if it doesn't exist
    track_mkdir "$wakatime_dir"
    
    # Detect architecture and normalise to release asset naming (amd64, arm64, 386)
    local arch_raw
    # Allow user to override detection when needed (e.g. unusual CI or manual testing)
    if [[ -n "${WAKATERM_ARCH:-}" ]]; then
        arch_raw="${WAKATERM_ARCH}"
    else
        arch_raw=$(uname -m)
    fi
    local arch
    case "$arch_raw" in
        x86_64|amd64)
            arch=amd64
            ;;
        aarch64|arm64)
            arch=arm64
            ;;
        i386|i686)
            arch=386
            ;;
        armv7l|armv7)
            # There may not be an exact armv7 build; try arm64 or armv6 fallback
            arch=armv6
            ;;
        *)
            arch="$arch_raw"
            ;;
    esac

    case "$os" in
        "macos")
            # Check if Homebrew is available
            if command_exists brew; then
                log "Installing wakatime-cli via Homebrew..."
                if brew install wakatime-cli; then
                    # Create symlink if brew install succeeded
                    local brew_wakatime
                    brew_wakatime=$(brew --prefix)/bin/wakatime-cli
                    if [[ -f "$brew_wakatime" ]]; then
                        ln -sf "$brew_wakatime" "$wakatime_cli"
                        
                        # Get version for tracking
                        local version
                        version=$("$wakatime_cli" --version 2>/dev/null | head -n1 || echo "unknown")
                        
                        # Track the installation
                        track_wakatime_cli_download "homebrew" "$version" "" "$wakatime_cli"
                        track_file_creation "$wakatime_cli"
                        
                        success "wakatime-cli installed via Homebrew"
                        return 0
                    fi
                fi
            fi
            # Try to pick the best asset from GitHub releases using API
            local os_label="darwin"
            local download_url=""
            if command_exists curl; then
                download_url=$(curl -s "https://api.github.com/repos/wakatime/wakatime-cli/releases/latest" \
                    | grep -Eo '"browser_download_url":\s*"[^"]+"' \
                    | sed -E 's/"browser_download_url":\s*"([^"]+)"/\1/' \
                    | grep -i "${os_label}" \
                    | grep -i "${arch}" \
                    | head -n 1 || true)
            fi
            if [[ -z "$download_url" ]]; then
                # Fallback to predictable path
                local asset_name="wakatime-cli-darwin-${arch}"
                download_url="https://github.com/wakatime/wakatime-cli/releases/latest/download/${asset_name}"
            fi
            log "Downloading wakatime-cli for macOS (${arch_raw} -> ${arch}) from ${download_url}..."
            if command_exists curl; then
                curl -sSL "$download_url" -o "$wakatime_cli.tmp"
            elif command_exists wget; then
                wget -q "$download_url" -O "$wakatime_cli.tmp"
            else
                error "Neither curl nor wget found. Cannot download wakatime-cli."
                return 1
            fi
            # If archive, extract and pick binary
            if file --brief --mime-type "$wakatime_cli.tmp" | grep -q "application/x-gzip\|application/gzip"; then
                mkdir -p "$wakatime_dir/tmp_extract"
                tar -xzf "$wakatime_cli.tmp" -C "$wakatime_dir/tmp_extract" || true
                # find executable named wakatime-cli
                find "$wakatime_dir/tmp_extract" -type f -name "wakatime-cli*" -perm /u+x -print -exec mv {} "$wakatime_cli" \; -quit || true
                rm -rf "$wakatime_dir/tmp_extract"
                rm -f "$wakatime_cli.tmp"
            elif file --brief --mime-type "$wakatime_cli.tmp" | grep -q "application/zip"; then
                mkdir -p "$wakatime_dir/tmp_extract"
                if command_exists unzip; then
                    unzip -q "$wakatime_cli.tmp" -d "$wakatime_dir/tmp_extract"
                    find "$wakatime_dir/tmp_extract" -type f -name "wakatime-cli*" -perm /u+x -print -exec mv {} "$wakatime_cli" \; -quit || true
                fi
                rm -rf "$wakatime_dir/tmp_extract"
                rm -f "$wakatime_cli.tmp"
            else
                # assume raw binary
                mv "$wakatime_cli.tmp" "$wakatime_cli"
            fi
            ;;
        "linux")
            # Try to pick the best asset from GitHub releases using API
            local os_label="linux"
            local download_url=""
            if command_exists curl; then
                download_url=$(curl -s "https://api.github.com/repos/wakatime/wakatime-cli/releases/latest" \
                    | grep -Eo '"browser_download_url":\s*"[^"]+"' \
                    | sed -E 's/"browser_download_url":\s*"([^"]+)"/\1/' \
                    | grep -i "${os_label}" \
                    | grep -i "${arch}" \
                    | head -n 1 || true)
            fi
            if [[ -z "$download_url" ]]; then
                local asset_name="wakatime-cli-linux-${arch}"
                download_url="https://github.com/wakatime/wakatime-cli/releases/latest/download/${asset_name}"
            fi
            log "Downloading wakatime-cli for Linux (${arch_raw} -> ${arch}) from ${download_url}..."
            if command_exists curl; then
                curl -sSL "$download_url" -o "$wakatime_cli.tmp"
            elif command_exists wget; then
                wget -q "$download_url" -O "$wakatime_cli.tmp"
            else
                error "Neither curl nor wget found. Cannot download wakatime-cli."
                return 1
            fi
            # If archive, extract and pick binary
            if file --brief --mime-type "$wakatime_cli.tmp" | grep -q "application/x-gzip\|application/gzip"; then
                mkdir -p "$wakatime_dir/tmp_extract"
                tar -xzf "$wakatime_cli.tmp" -C "$wakatime_dir/tmp_extract" || true
                find "$wakatime_dir/tmp_extract" -type f -name "wakatime-cli*" -perm /u+x -print -exec mv {} "$wakatime_cli" \; -quit || true
                rm -rf "$wakatime_dir/tmp_extract"
                rm -f "$wakatime_cli.tmp"
            elif file --brief --mime-type "$wakatime_cli.tmp" | grep -q "application/zip"; then
                mkdir -p "$wakatime_dir/tmp_extract"
                if command_exists unzip; then
                    unzip -q "$wakatime_cli.tmp" -d "$wakatime_dir/tmp_extract"
                    find "$wakatime_dir/tmp_extract" -type f -name "wakatime-cli*" -perm /u+x -print -exec mv {} "$wakatime_cli" \; -quit || true
                fi
                rm -rf "$wakatime_dir/tmp_extract"
                rm -f "$wakatime_cli.tmp"
            else
                # assume raw binary
                mv "$wakatime_cli.tmp" "$wakatime_cli"
            fi
            ;;
        *)
            error "Unsupported operating system: $(uname -s)"
            error "Please manually install wakatime-cli from: https://github.com/wakatime/wakatime-cli/releases"
            return 1
            ;;
    esac
    
    # Make executable
    if [[ -f "$wakatime_cli" ]]; then
        chmod +x "$wakatime_cli"
        
        # Test if it works
        if "$wakatime_cli" --version >/dev/null 2>&1; then
            # Get version for tracking
            local version
            version=$("$wakatime_cli" --version 2>/dev/null | head -n1 || echo "unknown")
            
            # Track the successful installation
            track_wakatime_cli_download "github_release" "$version" "${download_url:-}" "$wakatime_cli"
            track_file_creation "$wakatime_cli"
            
            success "wakatime-cli installed and working"
            return 0
        else
            error "wakatime-cli downloaded but not working properly"
            error "File exists at: $wakatime_cli"
            error "File info: $(ls -la "$wakatime_cli" 2>/dev/null || echo 'Could not stat file')"
            error "Try running: $wakatime_cli --version"
            return 1
        fi
    else
        error "Failed to download wakatime-cli"
        error "Expected file at: $wakatime_cli"
        error "Contents of wakatime directory:"
        if [[ -d "$wakatime_dir" ]]; then
            ls -la "$wakatime_dir" || error "Could not list directory contents"
        else
            error "Wakatime directory does not exist: $wakatime_dir"
        fi
        return 1
    fi
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

        # Ask with default yes; in non-interactive runs this returns yes
        ask_confirm_default_yes "Would you like to install wakatime-cli automatically? (Y/n):"
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            warn "Skipping wakatime-cli installation"
            warn "Please install wakatime-cli manually: https://wakatime.com/terminal"
            warn "Or download from: https://github.com/wakatime/wakatime-cli/releases"
            ask_confirm_default_yes "Continue anyway? (y/N):"
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            if install_wakatime_cli; then
                success "wakatime-cli installed successfully"
            else
                error "Failed to install wakatime-cli automatically"
                warn "Please install wakatime-cli manually: https://wakatime.com/terminal"
                ask_confirm_default_yes "Continue anyway? (y/N):"
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
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
        
        printf "Would you like to create a basic config file? (y/N): "
        read -n 1 -r REPLY </dev/tty
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
            printf "Would you like to add your API key now? (y/N): "
            read -n 1 -r REPLY </dev/tty
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
    
    printf "Enter your Wakatime API key: "
    read -s api_key </dev/tty
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
    printf "Enter your Wakatime API key: "
    read -s api_key </dev/tty
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
    
    # Migrate existing logs to new location if needed
    local old_logs_dir="$HOME/.local/share/wakaterm/logs"
    local new_logs_dir="$HOME/.local/share/wakaterm-logs"
    if [[ -d "$old_logs_dir" && ! -d "$new_logs_dir" ]]; then
        log "Migrating existing logs to new location..."
        mkdir -p "$new_logs_dir"
        mv "$old_logs_dir"/* "$new_logs_dir/" 2>/dev/null || true
        success "Migrated logs from $old_logs_dir to $new_logs_dir"
    fi
    
    # Ensure logs directory exists for fresh installations
    if [[ ! -d "$new_logs_dir" ]]; then
        log "Creating logs directory..."
        if mkdir -p "$new_logs_dir" 2>/dev/null; then
            success "Created logs directory at $new_logs_dir"
        else
            warn "Could not create logs directory at $new_logs_dir"
            warn "WakaTerm will attempt to create it at runtime or use a fallback location"
        fi
    fi
    
    # Check for existing installation
    if [[ -d "$INSTALL_DIR" ]]; then
        if [[ -f "$STATE_FILE" ]]; then
            warn "WakaTerm NG is already installed with state tracking."
            ask_confirm_default_yes "Do you want to reinstall (this will preserve your logs)? (Y/n)"
            if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
                log "Installation cancelled. Use '$0 upgrade' to update an existing installation."
                exit 0
            fi
            log "Performing clean reinstallation..."
            # Run uninstall first, then continue with installation
            uninstall
        else
            warn "Found existing installation directory without state tracking."
            ask_confirm_default_yes "Do you want to remove it and install fresh? (Y/n)"
            if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
                log "Installation cancelled."
                exit 0
            fi
            # Remove existing directory
            rm -rf "$INSTALL_DIR"
        fi
    fi
    
    # Clone files first (don't create directory beforehand!)
    git clone https://github.com/QinCai-rui/WakaTerm-NG.git "$INSTALL_DIR" || {
        error "Failed to clone WakaTerm NG repository. If you have already installed it, consider running '$0 upgrade' instead."
        exit 1
    }
    
    # NOW initialise state tracking after successful clone
    init_state_file
    
    # Track the install directory creation
    track_state "directories_created" "$INSTALL_DIR"
    
    # Track all files in the cloned directory
    find "$INSTALL_DIR" -type f | while read -r file; do
        track_file_creation "$file"
    done
    
    # Install wakatermctl command
    log "Installing wakatermctl command..."
    local bin_dir="$HOME/.local/bin"
    track_mkdir "$bin_dir"
    
    # Create symlink for wakatermctl
    if [[ -f "$INSTALL_DIR/wakatermctl" ]]; then
        chmod +x "$INSTALL_DIR/wakatermctl"
        track_symlink "$INSTALL_DIR/wakatermctl" "$bin_dir/wakatermctl"
        success "wakatermctl command installed to $bin_dir"
        
        # Check if ~/.local/bin is in PATH
        if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
            warn "~/.local/bin is not in your PATH. You may need to add it:"
            warn "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
            warn "  source ~/.bashrc"
        fi
    else
        warn "wakatermctl script not found in repository"
    fi
    
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
    
    # Add integration with tracking
    if ! echo "" >> "$config_file" 2>/dev/null; then
        error "Failed to write to $config_file"
        warn "Please manually add the following line to your shell configuration:"
        warn "  $source_line"
        return 1
    fi
    
    local integration_content="
# WakaTerm NG Integration
$source_line"
    
    modify_file_with_backup "$config_file" "$integration_content" "WakaTerm NG Integration"
    track_state "shell_integrations" "$config_file"
    
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
    
    # Add integration with tracking
    if ! echo "" >> "$config_file" 2>/dev/null; then
        error "Failed to write to $config_file"
        warn "Please manually add the following line to your zsh configuration:"
        warn "  $source_line"
        return 1
    fi
    
    local integration_content="
# WakaTerm NG Integration
$source_line"
    
    modify_file_with_backup "$config_file" "$integration_content" "WakaTerm NG Integration"
    track_state "shell_integrations" "$config_file"
    
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
    
    # Add integration with tracking
    if ! echo "" >> "$fish_config" 2>/dev/null; then
        error "Failed to write to $fish_config"
        warn "Please manually add the following line to your fish configuration:"
        warn "  $source_line"
        return 1
    fi
    
    local integration_content="
# WakaTerm NG Integration
$source_line"
    
    modify_file_with_backup "$fish_config" "$integration_content" "WakaTerm NG Integration"
    track_state "shell_integrations" "$fish_config"
    
    success "Fish integration added to config.fish"
    log "Please restart your terminal or run: source ~/.config/fish/config.fish"
}

# Smart uninstall function using state tracking
uninstall() {
    log "Uninstalling WakaTerm NG..."
    
    if [[ ! -f "$STATE_FILE" ]]; then
        warn "No installation state file found. Attempting legacy uninstall..."
        legacy_uninstall
        return
    fi
    
    log "Reading installation state..."
    local state_content=$(cat "$STATE_FILE")
    
    # Show installation info
    local install_date=$(echo "$state_content" | python3 -c "import sys,json; print(json.load(sys.stdin).get('install_date', 'Unknown'))")
    log "Found installation from: $install_date"
    
    # Restore backed up files
    log "Restoring backed up files..."
    echo "$state_content" | python3 -c "
import sys, json, os
try:
    data = json.load(sys.stdin)
    backups = data.get('backups_created', [])
    files_modified = data.get('files_modified', [])
    
    restored = 0
    for backup_path in backups:
        if os.path.exists(backup_path):
            # Find the original file path
            original_file = backup_path.split('.wakaterm.backup.')[0]
            if os.path.exists(original_file):
                os.rename(backup_path, original_file)
                print(f'   Restored: {os.path.basename(original_file)}')
                restored += 1
    
    if restored > 0:
        print(f'   Restored {restored} backed up files')
    else:
        print('   No backed up files to restore')
except Exception as e:
    print(f'   Error restoring backups: {e}')
"
    
    # Remove shell integrations based on state
    log "Removing shell integrations..."
    echo "$state_content" | python3 -c "
import sys, json, os
try:
    data = json.load(sys.stdin)
    integrations = data.get('shell_integrations', [])
    
    removed = 0
    for config_file in integrations:
        if os.path.exists(config_file):
            # Remove WakaTerm NG integration lines
            with open(config_file, 'r') as f:
                lines = f.readlines()
            
            # Filter out WakaTerm NG lines
            filtered_lines = []
            skip_next = False
            for line in lines:
                if 'WakaTerm NG Integration' in line:
                    skip_next = True
                    continue
                if skip_next and ('wakaterm' in line.lower() or 'source' in line):
                    skip_next = False
                    continue
                skip_next = False
                filtered_lines.append(line)
            
            # Write back the cleaned file
            with open(config_file, 'w') as f:
                f.writelines(filtered_lines)
            
            print(f'   Cleaned: {os.path.basename(config_file)}')
            removed += 1
    
    if removed > 0:
        print(f'   Removed integrations from {removed} shell config files')
    else:
        print('   No shell integrations found to remove')
except Exception as e:
    print(f'   Error removing integrations: {e}')
"
    
    # Remove symlinks
    log "Removing symlinks..."
    echo "$state_content" | python3 -c "
import sys, json, os
try:
    data = json.load(sys.stdin)
    symlinks = data.get('symlinks_created', [])
    
    removed = 0
    for symlink_path in symlinks:
        if os.path.islink(symlink_path):
            os.remove(symlink_path)
            print(f'   Removed: {symlink_path}')
            removed += 1
    
    if removed > 0:
        print(f'   Removed {removed} symlinks')
    else:
        print('   No symlinks found to remove')
except Exception as e:
    print(f'   Error removing symlinks: {e}')
"
    
    # Remove created files (but keep user data like logs)
    log "Removing installation files..."
    echo "$state_content" | python3 -c "
import sys, json, os, shutil
try:
    data = json.load(sys.stdin)
    files_created = data.get('files_created', [])
    directories_created = data.get('directories_created', [])
    
    # Remove files (excluding log files to preserve user data)
    removed_files = 0
    for file_path in files_created:
        if os.path.exists(file_path) and '.log' not in file_path.lower() and 'wakaterm-' not in os.path.basename(file_path):
            os.remove(file_path)
            removed_files += 1
    
    # Remove empty directories (in reverse order)
    removed_dirs = 0
    for dir_path in reversed(directories_created):
        try:
            if os.path.exists(dir_path) and 'logs' not in dir_path:
                if not os.listdir(dir_path):  # Only remove if empty
                    os.rmdir(dir_path)
                    removed_dirs += 1
        except OSError:
            pass  # Directory not empty or other issue
    
    print(f'   Removed {removed_files} files and {removed_dirs} empty directories')
    print(f'   Log files preserved in ~/.local/share/wakaterm-logs/')
except Exception as e:
    print(f'   Error removing files: {e}')
"
    
    # Remove main installation directory (but preserve logs)
    if [[ -d "$INSTALL_DIR" ]]; then
        # Move logs to a safe location if they exist
        local logs_dir="$HOME/.local/share/wakaterm/logs"
        local new_logs_dir="$HOME/.local/share/wakaterm-logs"
        local temp_logs_dir="/tmp/wakaterm_logs_backup_$$"
        
        if [[ -d "$logs_dir" ]]; then
            mv "$logs_dir" "$temp_logs_dir" 2>/dev/null || true
        fi
        
        # Remove the installation directory
        rm -rf "$INSTALL_DIR"
        success "Removed installation directory: $INSTALL_DIR"
        
        # Restore logs to new location if they existed
        if [[ -d "$temp_logs_dir" ]]; then
            mkdir -p "$new_logs_dir"
            mv "$temp_logs_dir"/* "$new_logs_dir/" 2>/dev/null || true
            rmdir "$temp_logs_dir" 2>/dev/null || true
            success "Preserved activity logs at: $new_logs_dir"
        fi
    fi
    
    # Remove state file last
    if [[ -f "$STATE_FILE" ]]; then
        rm -f "$STATE_FILE"
        success "Removed installation state file"
    fi
    
    success "WakaTerm NG uninstalled successfully!"
    log "Your activity logs have been preserved."
    log "Please restart your terminal to complete removal"
}

# Legacy uninstall for installations without state tracking
legacy_uninstall() {
    warn "Performing legacy uninstall (no state tracking available)"
    
    # Preserve logs before removing installation directory
    local logs_dir="$HOME/.local/share/wakaterm/logs"
    local new_logs_dir="$HOME/.local/share/wakaterm-logs"
    local temp_logs_dir="/tmp/wakaterm_logs_backup_$$"
    
    if [[ -d "$logs_dir" ]]; then
        mv "$logs_dir" "$temp_logs_dir" 2>/dev/null || true
    fi
    
    # Remove installation directory
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        success "Removed $INSTALL_DIR"
    fi
    
    # Restore logs to new location if they existed
    if [[ -d "$temp_logs_dir" ]]; then
        mkdir -p "$new_logs_dir"
        mv "$temp_logs_dir"/* "$new_logs_dir/" 2>/dev/null || true
        rmdir "$temp_logs_dir" 2>/dev/null || true
        success "Preserved activity logs at: $new_logs_dir"
    fi
    
    # Remove common symlinks
    local bin_dir="$HOME/.local/bin"
    if [[ -L "$bin_dir/wakatermctl" ]]; then
        rm -f "$bin_dir/wakatermctl"
        success "Removed wakatermctl symlink"
    fi
    
    # Remove shell integrations using old method
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
    
    success "Legacy uninstall completed"
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

# Show installation status
show_status() {
    echo "=== WakaTerm NG Installation Status ==="
    
    if [[ ! -f "$STATE_FILE" ]]; then
        if [[ -d "$INSTALL_DIR" ]]; then
            warn "Legacy installation detected (no state tracking)"
            log "Installation directory: $INSTALL_DIR"
            log "Use 'upgrade' to enable state tracking"
        else
            error "WakaTerm NG is not installed"
        fi
        return 1
    fi
    
    log "Reading installation state..."
    local state_content=$(cat "$STATE_FILE")
    
    echo "$state_content" | python3 -c "
import sys, json, os
try:
    data = json.load(sys.stdin)
    
    print(f'📅 Installation Date: {data.get(\"install_date\", \"Unknown\")}')
    print(f'🔖 Installer Version: {data.get(\"installer_version\", \"Unknown\")}')
    print()
    
    # Directories
    dirs = data.get('directories_created', [])
    print(f'📁 Directories Created: {len(dirs)}')
    for d in dirs[:5]:  # Show first 5
        status = '✅' if os.path.exists(d) else '❌'
        print(f'   {status} {d}')
    if len(dirs) > 5:
        print(f'   ... and {len(dirs) - 5} more')
    print()
    
    # Files
    files = data.get('files_created', [])
    print(f'📄 Files Created: {len(files)}')
    existing = sum(1 for f in files if os.path.exists(f))
    print(f'   {existing}/{len(files)} files still exist')
    print()
    
    # Shell integrations
    integrations = data.get('shell_integrations', [])
    print(f'🐚 Shell Integrations: {len(integrations)}')
    for config in integrations:
        status = '✅' if os.path.exists(config) else '❌'
        name = os.path.basename(config)
        # Check if integration is actually present
        if os.path.exists(config):
            with open(config, 'r') as f:
                content = f.read()
                if 'WakaTerm NG' in content:
                    status = '✅ Active'
                else:
                    status = '⚠️  Missing'
        print(f'   {status} {name}')
    print()
    
    # Symlinks
    symlinks = data.get('symlinks_created', [])
    print(f'🔗 Symlinks Created: {len(symlinks)}')
    for link in symlinks:
        if os.path.islink(link):
            target = os.readlink(link)
            status = '✅'
        else:
            status = '❌'
            target = 'Missing'
        name = os.path.basename(link)
        print(f'   {status} {name} -> {target}')
    print()
    
    # Backups
    backups = data.get('backups_created', [])
    print(f'💾 Backups Created: {len(backups)}')
    existing_backups = sum(1 for b in backups if os.path.exists(b))
    print(f'   {existing_backups}/{len(backups)} backup files preserved')
    print()
    
    # Quick health check
    missing_files = sum(1 for f in files if not os.path.exists(f))
    missing_links = sum(1 for l in symlinks if not os.path.islink(l))
    
    if missing_files == 0 and missing_links == 0:
        print('✅ Installation appears healthy')
    else:
        print(f'⚠️  Issues detected: {missing_files} missing files, {missing_links} missing symlinks')
        print('   Consider running: $0 upgrade')
    
except Exception as e:
    print(f'Error reading state: {e}')
"
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