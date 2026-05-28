import Foundation

package struct DashboardSnapshot: Equatable {
    package let generatedAt: Date
    package let serviceRows: [DashboardServiceRow]
    package let usageRows: [DashboardUsageRow]

    package init(
        generatedAt: Date,
        serviceRows: [DashboardServiceRow],
        usageRows: [DashboardUsageRow]
    ) {
        self.generatedAt = generatedAt
        self.serviceRows = serviceRows
        self.usageRows = usageRows
    }

    package var healthSummaryText: String {
        let available = serviceRows.filter { $0.kind == .green || $0.kind == .yellow }.count
        return "\(available)/\(serviceRows.count) OK"
    }
}

package struct DashboardServiceRow: Equatable {
    package let model: String
    package let kind: ServiceStatusCellKind
    package let statusText: String
    package let uptimeText: String
    package let samplesText: String
    package let cells: [ServiceStatusDisplayCell]

    package init(
        model: String,
        kind: ServiceStatusCellKind,
        statusText: String,
        uptimeText: String = "--",
        samplesText: String = "0/0",
        cells: [ServiceStatusDisplayCell] = []
    ) {
        self.model = model
        self.kind = kind
        self.statusText = statusText
        self.uptimeText = uptimeText
        self.samplesText = samplesText
        self.cells = cells
    }
}

package struct DashboardUsageRow: Equatable {
    package let keyName: String
    package let dailyUsageUSD: Double
    package let dailyLimitUSD: Double
    package let dailyUsageText: String
    package let dailyLimitText: String
    package let dailyPercentageText: String
    package let balanceText: String
    package let planName: String
    package let expiryText: String
    package let expiryDate: Date?
    package let remainingDaysText: String
    package let weeklyUsageText: String
    package let monthlyUsageText: String
    package let todayBucketText: String
    package let totalBucketText: String
    package let tokenBreakdownText: String
    package let costBreakdownText: String
    package let rateText: String
    package let alerts: [UsageThresholdAlertKind]

    package init(
        keyName: String,
        dailyUsageUSD: Double = 0,
        dailyLimitUSD: Double = 0,
        dailyUsageText: String,
        dailyLimitText: String,
        dailyPercentageText: String,
        balanceText: String,
        planName: String,
        expiryText: String,
        expiryDate: Date? = nil,
        remainingDaysText: String = "--",
        weeklyUsageText: String = "",
        monthlyUsageText: String = "",
        todayBucketText: String = "",
        totalBucketText: String = "",
        tokenBreakdownText: String = "",
        costBreakdownText: String = "",
        rateText: String = "",
        alerts: [UsageThresholdAlertKind]
    ) {
        self.keyName = keyName
        self.dailyUsageUSD = dailyUsageUSD
        self.dailyLimitUSD = dailyLimitUSD
        self.dailyUsageText = dailyUsageText
        self.dailyLimitText = dailyLimitText
        self.dailyPercentageText = dailyPercentageText
        self.balanceText = balanceText
        self.planName = planName
        self.expiryText = expiryText
        self.expiryDate = expiryDate
        self.remainingDaysText = remainingDaysText
        self.weeklyUsageText = weeklyUsageText
        self.monthlyUsageText = monthlyUsageText
        self.todayBucketText = todayBucketText
        self.totalBucketText = totalBucketText
        self.tokenBreakdownText = tokenBreakdownText
        self.costBreakdownText = costBreakdownText
        self.rateText = rateText
        self.alerts = alerts
    }
}
