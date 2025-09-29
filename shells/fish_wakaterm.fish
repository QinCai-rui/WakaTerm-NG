# WakaTerm NG - Fish Shell Integration
# This file should be sourced in ~/.config/fish/config.fish

# Get the directory where wakaterm is installed
set -g wakaterm_dir "$HOME/.local/share/wakaterm"
set -g wakaterm_python "$wakaterm_dir/wakaterm.py"

# Check if wakaterm.py exists
if not test -f "$wakaterm_python"
    echo "Warning: wakaterm.py not found at $wakaterm_python" >&2
    exit 1
end

# Function to send command to wakatime (using Python script)
function wakaterm_track
    set -l command "$argv[1]"
    set -l cwd (pwd)
    set -l timestamp (date +%s.%3N)
    
    # Skip empty commands and wakaterm itself
    if test -z "$command"; or string match -q "wakaterm*" "$command"
        return 0
    end
    
    # Debug: uncomment the next line to see what commands are being tracked
    # echo "Tracking: $command" >&2
    
    # Run Python script in background to avoid blocking the shell
    # Use -- to separate options from the command arguments
    python3 "$wakaterm_python" --cwd "$cwd" --timestamp "$timestamp" -- $command &
    disown
end

# Hook into fish command execution
# Check if wakaterm is already loaded to prevent double-loading
if not set -q WAKATERM_FISH_LOADED
    set -g WAKATERM_FISH_LOADED 1
    
    # Use fish_preexec and fish_postexec events properly
    function wakaterm_preexec --on-event fish_preexec
        # Store the command that's about to be executed
        set -g WAKATERM_LAST_COMMAND "$argv[1]"
    end
    
    function wakaterm_postexec --on-event fish_postexec
        # Use the command we stored in preexec
        if set -q WAKATERM_LAST_COMMAND
            wakaterm_track "$WAKATERM_LAST_COMMAND"
            set -e WAKATERM_LAST_COMMAND
        end
    end
else
    echo "Warning: wakaterm fish integration already loaded, skipping..." >&2
end