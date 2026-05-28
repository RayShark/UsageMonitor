import Foundation
import Crypto

package enum UsageKeyBaseURLMode: String, Codable, CaseIterable, Equatable {
    case inherited
    case independent

    package var displayName: String {
        switch self {
        case .inherited:
            return "继承全局 Base URL"
        case .independent:
            return "独立 Base URL"
        }
    }
}

package struct UsageKeyConfiguration: Codable, Equatable, Identifiable {
    package static let defaultSymbolName = "key.fill"
    package static let defaultSymbolColorHex = "#FFFFFF"

    package let id: String
    package var name: String
    package var symbolName: String
    package var symbolColorHex: String
    package var showsInMenuBar: Bool
    package var apiKey: String
    package var baseURLMode: UsageKeyBaseURLMode
    package var baseURLOverride: String

    package init(
        id: String = UUID().uuidString,
        name: String,
        symbolName: String = Self.defaultSymbolName,
        symbolColorHex: String = Self.defaultSymbolColorHex,
        showsInMenuBar: Bool = true,
        apiKey: String = "",
        baseURLMode: UsageKeyBaseURLMode = .inherited,
        baseURLOverride: String = ""
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.symbolColorHex = Self.normalizedSymbolColorHex(symbolColorHex)
        self.showsInMenuBar = showsInMenuBar
        self.apiKey = apiKey
        self.baseURLMode = baseURLMode
        self.baseURLOverride = baseURLOverride
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbolName
        case symbolColorHex
        case showsInMenuBar
        case apiKey
        case baseURLMode
        case baseURLOverride
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName) ?? Self.defaultSymbolName
        let decodedSymbolColorHex = try container.decodeIfPresent(String.self, forKey: .symbolColorHex)
            ?? Self.defaultSymbolColorHex
        symbolColorHex = Self.normalizedSymbolColorHex(decodedSymbolColorHex)
        showsInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showsInMenuBar) ?? true
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        baseURLMode = try container.decodeIfPresent(UsageKeyBaseURLMode.self, forKey: .baseURLMode) ?? .inherited
        baseURLOverride = try container.decodeIfPresent(String.self, forKey: .baseURLOverride) ?? ""
    }

    package func normalized(index: Int) -> UsageKeyConfiguration {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSymbol = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedOverride = baseURLMode == .independent
            ? Self.normalizedBaseURL(baseURLOverride)
            : ""
        return UsageKeyConfiguration(
            id: id,
            name: trimmedName.isEmpty ? "Key \(index + 1)" : trimmedName,
            symbolName: trimmedSymbol.isEmpty ? Self.defaultSymbolName : trimmedSymbol,
            symbolColorHex: Self.normalizedSymbolColorHex(symbolColorHex),
            showsInMenuBar: showsInMenuBar,
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURLMode: baseURLMode,
            baseURLOverride: normalizedOverride
        )
    }

    package func resolvedBaseURLText(defaultBaseURL: String) -> String {
        switch baseURLMode {
        case .inherited:
            return Self.normalizedBaseURL(defaultBaseURL)
        case .independent:
            return Self.normalizedBaseURL(baseURLOverride)
        }
    }

    package static func normalizedBaseURL(_ value: String) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    package static func normalizedSymbolColorHex(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard hex.count == 6, hex.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return defaultSymbolColorHex
        }
        return "#\(hex)"
    }
}

package struct UsageKeyEntry: Equatable, Identifiable {
    package var configuration: UsageKeyConfiguration
    package var snapshot: UsageResponse?
    package var lastSuccessfulRefresh: Date?
    package var lastError: String?
    package var lastFailureKind: UsageRefreshFailureKind?
    package var isRefreshing: Bool
    package var authState: UsageAuthState
    package var snapshotFreshness: UsageSnapshotFreshness
    package var thresholdAlertState: UsageThresholdAlertState?

    package init(
        configuration: UsageKeyConfiguration,
        snapshot: UsageResponse? = nil,
        lastSuccessfulRefresh: Date? = nil,
        lastError: String? = nil,
        lastFailureKind: UsageRefreshFailureKind? = nil,
        isRefreshing: Bool = false,
        authState: UsageAuthState = .notConfigured,
        snapshotFreshness: UsageSnapshotFreshness = .empty,
        thresholdAlertState: UsageThresholdAlertState? = nil
    ) {
        self.configuration = configuration
        self.snapshot = snapshot
        self.lastSuccessfulRefresh = lastSuccessfulRefresh
        self.lastError = lastError
        self.lastFailureKind = lastFailureKind
        self.isRefreshing = isRefreshing
        self.authState = authState
        self.snapshotFreshness = snapshotFreshness
        self.thresholdAlertState = thresholdAlertState
    }

    package var id: String {
        configuration.id
    }

    package var canShowSnapshotData: Bool {
        snapshot != nil && snapshotFreshness != .configurationMismatch
    }
}

package enum UsageAuthState: Equatable {
    case notConfigured
    case ready
    case authenticated
    case unauthorized
    case error
}

package struct UsageConfigurationFingerprint: Codable, Equatable {
    package let normalizedBaseURL: String
    package let apiKeyFingerprint: String

    package init(normalizedBaseURL: String, apiKeyFingerprint: String) {
        self.normalizedBaseURL = normalizedBaseURL
        self.apiKeyFingerprint = apiKeyFingerprint
    }

    package static func make(baseURLText: String, apiKey: String) -> UsageConfigurationFingerprint? {
        let normalizedBaseURL = UsageKeyConfiguration.normalizedBaseURL(baseURLText)
        guard
            !normalizedBaseURL.isEmpty,
            isValidBaseURL(normalizedBaseURL),
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return UsageConfigurationFingerprint(
            normalizedBaseURL: normalizedBaseURL,
            apiKeyFingerprint: fingerprint(for: apiKey)
        )
    }

    package static func isValidBaseURL(_ value: String) -> Bool {
        guard
            let url = URL(string: value),
            let scheme = url.scheme?.lowercased(),
            (scheme == "http" || scheme == "https"),
            url.host != nil
        else {
            return false
        }
        return true
    }

    private static func fingerprint(for apiKey: String) -> String {
        let digest = SHA256.hash(data: Data(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

package enum UsageSnapshotFreshness: Equatable {
    case fresh
    case stale
    case configurationMismatch
    case empty
}

package enum UsageRefreshFailureKind: Equatable {
    case unauthorized
    case network
    case server
    case decoding
    case invalidResponse
    case validation
    case unknown

    package var preservesMatchingCache: Bool {
        switch self {
        case .validation:
            return false
        case .unauthorized, .network, .server, .decoding, .invalidResponse, .unknown:
            return true
        }
    }

    package var stateTextWhenCached: String {
        switch self {
        case .unauthorized:
            return "认证失败，缓存已过期"
        case .network:
            return "网络失败，缓存已过期"
        case .server:
            return "服务端失败，缓存已过期"
        case .decoding:
            return "响应异常，缓存已过期"
        case .invalidResponse:
            return "无效响应，缓存已过期"
        case .validation, .unknown:
            return "缓存已过期"
        }
    }

    package var stateTextWithoutCache: String {
        switch self {
        case .unauthorized:
            return "未授权"
        case .network, .server, .decoding, .invalidResponse, .unknown:
            return "刷新失败"
        case .validation:
            return "未配置"
        }
    }
}

package enum UsageThresholdAlertKind: String, Codable, CaseIterable, Comparable {
    case dailyUsage80
    case dailyUsage95
    case lowBalance
    case subscriptionExpired
    case subscriptionExpiringSoon

    package var sortOrder: Int {
        switch self {
        case .dailyUsage95:
            return 0
        case .dailyUsage80:
            return 1
        case .subscriptionExpired:
            return 2
        case .subscriptionExpiringSoon:
            return 3
        case .lowBalance:
            return 4
        }
    }

    package var message: String {
        switch self {
        case .dailyUsage80:
            return "今日用量已达 80%"
        case .dailyUsage95:
            return "今日用量已达 95%"
        case .lowBalance:
            return "剩余余额偏低"
        case .subscriptionExpired:
            return "订阅已过期"
        case .subscriptionExpiringSoon:
            return "订阅即将到期"
        }
    }

    package static func < (lhs: UsageThresholdAlertKind, rhs: UsageThresholdAlertKind) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

package struct UsageThresholdAlertState: Equatable {
    package let kinds: [UsageThresholdAlertKind]
    package let isNew: Bool

    package init(kinds: [UsageThresholdAlertKind], isNew: Bool) {
        self.kinds = kinds
        self.isNew = isNew
    }

    package var primaryMessage: String? {
        kinds.first?.message
    }

    package var messages: [String] {
        kinds.map(\.message)
    }
}

package struct UsageSnapshotCacheEntry: Codable, Equatable {
    package let configurationFingerprint: UsageConfigurationFingerprint
    package let savedAt: Date
    package let lastSuccessfulRefreshAt: Date
    package let snapshot: UsageResponse

    package init(
        configurationFingerprint: UsageConfigurationFingerprint,
        savedAt: Date,
        lastSuccessfulRefreshAt: Date,
        snapshot: UsageResponse
    ) {
        self.configurationFingerprint = configurationFingerprint
        self.savedAt = savedAt
        self.lastSuccessfulRefreshAt = lastSuccessfulRefreshAt
        self.snapshot = snapshot
    }
}

struct KeyedUsageSnapshotCacheEntry: Codable, Equatable {
    let keyID: String
    let configurationFingerprint: UsageConfigurationFingerprint
    let savedAt: Date
    let lastSuccessfulRefreshAt: Date
    let snapshot: UsageResponse

    var legacyEntry: UsageSnapshotCacheEntry {
        UsageSnapshotCacheEntry(
            configurationFingerprint: configurationFingerprint,
            savedAt: savedAt,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt,
            snapshot: snapshot
        )
    }
}

package final class UsageSnapshotCacheStore {
    private let userDefaults: UserDefaults
    private let key: String

    package init(userDefaults: UserDefaults, key: String) {
        self.userDefaults = userDefaults
        self.key = key
    }

    package func loadLegacyEntry() -> UsageSnapshotCacheEntry? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder.sub2api.decode(UsageSnapshotCacheEntry.self, from: data)
    }

    package func loadKeyedEntries() -> [String: UsageSnapshotCacheEntry] {
        guard let data = userDefaults.data(forKey: key) else { return [:] }
        if let keyedEntries = try? JSONDecoder.sub2api.decode([KeyedUsageSnapshotCacheEntry].self, from: data) {
            return Dictionary(uniqueKeysWithValues: keyedEntries.map { ($0.keyID, $0.legacyEntry) })
        }
        return [:]
    }

    package func save(_ entry: UsageSnapshotCacheEntry, for keyID: String) {
        var entries = loadKeyedEntries()
        entries[keyID] = entry
        let keyedEntries = entries.map { keyID, entry in
            KeyedUsageSnapshotCacheEntry(
                keyID: keyID,
                configurationFingerprint: entry.configurationFingerprint,
                savedAt: entry.savedAt,
                lastSuccessfulRefreshAt: entry.lastSuccessfulRefreshAt,
                snapshot: entry.snapshot
            )
        }
        guard let data = try? JSONEncoder.sub2api.encode(keyedEntries) else { return }
        userDefaults.set(data, forKey: key)
    }
}
