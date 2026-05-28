import Foundation

package enum UsageAlertEvaluator {
    package static let lowBalanceAlertThresholdUSD = 10.0
    package static let expiringSoonWindowDays = 7

    package static func thresholdAlertKinds(
        for snapshot: UsageResponse,
        now: Date = Date()
    ) -> [UsageThresholdAlertKind] {
        var kinds: [UsageThresholdAlertKind] = []

        if let percentage = UsageFormatters.percentage(
            used: snapshot.subscription.dailyUsageUSD,
            limit: snapshot.subscription.dailyLimitUSD
        ) {
            if percentage >= 0.95 {
                kinds.append(.dailyUsage95)
            } else if percentage >= 0.80 {
                kinds.append(.dailyUsage80)
            }
        }

        if snapshot.remaining <= lowBalanceAlertThresholdUSD {
            kinds.append(.lowBalance)
        }

        if let expiresAt = snapshot.subscription.expiresAt {
            if expiresAt <= now {
                kinds.append(.subscriptionExpired)
            } else if let soonThreshold = Calendar.current.date(
                byAdding: .day,
                value: expiringSoonWindowDays,
                to: now
            ), expiresAt <= soonThreshold {
                kinds.append(.subscriptionExpiringSoon)
            }
        }

        return kinds.sorted()
    }
}
