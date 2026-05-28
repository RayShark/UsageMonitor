import XCTest
@testable import UsageMonitorCore

final class UsageFormattersTests: XCTestCase {
    func testCurrencyFormattingAlwaysKeepsTwoDecimals() {
        XCTAssertEqual(UsageFormatters.currency(84.04), "$84.04")
        XCTAssertEqual(UsageFormatters.currency(5), "$5.00")
        XCTAssertEqual(UsageFormatters.currency(0.5), "$0.50")
    }

    func testMenuBarDailyUsageUsesOnlyUsageValue() {
        XCTAssertEqual(
            UsageFormatters.menuBarDailyUsageText(84.04, showDecimals: true),
            "$84.04"
        )
        XCTAssertEqual(
            UsageFormatters.menuBarDailyUsageText(84.99, showDecimals: false),
            "$84"
        )
        XCTAssertEqual(
            UsageFormatters.menuBarDailyUsageText(84.99, showDecimals: true),
            "$84.99"
        )
    }

    func testBalanceFormattingUsesRemainingValue() {
        XCTAssertEqual(UsageFormatters.balanceText(415.96), "$415.96")
    }

    func testUsageLimitFormattingHandlesUnlimitedLimits() {
        XCTAssertEqual(
            UsageFormatters.usageLimitText(used: 84.04, limit: 500),
            "$84.04 / $500.00"
        )
        XCTAssertEqual(
            UsageFormatters.usageLimitText(used: 84.04, limit: 0),
            "$84.04 / ∞"
        )
    }

    func testHealthThresholdsMapAtEightyAndNinetyFivePercent() {
        XCTAssertEqual(UsageFormatters.healthState(used: 79.99, limit: 100), .normal)
        XCTAssertEqual(UsageFormatters.healthState(used: 80, limit: 100), .warning)
        XCTAssertEqual(UsageFormatters.healthState(used: 94.99, limit: 100), .warning)
        XCTAssertEqual(UsageFormatters.healthState(used: 95, limit: 100), .danger)
        XCTAssertEqual(UsageFormatters.healthState(used: 95, limit: 0), .normal)
    }

    func testRemainingDaysTextUsesRelativeDayCount() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let expiry = Date(timeIntervalSince1970: 1_700_172_800)

        XCTAssertEqual(UsageFormatters.remainingDaysText(expiry, now: now), "2天")
        XCTAssertEqual(UsageFormatters.remainingDaysText(nil, now: now), "--")
        XCTAssertEqual(UsageFormatters.remainingDaysText(Date(timeIntervalSince1970: 100), now: now), "已过期")
    }

    func testUsageBucketTextShowsRequestsTokensAndCost() {
        let bucket = UsageUsageBucket(
            requestCount: 12,
            inputTokens: 1000,
            outputTokens: 2000,
            totalTokens: 3000,
            inputCostUSD: 0.45,
            outputCostUSD: 0.78,
            totalCostUSD: 1.23
        )

        XCTAssertEqual(
            UsageFormatters.bucketText(bucket),
            "12 次 · 3,000 tokens · $1.23"
        )
    }
}
