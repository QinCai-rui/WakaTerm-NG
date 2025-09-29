#!/bin/bash
# WakaTerm NG Wakatime CLI Module
# Contains functions for installing and configuring wakatime-cli

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
                if ! tar -xzf "$wakatime_cli.tmp" -C "$wakatime_dir/tmp_extract"; then
                    error "Failed to extract wakatime-cli tarball. Aborting installation."
                    rm -rf "$wakatime_dir/tmp_extract"
                    rm -f "$wakatime_cli.tmp"
                    return 1
                fi
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
                if ! tar -xzf "$wakatime_cli.tmp" -C "$wakatime_dir/tmp_extract"; then
                    error "Failed to extract wakatime-cli tarball. Aborting installation."
                    rm -rf "$wakatime_dir/tmp_extract"
                    rm -f "$wakatime_cli.tmp"
                    return 1
                fi
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