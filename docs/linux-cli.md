# Linux CLI

`usage-monitor` is the Linux-friendly CLI for UsageMonitor. It reuses the same sub2api usage endpoint and service status endpoint as the macOS menu bar app.

## Build

```bash
swift build --product usage-monitor -c release
```

Release package:

```bash
./scripts/build-linux-cli.sh
```

The package is written to `build/usage-monitor-linux-amd64.tar.gz` with a matching `.sha256` file.

## One-Shot Usage

```bash
USAGE_MONITOR_BASE_URL=https://example.com \
USAGE_MONITOR_API_KEY=sk-... \
swift run usage-monitor -- usage
```

## One-Shot Service Status

```bash
swift run usage-monitor -- status
```

## tmux Bar Pane

For a TPM-style plugin that does not require Swift at runtime, see [tmux Plugin](tmux-plugin.md). The plugin uses `curl` and `jq` directly and is better suited for shared tmux setups.

Lite display, optimized for a tmux pane:

```bash
tmux split-window -v -l 2 'USAGE_MONITOR_BASE_URL=https://example.com USAGE_MONITOR_API_KEY=sk-... swift run usage-monitor -- bar --interval 60'
```

Detail display, closer to the macOS popover:

```bash
tmux split-window -v -l 10 'USAGE_MONITOR_BASE_URL=https://example.com USAGE_MONITOR_API_KEY=sk-... swift run usage-monitor -- bar --interval 60 --mode detail'
```

Single-line display for a status bar or a narrow tmux pane:

```bash
usage-monitor bar --mode oneline --interval 60
```

Theme options:

```bash
usage-monitor bar --theme contrast
usage-monitor bar --theme classic
usage-monitor bar --theme mono
usage-monitor bar --theme dracula
usage-monitor bar --theme catppuccin
usage-monitor bar --theme tokyonight
usage-monitor bar --theme nord
usage-monitor bar --theme gruvbox
```

`bar` monitors every configured key by default. Pass `--key ID_OR_NAME` when you only want one account.
Oneline mode renders total quota, aggregate channel health, gpt-5.5's circle health trace, first-token latency, and refresh cadence on one row. Lite mode renders a total quota progress bar first, then one progress bar per configured key, followed by circle-based channel health. Detail mode adds bordered service and usage panels.
For terminals that need explicit color handling, set `USAGE_MONITOR_COLOR_MODE=truecolor|ansi256|no-color`. This explicit setting can force color even when the shell exports `NO_COLOR`.

Live `bar` hotkeys:

```text
o  switch to oneline
d  switch to detail
l  switch to lite
c  cycle theme
Ctrl-C  exit
```

Hotkeys only re-render the last fetched snapshot. They do not trigger an extra usage or status request.

Data sources:

- First-token latency and channel health come from `GET https://status.input.im/api/status`.
- Quota, plan, balance, and per-key usage come from your configured Base URL with `GET /v1/usage`.
- The CLI does not send model inference requests for first-token latency or quota display.

## Config File

Create `~/.config/usage-monitor/config.json`:

```json
{
  "defaultBaseURL": "https://example.com",
  "refreshIntervalSeconds": 60,
  "showColors": true,
  "theme": "contrast",
  "keys": [
    {
      "id": "main",
      "name": "Key 1",
      "symbolName": "key.fill",
      "symbolColorHex": "#66D9EF",
      "showsInMenuBar": true,
      "apiKey": "sk-...",
      "baseURLMode": "inherited",
      "baseURLOverride": ""
    },
    {
      "id": "backup",
      "name": "Key 2",
      "symbolName": "key.fill",
      "symbolColorHex": "#FFD166",
      "showsInMenuBar": true,
      "apiKey": "sk-...",
      "baseURLMode": "inherited",
      "baseURLOverride": ""
    }
  ]
}
```

CLI flags override environment variables, and environment variables override this config file.
