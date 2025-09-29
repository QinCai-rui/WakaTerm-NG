# WakaTerm NG - Fish Shell Integration
# This file should be sourced in ~/.config/fish/config.fish

# Get the directory where wakaterm is installed
set -l wakaterm_dir "$HOME/.local/share/wakaterm"
set -l wakaterm_python "$wakaterm_dir/wakaterm.py"

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
    
    # Run Python script in background to avoid blocking the shell
    python3 "$wakaterm_python" --cwd "$cwd" --timestamp "$timestamp" $command &
    disown
end

# Hook into fish command execution
# Check if wakaterm is already loaded to prevent double-loading
if not set -q WAKATERM_FISH_LOADED
    set -g WAKATERM_FISH_LOADED 1
    
    function wakaterm_postexec --on-event fish_postexec
        # Get the command from the event
        set -l command "$argv[1]"
        
        # Track the command
        wakaterm_track "$command"
    end
else
    echo "Warning: wakaterm fish integration already loaded, skipping..." >&2
end