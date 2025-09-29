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
        self.log_dir = Path(log_dir or os.path.expanduser('~/.local/share/wakaterm-logs'))
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
            'python': 'Python', 'python3': 'Python', 'python2': 'Python', 'py': 'Python', 
            'pip': 'Python', 'pip3': 'Python', 'pip2': 'Python', 'pipenv': 'Python', 'poetry': 'Python',
            'conda': 'Python', 'mamba': 'Python', 'micromamba': 'Python', 'pixi': 'Python',
            'jupyter': 'Python', 'ipython': 'Python', 'pytest': 'Python', 'mypy': 'Python',
            'black': 'Python', 'flake8': 'Python', 'pylint': 'Python', 'isort': 'Python',
            'bandit': 'Python', 'autopep8': 'Python', 'pydocstyle': 'Python',
            
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
            'ssh': 'SSH', 'scp': 'SSH', 'sftp': 'SSH', 'rsync': 'File Transfer',
            'curl': 'HTTP', 'wget': 'HTTP', 'httpie': 'HTTP', 'http': 'HTTP', 'https': 'HTTP',
            'ping': 'Network', 'netstat': 'Network', 'ss': 'Network', 'nmap': 'Network',
            'iptables': 'Network', 'ufw': 'Network', 'firewall-cmd': 'Network',
            
            # System Administration
            'systemctl': 'System Admin', 'service': 'System Admin', 'launchctl': 'System Admin',
            'crontab': 'System Admin', 'at': 'System Admin', 'jobs': 'System Admin',
            'ps': 'System Admin', 'top': 'System Admin', 'htop': 'System Admin', 'btop': 'System Admin',
            'kill': 'System Admin', 'killall': 'System Admin', 'pkill': 'System Admin',
            'mount': 'System Admin', 'umount': 'System Admin', 'lsblk': 'System Admin',
            'df': 'System Admin', 'du': 'System Admin', 'fdisk': 'System Admin',
            'free': 'System Admin', 'uptime': 'System Admin', 'uname': 'System Admin',
            'whoami': 'System Admin', 'id': 'System Admin', 'groups': 'System Admin',
            'sudo': 'System Admin', 'su': 'System Admin', 'chmod': 'System Admin', 
            'chown': 'System Admin', 'chgrp': 'System Admin',
            
            # File Operations
            'ls': 'File Operations', 'dir': 'File Operations', 'find': 'File Operations', 
            'locate': 'File Operations', 'which': 'File Operations', 'whereis': 'File Operations',
            'cp': 'File Operations', 'mv': 'File Operations', 'rm': 'File Operations',
            'mkdir': 'File Operations', 'rmdir': 'File Operations', 'touch': 'File Operations',
            'ln': 'File Operations', 'readlink': 'File Operations',
            'tar': 'Archive', 'gzip': 'Archive', 'gunzip': 'Archive', 'zip': 'Archive', 
            'unzip': 'Archive', '7z': 'Archive', 'rar': 'Archive', 'unrar': 'Archive',
            
            # Text Processing
            'cat': 'Text Processing', 'less': 'Text Processing', 'more': 'Text Processing',
            'head': 'Text Processing', 'tail': 'Text Processing', 'grep': 'Text Processing',
            'egrep': 'Text Processing', 'fgrep': 'Text Processing', 'rg': 'Text Processing',
            'ag': 'Text Processing', 'ack': 'Text Processing', 'sed': 'Text Processing',
            'awk': 'Text Processing', 'sort': 'Text Processing', 'uniq': 'Text Processing',
            'wc': 'Text Processing', 'cut': 'Text Processing', 'tr': 'Text Processing',
            'jq': 'Text Processing', 'yq': 'Text Processing',
            
            # Databases
            'mysql': 'SQL', 'psql': 'PostgreSQL', 'sqlite3': 'SQLite',
            'mongo': 'MongoDB', 'mongosh': 'MongoDB', 'redis-cli': 'Redis',
            'influx': 'Database', 'clickhouse': 'Database', 'cassandra': 'Database',
            
            # Package Managers
            'brew': 'Package Manager', 'apt': 'Package Manager', 'apt-get': 'Package Manager',
            'yum': 'Package Manager', 'dnf': 'Package Manager', 'zypper': 'Package Manager',
            'pacman': 'Package Manager', 'portage': 'Package Manager', 'emerge': 'Package Manager',
            'choco': 'Package Manager', 'scoop': 'Package Manager', 'winget': 'Package Manager',
            'flatpak': 'Package Manager', 'snap': 'Package Manager', 'appimage': 'Package Manager',
            
            # Shell Navigation
            'cd': 'Navigation', 'pushd': 'Navigation', 'popd': 'Navigation', 'dirs': 'Navigation',
            'pwd': 'Navigation', 'tree': 'Navigation', 'exa': 'Navigation', 'lsd': 'Navigation',
            
            # Shell Features
            'history': 'Shell', 'alias': 'Shell', 'unalias': 'Shell', 'type': 'Shell',
            'command': 'Shell', 'builtin': 'Shell', 'hash': 'Shell', 'help': 'Shell',
            'man': 'Documentation', 'info': 'Documentation', 'tldr': 'Documentation',
            'whatis': 'Documentation', 'apropos': 'Documentation',
        }
        
        return language_map.get(cmd, 'Shell')
    
    
    def get_base_command(self, command: str) -> str:
        """Extract the base command from a full command line"""
        cmd = command.strip()
        if not cmd:
            return 'unknown'
            
        # Handle command prefixes and pipes
        # Remove common prefixes like 'time', 'nohup', 'nice', etc.
        prefixes_to_skip = ['time', 'nohup', 'nice', 'ionice', 'timeout', 'strace', 'ltrace']
        
        # Split by pipes and take the first command
        first_part = cmd.split('|')[0].strip()
        
        # Split by && and take the first command  
        first_part = first_part.split('&&')[0].strip()
        
        # Split by ; and take the first command
        first_part = first_part.split(';')[0].strip()
        
        cmd_parts = first_part.split()
        if not cmd_parts:
            return 'unknown'
            
        # Skip things to get to the actual command
        i = 0
        while i < len(cmd_parts) and cmd_parts[i] in prefixes_to_skip:
            i += 1
            
        if i < len(cmd_parts):
            base_cmd = cmd_parts[i]
            # Remove path components to get just the command name
            return os.path.basename(base_cmd)
        
        return cmd_parts[0]
    
    def create_activity_entry(self, command: str, cwd: str, timestamp: float, duration: float = 2.0) -> Dict:
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
            "duration": duration,
            "plugin": "wakaterm-ng/2.0.0"
        }
    
    def track_command(self, command: str, cwd: Optional[str] = None, timestamp: Optional[float] = None, duration: Optional[float] = None, debug: bool = False):
        """Main method to track a command by logging to local file"""
        if not command.strip():
            if debug:
                print(f"WAKATERM DEBUG: Skipping empty command", file=sys.stderr)
            return
        
        cwd = cwd or os.getcwd()
        timestamp = timestamp or time.time()
        duration = duration or 2.0  # Default fallback to 2 seconds
        
        try:
            # Create activity entry
            entry = self.create_activity_entry(command, cwd, timestamp, duration)
            
            if debug:
                print(f"WAKATERM DEBUG: Logging command '{command}' in project '{entry['project']}' (language: {entry['language']}, duration: {duration}s)", file=sys.stderr)
            
            # Append to log file (JSON Lines format)
            with open(self.log_file, 'a', encoding='utf-8') as f:
                f.write(json.dumps(entry) + '\n')
                
        except Exception as e:
            # If there's any error, log in debug mode or silently fail
            if debug:
                print(f"WAKATERM DEBUG: Error logging command '{command}': {e}", file=sys.stderr)
            pass
    
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
    parser.add_argument('--duration', type=float, help='Command execution duration in seconds')
    parser.add_argument('--log-dir', help='Directory to store log files')
    parser.add_argument('--cleanup', action='store_true', help='Cleanup old log files')
    parser.add_argument('--days-to-keep', type=int, default=30, help='Days of logs to keep (default: 30)')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    
    args = parser.parse_args()
    
    # Check for debug mode from environment variable as well
    debug_mode = args.debug or os.environ.get('WAKATERM_DEBUG') == '1'
    
    tracker = TerminalTracker(args.log_dir)
    
    # Handle cleanup if requested
    if args.cleanup:
        tracker.cleanup_old_logs(args.days_to_keep)
        return
    
    if not args.command:
        print("Usage: wakaterm.py <command>", file=sys.stderr)
        sys.exit(1)
    
    command = ' '.join(args.command)
    tracker.track_command(command, args.cwd, args.timestamp, args.duration, debug_mode)


if __name__ == '__main__':
    main()