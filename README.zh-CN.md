# UsageMonitor / 用量监控

[![CI](https://github.com/yanbohon/UsageMonitor/actions/workflows/ci.yml/badge.svg)](https://github.com/yanbohon/UsageMonitor/actions/workflows/ci.yml)
[![Linux CLI](https://github.com/yanbohon/UsageMonitor/actions/workflows/linux-cli.yml/badge.svg)](https://github.com/yanbohon/UsageMonitor/actions/workflows/linux-cli.yml)
[![Release](https://github.com/yanbohon/UsageMonitor/actions/workflows/release.yml/badge.svg)](https://github.com/yanbohon/UsageMonitor/actions/workflows/release.yml)

[English](README.md) | 中文

`用量监控` 是一个原生 macOS 菜单栏应用，也提供 Linux 友好的 `usage-monitor` CLI。它用于监控 sub2api 兼容的用量接口和公共渠道健康状态。

## 功能

- 连接一个或多个 sub2api 兼容实例。
- 使用 `GET /v1/usage` 和 `Authorization: Bearer <apiKey>` 获取套餐、余额和用量。
- macOS 端在菜单栏显示今日用量，并在弹窗中展示余额、套餐、订阅限制、用量统计和模型数据。
- Linux CLI 提供 `usage`、`status`、`bar`、`setup`、`config` 命令。
- Linux `bar` 模式支持总额度/多 Key 进度条、渠道健康、首 token 延迟、主题配色和热键切换。
- 首 token 延迟来自公共状态接口 `GET https://status.input.im/api/status`，CLI 不会为了显示延迟而向你的模型 API 发起推理请求。

## 要求

- macOS 13 Ventura 或更新版本。
- Swift 5.9+ / Xcode 15+。
- Linux CLI 构建推荐使用 `swift:5.9-jammy`。
- 一个可访问的 sub2api 兼容 `GET /v1/usage` 接口。

## macOS 快速开始

```bash
swift build
swift run UsageMonitor
```

打开菜单栏设置，填写 sub2api 根 URL 和 API Key，然后点击 `验证并刷新`。

## Linux CLI

本地构建：

```bash
swift build --product usage-monitor -c release
```

直接运行：

```bash
USAGE_MONITOR_BASE_URL=https://example.com \
USAGE_MONITOR_API_KEY=sk-... \
swift run usage-monitor -- bar --interval 60
```

构建 Linux amd64 发布包：

```bash
./scripts/build-linux-cli.sh
```

输出文件：

- `build/usage-monitor-linux-amd64.tar.gz`
- `build/usage-monitor-linux-amd64.tar.gz.sha256`

## bar 模式

```bash
usage-monitor bar --mode oneline
usage-monitor bar --mode lite
usage-monitor bar --mode detail
```

- `oneline`：单行显示总额度、渠道健康、gpt-5.5 状态和首 token 延迟。
- `lite`：显示总额度、每个 Key 的额度进度条、剩余天数和渠道健康。
- `detail`：在 lite 基础上增加服务状态和用量详情面板。

live `bar` 热键：

```text
o  切换到 oneline
d  切换到 detail
l  切换到 lite
c  循环切换主题
Ctrl-C  退出
```

热键只重绘上一份快照，不会额外请求用量或状态接口。

主题：

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

更多 CLI 说明见 [docs/linux-cli.md](docs/linux-cli.md)。

## 配置

默认配置文件位置：

```text
~/.config/usage-monitor/config.json
```

CLI 参数优先级：

```text
命令行参数 > 环境变量 > 配置文件
```

常用环境变量：

```bash
USAGE_MONITOR_BASE_URL=https://example.com
USAGE_MONITOR_API_KEY=sk-...
USAGE_MONITOR_INTERVAL_SECONDS=60
USAGE_MONITOR_THEME=contrast
USAGE_MONITOR_COLOR_MODE=truecolor
```

## CI/CD

- `CI`：在 `macos-14` 上构建并测试 macOS 应用。
- `Linux CLI`：在 `swift:5.9-jammy` 中运行 core/CLI 测试，构建 Linux amd64 tarball，校验 SHA-256，冒烟测试打包后的二进制，并上传 artifact。
- `Release`：构建 macOS DMG 和 Linux amd64 CLI 包，发布到 GitHub Release，并附带 `.sha256` 校验文件。

## 发布构建

macOS：

```bash
./scripts/build-app.sh
./scripts/create-dmg.sh
```

Linux：

```bash
./scripts/build-linux-cli.sh
```

## 测试

```bash
swift test
```

单元测试不会调用真实服务；网络行为通过可注入的 request loader 测试。

## License

Apache 2.0，见 [LICENSE.txt](LICENSE.txt)。
