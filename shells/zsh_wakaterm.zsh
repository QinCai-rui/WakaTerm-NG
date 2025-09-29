#!/bin/zsh
# WakaTerm NG - Zsh Shell Integration
# This file should be sourced in ~/.zshrc

# Get the directory where wakaterm is installed
WAKATERM_DIR="$HOME/.local/share/wakaterm"
WAKATERM_PYTHON="${WAKATERM_DIR}/wakaterm.py"

# Check if wakaterm.py exists
if [[ ! -f "$WAKATERM_PYTHON" ]]; then
    echo "Warning: wakaterm.py not found at $WAKATERM_PYTHON" >&2
    return 1
fi

# Function to send command to wakatime
wakaterm_track() {
    local command="$1"
    local duration="$2"
    local cwd="$PWD"
    # Use simple timestamp (seconds since epoch)
    local timestamp=$(date +%s)
    
    # Skip empty commands and wakaterm itself
    if [[ -z "$command" || "$command" =~ ^wakaterm ]]; then
        return 0
    fi
    
    # Optional debug mode - set WAKATERM_DEBUG=1 to see what's being tracked
    if [[ "$WAKATERM_DEBUG" == "1" ]]; then
        echo "WAKATERM: Tracking command: $command (duration: ${duration}s)" >&2
        # In debug mode, run in foreground to capture errors
        python3 "$WAKATERM_PYTHON" --cwd "$cwd" --timestamp "$timestamp" --duration "$duration" "$command"
    else
        # Run in background to avoid blocking the shell
        (python3 "$WAKATERM_PYTHON" --cwd "$cwd" --timestamp "$timestamp" --duration "$duration" "$command" >/dev/null 2>&1 &) 2>/dev/null
    fi
}

# Hook into zsh command execution using preexec and precmd
if [[ -n "$ZSH_VERSION" ]]; then
    # Check if wakaterm is already loaded to prevent double-loading
    if [[ " ${preexec_functions[*]} " =~ " wakaterm_preexec " ]]; then
        echo "Warning: wakaterm zsh integration already loaded, skipping..." >&2
        return 0
    fi
    
    # Variables to track timing
    WAKATERM_COMMAND_START_TIME=""
    WAKATERM_CURRENT_COMMAND=""
    
    # Store the original preexec functions if they exist (only if we haven't stored them before)
    if [[ -z "$WAKATERM_ORIGINAL_PREEXEC" ]]; then
        if [[ -n "$preexec_functions" ]]; then
            WAKATERM_ORIGINAL_PREEXEC=("${preexec_functions[@]}")
        else
            WAKATERM_ORIGINAL_PREEXEC=()
        fi
    fi
    
    # Store the original precmd functions if they exist
    if [[ -z "$WAKATERM_ORIGINAL_PRECMD" ]]; then
        if [[ -n "$precmd_functions" ]]; then
            WAKATERM_ORIGINAL_PRECMD=("${precmd_functions[@]}")
        else
            WAKATERM_ORIGINAL_PRECMD=()
        fi
    fi
    
    # Function to capture command start time
    wakaterm_preexec() {
        local command="$1"
        # Don't filter commands here - let wakaterm_track handle filtering
        WAKATERM_CURRENT_COMMAND="$command"
        WAKATERM_COMMAND_START_TIME=$(date +%s)
        
        if [[ "$WAKATERM_DEBUG" == "1" ]]; then
            echo "WAKATERM DEBUG: Preexec captured: $command" >&2
        fi
    }
    
    # Function to track command completion with duration
    wakaterm_precmd() {
        if [[ -n "$WAKATERM_CURRENT_COMMAND" && -n "$WAKATERM_COMMAND_START_TIME" ]]; then
            local end_time=$(date +%s)
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
            WAKATERM_CURRENT_COMMAND=""
            WAKATERM_COMMAND_START_TIME=""
        fi
    }
    
    # Add our functions to the appropriate hooks
    autoload -U add-zsh-hook
    add-zsh-hook preexec wakaterm_preexec
    add-zsh-hook precmd wakaterm_precmd
    
    # Restore original preexec functions (but avoid adding wakaterm_preexec again)
    for func in "${WAKATERM_ORIGINAL_PREEXEC[@]}"; do
        if [[ "$func" != "wakaterm_preexec" && ! " ${preexec_functions[*]} " =~ " $func " ]]; then
            add-zsh-hook preexec "$func"
        fi
    done
    
    # Restore original precmd functions (but avoid adding wakaterm_precmd again)
    for func in "${WAKATERM_ORIGINAL_PRECMD[@]}"; do
        if [[ "$func" != "wakaterm_precmd" && ! " ${precmd_functions[*]} " =~ " $func " ]]; then
            add-zsh-hook precmd "$func"
        fi
    done
    export WAKATERM_ZSH_LOADED=1
fi