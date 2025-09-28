#!/bin/zsh
# WakaTerm NG - Zsh Shell Integration
# This file should be sourced in ~/.zshrc

# Get the directory where wakaterm is installed
WAKATERM_DIR="${0:A:h:h}"
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

# Hook into zsh command execution using preexec
if [[ -n "$ZSH_VERSION" ]]; then
    # Store the original preexec functions if they exist
    if [[ -n "$preexec_functions" ]]; then
        WAKATERM_ORIGINAL_PREEXEC=("${preexec_functions[@]}")
    else
        WAKATERM_ORIGINAL_PREEXEC=()
    fi
    
    # Function to handle command tracking
    wakaterm_preexec() {
        local command="$1"
        
        # Track the command
        wakaterm_track "$command"
    }
    
    # Add our function to preexec_functions
    autoload -U add-zsh-hook
    add-zsh-hook preexec wakaterm_preexec
    
    # Restore original preexec functions
    for func in "${WAKATERM_ORIGINAL_PREEXEC[@]}"; do
        if [[ "$func" != "wakaterm_preexec" ]]; then
            add-zsh-hook preexec "$func"
        fi
    done
fi