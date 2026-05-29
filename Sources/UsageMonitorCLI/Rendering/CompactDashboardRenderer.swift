import Foundation
import UsageMonitorCore

enum CompactDashboardRenderer {
    static func render(
        _ snapshot: DashboardSnapshot,
        mode: BarMode,
        theme: CLITheme,
        colorEnabled: Bool,
        intervalSeconds: Int,
        now: Date
    ) -> String {
        switch mode {
        case .oneline:
            return renderOneline(
                snapshot,
                theme: theme,
                colorEnabled: colorEnabled,
                intervalSeconds: intervalSeconds,
                now: now
            )
        case .lite, .detail:
            let usageLines = renderUsageLines(
                snapshot,
                theme: theme,
                colorEnabled: colorEnabled,
                intervalSeconds: intervalSeconds,
                now: now
            )
            let healthLine = renderHealthLine(snapshot, theme: theme, colorEnabled: colorEnabled)

            if mode == .lite {
                return (usageLines + [healthLine]).joined(separator: "\n")
            }

            let statusPanel = renderStatusPanel(snapshot, theme: theme, colorEnabled: colorEnabled)
            let usagePanel = renderUsagePanel(snapshot, theme: theme, colorEnabled: colorEnabled)
            return (usageLines + [
                healthLine,
                statusPanel,
                usagePanel,
            ]).joined(separator: "\n")
        }
    }

    static func renderStatus(
        _ snapshot: DashboardSnapshot,
        colorEnabled: Bool,
        theme: CLITheme = .contrast,
        now: Date
    ) -> String {
        [
            renderHealthLine(snapshot, theme: theme, colorEnabled: colorEnabled),
            renderStatusPanel(snapshot, theme: theme, colorEnabled: colorEnabled),
            "刷新 \(timeText(now))",
        ].joined(separator: "\n")
    }

    private static func renderOneline(
        _ snapshot: DashboardSnapshot,
        theme: CLITheme,
        colorEnabled: Bool,
        intervalSeconds: Int,
        now: Date
    ) -> String {
        [
            renderTotalQuotaSummary(snapshot, theme: theme, colorEnabled: colorEnabled),
            renderOnelineHealth(snapshot, theme: theme, colorEnabled: colorEnabled),
            refreshText(now: now, intervalSeconds: intervalSeconds),
        ].joined(separator: "  ")
    }

    private static func renderOnelineHealth(
        _ snapshot: DashboardSnapshot,
        theme: CLITheme,
        colorEnabled: Bool
    ) -> String {
        guard let row = snapshot.serviceRows.first(where: { $0.model == ServiceStatusConfiguration.targetModel })
                ?? snapshot.serviceRows.first else {
            return "渠道健康 \(snapshot.healthSummaryText)"
        }

        return "渠道健康 \(snapshot.healthSummaryText)  \(row.model) \(renderBattery(row.cells, theme: theme, colorEnabled: colorEnabled)) \(firstTokenLatencyText(row))"
    }

    private static func renderTotalQuotaSummary(
        _ snapshot: DashboardSnapshot,
        theme: CLITheme,
        colorEnabled: Bool
    ) -> String {
        guard !snapshot.usageRows.isEmpty else {
            return "总额度  \(renderProgressBar(used: 0, limit: 1, theme: theme, colorEnabled: colorEnabled))  --  未配置 Key"
        }

        let totalUsage = snapshot.usageRows.reduce(0) { $0 + $1.dailyUsageUSD }
        let totalLimit = snapshot.usageRows.reduce(0) { $0 + max(0, $1.dailyLimitUSD) }
        return [
            "\(padEnd("总额度", toDisplayWidth: 8))\(renderProgressBar(used: totalUsage, limit: totalLimit, theme: theme, colorEnabled: colorEnabled))",
            UsageFormatters.percentageText(used: totalUsage, limit: totalLimit),
            renderTotalUsage(snapshot.usageRows),
        ].joined(separator: "  ")
    }

    private static func renderHealthLine(
        _ snapshot: DashboardSnapshot,
        theme: CLITheme,
        colorEnabled: Bool
    ) -> String {
        let services = snapshot.serviceRows
            .map { row in
                "\(row.model) \(renderBattery(row.cells, theme: theme, colorEnabled: colorEnabled)) \(row.statusText) \(firstTokenLatencyText(row))"
            }
            .joined(separator: "  ")

        if services.isEmpty {
            return "渠道健康 \(snapshot.healthSummaryText)"
        }
        return "渠道健康 \(snapshot.healthSummaryText)  \(services)"
    }

    private static func renderStatusPanel(
        _ snapshot: DashboardSnapshot,
        theme: CLITheme,
        colorEnabled: Bool
    ) -> String {
        guard !snapshot.serviceRows.isEmpty else {
            return "服务状态\n  暂无服务状态"
        }

        let modelWidth = max(12, snapshot.serviceRows.map { displayWidth($0.model) }.max() ?? 12)
        let statusWidth = max(8, snapshot.serviceRows.map { displayWidth($0.statusText) }.max() ?? 8)
        let uptimeWidth = max(7, snapshot.serviceRows.map { displayWidth($0.uptimeText) }.max() ?? 7)
        let samplesWidth = max(5, snapshot.serviceRows.map { displayWidth($0.samplesText) }.max() ?? 5)
        let firstTokenWidth = max(8, snapshot.serviceRows.map { displayWidth(firstTokenLatencyText($0)) }.max() ?? 8)

        let rows = snapshot.serviceRows.map { row in
            let model = padEnd(row.model, toDisplayWidth: modelWidth)
            let status = padEnd(row.statusText, toDisplayWidth: statusWidth)
            let uptime = padEnd(row.uptimeText, toDisplayWidth: uptimeWidth)
            let samples = padEnd(row.samplesText, toDisplayWidth: samplesWidth)
            let firstToken = padEnd(firstTokenLatencyText(row), toDisplayWidth: firstTokenWidth)
            return "│ \(model)  \(status)  可用率 \(uptime)  样本 \(samples)  \(renderBattery(row.cells, theme: theme, colorEnabled: colorEnabled))  \(firstToken)"
        }

        return (["╭─ 服务状态"] + rows + ["╰─"]).joined(separator: "\n")
    }

    private static func renderUsagePanel(
        _ snapshot: DashboardSnapshot,
        theme: CLITheme,
        colorEnabled: Bool
    ) -> String {
        guard !snapshot.usageRows.isEmpty else {
            return "用量详情\n  未配置 Key  无套餐数据"
        }

        let layout = UsagePanelLayout(rows: snapshot.usageRows)
        let rows = snapshot.usageRows.flatMap { row -> [String] in
            let key = padEnd(row.keyName, toDisplayWidth: layout.keyWidth)
            let blankKey = String(repeating: " ", count: layout.keyWidth)
            let usageText = padEnd("\(row.dailyUsageText) / \(row.dailyLimitText)", toDisplayWidth: layout.usageWidth)
            let percentageText = padEnd(row.dailyPercentageText, toDisplayWidth: layout.percentageWidth)
            let usageBlock = "\(usageText)  \(percentageText)"
            let coloredUsageBlock = colorEnabled ? theme.color(usageBlock, for: usageKind(for: row)) : usageBlock
            let balance = padEnd(row.balanceText, toDisplayWidth: layout.balanceWidth)
            let planName = padEnd(row.planName, toDisplayWidth: layout.planWidth)
            let weekly = padEnd(row.weeklyUsageText, toDisplayWidth: layout.weeklyWidth)
            let todayBucket = padEnd(row.todayBucketText, toDisplayWidth: layout.todayBucketWidth)
            let totalBucket = padEnd(row.totalBucketText, toDisplayWidth: layout.totalBucketWidth)
            let tokenBreakdown = padEnd(row.tokenBreakdownText, toDisplayWidth: layout.tokenBreakdownWidth)
            return [
                "│ \(key)  今日 \(coloredUsageBlock)  余额 \(balance)  剩余 \(row.remainingDaysText)",
                "│ \(blankKey)  订阅 \(planName)  周 \(weekly)  月 \(row.monthlyUsageText)",
                "│ \(blankKey)  今日统计 \(todayBucket)  总计 \(totalBucket)  \(row.rateText)",
                "│ \(blankKey)  Token \(tokenBreakdown)  费用 \(row.costBreakdownText)",
            ]
        }
        return (["╭─ 用量详情"] + rows + ["╰─"]).joined(separator: "\n")
    }

    private struct UsagePanelLayout {
        let keyWidth: Int
        let usageWidth: Int
        let percentageWidth: Int
        let balanceWidth: Int
        let planWidth: Int
        let weeklyWidth: Int
        let todayBucketWidth: Int
        let totalBucketWidth: Int
        let tokenBreakdownWidth: Int

        init(rows: [DashboardUsageRow]) {
            keyWidth = max(8, rows.map { displayWidth($0.keyName) }.max() ?? 8)
            usageWidth = rows
                .map { displayWidth("\($0.dailyUsageText) / \($0.dailyLimitText)") }
                .max() ?? 0
            percentageWidth = rows.map { displayWidth($0.dailyPercentageText) }.max() ?? 0
            balanceWidth = rows.map { displayWidth($0.balanceText) }.max() ?? 0
            planWidth = rows.map { displayWidth($0.planName) }.max() ?? 0
            weeklyWidth = rows.map { displayWidth($0.weeklyUsageText) }.max() ?? 0
            todayBucketWidth = rows.map { displayWidth($0.todayBucketText) }.max() ?? 0
            totalBucketWidth = rows.map { displayWidth($0.totalBucketText) }.max() ?? 0
            tokenBreakdownWidth = rows.map { displayWidth($0.tokenBreakdownText) }.max() ?? 0
        }
    }

    private static func renderUsageLines(
        _ snapshot: DashboardSnapshot,
        theme: CLITheme,
        colorEnabled: Bool,
        intervalSeconds: Int,
        now: Date
    ) -> [String] {
        guard !snapshot.usageRows.isEmpty else {
            return ["总额度  \(renderProgressBar(used: 0, limit: 1, theme: theme, colorEnabled: colorEnabled))  --  未配置 Key  剩余 --  \(refreshText(now: now, intervalSeconds: intervalSeconds))"]
        }

        let totalUsage = snapshot.usageRows.reduce(0) { $0 + $1.dailyUsageUSD }
        let totalLimit = snapshot.usageRows.reduce(0) { $0 + max(0, $1.dailyLimitUSD) }
        let totalItem = QuotaLineItem(
            label: "总额度",
            used: totalUsage,
            limit: totalLimit,
            usageText: renderTotalUsage(snapshot.usageRows),
            percentageText: UsageFormatters.percentageText(used: totalUsage, limit: totalLimit),
            trailingLabel: "剩余",
            trailingValue: "\(remainingDaysText(snapshot.usageRows, now: now))  \(refreshText(now: now, intervalSeconds: intervalSeconds))"
        )

        let keyItems = snapshot.usageRows.map { row in
            QuotaLineItem(
                label: row.keyName,
                used: row.dailyUsageUSD,
                limit: row.dailyLimitUSD,
                usageText: "\(row.dailyUsageText) / \(row.dailyLimitText)",
                percentageText: row.dailyPercentageText,
                trailingLabel: "余额",
                trailingValue: row.balanceText
            )
        }
        let items = [totalItem] + keyItems
        let layout = QuotaLineLayout(items: items)
        return items.map {
            renderQuotaLine(
                $0,
                layout: layout,
                theme: theme,
                colorEnabled: colorEnabled
            )
        }
    }

    private struct QuotaLineItem {
        let label: String
        let used: Double
        let limit: Double
        let usageText: String
        let percentageText: String
        let trailingLabel: String
        let trailingValue: String
    }

    private struct QuotaLineLayout {
        let labelWidth: Int
        let percentageWidth: Int
        let usageWidth: Int
        let trailingLabelWidth: Int

        init(items: [QuotaLineItem]) {
            labelWidth = max(8, items.map { displayWidth($0.label) }.max() ?? 8)
            percentageWidth = items.map { displayWidth($0.percentageText) }.max() ?? 0
            usageWidth = items.map { displayWidth($0.usageText) }.max() ?? 0
            trailingLabelWidth = items.map { displayWidth($0.trailingLabel) }.max() ?? 0
        }
    }

    private static func renderTotalUsage(_ rows: [DashboardUsageRow]) -> String {
        let totalUsage = rows.reduce(0) { $0 + $1.dailyUsageUSD }
        let totalLimit = rows.reduce(0) { $0 + max(0, $1.dailyLimitUSD) }
        guard totalLimit > 0 else {
            return "\(UsageFormatters.currency(totalUsage)) / ∞"
        }
        return "\(UsageFormatters.currency(totalUsage)) / \(UsageFormatters.currency(totalLimit))"
    }

    private static func remainingDaysText(_ rows: [DashboardUsageRow], now: Date) -> String {
        if let earliestExpiry = rows.compactMap(\.expiryDate).min() {
            return UsageFormatters.remainingDaysText(earliestExpiry, now: now)
        }
        return rows.first?.remainingDaysText ?? "--"
    }

    private static func firstTokenLatencyText(_ row: DashboardServiceRow) -> String {
        guard let latencyMS = row.cells.reversed().compactMap({ $0.probe?.latencyMS }).first else {
            return "(首T---)"
        }

        return String(format: "(首T-%.1fs)", Double(latencyMS) / 1_000)
    }

    private static func renderBattery(
        _ cells: [ServiceStatusDisplayCell],
        theme: CLITheme,
        colorEnabled: Bool
    ) -> String {
        cells
            .map { cell in batteryCell(for: cell.kind, theme: theme, colorEnabled: colorEnabled) }
            .joined(separator: "|")
    }

    private static func batteryCell(
        for kind: ServiceStatusCellKind,
        theme: CLITheme,
        colorEnabled: Bool
    ) -> String {
        let symbol = batterySymbol(for: kind)
        if colorEnabled {
            return theme.color(symbol, for: kind)
        }

        return symbol
    }

    private static func batterySymbol(for kind: ServiceStatusCellKind) -> String {
        switch kind {
        case .green:
            return "○"
        case .yellow:
            return "◐"
        case .red:
            return "●"
        case .gray:
            return "·"
        }
    }

    private static func renderQuotaLine(
        _ item: QuotaLineItem,
        layout: QuotaLineLayout,
        theme: CLITheme,
        colorEnabled: Bool
    ) -> String {
        [
            "\(padEnd(item.label, toDisplayWidth: layout.labelWidth))\(renderProgressBar(used: item.used, limit: item.limit, theme: theme, colorEnabled: colorEnabled))",
            padEnd(item.percentageText, toDisplayWidth: layout.percentageWidth),
            padEnd(item.usageText, toDisplayWidth: layout.usageWidth),
            "\(padEnd(item.trailingLabel, toDisplayWidth: layout.trailingLabelWidth)) \(item.trailingValue)",
        ].joined(separator: "  ")
    }

    private static func renderProgressBar(
        used: Double,
        limit: Double,
        theme: CLITheme,
        colorEnabled: Bool
    ) -> String {
        let width = 18
        let ratio = limit > 0 ? min(max(used / limit, 0), 1) : 0
        let filledCount = Int((ratio * Double(width)).rounded())
        let emptyCount = max(0, width - filledCount)
        let filled = String(repeating: "█", count: filledCount)
        let empty = String(repeating: "░", count: emptyCount)
        guard colorEnabled else {
            return "[\(filled)\(empty)]"
        }

        let kind = usageKind(used: used, limit: limit)
        let coloredFilled = theme.color(filled, for: kind)
        let coloredEmpty = theme.color(empty, for: .gray)
        return "[\(coloredFilled)\(coloredEmpty)]"
    }

    private static func usageKind(for row: DashboardUsageRow) -> ServiceStatusCellKind {
        usageKind(used: row.dailyUsageUSD, limit: row.dailyLimitUSD)
    }

    private static func usageKind(used: Double, limit: Double) -> ServiceStatusCellKind {
        switch UsageFormatters.healthState(used: used, limit: limit) {
        case .normal:
            return .green
        case .warning:
            return .yellow
        case .danger:
            return .red
        }
    }

    private static func refreshText(now: Date, intervalSeconds: Int) -> String {
        "\(timeText(now)) ↻ \(intervalSeconds)s"
    }

    private static func timeText(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static func padEnd(_ text: String, toDisplayWidth targetWidth: Int) -> String {
        let width = displayWidth(text)
        guard width < targetWidth else { return text }
        return text + String(repeating: " ", count: targetWidth - width)
    }

    private static func displayWidth(_ text: String) -> Int {
        var width = 0
        var inEscapeSequence = false

        for scalar in text.unicodeScalars {
            if inEscapeSequence {
                if scalar == "m" {
                    inEscapeSequence = false
                }
                continue
            }

            if scalar.value == 0x1B {
                inEscapeSequence = true
                continue
            }

            if CharacterSet.controlCharacters.contains(scalar) {
                continue
            }

            width += isWide(scalar) ? 2 : 1
        }

        return width
    }

    private static func isWide(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x1100...0x115F,
             0x2329...0x232A,
             0x2E80...0xA4CF,
             0xAC00...0xD7A3,
             0xF900...0xFAFF,
             0xFE10...0xFE19,
             0xFE30...0xFE6F,
             0xFF00...0xFF60,
             0xFFE0...0xFFE6:
            return true
        default:
            return false
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
