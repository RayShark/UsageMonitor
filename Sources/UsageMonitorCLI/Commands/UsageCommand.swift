import Foundation
import UsageMonitorCore

enum UsageCommand {
    static func makeUsageRow(
        keyName: String,
        response: UsageResponse,
        now: Date = Date()
    ) -> DashboardUsageRow {
        DashboardUsageRow(
            keyName: keyName,
            dailyUsageUSD: response.subscription.dailyUsageUSD,
            dailyLimitUSD: response.subscription.dailyLimitUSD,
            dailyUsageText: UsageFormatters.currency(response.subscription.dailyUsageUSD),
            dailyLimitText: UsageFormatters.currency(response.subscription.dailyLimitUSD),
            dailyPercentageText: UsageFormatters.percentageText(
                used: response.subscription.dailyUsageUSD,
                limit: response.subscription.dailyLimitUSD
            ),
            balanceText: UsageFormatters.balanceText(response.remaining),
            planName: response.planName,
            expiryText: UsageFormatters.expiryText(response.subscription.expiresAt, now: now),
            expiryDate: response.subscription.expiresAt,
            remainingDaysText: UsageFormatters.remainingDaysText(response.subscription.expiresAt, now: now),
            weeklyUsageText: UsageFormatters.usageLimitText(
                used: response.subscription.weeklyUsageUSD,
                limit: response.subscription.weeklyLimitUSD
            ),
            monthlyUsageText: UsageFormatters.usageLimitText(
                used: response.subscription.monthlyUsageUSD,
                limit: response.subscription.monthlyLimitUSD
            ),
            todayBucketText: UsageFormatters.bucketText(response.usage.today),
            totalBucketText: UsageFormatters.bucketText(response.usage.total),
            tokenBreakdownText: UsageFormatters.tokenBreakdownText(
                input: response.usage.today.inputTokens,
                output: response.usage.today.outputTokens
            ),
            costBreakdownText: UsageFormatters.costBreakdownText(
                input: response.usage.today.inputCostUSD,
                output: response.usage.today.outputCostUSD
            ),
            rateText: UsageFormatters.rateText(rpm: response.usage.rpm, tpm: response.usage.tpm),
            alerts: UsageAlertEvaluator.thresholdAlertKinds(for: response, now: now)
        )
    }

    static func run(
        config: CLIConfig,
        json: Bool,
        keyID: String? = nil,
        output: CLIOutput = .standard,
        client: Sub2APIClient = Sub2APIClient()
    ) async throws {
        let key = try config.selectedKey(id: keyID)
        guard !key.apiKey.isEmpty else { throw CLIConfigError.missingAPIKey }
        let url = try config.resolvedBaseURL(for: key)

        let response = try await client.usage(baseURL: url, apiKey: key.apiKey)
        if json {
            let data = try JSONEncoder.sub2api.encode(response)
            output.write(String(data: data, encoding: .utf8) ?? "{}")
            return
        }

        let row = makeUsageRow(keyName: key.name, response: response)
        output.write(
            "\(row.keyName)  今日 \(row.dailyUsageText) / \(row.dailyLimitText)  \(row.dailyPercentageText)  余额 \(row.balanceText)  \(row.planName)  到期 \(row.expiryText)"
        )
    }
}
