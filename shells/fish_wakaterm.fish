# WakaTerm NG - Fish Shell Integration
# This file should be sourced in ~/.config/fish/config.fish

# Get the directory where wakaterm is installed
set -l wakaterm_dir (dirname (status --current-filename))/..
set -l wakaterm_python "$wakaterm_dir/wakaterm.py"

# Check if wakaterm.py exists
if not test -f "$wakaterm_python"
    echo "Warning: wakaterm.py not found at $wakaterm_python" >&2
    exit 1
end

# Function to send command to wakatime
function wakaterm_track
    set -l command "$argv[1]"
    set -l cwd (pwd)
    set -l timestamp (date +%s.%3N)
    
    # Skip empty commands and wakaterm itself
    if test -z "$command"; or string match -q "wakaterm*" "$command"
        return 0
    end
    
    # Run in background to avoid blocking the shell
    python3 "$wakaterm_python" --cwd "$cwd" --timestamp "$timestamp" $command &
end

# Hook into fish command execution
function wakaterm_postexec --on-event fish_postexec
    # Get the command from the event
    set -l command "$argv[1]"
    
    # Track the command
    wakaterm_track "$command"
end