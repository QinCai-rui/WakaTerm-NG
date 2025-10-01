#!/bin/bash
# WakaTerm NG Uninstallation Module
# Handles complete removal of WakaTerm NG installations

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