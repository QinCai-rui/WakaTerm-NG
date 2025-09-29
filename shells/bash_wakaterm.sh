#!/bin/bash
# WakaTerm NG - Bash Shell Integration
# This file should be sourced in ~/.bashrc or ~/.bash_profile

# Get the directory where wakaterm is installed
WAKATERM_DIR="$HOME/.local/share/wakaterm"
WAKATERM_PYTHON="${WAKATERM_DIR}/wakaterm.py"

# Check if wakaterm.py exists
if [[ ! -f "$WAKATERM_PYTHON" ]]; then
    echo "Warning: wakaterm.py not found at $WAKATERM_PYTHON" >&2
    return 1
fi

# Function to send command to wakatime (using Python script)
wakaterm_track() {
    local command="$1"
    local duration="$2"
    local cwd="$PWD"
    local timestamp=$(date +%s.%3N)
    
    # Skip empty commands, wakaterm itself, and source commands to avoid infinite loops
    if [[ -z "$command" || "$command" =~ ^wakaterm || "$command" =~ ^source.*wakaterm ]]; then
        return 0
    fi
    
    # Run Python script in background with proper detachment to avoid blocking the shell
    {
        python3 "$WAKATERM_PYTHON" --cwd "$cwd" --timestamp "$timestamp" --duration "$duration" "$command" >/dev/null 2>&1 &
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
    
    # Variables to track command timing
    WAKATERM_COMMAND_START_TIME=""
    WAKATERM_CURRENT_COMMAND=""
    WAKATERM_LAST_COMMAND=""
    
    # DEBUG trap to capture command start time
    wakaterm_debug_trap() {
        # Only capture timing for actual commands (not during completion, etc.)
        if [[ "$BASH_COMMAND" != "wakaterm_prompt_command" && 
              "$BASH_COMMAND" != *"wakaterm"* && 
              "$BASH_COMMAND" != *"PROMPT_COMMAND"* &&
              "$BASH_COMMAND" != *"history"* ]]; then
            WAKATERM_COMMAND_START_TIME=$(date +%s.%3N)
            WAKATERM_CURRENT_COMMAND="$BASH_COMMAND"
        fi
    }
    
    # Function to handle command tracking
    wakaterm_prompt_command() {
        local exit_code=$?
        
        # Calculate duration if we have a start time
        if [[ -n "$WAKATERM_COMMAND_START_TIME" && -n "$WAKATERM_CURRENT_COMMAND" ]]; then
            local end_time=$(date +%s.%3N)
            local duration=$(echo "$end_time - $WAKATERM_COMMAND_START_TIME" | bc -l 2>/dev/null || echo "2.0")
            
            # Ensure duration is at least 0.1 seconds and reasonable (max 1 hour)
            if (( $(echo "$duration < 0.1" | bc -l 2>/dev/null || echo "0") )); then
                duration="0.1"
            elif (( $(echo "$duration > 3600" | bc -l 2>/dev/null || echo "0") )); then
                duration="3600"
            fi
            
            # Track the command with real duration
            wakaterm_track "$WAKATERM_CURRENT_COMMAND" "$duration"
            
            # Reset timing variables
            WAKATERM_COMMAND_START_TIME=""
            WAKATERM_CURRENT_COMMAND=""
        fi
        
        # Execute original PROMPT_COMMAND if it exists and it's not our own function
        if [[ -n "$WAKATERM_ORIGINAL_PROMPT_COMMAND" && "$WAKATERM_ORIGINAL_PROMPT_COMMAND" != "wakaterm_prompt_command" ]]; then
            eval "$WAKATERM_ORIGINAL_PROMPT_COMMAND"
        fi
        
        return $exit_code
    }
    
    # Set up the DEBUG trap and PROMPT_COMMAND
    trap 'wakaterm_debug_trap' DEBUG
    PROMPT_COMMAND="wakaterm_prompt_command"
fi