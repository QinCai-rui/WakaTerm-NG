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
import subprocess
from pathlib import Path
from typing import Optional, List, Dict
from datetime import datetime

# init DEBUG_MODE as global variable
DEBUG_MODE = False

class TerminalTracker:
    """Main terminal tracking class that logs to local files"""
    
    def __init__(self, log_dir: Optional[str] = None):
        self.log_dir = Path(log_dir or os.path.expanduser('~/.local/share/wakaterm-logs'))
        
        # Create logs directory with better error handling
        try:
            self.log_dir.mkdir(parents=True, exist_ok=True)
        except (OSError, PermissionError) as e:
            # Fallback to a temp directory if we can't create in the preferred location
            import tempfile
            fallback_dir = Path(tempfile.gettempdir()) / 'wakaterm-logs'
            try:
                fallback_dir.mkdir(parents=True, exist_ok=True)
                self.log_dir = fallback_dir
                # Write a warning to stderr ONLY if in debug mode
                if DEBUG_MODE:
                    print(f"Warning: Could not create {log_dir or '~/.local/share/wakaterm-logs'}, using {fallback_dir}", file=sys.stderr)
            except Exception:
                # If even temp directory fails, can't log anything
                if DEBUG_MODE:
                    print(f"Error: Could not create any log directory. Original error: {e}", file=sys.stderr)
                raise
        
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
    
    def _get_git_branch(self, cwd: str) -> Optional[str]:
        """Get the current Git branch if in a Git repository"""
        try:
            import subprocess
            result = subprocess.run(
                ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                cwd=cwd,
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception:
            pass
        return None
    
    def _is_write_command(self, base_command: str) -> bool:
        """Determine if a command is a write operation"""
        write_commands = {
            # File operations that modify files
            'cp', 'mv', 'rm', 'mkdir', 'rmdir', 'touch', 'ln',
            # Text editors
            'vim', 'nvim', 'emacs', 'nano', 'code', 'subl',
            # Archive operations
            'tar', 'gzip', 'zip', 'unzip',
            # Version control write operations
            'git',  # Many git commands are writes (commit, push, etc.)
            # Build and install operations
            'make', 'cargo', 'npm', 'pip', 'poetry', 'composer',
            # Database operations (often writes)
            'mysql', 'psql', 'mongo', 'redis-cli'
        }
        return base_command in write_commands
    
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
    
    def _is_wakatime_available(self) -> bool:
        """Check if wakatime-cli is available and configured"""
        # Check for wakatime-cli executable
        wakatime_paths = [
            Path.home() / '.wakatime' / 'wakatime-cli',
            Path('/usr/local/bin/wakatime-cli'),
            Path('/usr/bin/wakatime-cli')
        ]
        
        wakatime_cli = None
        for path in wakatime_paths:
            if path.exists() and os.access(path, os.X_OK):
                wakatime_cli = path
                break
        
        if not wakatime_cli:
            # Try to find in PATH
            import shutil
            wakatime_cli = shutil.which('wakatime-cli')
            if not wakatime_cli:
                return False
        
        # Check for API key in config file
        config_path = Path.home() / '.wakatime.cfg'
        if config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    content = f.read()
                    if 'api_key' in content and len(content.strip()) > 20:  # Basic check
                        return True
            except Exception:
                pass
        
        # Check for API key in environment
        if os.environ.get('WAKATIME_API_KEY'):
            return True
            
        return False
    
    def _send_to_wakatime(self, command: str, cwd: str, timestamp: float, duration: float, debug: bool = False):
        """Send command data to WakaTime using wakatime-cli"""
        if not self._is_wakatime_available():
            if debug:
                print("WAKATERM DEBUG: wakatime-cli not available or not configured, skipping WakaTime sync", file=sys.stderr)
            return
        
        try:
            # Find wakatime-cli executable
            wakatime_cli = None
            wakatime_paths = [
                Path.home() / '.wakatime' / 'wakatime-cli',
                Path('/usr/local/bin/wakatime-cli'),
                Path('/usr/bin/wakatime-cli')
            ]
            
            for path in wakatime_paths:
                if path.exists() and os.access(path, os.X_OK):
                    wakatime_cli = str(path)
                    break
            
            if not wakatime_cli:
                import shutil
                wakatime_cli = shutil.which('wakatime-cli')
            
            if not wakatime_cli:
                if debug:
                    print("WAKATERM DEBUG: wakatime-cli executable not found", file=sys.stderr)
                return

            # Use the existing create_activity_entry method to get all metadata!
            entry = self.create_activity_entry(command, cwd, timestamp, duration)
            
            # Use a PROPER URL scheme for terminal activities (otherwise WakaTime ignore them)
            # This is much cleaner and more descriptive than fake file paths
            wakaterm_url = f"terminal://{entry['project']}/{entry['base_command']}"

            wakatime_args = [
                wakatime_cli,
                '--entity', wakaterm_url,
                '--entity-type', 'url',  # Use 'url' for custom wakaterm-ng:// scheme
                '--project', entry['project'],
                '--language', entry['language'],
                '--time', str(entry['timestamp']),
                '--plugin', entry['plugin'],
                '--project-folder', cwd,  # Help with project detection
                '--timeout', '30'  # Prevent hanging on network issues
            ]
            
            # Add Git branch if  in a Git repository
            git_branch = self._get_git_branch(cwd)
            if git_branch:
                wakatime_args.extend(['--alternate-branch', git_branch])
            
            # Mark write operations for certain commands
            if self._is_write_command(entry['base_command']):
                wakatime_args.append('--write')
            
            '''
            # Add category based on language
            if entry['language'] in ['Shell', 'Navigation', 'Text Processing', 'Package Manager', 'Documentation', 'Archive', 'File Operations', 'System Admin']:
                wakatime_args.extend(['--category', 'debugging'])
            elif entry['language'] in ['Git', 'Subversion', 'Mercurial']:
                wakatime_args.extend(['--category', 'code reviewing'])
            elif entry['language'] in ['Docker', 'Kubernetes', 'Terraform', 'Ansible']:
                wakatime_args.extend(['--category', 'building'])
            else:
                wakatime_args.extend(['--category', 'coding'])
            '''

            wakatime_args.extend(['--category', 'coding'])

            if debug:
                print(f"WAKATERM DEBUG: Executing wakatime-cli command: {' '.join(wakatime_args)}", file=sys.stderr)
            
            # Run wakatime-cli in background
            if debug:
                # In debug mode, capture output to see any errors
                result = subprocess.run(
                    wakatime_args,
                    capture_output=True,
                    text=True,
                    timeout=10  # Add timeout to prevent hanging
                )
                if result.returncode == 0:
                    print(f"WAKATERM DEBUG: WakaTime CLI exited successfully (code 0): {entry['entity']}", file=sys.stderr)
                    if result.stdout.strip():
                        print(f"WAKATERM DEBUG: WakaTime CLI stdout: {result.stdout}", file=sys.stderr)
                    if result.stderr.strip():
                        print(f"WAKATERM DEBUG: WakaTime CLI stderr: {result.stderr}", file=sys.stderr)
                else:
                    print(f"WAKATERM DEBUG: WakaTime CLI FAILED with exit code {result.returncode}:", file=sys.stderr)
                    if result.stdout:
                        print(f"WAKATERM DEBUG: stdout: {result.stdout}", file=sys.stderr)
                    if result.stderr:
                        print(f"WAKATERM DEBUG: stderr: {result.stderr}", file=sys.stderr)
            else:
                # Normal mode: run in background with no output
                subprocess.Popen(
                    wakatime_args,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True  # Detach from parent process
                )
                
        except Exception as e:
            if debug:
                print(f"WAKATERM DEBUG: Error sending to WakaTime: {e}", file=sys.stderr)
            pass  # Silently fail WakaTime integration
    
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
            
            # Also send to WakaTime
            self._send_to_wakatime(command, cwd, timestamp, duration, debug)
                
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
    global DEBUG_MODE
    DEBUG_MODE = args.debug or os.environ.get("WAKATERM_DEBUG", "").lower() in ("1", "true", "yes", "on")
    
    tracker = TerminalTracker(args.log_dir)
    
    # Handle cleanup if requested
    if args.cleanup:
        tracker.cleanup_old_logs(args.days_to_keep)
        return
    
    if not args.command:
        print("Usage: wakaterm.py <command>", file=sys.stderr)
        sys.exit(1)
    
    command = ' '.join(args.command)
    tracker.track_command(command, args.cwd, args.timestamp, args.duration, DEBUG_MODE)


if __name__ == '__main__':
    main()