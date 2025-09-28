#!/bin/bash
# WakaTerm NG - Bash Shell Integration
# This file should be sourced in ~/.bashrc or ~/.bash_profile

# Get the directory where wakaterm is installed
WAKATERM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAKATERM_PYTHON="${WAKATERM_DIR}/wakaterm.py"

# Check if wakaterm.py exists
if [[ ! -f "$WAKATERM_PYTHON" ]]; then
    echo "Warning: wakaterm.py not found at $WAKATERM_PYTHON" >&2
    return 1
fi

# Function to send command to wakatime (using Python script)
wakaterm_track() {
    local command="$1"
    local cwd="$PWD"
    local timestamp=$(date +%s.%3N)
    
    # Skip empty commands, wakaterm itself, and source commands to avoid infinite loops
    if [[ -z "$command" || "$command" =~ ^wakaterm || "$command" =~ ^source.*wakaterm ]]; then
        return 0
    fi
    
    # Run Python script in background with proper detachment to avoid blocking the shell
    {
        python3 "$WAKATERM_PYTHON" --cwd "$cwd" --timestamp "$timestamp" "$command" >/dev/null 2>&1 &
        disown
    } 2>/dev/null
}

# Hook into bash command execution
if [[ -n "$BASH_VERSION" ]]; then
    # Check if wakaterm is already loaded to prevent double-loading
    if [[ "$PROMPT_COMMAND" =~ wakaterm_prompt_command ]]; then
        echo "Warning: wakaterm bash integration already loaded, skipping..." >&2
        return 0
    fi
    
    # Store the original PROMPT_COMMAND (only if we haven't stored it before)
    if [[ -z "$WAKATERM_ORIGINAL_PROMPT_COMMAND" ]]; then
        WAKATERM_ORIGINAL_PROMPT_COMMAND="$PROMPT_COMMAND"
    fi
    
    # Function to handle command tracking
    wakaterm_prompt_command() {
        local exit_code=$?
        
        # Get the last command from history
        local last_command=$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
        
        # Skip tracking prompt command and history commands to avoid loops
        if [[ "$last_command" =~ wakaterm_prompt_command || "$last_command" =~ ^history ]]; then
            return $exit_code
        fi
        
        # Track the command
        if [[ -n "$last_command" && "$last_command" != "$WAKATERM_LAST_COMMAND" ]]; then
            wakaterm_track "$last_command"
            WAKATERM_LAST_COMMAND="$last_command"
        fi
        
        # Execute original PROMPT_COMMAND if it exists and it's not our own function
        if [[ -n "$WAKATERM_ORIGINAL_PROMPT_COMMAND" && "$WAKATERM_ORIGINAL_PROMPT_COMMAND" != "wakaterm_prompt_command" ]]; then
            eval "$WAKATERM_ORIGINAL_PROMPT_COMMAND"
        fi
        
        return $exit_code
    }
    
    # Set our prompt command
    PROMPT_COMMAND="wakaterm_prompt_command"
    
    # init
    WAKATERM_LAST_COMMAND=""
fi