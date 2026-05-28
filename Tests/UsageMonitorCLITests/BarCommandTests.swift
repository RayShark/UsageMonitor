import XCTest
import UsageMonitorCore
@testable import UsageMonitorCLI

final class BarCommandTests: XCTestCase {
    func testMakeDashboardCombinesStatusAndMultipleUsageRows() {
        let status = ServiceStatusResponse(
            allOK: true,
            generatedAt: 100,
            services: [
                ServiceStatusService(
                    model: "gpt-5.5",
                    uptimePct: 100,
                    last: ServiceStatusProbe(ts: 100, ok: true, latencyMS: 100, error: nil),
                    history: []
                ),
            ]
        )
        let snapshot = BarCommand.makeDashboardSnapshot(
            statusResponse: status,
            usageResponses: [
                KeyedUsageResponse(keyName: "Key 1", response: Self.usage(daily: 3.24, limit: 10, remaining: 42.12)),
                KeyedUsageResponse(keyName: "Key 2", response: Self.usage(daily: 2.76, limit: 10, remaining: 51)),
            ],
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(snapshot.serviceRows.first?.statusText, "在线")
        XCTAssertEqual(snapshot.usageRows.map(\.keyName), ["Key 1", "Key 2"])
        XCTAssertEqual(snapshot.usageRows.map(\.dailyUsageText), ["$3.24", "$2.76"])
    }

    func testDefaultBarKeysIncludeAllConfiguredKeys() throws {
        let config = CLIConfig(
            defaultBaseURL: "https://file.example.com",
            refreshIntervalSeconds: 5,
            showColors: true,
            keys: [
                UsageKeyConfiguration(id: "main", name: "Key 1", apiKey: "main-key"),
                UsageKeyConfiguration(id: "backup", name: "Key 2", apiKey: "backup-key"),
            ]
        )

        let keys = try BarCommand.configuredUsageKeys(argumentsKeyID: nil, config: config)

        XCTAssertEqual(keys.map(\.name), ["Key 1", "Key 2"])
    }

    func testSelectedBarKeyLimitsToOneConfiguredKey() throws {
        let config = CLIConfig(
            defaultBaseURL: "https://file.example.com",
            refreshIntervalSeconds: 5,
            showColors: true,
            keys: [
                UsageKeyConfiguration(id: "main", name: "Key 1", apiKey: "main-key"),
                UsageKeyConfiguration(id: "backup", name: "Key 2", apiKey: "backup-key"),
            ]
        )

        let keys = try BarCommand.configuredUsageKeys(argumentsKeyID: "backup", config: config)

        XCTAssertEqual(keys.map(\.name), ["Key 2"])
    }

    func testKeyboardActionsSwitchModeAndCycleTheme() {
        var state = BarRuntimeState(mode: .lite, theme: .contrast)

        XCTAssertEqual(BarKeyboardAction.parse(byte: UInt8(ascii: "o")), .mode(.oneline))
        XCTAssertEqual(BarKeyboardAction.parse(byte: UInt8(ascii: "d")), .mode(.detail))
        XCTAssertEqual(BarKeyboardAction.parse(byte: UInt8(ascii: "l")), .mode(.lite))
        XCTAssertEqual(BarKeyboardAction.parse(byte: UInt8(ascii: "c")), .nextTheme)
        XCTAssertNil(BarKeyboardAction.parse(byte: UInt8(ascii: "x")))

        state.apply(.mode(.oneline))
        XCTAssertEqual(state.mode, .oneline)
        XCTAssertEqual(state.theme, .contrast)

        state.apply(.mode(.detail))
        XCTAssertEqual(state.mode, .detail)

        state.apply(.nextTheme)
        XCTAssertEqual(state.theme, .classic)
        state.apply(.nextTheme)
        XCTAssertEqual(state.theme, .mono)
    }

    private static func usage(daily: Double, limit: Double, remaining: Double) -> UsageResponse {
        UsageResponse(
            isValid: true,
            mode: "normal",
            modelStats: [],
            planName: "Pro",
            remaining: remaining,
            subscription: UsageSubscription(
                dailyUsageUSD: daily,
                dailyLimitUSD: limit,
                weeklyUsageUSD: 0,
                weeklyLimitUSD: 100,
                monthlyUsageUSD: 0,
                monthlyLimitUSD: 300,
                expiresAt: nil
            ),
            unit: "usd",
            usage: UsageUsageSummary(
                today: UsageUsageBucket(
                    requestCount: 0,
                    inputTokens: 0,
                    outputTokens: 0,
                    totalTokens: 0,
                    inputCostUSD: 0,
                    outputCostUSD: 0,
                    totalCostUSD: 0
                ),
                total: UsageUsageBucket(
                    requestCount: 0,
                    inputTokens: 0,
                    outputTokens: 0,
                    totalTokens: 0,
                    inputCostUSD: 0,
                    outputCostUSD: 0,
                    totalCostUSD: 0
                ),
                averageDurationMS: 0,
                rpm: 0,
                tpm: 0
            )
        )
    }
}
