#!/usr/bin/env python3
"""
WakaTerm NG - Command Ignore Pattern Parser
A module to handle .gitignore-style pattern matching for command filtering
"""

import os
import re
from pathlib import Path
from typing import List, Optional


class CommandIgnoreFilter:
    """
    A filter to check if commands should be ignored based on .gitignore-style patterns.
    
    Supports:
    - Simple wildcards (*, ?, [abc])
    - Negation patterns (starting with !)
    - Comment lines (starting with #)
    - Blank lines (ignored)
    - Exact command names
    - Pattern matching for command arguments
    """
    
    def __init__(self, ignore_file_path: Optional[str] = None):
        """
        Initialise the ignore filter.
        
        Args:
            ignore_file_path: Path to the ignore file. If None, uses default location.
        """
        if ignore_file_path is None:
            ignore_file_path = os.path.expanduser("~/.config/wakaterm/wakaterm_ignore")
        
        self.ignore_file_path = Path(ignore_file_path)
        self.patterns: List[str] = []
        self.negation_patterns: List[str] = []
        self._compiled_patterns: List[re.Pattern] = []
        self._compiled_negation_patterns: List[re.Pattern] = []
        self._last_mtime: Optional[float] = None
        
        self._load_patterns()
    
    def _load_patterns(self) -> None:
        """Load patterns from the ignore file."""
        try:
            if not self.ignore_file_path.exists():
                # Create default ignore file with common examples
                self._create_default_ignore_file()
                return
            
            # Check if file was modified since last load
            current_mtime = self.ignore_file_path.stat().st_mtime
            if self._last_mtime is not None and current_mtime == self._last_mtime:
                return  # No changes, skip reload
            
            self._last_mtime = current_mtime
            
            patterns = []
            negation_patterns = []
            
            with open(self.ignore_file_path, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    
                    # Skip empty lines and comments
                    if not line or line.startswith('#'):
                        continue
                    
                    # Handle negation patterns
                    if line.startswith('!'):
                        pattern = line[1:].strip()
                        if pattern:
                            negation_patterns.append(pattern)
                    else:
                        patterns.append(line)
            
            self.patterns = patterns
            self.negation_patterns = negation_patterns
            self._compile_patterns()
            
        except Exception as e:
            # If there's any error reading the file, use empty patterns
            # This ensures wakaterm doesn't break if the ignore file has issues
            self.patterns = []
            self.negation_patterns = []
            self._compiled_patterns = []
            self._compiled_negation_patterns = []
            
            # Only log in debug mode
            if os.environ.get('WAKATERM_DEBUG', '').lower() in ('1', 'true', 'yes', 'on'):
                print(f"WAKATERM DEBUG: Error loading ignore patterns: {e}", file=os.sys.stderr)
    
    def _create_default_ignore_file(self) -> None:
        """Create a default ignore file with common patterns."""
        try:
            # Ensure the config directory exists
            self.ignore_file_path.parent.mkdir(parents=True, exist_ok=True)
            
            default_content = """# WakaTerm Ignore Patterns
# This file uses .gitignore-style syntax to specify commands to ignore
# Lines starting with # are comments
# Use ! to negate patterns (include commands that would otherwise be ignored)

# System and shell built-ins
cd
pwd
ls
ll
la
clear
exit
logout
history

# Navigation and basic file operations (uncomment if you want to ignore these)
# tree
# exa
# lsd

# Temporary or testing commands
test*
tmp*

# Sensitive commands (uncomment to ignore)
# ssh*
# scp*
# rsync*

# Version control status checks (uncomment if you want to ignore frequent status checks)
# git status
# git diff
# git log*

# Package manager update checks
# apt update
# brew update
# pacman -Sy

# Example: Ignore all commands starting with "debug_"
debug_*

# Example: Ignore specific command with arguments
# docker ps -a

# Example negation: Always track python commands even if other python* patterns exist
# !python
# !python3
"""
            
            with open(self.ignore_file_path, 'w', encoding='utf-8') as f:
                f.write(default_content)
                
        except Exception as e:
            # If we can't create the default file, continue silently
            if os.environ.get('WAKATERM_DEBUG', '').lower() in ('1', 'true', 'yes', 'on'):
                print(f"WAKATERM DEBUG: Could not create default ignore file: {e}", file=os.sys.stderr)
    
    def _compile_patterns(self) -> None:
        """Compile patterns into regular expressions for efficient matching."""
        self._compiled_patterns = []
        self._compiled_negation_patterns = []
        
        for pattern in self.patterns:
            try:
                regex = self._pattern_to_regex(pattern)
                self._compiled_patterns.append(re.compile(regex, re.IGNORECASE))
            except re.error:
                # Skip invalid patterns
                if os.environ.get('WAKATERM_DEBUG', '').lower() in ('1', 'true', 'yes', 'on'):
                    print(f"WAKATERM DEBUG: Invalid ignore pattern: {pattern}", file=os.sys.stderr)
        
        for pattern in self.negation_patterns:
            try:
                regex = self._pattern_to_regex(pattern)
                self._compiled_negation_patterns.append(re.compile(regex, re.IGNORECASE))
            except re.error:
                if os.environ.get('WAKATERM_DEBUG', '').lower() in ('1', 'true', 'yes', 'on'):
                    print(f"WAKATERM DEBUG: Invalid negation pattern: {pattern}", file=os.sys.stderr)
    
    def _pattern_to_regex(self, pattern: str) -> str:
        """
        Convert a gitignore-style pattern to a regex.
        
        Args:
            pattern: The gitignore-style pattern
            
        Returns:
            A regex string that can be compiled
        """
        # Escape special regex characters except for our wildcards
        # We'll handle *, ?, and [] specially
        pattern = re.escape(pattern)
        
        # Convert gitignore wildcards to regex
        # * matches any characters except space (to match command names but not cross word boundaries easily)
        pattern = pattern.replace(r'\*', r'[^\s]*')
        
        # ? matches any single character except space
        pattern = pattern.replace(r'\?', r'[^\s]')
        
        # Handle character classes [abc]
        pattern = re.sub(r'\\?\[([^\]]+)\\?\]', r'[\1]', pattern)
        
        # Anchor the pattern to match from the beginning of the command
        # This ensures we match the command name or full command line properly
        pattern = f'^{pattern}(?:\\s|$)'
        
        return pattern
    
    def should_ignore(self, command: str) -> bool:
        """
        Check if a command should be ignored based on the loaded patterns.
        
        Args:
            command: The command string to check
            
        Returns:
            True if the command should be ignored, False otherwise
        """
        if not command.strip():
            return True
        
        # Reload patterns if file was modified
        self._load_patterns()
        
        command = command.strip()
        
        # First check if any ignore patterns match
        ignored = False
        for pattern in self._compiled_patterns:
            if pattern.match(command):
                ignored = True
                break
        
        # If ignored, check if any negation patterns override this
        if ignored:
            for pattern in self._compiled_negation_patterns:
                if pattern.match(command):
                    return False  # Negation pattern matches, don't ignore
        
        return ignored
    
    def add_pattern(self, pattern: str) -> None:
        """
        Add a new ignore pattern to the file.
        
        Args:
            pattern: The pattern to add
        """
        try:
            # Ensure the config directory exists
            self.ignore_file_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(self.ignore_file_path, 'a', encoding='utf-8') as f:
                f.write(f"\n{pattern}\n")
            
            # Reload patterns
            self._load_patterns()
            
        except Exception as e:
            if os.environ.get('WAKATERM_DEBUG', '').lower() in ('1', 'true', 'yes', 'on'):
                print(f"WAKATERM DEBUG: Could not add pattern '{pattern}': {e}", file=os.sys.stderr)
    
    def remove_pattern(self, pattern: str) -> bool:
        """
        Remove a pattern from the ignore file.
        
        Args:
            pattern: The pattern to remove
            
        Returns:
            True if the pattern was found and removed, False otherwise
        """
        try:
            if not self.ignore_file_path.exists():
                return False
            
            with open(self.ignore_file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            # Find and remove the pattern
            new_lines = []
            found = False
            for line in lines:
                stripped_line = line.strip()
                if stripped_line != pattern and stripped_line != f"!{pattern}":
                    new_lines.append(line)
                else:
                    found = True
            
            if found:
                with open(self.ignore_file_path, 'w', encoding='utf-8') as f:
                    f.writelines(new_lines)
                
                # Reload patterns
                self._load_patterns()
            
            return found
            
        except Exception as e:
            if os.environ.get('WAKATERM_DEBUG', '').lower() in ('1', 'true', 'yes', 'on'):
                print(f"WAKATERM DEBUG: Could not remove pattern '{pattern}': {e}", file=os.sys.stderr)
            return False
    
    def list_patterns(self) -> List[str]:
        """
        Get all current patterns (both ignore and negation patterns).
        
        Returns:
            List of all patterns with negation patterns prefixed with '!'
        """
        self._load_patterns()
        result = self.patterns.copy()
        result.extend(f"!{pattern}" for pattern in self.negation_patterns)
        return result
    
    def get_ignore_file_path(self) -> str:
        """Get the path to the ignore file."""
        return str(self.ignore_file_path)


# Convenience function for simple usage
def should_ignore_command(command: str, ignore_file_path: Optional[str] = None) -> bool:
    """
    Convenience function to check if a command should be ignored.
    
    Args:
        command: The command to check
        ignore_file_path: Path to ignore file (optional)
        
    Returns:
        True if command should be ignored
    """
    filter_instance = CommandIgnoreFilter(ignore_file_path)
    return filter_instance.should_ignore(command)


if __name__ == '__main__':
    # Simple CLI for testing
    import sys
    
    if len(sys.argv) != 2:
        print("Usage: python ignore_filter.py <command>")
        print("Tests if a command would be ignored by current ignore patterns")
        sys.exit(1)
    
    command = sys.argv[1]
    ignore_filter = CommandIgnoreFilter()
    
    if ignore_filter.should_ignore(command):
        print(f"IGNORE: '{command}'")
        sys.exit(1)
    else:
        print(f"TRACK: '{command}'")
        sys.exit(0)