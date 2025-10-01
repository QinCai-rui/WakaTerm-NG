#!/bin/bash
# WakaTerm NG Binary Installation Module
# Handles pre-compiled binary downloads and installation

# Detect platform for binary downloads
detect_binary_platform() {
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$os" in
        linux*)
            echo "linux"
            ;;
        darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Detect architecture for binary downloads
detect_binary_arch() {
    local machine
    machine=$(uname -m | tr '[:upper:]' '[:lower:]')
    
    case "$machine" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        i386|i686)
            echo "x86"
            ;;
        *)
            echo "$machine"
            ;;
    esac
}

# Install pre-compiled binary from GitHub releases
install_prebuilt_binary() {
    log "Installing WakaTerm NG pre-compiled binary..."
    
    # Detect platform and architecture
    local platform
    local arch
    platform=$(detect_binary_platform)
    arch=$(detect_binary_arch)
    
    if [[ "$platform" == "unknown" ]]; then
        error "Unsupported platform for binary installation"
        warn "Try Python source installation instead: $0 install --python"
        exit 1
    fi
    
    log "Detected platform: $platform-$arch"
    
    # Initialize state tracking
    init_state_file
    
    # Create temporary directory for downloads
    local temp_dir
    temp_dir=$(mktemp -d) || {
        error "Failed to create temporary directory"
        exit 1
    }
    
    # Try to download the zip package first (preferred method)
    local zip_filename="wakaterm-$platform-$arch.tar.gz"
    local download_url="https://github.com/QinCai-rui/WakaTerm-NG/releases/latest/download/${zip_filename}"
    local zip_file="$temp_dir/${zip_filename}"
    
    log "Downloading binary package from: $download_url"
    
    local downloaded=false
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL -o "$zip_file" "$download_url" 2>/dev/null; then
            downloaded=true
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q -O "$zip_file" "$download_url" 2>/dev/null; then
            downloaded=true
        fi
    else
        error "Neither curl nor wget found - cannot download binaries"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    if [[ "$downloaded" != "true" ]]; then
        warn "Failed to download pre-built binary package"
        warn "This might mean no release exists for $platform-$arch yet"
        warn "Falling back to building from source..."
        rm -rf "$temp_dir"
        install_wakaterm_from_source
        return
    fi
    
    success "Binary package downloaded successfully"
    
    # Extract the package
    log "Extracting binary package..."
    cd "$temp_dir"
    if tar -xzf "$zip_file" 2>/dev/null; then
        success "Package extracted successfully"
    else
        error "Failed to extract package"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Install binaries
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir" || {
        error "Failed to create bin directory: $bin_dir"
        rm -rf "$temp_dir"
        exit 1
    }
    
    # Look for the binary files
    local installed_count=0
    if [[ -f "wakaterm-$platform-$arch" ]]; then
        log "Installing wakaterm binary..."
        cp "wakaterm-$platform-$arch" "$bin_dir/wakaterm"
        chmod +x "$bin_dir/wakaterm"
        track_file_creation "$bin_dir/wakaterm"
        success "wakaterm installed to $bin_dir/wakaterm"
        ((installed_count++))
    fi
    
    if [[ -f "wakatermctl-$platform-$arch" ]]; then
        log "Installing wakatermctl binary..."
        cp "wakatermctl-$platform-$arch" "$bin_dir/wakatermctl"
        chmod +x "$bin_dir/wakatermctl"
        track_file_creation "$bin_dir/wakatermctl"
        success "wakatermctl installed to $bin_dir/wakatermctl"
        ((installed_count++))
    fi
    
    # Check for compiled modules directory
    if [[ -d "wakaterm-dist" ]]; then
        local shared_dir="$HOME/.local/share/wakaterm-ng"
        mkdir -p "$shared_dir"
        log "Installing compiled modules..."
        cp -r "wakaterm-dist" "$shared_dir/"
        track_state "directories_created" "$shared_dir/wakaterm-dist"
        success "Compiled modules installed to $shared_dir/wakaterm-dist"

        # Create a small shim so the wrapper in ~/.local/bin can import compiled modules
        # The wrapper expects a 'wakaterm-dist' directory next to the binary, so
        # create a symlink in the bin directory pointing to the shared compiled modules.
        mkdir -p "$bin_dir"
        if [[ -L "$bin_dir/wakaterm-dist" || -e "$bin_dir/wakaterm-dist" ]]; then
            log "Existing $bin_dir/wakaterm-dist found; skipping symlink creation"
        else
            ln -s "$shared_dir/wakaterm-dist" "$bin_dir/wakaterm-dist" 2>/dev/null || {
                warn "Could not create symlink at $bin_dir/wakaterm-dist. You may need to create it manually."
            }
        fi
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    if [[ $installed_count -eq 0 ]]; then
        error "No binaries were installed"
        exit 1
    fi
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        warn "~/.local/bin is not in your PATH. You may need to add it:"
        warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    
    # Install shell integration files
    install_shell_files
    
    # Track installation type
    track_state "install_type" "prebuilt_binary"
    track_state "platform" "$platform-$arch"
    
    success "Pre-built binary installation complete!"
}

# Download and install shell integration files
install_shell_files() {
    log "Installing shell integration files..."
    
    # Ensure required variables are defined
    local install_dir="${INSTALL_DIR:-$HOME/.local/share/wakaterm}"
    local raw_base="${RAW_BASE:-https://raw.githubusercontent.com/QinCai-rui/WakaTerm-NG/refs/heads/main}"
    
    # Create shells directory
    local shells_dir="$install_dir/shells"
    mkdir -p "$shells_dir" || {
        error "Failed to create shells directory: $shells_dir"
        return 1
    }
    track_state "directories_created" "$shells_dir"
    
    # Define shell files to download
    local shell_files=("bash_wakaterm.sh" "zsh_wakaterm.zsh" "fish_wakaterm.fish")
    local base_url="$raw_base/shells"
    
    # Download each shell file
    for shell_file in "${shell_files[@]}"; do
        local url="$base_url/$shell_file"
        local target="$shells_dir/$shell_file"
        
        log "Downloading $shell_file..."
        
        local downloaded=false
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL -o "$target" "$url" 2>/dev/null; then
                downloaded=true
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q -O "$target" "$url" 2>/dev/null; then
                downloaded=true
            fi
        fi
        
        if [[ "$downloaded" == "true" ]]; then
            chmod +x "$target"
            track_file_creation "$target"
            log "Installed $shell_file to $target"
        else
            error "Failed to download $shell_file from $url"
            return 1
        fi
    done
    
    success "Shell integration files installed successfully"
}