# WakaTerm NG

<div align="center">
  <h3>🕔 Next Generation Terminal Activity Tracker for WakaTime 🕔</h3>
  <p>Automatically track your terminal-based development activity with WakaTime</p>
  
  ![License](https://img.shields.io/github/license/QinCai-rui/WakaTerm-NG)
  ![Shell Support](https://img.shields.io/badge/shells-bash%20%7C%20zsh%20%7C%20fish-blue)
  ![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-green)
</div>

## ✨ Features

- **Intelligent Command Tracking**: Automatically detects and categorizes terminal commands by language and project
- **Multi-Shell Support**: Works with Bash, Zsh, and Fish shells
- **Rich Analytics**: Built-in statistics viewer with `wakatermctl` command
- **Project Detection**: Smart project identification using common indicators (`.git`, `package.json`, etc.)
- **Performance Optimised**: Lightweight background tracking with minimal shell overhead (will compile to binary in future; python too slow)
- **Local-First**: Stores activity logs locally before syncing to WakaTime
- **Easy Setup**: One-command installation with automatic shell integration

## Quick Installation

### One-Line Install

```bash
curl -fsSL https://go.qincai.xyz/wakaterm-ng | bash
```

### Manual Installation

```bash
# Download and run the installer
curl -fsSL https://raw.githubusercontent.com/QinCai-rui/WakaTerm-NG/main/common.sh | bash

# Or clone and install manually
git clone https://github.com/QinCai-rui/WakaTerm-NG.git
cd WakaTerm-NG
./common.sh install
```

### Prerequisites

- **Python 3.6+** (for the tracking script)
- **Git** (for installation)
- **WakaTime Account** and API key ([Get yours here](https://wakatime.com/api-key)) (Or compatible self-hosted WakaTime server, such as Hackatime)

## Architecture

WakaTerm NG consists of several key components:

- **`wakaterm.py`**: Core Python tracker with intelligent command categorization
- **`wakatermctl`**: Command-line tool for viewing local statistics
- **Shell Integrations**: Native hooks for Bash, Zsh, and Fish
- **Installation System**: Modular installer with state tracking and rollback support

## 🔧 Configuration

### WakaTime Setup

The installer will prompt you to configure your WakaTime API key. You can also set it manually:

```bash
# Create or edit ~/.wakatime.cfg
[settings]
api_key = your-api-key-here
```

### Environment Variables

- `WAKATERM_DEBUG=1`: Enable debug output to see what commands are being tracked
- `WAKATERM_AUTO_INSTALL=1`: Skip interactive prompts during installation

### Advanced Configuration

- **Log Directory**: `~/.local/share/wakaterm-logs/` (customisable via `--log-dir`)
- **Installation Directory**: `~/.local/share/wakaterm/`
- **Shell Integration**: Automatic detection and setup

## 📊 Usage

### Automatic Tracking

Once installed, WakaTerm NG automatically tracks all your terminal commands:

```bash
# These commands will be automatically tracked
python main.py          # → Detected as Python
npm install             # → Detected as JavaScript  
git commit -m "fix"     # → Detected as Git
docker build .          # → Detected as Docker
```

### View Statistics

Use the built-in `wakatermctl` command to view your terminal activity:

```bash
# View today's activity
wakatermctl

# View different time periods
wakatermctl yesterday
wakatermctl last_7_days
wakatermctl last_30_days
wakatermctl last_6_months
wakatermctl last_year

# Export as JSON
wakatermctl today --json

# Debug mode
wakatermctl today --debug
```

### Example Output

```
📊 Today's Terminal Activity
============================
⏱️  Total Time: 2h 34m (127 commands)
📈 Daily Average: 2h 34m

🔤 Languages/Categories:
   • Python: 1h 12m (47.2%)
   • Git: 32m (20.8%)
   • JavaScript: 28m (18.3%)
   • Docker: 15m (9.7%)
   • Shell: 7m (4.0%)

⚡ Most Used Commands:
   • python: 23 times (18.1%)
   • git: 18 times (14.2%)
   • npm: 12 times (9.4%)
   • code: 8 times (6.3%)
   • docker: 7 times (5.5%)

📁 Projects:
   • my-python-project: 1h 8m (44.2%)
   • web-frontend: 45m (29.1%)
   • terminal-wakatime: 32m (20.7%)
   • dotfiles: 9m (6.0%)
```

## Management Commands

```bash
# Installation management
./common.sh install              # Fresh installation
./common.sh uninstall            # Complete removal
./common.sh upgrade              # Upgrade to latest version
./common.sh test                 # Test current installation
./common.sh status               # Show installation status

# Shell integration
./common.sh setup-integration         # Auto-detect and setup current shell
./common.sh setup-integration bash    # Setup specific shell
./common.sh setup-integration zsh
./common.sh setup-integration fish

# Non-interactive installation
./common.sh install --yes        # Skip prompts
WAKATERM_AUTO_INSTALL=1 ./common.sh install
```

## Shell Support

### Bash Integration

- **File**: `shells/bash_wakaterm.sh`
- **Hook Method**: `PROMPT_COMMAND` and `DEBUG` trap
- **Configuration**: Added to `~/.bashrc` or `~/.bash_profile`

### Zsh Integration  

- **File**: `shells/zsh_wakaterm.zsh`
- **Hook Method**: `preexec` and `precmd` functions
- **Configuration**: Added to `~/.zshrc`

### Fish Integration

- **File**: `shells/fish_wakaterm.fish`
- **Hook Method**: `fish_preexec` and `fish_postexec` events
- **Configuration**: Added to `~/.config/fish/config.fish`

## Language Detection

WakaTerm NG intelligently categorizes commands into languages and tools:

### Programming Languages

- **Python**: `python`, `pip`, `poetry`, `pytest`, `black`, etc.
- **JavaScript/Node**: `node`, `npm`, `yarn`, `webpack`, `next`, etc.
- **Go**: `go`, `gofmt`, `go mod`, etc.
- **Rust**: `cargo`, `rustc`, `rustup`, etc.
- **Java**: `java`, `mvn`, `gradle`, etc.
- **And many more...**

### Development Tools

- **Version Control**: `git`, `svn`, `hg`
- **Containers**: `docker`, `podman`, `kubectl`
- **Infrastructure**: `terraform`, `ansible`, `vagrant`
- **Databases**: `mysql`, `psql`, `mongo`, `redis-cli`

### System Operations
- **File Operations**: `
ls`, `cp`, `mv`, `find`, etc.
- **Text Processing**: `grep`, `sed`, `awk`, `jq`, etc.
- **System Admin**: `systemctl`, `ps`, `top`, `chmod`, etc.

## Troubleshooting

### Common Issues

**WakaTerm not tracking commands?**

```bash
# Check if shell integration is loaded
echo $WAKATERM_FISH_LOADED  # For Fish
env | grep WAKATERM         # Check environment

# Enable debug mode
export WAKATERM_DEBUG=1
# Run a command and check output
```

**Installation fails?**

```bash
# Check dependencies
python3 --version
git --version

# Try manual installation
git clone https://github.com/QinCai-rui/WakaTerm-NG.git
cd WakaTerm-NG
./common.sh install
```

**Commands not appearing in WakaTime?**

```bash
# Check WakaTime configuration
cat ~/.wakatime.cfg

# Test local tracking
wakatermctl today --debug

# Check log files
ls ~/.local/share/wakaterm-logs/
```

### Debug Mode

Enable debug output to see what's happening:

```bash
export WAKATERM_DEBUG=1
# Now run commands to see tracking output
```

## Uninstallation

If you need to completely remove WakaTerm NG:

```bash
curl -fsSL https://go.qincai.xyz/wakaterm-ng | bash -s -- uninstall
```

## License

This project is licensed under the Mozilla Public License 2.0. See the [LICENSE](LICENSE) file for details.