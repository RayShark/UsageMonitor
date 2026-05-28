# UsageMonitor / 用量监控

[![CI](https://github.com/yanbohon/UsageMonitor/actions/workflows/ci.yml/badge.svg)](https://github.com/yanbohon/UsageMonitor/actions/workflows/ci.yml)
[![Linux CLI](https://github.com/yanbohon/UsageMonitor/actions/workflows/linux-cli.yml/badge.svg)](https://github.com/yanbohon/UsageMonitor/actions/workflows/linux-cli.yml)
[![Release](https://github.com/yanbohon/UsageMonitor/actions/workflows/release.yml/badge.svg)](https://github.com/yanbohon/UsageMonitor/actions/workflows/release.yml)

English | [中文](README.zh-CN.md)

`用量监控` is a native macOS menu bar app and Linux-friendly CLI for monitoring sub2api-compatible usage endpoints and public channel health. The technical macOS executable name is `UsageMonitor`, with bundle identifier `com.usagemonitor.app`.

## What It Does

- Connects to one or more sub2api-compatible instances with Base URL and API Key configuration
- Calls `GET /v1/usage` with `Authorization: Bearer <apiKey>`
- Stores Base URL, API keys, refresh interval, and display preferences
- Shows `subscription.daily_usage_usd` in the menu bar, with an option to hide decimal places
- Shows remaining balance, plan, mode, subscription limits, usage summary, and model stats in the popover
- Shows public channel health and first-token latency from `GET https://status.input.im/api/status`
- Provides a TPM-style tmux plugin path for users who want a shell-native pane without installing Swift
- Preserves the last successful usage snapshot in memory when refresh fails

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ / Xcode 15+
- A reachable sub2api-compatible `GET /v1/usage` endpoint
- tmux plugin runtime: `tmux`, `bash`, `curl`, and `jq`

## Quick Start

```bash
swift build
swift run UsageMonitor
```

Open settings from the menu bar, enter the sub2api root URL and API Key, then click `验证并刷新`. The display section lets you choose whether the menu bar shows decimal places.

## Linux CLI

The macOS app remains the primary menu-bar experience. Linux users can run the compact CLI dashboard:

```bash
swift build --product usage-monitor -c release
USAGE_MONITOR_BASE_URL=https://example.com USAGE_MONITOR_API_KEY=sk-... swift run usage-monitor -- bar --interval 60
```

Linux release packages are built with:

```bash
./scripts/build-linux-cli.sh
```

The `bar` command is designed for a tmux pane. `--mode oneline` keeps total quota and gpt-5.5 health on one row. `--mode lite` shows a total quota bar, one quota bar per key, remaining days, and circle-based channel health with first-token latency. `--mode detail` adds bordered service and per-key detail panels. In live `bar` mode, press `o`, `d`, or `l` to switch modes, `c` to cycle themes, and `Ctrl-C` to exit. Themes include `contrast`, `classic`, `mono`, `dracula`, `catppuccin`, `tokyonight`, `nord`, and `gruvbox`.

See [docs/linux-cli.md](docs/linux-cli.md).

## tmux Plugin

Install the shell-native plugin with TPM when you want a persistent tmux pane without Swift at runtime:

```tmux
set -g @plugin 'yanbohon/UsageMonitor'
set -g @usage_monitor_config "$HOME/.config/tmux-usage-monitor/config.json"
set -g @usage_monitor_key "u"
set -g @usage_monitor_global_key "U"
```

Press prefix + `u` to toggle the current window monitor, or prefix + `U` to toggle monitors for every window in the session. See [docs/tmux-plugin.md](docs/tmux-plugin.md) for config shape, themes, dependencies, and troubleshooting.

## CI/CD

- `CI` builds and tests the macOS app on `macos-14`.
- `Linux CLI` runs tmux plugin shell tests plus core and CLI tests in `swift:5.9-jammy`, builds `usage-monitor-linux-amd64.tar.gz`, verifies its checksum, smokes the packaged binary, and uploads the artifact.
- `Release` repeats the Linux/tmux checks, builds the macOS DMG and Linux amd64 CLI package, attaches both to the GitHub Release, and publishes SHA-256 checksum files.

## Configuration

The Base URL must start with `http://` or `https://` and should be the instance root only. The app removes trailing slashes before saving and always builds the usage path as:

- `/v1/usage`

Refresh intervals are limited to 1, 5, 15, 30, and 60 minutes. The default is 5 minutes.

## Build for Distribution

```bash
./scripts/build-app.sh
./scripts/create-dmg.sh
```

Outputs:

- `build/UsageMonitor.app`
- `build/UsageMonitor.dmg`

## Run Tests

```bash
swift test
```

No unit test calls a real service. API behavior is tested through an injectable request loader.

## Project Structure

```text
Sources/UsageMonitorCore/
├── Configuration/
├── Formatters/
├── Models/
├── Services/
└── Terminal/

Sources/UsageMonitor/
├── UsageMonitorApp.swift
├── Controllers/
├── Monitors/
├── Services/
└── Views/

Sources/UsageMonitorCLI/
├── Commands/
├── Rendering/
├── CLIArguments.swift
├── CLIConfig.swift
├── CLIOutput.swift
└── main.swift

Tests/
├── UsageMonitorCoreTests/
├── UsageMonitorCLITests/
└── UsageMonitorTests/
```

## License

Apache 2.0 — see [LICENSE.txt](LICENSE.txt).
