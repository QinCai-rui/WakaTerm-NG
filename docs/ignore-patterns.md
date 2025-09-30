# WakaTerm NG - Command Ignore Patterns

WakaTerm NG supports ignoring specific commands using `.gitignore`-style patterns. This allows you to exclude certain commands from being tracked and sent to WakaTime, giving you fine-grained control over what terminal activity is logged.

## Quick Start

### Managing Ignore Patterns

Use the `wakatermctl ignore` command to manage your ignore patterns:

```bash
# Add patterns to ignore
wakatermctl ignore add "ls"          # Ignore exact command
wakatermctl ignore add "git status"  # Ignore command with arguments
wakatermctl ignore add "debug_*"     # Ignore commands matching pattern

# List current patterns
wakatermctl ignore list

# Test if a command would be ignored
wakatermctl ignore test "git status"

# Remove a pattern
wakatermctl ignore remove "ls"

# Edit patterns file directly
wakatermctl ignore edit

# Clear all patterns
wakatermctl ignore clear
```

## Ignore File Location

Ignore patterns are stored in:

```file
~/.config/wakaterm/wakaterm_ignore
```

This file is automatically created when you first add a pattern, or you can create it manually.

## Pattern Syntax

WakaTerm uses `.gitignore`-style syntax with the following features:

### Basic Patterns

- **Exact match**: `ls` - matches exactly "ls"
- **With arguments**: `git status` - matches "git status" exactly
- **Command only**: `git` - matches any command starting with "git"

### Wildcards

- **Asterisk (`*`)**: Matches any characters (except spaces)
  - `git*` - matches `git`, `gitk`, `github`
  - `debug_*` - matches `debug_test`, `debug_production`
  
- **Question mark (`?`)**: Matches any single character
  - `t?st` - matches `test`, `tost`, `tast`
  
- **Character classes (`[abc]`)**: Matches any character in brackets
  - `[abc]ls` - matches `als`, `bls`, `cls`
  - `[0-9]*` - matches commands starting with a number

### Negation Patterns

Use `!` at the start of a pattern to explicitly include commands that would otherwise be ignored:

```file
# Ignore all git commands
git*

# But always track git push and git commit
!git push*
!git commit*
```

### Comments and Empty Lines

- Lines starting with `#` are comments
- Empty lines are ignored
- Whitespace at the beginning and end of lines is ignored

## Example Patterns

### Common System Commands

```bash
# Basic navigation and listing
cd
pwd
ls
ll
la
clear
exit
logout

# File operations you might not want to track
cp
mv
rm
mkdir
rmdir
```

### Development Workflow

```bash
# Ignore frequent status checks
git status
git diff
git log*

# But track important git operations
!git push*
!git pull*
!git commit*
!git merge*

# Package manager updates (usually automated)
npm update
pip install*
apt update
brew update

# Temporary/debug commands
tmp*
debug_*
test_*
```

### Sensitive Commands

> [!NOTE]
> WakaTerm-NG does not send the whole command to WakaTime, only the command name (`basename`). However, you may still want to ignore certain commands for whatever reasons.

```bash
# Security-sensitive commands
ssh*
scp*
rsync*
sudo*

# Database connections (if they contain credentials)
mysql*
psql*
```

### Productivity Commands

```bash
# Frequent low-value commands
history
which*
whereis*
man *
help*

# Simple text operations
cat*
less*
more*
head*
tail*
```

## Pattern Matching Logic

1. **All patterns are case-insensitive**
2. **Patterns match from the beginning of the command**
3. **Wildcards don't cross word boundaries easily** - `*` stops at spaces
4. **Negation patterns (`!`) override ignore patterns**
5. **The file is re-read automatically when modified**

### Examples of Pattern Matching

| Pattern       | Command               | Matches? | Reason                        |
|---------------|-----------------------|----------|-------------------------------|
| `ls`          | `ls`                  | ✅       | Exact match                   |
| `ls`          | `ls -la`              | ✅       | Command starts with pattern   |
| `git*`        | `git status`          | ✅       | Wildcard matches              |
| `git*`        | `github clone`        | ✅       | Wildcard matches              |
| `git status`  | `git status`          | ✅       | Exact match                   |
| `git status`  | `git status --short`  | ✅       | Command starts with pattern   |
| `debug_*`     | `debug_test`          | ✅       | Wildcard matches              |
| `debug_*`     | `run_debug_test`      | ❌       | Pattern must match from start |

## Advanced Usage

### Testing Patterns

Before adding patterns, test them to make sure they work as expected:

```bash
# Test individual commands
wakatermctl ignore test "git status"
wakatermctl ignore test "debug_production"

# Test with different variations
wakatermctl ignore test "ls"
wakatermctl ignore test "ls -la"
wakatermctl ignore test "lsd"  # Different command
```

### Editing the File Directly

You can edit the ignore file directly:

```bash
# Open in your default editor
wakatermctl ignore edit

# Or edit manually
nano ~/.config/wakaterm/wakaterm_ignore
vim ~/.config/wakaterm/wakaterm_ignore
```

### Backup and Sharing

Since ignore patterns are stored in a simple text file, you can:

```bash
# Backup your patterns
cp ~/.config/wakaterm/wakaterm_ignore ~/wakaterm_ignore.backup

# Share patterns between machines
scp ~/.config/wakaterm/wakaterm_ignore user@other-machine:~/.config/wakaterm/

# Version control your patterns
cd ~/.config/wakaterm
git init
git add wakaterm_ignore
git commit -m "Add wakaterm ignore patterns"
```

### Dynamic Patterns

The ignore file is re-read automatically whenever it's modified, so you can:

1. **Add patterns on-the-fly** without restarting your shell
2. **Temporarily modify patterns** and they take effect immediately  
3. **Use external tools** to modify the patterns file

## Troubleshooting

### Debug Mode

Enable debug mode to see what patterns are being applied:

```bash
export WAKATERM_DEBUG=1
# Run commands and check the output
```

### Pattern Not Working

1. **Test the pattern**: `wakatermctl ignore test "your command"`
2. **Check pattern syntax**: Make sure wildcards are correctly placed
3. **Check for negation**: A `!` pattern might be overriding your ignore
4. **Case sensitivity**: Patterns are case-insensitive, but double-check

### File Permissions

If you can't edit the ignore file:

```bash
# Check permissions
ls -la ~/.config/wakaterm/wakaterm_ignore

# Fix permissions if needed
chmod 644 ~/.config/wakaterm/wakaterm_ignore

# Create directory if missing
mkdir -p ~/.config/wakaterm
```

### Starting Fresh

To start with a clean ignore configuration:

```bash
# Remove all patterns
wakatermctl ignore clear --yes

# Or delete the file manually
rm ~/.config/wakaterm/wakaterm_ignore
```

## Default Patterns

When you first install WakaTerm NG, a default ignore file is created with common patterns for system commands. You can customise this file to suit your workflow.

The default patterns include:

- Basic navigation commands (`cd`, `pwd`, `ls`)  
- Shell built-ins (`clear`, `exit`, `history`)
- Common file operations you might not want to track

You can view the current patterns with:

```bash
wakatermctl ignore list
```

## Integration with WakaTime

Commands that match ignore patterns are:

1. **Not sent to WakaTime** - They won't appear in your WakaTime dashboard
2. **Not logged locally** - They won't appear in `wakatermctl` statistics
3. **Completely filtered out** - As if they were never run

This filtering happens before any network requests, so ignored commands don't consume WakaTime API quota or generate any logs.