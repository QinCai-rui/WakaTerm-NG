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

# Function to send command to wakatime (optimized for performance)
wakaterm_track() {
    local command="$1"
    local duration="$2"
    local cwd="$PWD"
    # Use simple timestamp (seconds since epoch)
    local timestamp=$(date +%s)
    
    # Skip empty commands, wakaterm itself, and source commands to avoid infinite loops
    if [[ -z "$command" || "$command" =~ ^wakaterm || "$command" =~ ^source.*wakaterm ]]; then
        return 0
    fi
    
    # Optional debug mode - set WAKATERM_DEBUG=1 to see what's being tracked
    if [[ "$WAKATERM_DEBUG" == "1" ]]; then
        echo "WAKATERM: Tracking command: $command (duration: ${duration}s)" >&2
        # In debug mode, run in foreground to capture errors and pass --debug flag
        python3 "$WAKATERM_PYTHON" --cwd "$cwd" --timestamp "$timestamp" --duration "$duration" --debug "$command"
    else
        # better (?) background execution with minimal overhead
        # Use nohup and disown for better decoupling, redirect all output to blackhole(TM)
        nohup python3 "$WAKATERM_PYTHON" --cwd "$cwd" --timestamp "$timestamp" --duration "$duration" "$command" >/dev/null 2>&1 &
        # Disown immediately to prevent job control messages
        disown >/dev/null 2>&1
    fi
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
    
# DEBUG trap to capture command start time (optimized)
wakaterm_debug_trap() {
    # Fast check: only track commands that are likely to be meaningful
    # Skip our internal functions and direct Python wakaterm calls to prevent infinite loops
    case "$BASH_COMMAND" in
        wakaterm_prompt_command|wakaterm_track*|wakaterm_debug_trap)
            return 0
            ;;
        *"python"*wakaterm.py*)
            return 0
            ;;
    esac
    
    # Only set timing for commands that look like actual commands (not empty, not just whitespace)
    if [[ -n "$BASH_COMMAND" && "$BASH_COMMAND" =~ [^[:space:]] ]]; then
        WAKATERM_COMMAND_START_TIME=$(date +%s)
        WAKATERM_CURRENT_COMMAND="$BASH_COMMAND"
        
        if [[ "$WAKATERM_DEBUG" == "1" ]]; then
            echo "WAKATERM DEBUG: Captured command: $BASH_COMMAND" >&2
        fi
    fi
}

# Function to handle command tracking (optimized)
wakaterm_prompt_command() {
    local exit_code=$?
    
    # Fast check: only process if we have timing data
    if [[ -n "$WAKATERM_COMMAND_START_TIME" && -n "$WAKATERM_CURRENT_COMMAND" ]]; then
        local end_time=$(date +%s)
        local duration=$((end_time - WAKATERM_COMMAND_START_TIME))
        
        # Ensure duration is reasonable (0.1 to 3600 seconds)
        if (( duration < 1 )); then
            duration="0.1"
        elif (( duration > 3600 )); then
            duration="3600"
        fi
        
        # Track the command asynchronously
        wakaterm_track "$WAKATERM_CURRENT_COMMAND" "$duration"
        
        # Reset timing variables immediately
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
    export WAKATERM_BASH_LOADED=1
fi