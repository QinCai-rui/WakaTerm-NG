#!/bin/bash
# WakaTerm NG Source Installation Module
# Handles Python source installation and git-based source installs

# Install Python source files directly
install_python_source() {
    log "Installing WakaTerm NG Python source files..."
    
    # Check if Python is available
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 is required for Python source installation"
        exit 1
    fi
    
    # Check if git is available for source download
    if ! command -v git >/dev/null 2>&1; then
        warn "Git not found. Attempting to download individual source files..."
        download_source_files_direct
        return
    fi
    
    # Create temporary directory for cloning
    local temp_dir
    temp_dir=$(mktemp -d) || {
        error "Failed to create temporary directory"
        exit 1
    }
    
    (
        cd "$temp_dir"
        log "Downloading WakaTerm NG source code..."
        
        if git clone "https://github.com/QinCai-rui/WakaTerm-NG.git" wakaterm 2>/dev/null; then
            cd wakaterm
            
            # Create source installation directory
            local source_dir="$HOME/.local/share/wakaterm-source"
            mkdir -p "$source_dir" || {
                error "Failed to create source directory: $source_dir"
                exit 1
            }
            
            # Copy Python source files
            log "Installing source files..."
            cp wakaterm.py "$source_dir/" 2>/dev/null || {
                error "Failed to copy wakaterm.py"
                exit 1
            }
            cp wakaterm_minimal.py "$source_dir/" 2>/dev/null || true  # Optional file
            cp ignore_filter.py "$source_dir/" 2>/dev/null || {
                error "Failed to copy ignore_filter.py"
                exit 1
            }
            cp wakatermctl "$source_dir/" 2>/dev/null || {
                error "Failed to copy wakatermctl"
                exit 1
            }
            
            # Make sure install directory exists
            mkdir -p "$INSTALL_DIR" || {
                error "Failed to create install directory: $INSTALL_DIR"
                exit 1
            }
            
            # Create wrapper scripts
            create_python_wrappers "$source_dir"
            
            success "Python source files installed successfully"
        else
            error "Failed to clone repository"
            exit 1
        fi
    )
    
    # Clean up temp directory
    rm -rf "$temp_dir" 2>/dev/null || true
}

# Create wrapper scripts for Python source installation
create_python_wrappers() {
    local source_dir="$1"
    
    # Create wakaterm wrapper
    local wakaterm_wrapper="$INSTALL_DIR/wakaterm"
    cat > "$wakaterm_wrapper" << EOF
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.expanduser('$source_dir'))
try:
    import wakaterm
    wakaterm.main()
except ImportError as e:
    print(f"Error: Could not import wakaterm module: {e}", file=sys.stderr)
    print(f"Make sure Python source files are installed in: $source_dir", file=sys.stderr)
    sys.exit(1)
EOF
    chmod +x "$wakaterm_wrapper" || {
        error "Failed to make wakaterm wrapper executable"
        exit 1
    }
    
    # Create wakatermctl wrapper
    local wakatermctl_wrapper="$INSTALL_DIR/wakatermctl"
    cat > "$wakatermctl_wrapper" << EOF
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.expanduser('$source_dir'))
try:
    with open(os.path.expanduser('$source_dir/wakatermctl'), 'r') as f:
        exec(f.read())
except FileNotFoundError:
    print(f"Error: wakatermctl script not found in: $source_dir", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Error executing wakatermctl: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    chmod +x "$wakatermctl_wrapper" || {
        error "Failed to make wakatermctl wrapper executable"
        exit 1
    }
    
    # Track installation for state management
    track_state "install_type" "python_source"
    track_state "source_directory" "$source_dir"
    track_state "files_created" "$wakaterm_wrapper,$wakatermctl_wrapper"
}

# Install wakaterm from source (clone and use Python files or build)
install_wakaterm_from_source() {
    log "Installing WakaTerm NG from source..."
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        error "Git is required for source installation"
        exit 1
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
            uninstall
        else
            warn "Found existing installation directory without state tracking."
            ask_confirm_default_yes "Do you want to remove it and install fresh? (Y/n)"
            if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
                log "Installation cancelled."
                exit 0
            fi
            rm -rf "$INSTALL_DIR"
        fi
    fi
    
    # Migrate existing logs to new location if needed
    local old_logs_dir="$HOME/.local/share/wakaterm/logs"
    local new_logs_dir="$HOME/.local/share/wakaterm-logs"
    if [[ -d "$old_logs_dir" && ! -d "$new_logs_dir" ]]; then
        log "Migrating existing logs to new location..."
        mkdir -p "$new_logs_dir"
        mv "$old_logs_dir"/* "$new_logs_dir/" 2>/dev/null || true
        success "Migrated logs from $old_logs_dir to $new_logs_dir"
    fi
    
    # Ensure logs directory exists
    if [[ ! -d "$new_logs_dir" ]]; then
        log "Creating logs directory..."
        if mkdir -p "$new_logs_dir" 2>/dev/null; then
            success "Created logs directory at $new_logs_dir"
        else
            warn "Could not create logs directory at $new_logs_dir"
        fi
    fi
    
    # Ensure config directory exists
    local config_dir="$HOME/.config/wakaterm"
    if [[ ! -d "$config_dir" ]]; then
        log "Creating config directory..."
        if mkdir -p "$config_dir" 2>/dev/null; then
            success "Created config directory at $config_dir"
            track_state "directories_created" "$config_dir"
        else
            warn "Could not create config directory at $config_dir"
        fi
    fi
    
    # Clone the repository
    git clone https://github.com/QinCai-rui/WakaTerm-NG.git "$INSTALL_DIR" || {
        error "Failed to clone WakaTerm NG repository"
        exit 1
    }
    
    # Initialize state tracking after successful clone
    init_state_file
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
            warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    else
        error "wakatermctl not found in cloned repository"
    fi
    
    # Track installation type
    track_state "install_type" "source"
    
    success "Source installation complete!"
}