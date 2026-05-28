# tmux Plugin

`tmux-usage-monitor` is a TPM-style plugin for showing UsageMonitor balance and channel health in a tmux pane. It does not require Swift, Xcode, SwiftPM, or the `usage-monitor` CLI at runtime.

The plugin uses:

- `tmux` for pane lifecycle and key binding
- `curl` for `GET /v1/usage` and public status requests
- `jq` for JSON parsing

## Install With TPM

Add the plugin to `.tmux.conf`:

```tmux
set -g @plugin 'yanbohon/UsageMonitor'
set -g @usage_monitor_config "$HOME/.config/tmux-usage-monitor/config.json"
set -g @usage_monitor_interval "60"
set -g @usage_monitor_height "2"
set -g @usage_monitor_model "gpt-5.5"
set -g @usage_monitor_key "u"
```

Reload tmux and install TPM plugins with your TPM install binding. The repository root contains `usage-monitor.tmux`, which forwards to the shell-native plugin scripts under `tmux/`.

For a local checkout, load the plugin entrypoint directly:

```bash
tmux run-shell "$PWD/usage-monitor.tmux"
```

## Config

Create `~/.config/tmux-usage-monitor/config.json`:

```json
{
  "defaultBaseURL": "https://example.com",
  "refreshIntervalSeconds": 60,
  "statusEndpoint": "https://status.input.im/api/status",
  "model": "gpt-5.5",
  "keys": [
    {
      "id": "main",
      "name": "Main",
      "apiKey": "sk-...",
      "baseURL": "https://example.com"
    }
  ]
}
```

Protect the file because it contains API keys:

```bash
chmod 600 ~/.config/tmux-usage-monitor/config.json
```

The plugin also accepts the existing UsageMonitor CLI config shape with `defaultBaseURL`, `apiKey`, `baseURLMode`, and `baseURLOverride`. Empty `baseURLOverride` values fall back to `defaultBaseURL`.

## Usage

Press your tmux prefix and `u` to toggle the monitor pane. Change the key with:

```tmux
set -g @usage_monitor_key "U"
```

The pane renders a compact line:

```text
总额度 [████████████████░░] 88.0% $968.37/$1100.00 余额 $131.63 渠道 3/3 OK gpt-5.5 ○○◐○○ 首T 2.1s ↻60s
```

The plugin creates at most one `usage-monitor` pane per tmux session. Pressing the binding again closes that pane.

## Options

```tmux
set -g @usage_monitor_config "$HOME/.config/tmux-usage-monitor/config.json"
set -g @usage_monitor_interval "60"
set -g @usage_monitor_height "2"
set -g @usage_monitor_model "gpt-5.5"
set -g @usage_monitor_key "u"
```

## Data Sources

- Quota, balance, and per-key usage come from your configured Base URL with `GET /v1/usage`.
- Channel health and first-token latency come from `GET https://status.input.im/api/status`.
- The plugin does not send model inference requests.

## Troubleshooting

`usage-monitor: missing jq` means `jq` is not installed.

`usage-monitor: missing curl` means `curl` is not installed.

`usage-monitor: config not found` means the configured file path does not exist.

`usage-monitor: no usable keys configured` means the config file has no key with both `apiKey` and a resolvable Base URL.

HTTP 401 or 403 responses mean the API key is invalid or not accepted by the configured Base URL.
