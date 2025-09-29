#!/bin/bash
# WakaTerm NG Installation Module
# Contains main installation, uninstallation, and upgrade functions

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