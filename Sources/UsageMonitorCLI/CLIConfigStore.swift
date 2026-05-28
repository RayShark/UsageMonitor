import Foundation
import UsageMonitorCore

struct CLIConfigStore {
    let url: URL
    private let fileManager: FileManager

    init(url: URL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
    }

    static func defaultConfigURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
        let home = environment["HOME"] ?? fileManager.homeDirectoryForCurrentUser.path
        return URL(fileURLWithPath: home)
            .appendingPathComponent(".config")
            .appendingPathComponent("usage-monitor")
            .appendingPathComponent("config.json")
    }

    static func `default`() -> CLIConfigStore {
        CLIConfigStore(url: defaultConfigURL())
    }

    func load() -> CLIConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? CLIConfig.decode(data: data)
    }

    func save(_ config: CLIConfig) throws {
        let normalized = normalize(config)
        let data = try JSONEncoder.sub2api.encode(normalized)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic])
    }

    private func normalize(_ config: CLIConfig) -> CLIConfig {
        CLIConfig(
            defaultBaseURL: UsageKeyConfiguration.normalizedBaseURL(config.defaultBaseURL),
            refreshIntervalSeconds: max(1, config.refreshIntervalSeconds),
            showColors: config.showColors,
            theme: config.theme,
            keys: config.keys.enumerated().map { index, key in key.normalized(index: index) }
        )
    }
}
