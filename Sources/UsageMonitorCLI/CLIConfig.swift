import Foundation
import UsageMonitorCore

struct CLIConfig: Codable, Equatable {
    var defaultBaseURL: String
    var refreshIntervalSeconds: Int
    var showColors: Bool
    var theme: CLITheme
    var keys: [UsageKeyConfiguration]

    init(
        defaultBaseURL: String,
        refreshIntervalSeconds: Int,
        showColors: Bool,
        theme: CLITheme = .contrast,
        keys: [UsageKeyConfiguration]
    ) {
        self.defaultBaseURL = defaultBaseURL
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.showColors = showColors
        self.theme = theme
        self.keys = keys
    }

    enum CodingKeys: String, CodingKey {
        case defaultBaseURL
        case refreshIntervalSeconds
        case showColors
        case theme
        case keys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultBaseURL = try container.decodeIfPresent(String.self, forKey: .defaultBaseURL) ?? ""
        refreshIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .refreshIntervalSeconds) ?? 60
        showColors = try container.decodeIfPresent(Bool.self, forKey: .showColors) ?? true
        theme = try container.decodeIfPresent(CLITheme.self, forKey: .theme) ?? .contrast
        keys = try container.decodeIfPresent([UsageKeyConfiguration].self, forKey: .keys) ?? []
    }

    static func resolve(
        arguments: CLIArguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileConfig: CLIConfig?
    ) throws -> CLIConfig {
        let defaultBaseURL = firstNonEmpty([
            arguments.baseURL,
            environment["USAGE_MONITOR_BASE_URL"],
            fileConfig?.defaultBaseURL,
        ]).map(UsageKeyConfiguration.normalizedBaseURL) ?? ""

        let overrideAPIKey = firstNonEmpty([
            arguments.apiKey,
            environment["USAGE_MONITOR_API_KEY"],
        ])

        let refreshIntervalSeconds = try resolvedRefreshIntervalSeconds(
            arguments: arguments,
            environment: environment,
            fileConfig: fileConfig
        )
        let showColors = resolvedShowColors(
            arguments: arguments,
            environment: environment,
            fileConfig: fileConfig
        )
        let theme = try resolvedTheme(
            arguments: arguments,
            environment: environment,
            fileConfig: fileConfig
        )
        let keys = resolvedKeys(
            arguments: arguments,
            fileConfig: fileConfig,
            overrideAPIKey: overrideAPIKey,
            overrideBaseURL: arguments.baseURL ?? environment["USAGE_MONITOR_BASE_URL"]
        )

        return CLIConfig(
            defaultBaseURL: defaultBaseURL,
            refreshIntervalSeconds: refreshIntervalSeconds,
            showColors: showColors,
            theme: theme,
            keys: keys
        )
    }

    func selectedKey(id: String?) throws -> UsageKeyConfiguration {
        let trimmedID = id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedID.isEmpty {
            if let key = keys.first(where: { $0.id == trimmedID || $0.name == trimmedID }) {
                return key
            }
            throw CLIConfigError.unknownKey(trimmedID)
        }

        guard let key = keys.first else {
            throw CLIConfigError.missingAPIKey
        }
        return key
    }

    func selectedUsageKeys(id: String?) throws -> [UsageKeyConfiguration] {
        let trimmedID = id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedID.isEmpty {
            let key = try selectedKey(id: trimmedID)
            guard !key.apiKey.isEmpty else { throw CLIConfigError.missingAPIKey }
            return [key]
        }

        let configuredKeys = keys.filter { !$0.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !configuredKeys.isEmpty else {
            throw CLIConfigError.missingAPIKey
        }
        return configuredKeys
    }

    func resolvedBaseURL(for key: UsageKeyConfiguration) throws -> URL {
        let baseURLText = key.resolvedBaseURLText(defaultBaseURL: defaultBaseURL)
        guard !baseURLText.isEmpty else { throw CLIConfigError.missingBaseURL }
        guard let url = URL(string: baseURLText) else { throw CLIConfigError.missingBaseURL }
        return url
    }

    static func decode(data: Data) throws -> CLIConfig {
        try JSONDecoder.sub2api.decode(CLIConfig.self, from: data)
    }

    static func loadDefaultFile(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> CLIConfig? {
        let home = environment["HOME"] ?? fileManager.homeDirectoryForCurrentUser.path
        let url = URL(fileURLWithPath: home)
            .appendingPathComponent(".config")
            .appendingPathComponent("usage-monitor")
            .appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decode(data: data)
    }

    private static func resolvedKeys(
        arguments: CLIArguments,
        fileConfig: CLIConfig?,
        overrideAPIKey: String?,
        overrideBaseURL: String?
    ) -> [UsageKeyConfiguration] {
        var keys = fileConfig?.keys.enumerated().map { index, key in key.normalized(index: index) } ?? [
            UsageKeyConfiguration(name: "Default"),
        ]
        guard !keys.isEmpty else {
            keys = [UsageKeyConfiguration(name: "Default")]
            return keys
        }

        guard overrideAPIKey != nil || firstNonEmpty([overrideBaseURL]) != nil else {
            return keys
        }

        let targetID = arguments.keyID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetIndex = keys.firstIndex {
            guard let targetID, !targetID.isEmpty else { return false }
            return $0.id == targetID || $0.name == targetID
        } ?? 0
        var selected = keys[targetIndex]
        if let overrideAPIKey {
            selected.apiKey = overrideAPIKey
        }
        if let overrideBaseURL = firstNonEmpty([overrideBaseURL]) {
            selected.baseURLMode = .independent
            selected.baseURLOverride = UsageKeyConfiguration.normalizedBaseURL(overrideBaseURL)
        }
        keys[targetIndex] = selected.normalized(index: targetIndex)
        return keys
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        values.lazy
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func resolvedRefreshIntervalSeconds(
        arguments: CLIArguments,
        environment: [String: String],
        fileConfig: CLIConfig?
    ) throws -> Int {
        if arguments.hasProvided(.interval) {
            return arguments.intervalSeconds
        }

        if let rawValue = firstNonEmpty([environment["USAGE_MONITOR_INTERVAL_SECONDS"]]) {
            guard let interval = Int(rawValue), interval > 0 else {
                throw CLIArgumentError.invalidValue("USAGE_MONITOR_INTERVAL_SECONDS")
            }
            return interval
        }

        return fileConfig?.refreshIntervalSeconds ?? arguments.intervalSeconds
    }

    private static func resolvedShowColors(
        arguments: CLIArguments,
        environment: [String: String],
        fileConfig: CLIConfig?
    ) -> Bool {
        if arguments.hasProvided(.noColor) {
            return !arguments.noColor
        }

        if let rawValue = firstNonEmpty([environment["USAGE_MONITOR_NO_COLOR"]]) {
            return !isTruthy(rawValue)
        }

        return fileConfig?.showColors ?? !arguments.noColor
    }

    private static func resolvedTheme(
        arguments: CLIArguments,
        environment: [String: String],
        fileConfig: CLIConfig?
    ) throws -> CLITheme {
        if let theme = arguments.theme {
            return theme
        }

        if let rawValue = firstNonEmpty([environment["USAGE_MONITOR_THEME"]]) {
            guard let theme = CLITheme(rawValue: rawValue) else {
                throw CLIArgumentError.invalidValue("USAGE_MONITOR_THEME")
            }
            return theme
        }

        return fileConfig?.theme ?? .contrast
    }

    private static func isTruthy(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        default:
            return false
        }
    }
}

enum CLIConfigError: Error, Equatable {
    case missingBaseURL
    case missingAPIKey
    case unknownKey(String)
}

extension CLIConfigError: CustomStringConvertible {
    var description: String {
        switch self {
        case .missingBaseURL:
            return "Base URL is required. Pass --base-url or set USAGE_MONITOR_BASE_URL."
        case .missingAPIKey:
            return "API Key is required. Pass --api-key or set USAGE_MONITOR_API_KEY."
        case let .unknownKey(key):
            return "Key not found: \(key). Run usage-monitor config to inspect configured keys."
        }
    }
}

extension CLIConfigError: LocalizedError {
    var errorDescription: String? {
        description
    }
}
