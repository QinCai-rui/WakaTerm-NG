#!/usr/bin/env python3
"""
WakaTerm NG - Terminal Activity Logger
A terminal plugin that logs command usage to local files for offline tracking
"""

import os
import sys
import time
import json
import hashlib
import argparse
from pathlib import Path
from typing import Optional, List, Dict
from datetime import datetime


class TerminalTracker:
    """Main terminal tracking class that logs to local files"""
    
    def __init__(self, log_dir: Optional[str] = None):
        self.log_dir = Path(log_dir or os.path.expanduser('~/.local/share/wakaterm/logs'))
        self.log_dir.mkdir(parents=True, exist_ok=True)
        
        # Log file path - one file per day
        today = datetime.now().strftime('%Y-%m-%d')
        self.log_file = self.log_dir / f"wakaterm-{today}.jsonl"
    
    def get_project_name(self, cwd: str) -> str:
        """Determine project name from current directory"""
        path = Path(cwd)
        # Look for common project indicators
        for parent in [path] + list(path.parents):
            if any((parent / indicator).exists() for indicator in 
                   ['.git', '.svn', '.hg', 'package.json', 'Cargo.toml', 'pyproject.toml', 'setup.py', 'pom.xml', 'Gemfile']):
                return parent.name
        return path.name if path.name else 'terminal'
    
    def get_language_from_command(self, command: str) -> str:
        """Determine language/category from command"""
        cmd_parts = command.strip().split()
        if not cmd_parts:
            return 'Shell'
        
        cmd = cmd_parts[0]
        
        # Expanded language mappings
        language_map = {
            # Python
            'python': 'Python', 'python3': 'Python', 'py': 'Python', 
            'pip': 'Python', 'pip3': 'Python', 'pipenv': 'Python', 'poetry': 'Python',
            'conda': 'Python', 'jupyter': 'Python', 'ipython': 'Python',
            
            # JavaScript/Node
            'node': 'JavaScript', 'npm': 'JavaScript', 'yarn': 'JavaScript', 
            'npx': 'JavaScript', 'pnpm': 'JavaScript', 'bun': 'JavaScript',
            
            # Web Development  
            'webpack': 'JavaScript', 'vite': 'JavaScript', 'parcel': 'JavaScript',
            'next': 'JavaScript', 'nuxt': 'JavaScript', 'gatsby': 'JavaScript',
            
            # System Languages
            'go': 'Go', 'cargo': 'Rust', 'rustc': 'Rust', 'rustup': 'Rust',
            'gcc': 'C', 'g++': 'C++', 'clang': 'C', 'clang++': 'C++',
            'zig': 'Zig', 'nim': 'Nim', 'crystal': 'Crystal',
            
            # JVM Languages  
            'java': 'Java', 'javac': 'Java', 'mvn': 'Java', 'gradle': 'Java',
            'kotlin': 'Kotlin', 'scala': 'Scala', 'sbt': 'Scala',
            
            # Other Languages
            'ruby': 'Ruby', 'gem': 'Ruby', 'bundle': 'Ruby', 'rails': 'Ruby',
            'php': 'PHP', 'composer': 'PHP', 'artisan': 'PHP',
            'dotnet': 'C#', 'nuget': 'C#',
            'swift': 'Swift', 'swiftc': 'Swift',
            'dart': 'Dart', 'flutter': 'Dart',
            'elixir': 'Elixir', 'mix': 'Elixir',
            'lua': 'Lua', 'luarocks': 'Lua',
            'perl': 'Perl', 'cpan': 'Perl',
            'r': 'R', 'rscript': 'R',
            
            # Tools & Infrastructure
            'docker': 'Docker', 'docker-compose': 'Docker', 'podman': 'Docker',
            'kubectl': 'Kubernetes', 'helm': 'Kubernetes', 'k9s': 'Kubernetes',
            'terraform': 'Terraform', 'terragrunt': 'Terraform',
            'ansible': 'Ansible', 'ansible-playbook': 'Ansible',
            'vagrant': 'Vagrant',
            
            # Version Control
            'git': 'Git', 'gh': 'Git', 'hub': 'Git', 'gitk': 'Git',
            'svn': 'Subversion', 'hg': 'Mercurial',
            
            # Editors
            'vim': 'Vim', 'nvim': 'Neovim', 'emacs': 'Emacs', 'nano': 'Nano',
            'code': 'VS Code', 'subl': 'Sublime Text', 'atom': 'Atom',
            
            # Build Systems
            'make': 'Make', 'cmake': 'CMake', 'ninja': 'Ninja',
            'bazel': 'Bazel', 'buck': 'Buck',
            
            # Network/System  
            'ssh': 'SSH', 'scp': 'SSH', 'rsync': 'File Transfer',
            'curl': 'HTTP', 'wget': 'HTTP', 'httpie': 'HTTP',
            'ping': 'Network', 'netstat': 'Network', 'ss': 'Network',
            
            # Databases
            'mysql': 'SQL', 'psql': 'PostgreSQL', 'sqlite3': 'SQLite',
            'mongo': 'MongoDB', 'redis-cli': 'Redis',
            
            # Package Managers
            'brew': 'Package Manager', 'apt': 'Package Manager', 'yum': 'Package Manager',
            'pacman': 'Package Manager', 'zypper': 'Package Manager', 'dnf': 'Package Manager',
            'choco': 'Package Manager', 'scoop': 'Package Manager',
        }
        
        return language_map.get(cmd, 'Shell')
    
    
    def get_base_command(self, command: str) -> str:
        """Extract the base command from a full command line"""
        cmd_parts = command.strip().split()
        if not cmd_parts:
            return 'unknown'
        return cmd_parts[0]
    
    def create_activity_entry(self, command: str, cwd: str, timestamp: float) -> Dict:
        """Create an activity log entry"""
        base_cmd = self.get_base_command(command)
        project = self.get_project_name(cwd)
        language = self.get_language_from_command(command)
        
        # Create a unique entity ID for this command
        entity_hash = hashlib.md5(f"{base_cmd}:{cwd}".encode()).hexdigest()[:12]
        
        return {
            "timestamp": timestamp,
            "datetime": datetime.fromtimestamp(timestamp).isoformat(),
            "command": command,
            "base_command": base_cmd,
            "cwd": cwd,
            "project": project,
            "language": language,
            "entity": f"terminal://{project}/{base_cmd}#{entity_hash}",
            "duration": 2.0,  # Default 2 seconds per command
            "plugin": "wakaterm-ng/2.0.0"
        }
    
    def track_command(self, command: str, cwd: Optional[str] = None, timestamp: Optional[float] = None):
        """Main method to track a command by logging to local file"""
        if not command.strip():
            return
        
        cwd = cwd or os.getcwd()
        timestamp = timestamp or time.time()
        
        try:
            # Create activity entry
            entry = self.create_activity_entry(command, cwd, timestamp)
            
            # Append to log file (JSON Lines format)
            with open(self.log_file, 'a', encoding='utf-8') as f:
                f.write(json.dumps(entry) + '\n')
                
        except Exception as e:
            # If there's any error, silently fail to avoid breaking terminal
            pass  # Could optionally log to stderr in debug mode
    
    def cleanup_old_logs(self, days_to_keep: int = 30):
        """Remove log files older than specified days"""
        try:
            cutoff_time = time.time() - (days_to_keep * 24 * 3600)
            for log_file in self.log_dir.glob("wakaterm-*.jsonl"):
                if log_file.stat().st_mtime < cutoff_time:
                    log_file.unlink()
        except Exception:
            pass  # Silently fail cleanup


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='WakaTerm NG - Terminal Activity Logger')
    parser.add_argument('command', nargs='*', help='Command to track')
    parser.add_argument('--cwd', help='Current working directory')
    parser.add_argument('--timestamp', type=float, help='Command timestamp')
    parser.add_argument('--log-dir', help='Directory to store log files')
    parser.add_argument('--cleanup', action='store_true', help='Cleanup old log files')
    parser.add_argument('--days-to-keep', type=int, default=30, help='Days of logs to keep (default: 30)')
    
    args = parser.parse_args()
    
    tracker = TerminalTracker(args.log_dir)
    
    # Handle cleanup if requested
    if args.cleanup:
        tracker.cleanup_old_logs(args.days_to_keep)
        return
    
    if not args.command:
        print("Usage: wakaterm.py <command>", file=sys.stderr)
        sys.exit(1)
    
    command = ' '.join(args.command)
    tracker.track_command(command, args.cwd, args.timestamp)


if __name__ == '__main__':
    main()