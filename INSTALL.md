# Installation & Setup

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- sub2api Base URL and API Key for `GET /v1/usage`

## Installation Methods

### Install Script

```bash
./scripts/install.sh
```

This builds a release binary, creates `UsageMonitor.app`, and copies it to `/Applications/`.

### DMG

```bash
./scripts/create-dmg.sh
```

Open `build/UsageMonitor.dmg` and drag `UsageMonitor.app` into Applications.

### Manual

```bash
swift build -c release
./scripts/build-app.sh
cp -R build/UsageMonitor.app /Applications/
```

## Launch

```bash
open /Applications/UsageMonitor.app
```

The app runs in the menu bar. Open settings, enter the sub2api Base URL and API Key, then click `验证并刷新`.

## Linux CLI

Install Swift 5.9+ on Linux, then build:

```bash
swift build --product usage-monitor -c release
mkdir -p ~/.local/bin
cp .build/release/usage-monitor ~/.local/bin/usage-monitor
```

Run:

```bash
USAGE_MONITOR_BASE_URL=https://example.com \
USAGE_MONITOR_API_KEY=sk-... \
usage-monitor bar --interval 60
```

See [docs/linux-cli.md](docs/linux-cli.md) for tmux recipes and config file setup.

## tmux Plugin

For a shell-native tmux pane that does not require Swift at runtime, install the TPM-style plugin and configure `~/.config/tmux-usage-monitor/config.json`:

```tmux
set -g @plugin 'yanbohon/UsageMonitor'
set -g @usage_monitor_config "$HOME/.config/tmux-usage-monitor/config.json"
```

The plugin runtime needs `tmux`, `bash`, `curl`, and `jq`. See [docs/tmux-plugin.md](docs/tmux-plugin.md).

## Uninstall

```bash
rm -rf /Applications/UsageMonitor.app
```
