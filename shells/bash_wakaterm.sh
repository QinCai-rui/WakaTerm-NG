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

# Function to send command to wakatime
wakaterm_track() {
    local command="$1"
    local cwd="$PWD"
    local timestamp=$(date +%s.%3N)
    
    # Skip empty commands and wakaterm itself
    if [[ -z "$command" || "$command" =~ ^wakaterm ]]; then
        return 0
    fi
    
    # Run in background to avoid blocking the shell
    (python3 "$WAKATERM_PYTHON" --cwd "$cwd" --timestamp "$timestamp" "$command" &) 2>/dev/null
}

# Hook into bash command execution
if [[ -n "$BASH_VERSION" ]]; then
    # Store the original PROMPT_COMMAND
    WAKATERM_ORIGINAL_PROMPT_COMMAND="$PROMPT_COMMAND"
    
    # Function to handle command tracking
    wakaterm_prompt_command() {
        local exit_code=$?
        
        # Get the last command from history
        local last_command=$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
        
        # Track the command
        if [[ -n "$last_command" && "$last_command" != "$WAKATERM_LAST_COMMAND" ]]; then
            wakaterm_track "$last_command"
            WAKATERM_LAST_COMMAND="$last_command"
        fi
        
        # Execute original PROMPT_COMMAND if it exists
        if [[ -n "$WAKATERM_ORIGINAL_PROMPT_COMMAND" ]]; then
            eval "$WAKATERM_ORIGINAL_PROMPT_COMMAND"
        fi
        
        return $exit_code
    }
    
    # Set our prompt command
    PROMPT_COMMAND="wakaterm_prompt_command"
    
    # init
    WAKATERM_LAST_COMMAND=""
fi