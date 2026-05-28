import Foundation
import UsageMonitorCore

enum InteractiveError: Error, Equatable {
    case requiresTTY
}

extension InteractiveError: CustomStringConvertible {
    var description: String {
        switch self {
        case .requiresTTY:
            return "Interactive mode requires a TTY. Use usage-monitor setup, usage-monitor config, or pass flags in scripts."
        }
    }
}

extension InteractiveError: LocalizedError {
    var errorDescription: String? { description }
}

enum UsageMonitorInteractive {
    static func run(
        mode: InteractiveMode,
        store: CLIConfigStore = .default(),
        terminal: InteractiveTerminal = .standard
    ) throws {
        guard terminal.isTTY() else { throw InteractiveError.requiresTTY }

        var config = store.load() ?? defaultConfig()
        switch mode {
        case .auto:
            if needsSetup(config) {
                try runSetup(config: &config, store: store, terminal: terminal)
            } else {
                try runHome(config: &config, store: store, terminal: terminal)
            }
        case .setup:
            try runSetup(config: &config, store: store, terminal: terminal)
        case .config:
            try runConfig(config: &config, store: store, terminal: terminal)
        }
    }

    private static func runHome(
        config: inout CLIConfig,
        store: CLIConfigStore,
        terminal: InteractiveTerminal
    ) throws {
        while true {
            terminal.clearScreen()
            terminal.write("""
            用量监控

            配置：\(store.url.path)
            Base URL：\(display(config.defaultBaseURL))
            Keys：\(config.keys.count)

            1. 管理配置
            2. 重新 setup
            3. 退出
            """)
            switch prompt("选择", terminal: terminal) {
            case "1":
                try runConfig(config: &config, store: store, terminal: terminal)
            case "2":
                try runSetup(config: &config, store: store, terminal: terminal)
            case "3", "q", "Q", "":
                return
            default:
                pause("无效选择", terminal: terminal)
            }
        }
    }

    private static func runSetup(
        config: inout CLIConfig,
        store: CLIConfigStore,
        terminal: InteractiveTerminal
    ) throws {
        terminal.clearScreen()
        terminal.write("用量监控 setup\n")
        let baseURL = prompt("Base URL", defaultValue: config.defaultBaseURL, terminal: terminal)
        let keyName = prompt("Key 名称", defaultValue: config.keys.first?.name ?? "Default", terminal: terminal)
        let apiKey = prompt("API Key", defaultValue: config.keys.first?.apiKey ?? "", terminal: terminal)
        let normalizedBaseURL = UsageKeyConfiguration.normalizedBaseURL(baseURL)
        guard !normalizedBaseURL.isEmpty, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            pause("Base URL 和 API Key 都不能为空，未保存配置。", terminal: terminal)
            return
        }

        config.defaultBaseURL = normalizedBaseURL
        config.keys = [
            UsageKeyConfiguration(
                id: config.keys.first?.id ?? UUID().uuidString,
                name: keyName.isEmpty ? "Default" : keyName,
                apiKey: apiKey,
                baseURLMode: .inherited,
                baseURLOverride: ""
            ),
        ]
        try store.save(config)
        pause("已保存到 \(store.url.path)", terminal: terminal)
    }

    private static func runConfig(
        config: inout CLIConfig,
        store: CLIConfigStore,
        terminal: InteractiveTerminal
    ) throws {
        while true {
            terminal.clearScreen()
            terminal.write(renderConfig(config: config, path: store.url.path))
            switch prompt("选择", terminal: terminal) {
            case "1":
                addKey(config: &config, terminal: terminal)
                try store.save(config)
            case "2":
                editKey(config: &config, terminal: terminal)
                try store.save(config)
            case "3":
                deleteKey(config: &config, terminal: terminal)
                try store.save(config)
            case "4":
                config.defaultBaseURL = UsageKeyConfiguration.normalizedBaseURL(
                    prompt("全局 Base URL", defaultValue: config.defaultBaseURL, terminal: terminal)
                )
                try store.save(config)
            case "5":
                let rawValue = prompt("刷新间隔秒数", defaultValue: "\(config.refreshIntervalSeconds)", terminal: terminal)
                if let value = Int(rawValue), value > 0 {
                    config.refreshIntervalSeconds = value
                    try store.save(config)
                } else {
                    pause("刷新间隔必须是正整数", terminal: terminal)
                }
            case "6":
                config.showColors.toggle()
                try store.save(config)
            case "7":
                updateTheme(config: &config, terminal: terminal)
                try store.save(config)
            case "8", "q", "Q", "":
                return
            default:
                pause("无效选择", terminal: terminal)
            }
        }
    }

    private static func renderConfig(config: CLIConfig, path: String) -> String {
        let rows = config.keys.enumerated().map { index, key in
            let baseURL = key.baseURLMode == .inherited
                ? "继承"
                : key.resolvedBaseURLText(defaultBaseURL: config.defaultBaseURL)
            return "\(index + 1). \(key.name)  id=\(key.id)  \(baseURL)"
        }.joined(separator: "\n")

        return """
        用量监控配置

        配置：\(path)
        全局 Base URL：\(display(config.defaultBaseURL))
        刷新间隔：\(config.refreshIntervalSeconds)s
        颜色：\(config.showColors ? "开启" : "关闭")
        主题：\(config.theme.rawValue)

        Keys
        \(rows.isEmpty ? "暂无 Key" : rows)

        1. 新增 Key
        2. 编辑 Key
        3. 删除 Key
        4. 修改全局 Base URL
        5. 修改刷新间隔
        6. 切换颜色
        7. 修改主题
        8. 返回/退出
        """
    }

    private static func addKey(config: inout CLIConfig, terminal: InteractiveTerminal) {
        let name = prompt("Key 名称", defaultValue: "Key \(config.keys.count + 1)", terminal: terminal)
        let apiKey = prompt("API Key", terminal: terminal)
        let independent = prompt("是否使用独立 Base URL? y/N", terminal: terminal)
        let baseURLMode: UsageKeyBaseURLMode = independent.lowercased() == "y" ? .independent : .inherited
        let override = baseURLMode == .independent
            ? prompt("独立 Base URL", terminal: terminal)
            : ""
        config.keys.append(
            UsageKeyConfiguration(
                name: name,
                apiKey: apiKey,
                baseURLMode: baseURLMode,
                baseURLOverride: override
            )
        )
    }

    private static func editKey(config: inout CLIConfig, terminal: InteractiveTerminal) {
        guard let index = keyIndex(config: config, terminal: terminal) else { return }
        var key = config.keys[index]
        key.name = prompt("Key 名称", defaultValue: key.name, terminal: terminal)
        key.apiKey = prompt("API Key", defaultValue: key.apiKey, terminal: terminal)
        let mode = prompt("Base URL 模式 inherited/independent", defaultValue: key.baseURLMode.rawValue, terminal: terminal)
        key.baseURLMode = mode == UsageKeyBaseURLMode.independent.rawValue ? .independent : .inherited
        key.baseURLOverride = key.baseURLMode == .independent
            ? prompt("独立 Base URL", defaultValue: key.baseURLOverride, terminal: terminal)
            : ""
        config.keys[index] = key
    }

    private static func deleteKey(config: inout CLIConfig, terminal: InteractiveTerminal) {
        guard config.keys.count > 1 else {
            pause("至少保留一个 Key", terminal: terminal)
            return
        }
        guard let index = keyIndex(config: config, terminal: terminal) else { return }
        let confirm = prompt("确认删除 \(config.keys[index].name)? y/N", terminal: terminal)
        if confirm.lowercased() == "y" {
            config.keys.remove(at: index)
        }
    }

    private static func updateTheme(config: inout CLIConfig, terminal: InteractiveTerminal) {
        let value = prompt(
            "主题 contrast/classic/mono/dracula/catppuccin/tokyonight/nord/gruvbox",
            defaultValue: config.theme.rawValue,
            terminal: terminal
        )
        guard let theme = CLITheme(rawValue: value) else {
            pause("主题必须是 contrast、classic、mono、dracula、catppuccin、tokyonight、nord 或 gruvbox", terminal: terminal)
            return
        }
        config.theme = theme
    }

    private static func keyIndex(config: CLIConfig, terminal: InteractiveTerminal) -> Int? {
        let value = prompt("Key 序号", terminal: terminal)
        guard let index = Int(value), config.keys.indices.contains(index - 1) else {
            pause("Key 序号无效", terminal: terminal)
            return nil
        }
        return index - 1
    }

    private static func prompt(
        _ label: String,
        defaultValue: String = "",
        terminal: InteractiveTerminal
    ) -> String {
        let suffix = defaultValue.isEmpty ? "" : " [\(defaultValue)]"
        terminal.write("\(label)\(suffix): ")
        let value = terminal.readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? defaultValue : value
    }

    private static func pause(_ message: String, terminal: InteractiveTerminal) {
        terminal.write("\n\(message)")
        terminal.write("按 Enter 继续...")
        _ = terminal.readLine()
    }

    private static func defaultConfig() -> CLIConfig {
        CLIConfig(
            defaultBaseURL: "",
            refreshIntervalSeconds: 60,
            showColors: true,
            keys: [UsageKeyConfiguration(name: "Default")]
        )
    }

    private static func needsSetup(_ config: CLIConfig) -> Bool {
        config.defaultBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || config.keys.allSatisfy { $0.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func display(_ value: String) -> String {
        value.isEmpty ? "--" : value
    }
}
