import XCTest
import UsageMonitorCore
@testable import UsageMonitorCLI

final class UsageCommandTests: XCTestCase {
    func testBuildUsageRowFormatsCoreSnapshot() {
        let response = UsageResponse(
            isValid: true,
            mode: "normal",
            modelStats: [],
            planName: "Pro",
            remaining: 42.12,
            subscription: UsageSubscription(
                dailyUsageUSD: 3.24,
                dailyLimitUSD: 10,
                weeklyUsageUSD: 12,
                weeklyLimitUSD: 100,
                monthlyUsageUSD: 33,
                monthlyLimitUSD: 300,
                expiresAt: Date(timeIntervalSince1970: 1_780_000_000)
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

        let row = UsageCommand.makeUsageRow(
            keyName: "Key 1",
            response: response,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(row.keyName, "Key 1")
        XCTAssertEqual(row.dailyUsageText, "$3.24")
        XCTAssertEqual(row.dailyLimitText, "$10.00")
        XCTAssertEqual(row.dailyPercentageText, "32.4%")
        XCTAssertEqual(row.balanceText, "$42.12")
        XCTAssertEqual(row.planName, "Pro")
    }
}
