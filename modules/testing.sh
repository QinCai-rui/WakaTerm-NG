#!/bin/bash
# WakaTerm NG Testing and Status Module
# Handles installation testing, status reporting, and upgrades

# Test installation
test_installation() {
    log "Testing installation..."
    
    local bin_dir="$HOME/.local/bin"
    local wakaterm_bin="$bin_dir/wakaterm"
    local wakatermctl_bin="$bin_dir/wakatermctl"

    local wakaterm_ok=false
    local wakatermctl_ok=false

    if [[ -x "$wakaterm_bin" ]]; then
        log "Running: $wakaterm_bin --help"
        if "$wakaterm_bin" --help >/dev/null 2>&1; then
            wakaterm_ok=true
            success "wakaterm binary responded to --help"
        else
            warn "wakaterm binary failed --help check"
        fi
    else
        warn "wakaterm binary not found at $wakaterm_bin"
    fi

    if [[ -x "$wakatermctl_bin" ]]; then
        log "Running: $wakatermctl_bin stats --no-color"
        if "$wakatermctl_bin" stats --no-color >/dev/null 2>&1; then
            wakatermctl_ok=true
            success "wakatermctl ran 'stats' successfully"
        else
            warn "wakatermctl failed to run 'stats'"
        fi
    else
        warn "wakatermctl binary not found at $wakatermctl_bin"
    fi

    if [[ "$wakaterm_ok" == "true" || "$wakatermctl_ok" == "true" ]]; then
        success "WakaTerm NG installation tests passed (at least one binary functional)"
    else
        error "Installation test failed: no functional binaries found"
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
        print('   Consider running: \$0 upgrade')
    
except Exception as e:
    print(f'Error reading state: {e}')
"
}