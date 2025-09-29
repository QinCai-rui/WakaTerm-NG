# WakaTerm NG

Next Generation Wakatime Terminal Plugin

## Overview

WakaTerm NG is a terminal plugin that integrates with [WakaTime](https://wakatime.com/) to automatically track your coding activity directly from your terminal sessions. It supports multiple shells (`bash`, `zsh`, and `fish`) and is designed for easy installation and minimal configuration.

## Features

- Automatic time tracking for terminal-based development/coding
- Supports Bash, Zsh, and Fish shells
- Lightweight and easy to set up
- Integrates seamlessly with your WakaTime account

## Installation

1. Run the following commands in your terminal:

   ```bash
   curl -fsSL https://go.qincai.xyz/wakaterm-ng | bash
   ```

2. Follow the prompts to configure your shell and enter your WakaTime API key.

## Supported Shells

- Bash (`shells/bash_wakaterm.sh`)
- Zsh (`shells/zsh_wakaterm.zsh`)
- Fish (`shells/fish_wakaterm.fish`)

## Usage

Once installed, your terminal activity will be tracked automatically. A `wakatermctl` command-line tool is planned for viewing stats right in the terminal in future releases.

## License

This project is licensed under the MPL v2 License. See the [LICENSE](LICENSE) file for details.
