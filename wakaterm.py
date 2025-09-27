#!/usr/bin/env python3
"""
WakaTerm NG - Terminal Wakatime Plugin
A terminal plugin that tracks command usage using the official wakatime-cli
"""

import os
import sys
import time
import hashlib
import argparse
import subprocess
from pathlib import Path
from typing import Optional, List


class TerminalTracker:
    """Main terminal tracking class using official wakatime-cli"""
    
    def __init__(self, wakatime_cli_path: Optional[str] = None, config_file: Optional[str] = None):
        self.wakatime_cli = wakatime_cli_path or os.path.expanduser('~/.wakatime/wakatime-cli')
        self.config_file = config_file
        
        # Check if wakatime-cli exists
        if not os.path.isfile(self.wakatime_cli):
            print(f"Warning: wakatime-cli not found at {self.wakatime_cli}", file=sys.stderr)
            print("Please install wakatime-cli: https://wakatime.com/terminal", file=sys.stderr)
            return
        
        # Make sure it's executable
        if not os.access(self.wakatime_cli, os.X_OK):
            try:
                os.chmod(self.wakatime_cli, 0o755)
            except PermissionError:
                print(f"Warning: wakatime-cli at {self.wakatime_cli} is not executable", file=sys.stderr)
                return
    
    def get_project_name(self, cwd: str) -> str:
        """Determine project name from current directory"""
        path = Path(cwd)
        
        # Check for common project indicators
        project_files = ['.git', 'package.json', 'Cargo.toml', 'setup.py', 
                        'pyproject.toml', 'go.mod', 'composer.json', '.project']
        
        current = path
        while current != current.parent:
            for project_file in project_files:
                if (current / project_file).exists():
                    return current.name
            current = current.parent
        
        # Fallback to directory name
        return path.name if path.name else 'terminal'
    
    def get_language_from_command(self, command: str) -> str:
        """Determine language/category from command"""
        cmd_parts = command.strip().split()
        if not cmd_parts:
            return 'Shell'
        
        cmd = cmd_parts[0]
        
        # Language mappings
        language_map = {
            'python': 'Python',
            'python3': 'Python',
            'py': 'Python',
            'pip': 'Python',
            'pip3': 'Python',
            'node': 'JavaScript',
            'npm': 'JavaScript',
            'yarn': 'JavaScript',
            'npx': 'JavaScript',
            'go': 'Go',
            'cargo': 'Rust',
            'rustc': 'Rust',
            'gcc': 'C',
            'g++': 'C++',
            'clang': 'C',
            'clang++': 'C++',
            'java': 'Java',
            'javac': 'Java',
            'mvn': 'Java',
            'gradle': 'Java',
            'ruby': 'Ruby',
            'gem': 'Ruby',
            'php': 'PHP',
            'composer': 'PHP',
            'dotnet': 'C#',
            'docker': 'Docker',
            'kubectl': 'Kubernetes',
            'git': 'Git',
            'vim': 'Vim',
            'nvim': 'Vim',
            'emacs': 'Emacs',
            'code': 'VS Code',
            'make': 'Make',
            'cmake': 'CMake',
            'ssh': 'SSH',
            'rsync': 'File Transfer',
            'scp': 'File Transfer',
            'curl': 'HTTP',
            'wget': 'HTTP',
        }
        
        return language_map.get(cmd, 'Shell')
    
    def get_category_from_command(self, command: str) -> str:
        """Determine wakatime category from command"""
        cmd_parts = command.strip().split()
        if not cmd_parts:
            return 'debugging'
        
        cmd = cmd_parts[0]
        
        # Category mappings based on wakatime-cli supported categories
        category_map = {
            # Development tools
            'git': 'coding',
            'vim': 'coding',
            'nvim': 'coding',
            'emacs': 'coding',
            'code': 'coding',
            'nano': 'coding',
            
            # Build tools
            'make': 'building',
            'cmake': 'building',
            'cargo': 'building',
            'npm': 'building',
            'yarn': 'building',
            'gradle': 'building',
            'mvn': 'building',
            
            # Testing
            'pytest': 'running tests',
            'jest': 'running tests',
            'mocha': 'running tests',
            'phpunit': 'running tests',
            'rspec': 'running tests',
            
            # Debugging
            'gdb': 'debugging',
            'lldb': 'debugging',
            'pdb': 'debugging',
            'node': 'debugging',  # when used for debugging
            
            # Research/Learning
            'man': 'learning',
            'help': 'learning',
            'info': 'learning',
            
            # Communication
            'curl': 'communicating',
            'wget': 'communicating',
            'ssh': 'communicating',
            'scp': 'communicating',
            'rsync': 'communicating',
        }
        
        return category_map.get(cmd, 'debugging')  # Default to debugging for terminal usage
    
    def create_entity_name(self, command: str, cwd: str) -> str:
        """Create a pseudo-entity name for the command"""
        # Create a unique but consistent entity name
        cmd_hash = hashlib.md5(command.encode()).hexdigest()[:8]
        cwd_safe = cwd.replace('/', '_').replace(' ', '_')
        return f"terminal://{cwd_safe}#{cmd_hash}"
    
    def track_command(self, command: str, cwd: Optional[str] = None, timestamp: Optional[float] = None):
        """Main method to track a command using wakatime-cli"""
        if not command.strip():
            return
        
        cwd = cwd or os.getcwd()
        timestamp = timestamp or time.time()
        
        # Create arguments for wakatime-cli
        args = [self.wakatime_cli]
        
        # Add entity (the "file" we're tracking)
        entity = self.create_entity_name(command, cwd)
        args.extend(['--entity', entity])
        
        # Set entity type to app (since we're tracking terminal commands, not files)
        args.extend(['--entity-type', 'app'])
        
        # Set project name
        project = self.get_project_name(cwd)
        args.extend(['--project', project])
        
        # Set language
        language = self.get_language_from_command(command)
        args.extend(['--language', language])
        
        # Set category
        category = self.get_category_from_command(command)
        args.extend(['--category', category])
        
        # Set timestamp
        args.extend(['--time', str(timestamp)])
        
        # Set plugin identification
        args.extend(['--plugin', 'wakaterm-ng/1.0.0'])
        
        # Add config file if specified
        if self.config_file:
            args.extend(['--config', self.config_file])
        
        # Don't log to stdout to avoid cluttering terminal
        # wakatime-cli will handle all config, caching, and API communication
        
        try:
            # Run wakatime-cli in background
            subprocess.run(
                args,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10  # Don't block terminal for too long
            )
        except subprocess.TimeoutExpired:
            # If wakatime-cli takes too long, just continue
            pass
        except Exception as e:
            # If there's any error, log it but don't break terminal
            print(f"Warning: Failed to track command with wakatime-cli: {e}", file=sys.stderr)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='WakaTerm NG - Terminal Wakatime Plugin')
    parser.add_argument('command', nargs='*', help='Command to track')
    parser.add_argument('--cwd', help='Current working directory')
    parser.add_argument('--timestamp', type=float, help='Command timestamp')
    parser.add_argument('--config', help='Path to wakatime config file')
    parser.add_argument('--wakatime-cli', help='Path to wakatime-cli binary')
    
    args = parser.parse_args()
    
    if not args.command:
        print("Usage: wakaterm.py <command>", file=sys.stderr)
        sys.exit(1)
    
    command = ' '.join(args.command)
    tracker = TerminalTracker(args.wakatime_cli, args.config)
    tracker.track_command(command, args.cwd, args.timestamp)


if __name__ == '__main__':
    main()