# WakaTerm NG - Fish Shell Integration
# This file should be sourced in ~/.config/fish/config.fish

# Get the directory where wakaterm is installed
set -g wakaterm_dir "$HOME/.local/share/wakaterm"
set -g wakaterm_python "$wakaterm_dir/wakaterm.py"

# Check if wakaterm.py exists (could be a Python file or a symlink to binary)
if not test -e "$wakaterm_python"
    echo "Warning: wakaterm.py not found at $wakaterm_python" >&2
    exit 1
end

# Detect if this is a compiled binary or Python script
set -g wakaterm_is_binary 0
if test -x "$wakaterm_python"; and not grep -q "^#!.*python" "$wakaterm_python" 2>/dev/null
    set -g wakaterm_is_binary 1
end

# Function to send command to wakatime (using Python script)
function wakaterm_track
    set -l command "$argv[1]"
    set -l duration "$argv[2]"
    set -l cwd (pwd)
    set -l timestamp (date +%s)
    
    # Skip empty commands and wakaterm itself
    if test -z "$command"; or string match -q "wakaterm*" "$command"
        return 0
    end
    
    # Optional debug mode - set WAKATERM_DEBUG=1 to see what's being tracked
    if test "$WAKATERM_DEBUG" = "1"
        echo "WAKATERM: Tracking command: $command (duration: $duration s)" >&2
        # In debug mode, run in foreground to capture errors
        if test "$wakaterm_is_binary" = "1"
            eval "$wakaterm_python" --cwd "$cwd" --timestamp "$timestamp" --duration "$duration" --debug -- $command
        else
            python3 "$wakaterm_python" --cwd "$cwd" --timestamp "$timestamp" --duration "$duration" --debug -- $command
        end
    else
        # Run in background to avoid blocking the shell
        # Use -- to separate options from the command arguments
        if test "$wakaterm_is_binary" = "1"
            eval "$wakaterm_python" --cwd "$cwd" --timestamp "$timestamp" --duration "$duration" -- $command >/dev/null 2>&1 &
            disown
        else
            python3 "$wakaterm_python" --cwd "$cwd" --timestamp "$timestamp" --duration "$duration" -- $command >/dev/null 2>&1 &
            disown
        end
    end
end

# Hook into fish command execution
# Check if wakaterm is already loaded to prevent double-loading
if not set -q WAKATERM_FISH_LOADED
    set -gx WAKATERM_FISH_LOADED 1
    
    # Variables to track timing
    set -g WAKATERM_COMMAND_START_TIME ""
    set -g WAKATERM_CURRENT_COMMAND ""
    
    # Use fish_preexec and fish_postexec events properly
    function wakaterm_preexec --on-event fish_preexec
        # Store the command and start time - don't filter here, let wakaterm_track handle it
        set -g WAKATERM_CURRENT_COMMAND "$argv[1]"
        set -g WAKATERM_COMMAND_START_TIME (date +%s)
        
        if test "$WAKATERM_DEBUG" = "1"
            echo "WAKATERM DEBUG: Preexec captured: $argv[1]" >&2
        end
    end
    
    function wakaterm_postexec --on-event fish_postexec
        # Calculate duration and track command
        if set -q WAKATERM_CURRENT_COMMAND; and set -q WAKATERM_COMMAND_START_TIME
            set -l end_time (date +%s)
            # Use bc for floating point arithmetic, fallback to 2.0 if bc is not available
            set -l duration (math "$end_time - $WAKATERM_COMMAND_START_TIME" 2>/dev/null; or echo "2.0")
            
            # Ensure duration is at least 0.1 seconds and reasonable (max 1 hour)
            if test (math "$duration < 0.1" 2>/dev/null; or echo "0") -eq 1
                set duration "0.1"
            else if test (math "$duration > 3600" 2>/dev/null; or echo "0") -eq 1
                set duration "3600"
            end
            
            wakaterm_track "$WAKATERM_CURRENT_COMMAND" "$duration"
            
            # Clear timing variables
            set -e WAKATERM_CURRENT_COMMAND
            set -e WAKATERM_COMMAND_START_TIME
        end
    end
    
    # Set environment variable to indicate WakaTerm is loaded
    set -gx WAKATERM_FISH_LOADED 1
else
    echo "Warning: wakaterm fish integration already loaded, skipping..." >&2
end