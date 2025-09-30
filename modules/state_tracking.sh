#!/bin/bash
# WakaTerm NG State Tracking Module
# Contains all functions for tracking installation state and managing backups

# State tracking functions
# This is purely created by GitHub Copilot
init_state_file() {
    mkdir -p "$(dirname "$STATE_FILE")"
    cat > "$STATE_FILE" << EOF
{
  "install_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "installer_version": "2.1.0",
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