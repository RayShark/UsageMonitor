import XCTest
@testable import UsageMonitorCore

final class UsageAlertEvaluatorTests: XCTestCase {
    func testDailyUsageWarningAndLowBalanceAreReported() {
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(dailyUsageUSD: 8, dailyLimitUSD: 10, remaining: 8),
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(kinds, [.dailyUsage80, .lowBalance])
    }

    func testDailyUsageBelowEightyPercentDoesNotReportDailyAlert() {
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(dailyUsageUSD: 79.99, dailyLimitUSD: 100),
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertFalse(kinds.contains(.dailyUsage80))
        XCTAssertFalse(kinds.contains(.dailyUsage95))
    }

    func testDailyUsageAtEightyPercentReportsWarningAlert() {
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(dailyUsageUSD: 80, dailyLimitUSD: 100),
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(kinds, [.dailyUsage80])
    }

    func testDailyUsageBetweenEightyAndNinetyFivePercentReportsWarningAlert() {
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(dailyUsageUSD: 94.99, dailyLimitUSD: 100),
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(kinds, [.dailyUsage80])
    }

    func testDailyUsageAtNinetyFivePercentReportsDangerAlert() {
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(dailyUsageUSD: 95, dailyLimitUSD: 100),
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(kinds, [.dailyUsage95])
    }

    func testDailyUsageWithZeroLimitDoesNotReportDailyAlert() {
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(dailyUsageUSD: 100, dailyLimitUSD: 0),
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertFalse(kinds.contains(.dailyUsage80))
        XCTAssertFalse(kinds.contains(.dailyUsage95))
    }

    func testBalanceAtLowBalanceThresholdReportsLowBalanceAlert() {
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(remaining: 10),
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(kinds, [.lowBalance])
    }

    func testExpiryAtNowReportsExpiredAlert() {
        let now = Date(timeIntervalSince1970: 1_000)
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(expiresAt: now),
            now: now
        )

        XCTAssertEqual(kinds, [.subscriptionExpired])
    }

    func testExpiryAtSevenDayWindowReportsExpiringSoonAlert() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let expiresAt = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 7, to: now))
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(expiresAt: expiresAt),
            now: now
        )

        XCTAssertEqual(kinds, [.subscriptionExpiringSoon])
    }

    func testExpiryAfterSevenDayWindowDoesNotReportExpiryAlert() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let expiresAt = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 8, to: now))
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(expiresAt: expiresAt),
            now: now
        )

        XCTAssertFalse(kinds.contains(.subscriptionExpired))
        XCTAssertFalse(kinds.contains(.subscriptionExpiringSoon))
    }

    func testMultipleAlertsAreSortedByAlertKindSortOrder() {
        let now = Date(timeIntervalSince1970: 1_000)
        let kinds = UsageAlertEvaluator.thresholdAlertKinds(
            for: makeSnapshot(
                dailyUsageUSD: 95,
                dailyLimitUSD: 100,
                remaining: 10,
                expiresAt: now
            ),
            now: now
        )

        XCTAssertEqual(kinds, [.dailyUsage95, .subscriptionExpired, .lowBalance])
    }

    private func makeSnapshot(
        dailyUsageUSD: Double = 0,
        dailyLimitUSD: Double = 100,
        remaining: Double = 100,
        expiresAt: Date? = nil
    ) -> UsageResponse {
        UsageResponse(
            isValid: true,
            mode: "normal",
            modelStats: [],
            planName: "Pro",
            remaining: remaining,
            subscription: UsageSubscription(
                dailyUsageUSD: dailyUsageUSD,
                dailyLimitUSD: dailyLimitUSD,
                weeklyUsageUSD: 12,
                weeklyLimitUSD: 100,
                monthlyUsageUSD: 33,
                monthlyLimitUSD: 300,
                expiresAt: expiresAt
            ),
            unit: "usd",
            usage: UsageUsageSummary(
                today: UsageUsageBucket(
                    requestCount: 1,
                    inputTokens: 2,
                    outputTokens: 3,
                    totalTokens: 5,
                    inputCostUSD: 1,
                    outputCostUSD: 1,
                    totalCostUSD: 2
                ),
                total: UsageUsageBucket(
                    requestCount: 1,
                    inputTokens: 2,
                    outputTokens: 3,
                    totalTokens: 5,
                    inputCostUSD: 1,
                    outputCostUSD: 1,
                    totalCostUSD: 2
                ),
                averageDurationMS: 100,
                rpm: 1,
                tpm: 2
            )
        )
    }
}
