import XCTest
import UsageMonitorCore
@testable import UsageMonitorCLI

final class CompactDashboardRendererTests: XCTestCase {
    func testDefaultRenderUsesStatusAndUsagePanels() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [
                DashboardServiceRow(
                    model: "gpt-5.5",
                    kind: .green,
                    statusText: "正常",
                    uptimeText: "100.00%",
                    samplesText: "3/60",
                    cells: [
                        ServiceStatusDisplayCell(kind: .green, probe: nil),
                        ServiceStatusDisplayCell(kind: .yellow, probe: nil),
                        ServiceStatusDisplayCell(kind: .red, probe: nil),
                    ]
                ),
                DashboardServiceRow(
                    model: "gpt-5.4",
                    kind: .yellow,
                    statusText: "高延迟",
                    uptimeText: "98.00%",
                    samplesText: "3/60",
                    cells: [
                        ServiceStatusDisplayCell(kind: .green, probe: nil),
                        ServiceStatusDisplayCell(kind: .green, probe: nil),
                        ServiceStatusDisplayCell(kind: .yellow, probe: nil),
                    ]
                ),
                DashboardServiceRow(
                    model: "gpt-5.4-mini",
                    kind: .red,
                    statusText: "失败",
                    uptimeText: "80.00%",
                    samplesText: "3/60",
                    cells: [
                        ServiceStatusDisplayCell(kind: .green, probe: nil),
                        ServiceStatusDisplayCell(kind: .red, probe: nil),
                        ServiceStatusDisplayCell(kind: .red, probe: nil),
                    ]
                ),
            ],
            usageRows: [
                DashboardUsageRow(
                    keyName: "Key 1",
                    dailyUsageUSD: 3.24,
                    dailyLimitUSD: 10,
                    dailyUsageText: "$3.24",
                    dailyLimitText: "$10.00",
                    dailyPercentageText: "32.4%",
                    balanceText: "$42.12",
                    planName: "Pro",
                    expiryText: "2026-06-03",
                    expiryDate: Date(timeIntervalSince1970: 80_006_500),
                    remainingDaysText: "926天",
                    alerts: []
                ),
            ]
        )

        let rendered = CompactDashboardRenderer.render(
            snapshot,
            mode: .detail,
            theme: .mono,
            colorEnabled: false,
            intervalSeconds: 60,
            now: Date(timeIntervalSince1970: 100)
        )

        let lines = rendered.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.first, "总额度  [██████░░░░░░░░░░░░]  32.4%  $3.24 / $10.00  剩余 926天  00:01:40 ↻ 60s")
        XCTAssertFalse(rendered.contains("Ctrl-C 退出"))
        XCTAssertFalse(rendered.contains("到期 2026-06-03"))
        XCTAssertTrue(rendered.contains("渠道健康 2/3 OK"))
        XCTAssertTrue(rendered.contains("╭─ 服务状态"))
        XCTAssertTrue(rendered.contains("gpt-5.5"))
        XCTAssertTrue(rendered.contains("可用率 100.00%"))
        XCTAssertTrue(rendered.contains("样本 3/60"))
        XCTAssertTrue(rendered.contains(Self.battery(["○", "◐", "●"])))
        XCTAssertFalse(rendered.contains("▕"))
        XCTAssertFalse(rendered.contains("▏"))
        XCTAssertTrue(rendered.contains("╭─ 用量详情"))
        XCTAssertTrue(rendered.contains("Key 1"))
        XCTAssertTrue(rendered.contains("余额 $42.12"))
    }

    func testLiteRenderUsesQuotaBarsForTotalAndEachKey() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [
                DashboardServiceRow(
                    model: "gpt-5.5",
                    kind: .green,
                    statusText: "正常",
                    uptimeText: "100.00%",
                    samplesText: "1/60",
                    cells: [
                        ServiceStatusDisplayCell(kind: .green, probe: nil),
                    ]
                ),
            ],
            usageRows: [
                DashboardUsageRow(
                    keyName: "Key 1",
                    dailyUsageUSD: 3.24,
                    dailyLimitUSD: 10,
                    dailyUsageText: "$3.24",
                    dailyLimitText: "$10.00",
                    dailyPercentageText: "32.4%",
                    balanceText: "$42.12",
                    planName: "Pro",
                    expiryText: "2026-06-03",
                    expiryDate: Date(timeIntervalSince1970: 80_006_500),
                    remainingDaysText: "926天",
                    alerts: []
                ),
                DashboardUsageRow(
                    keyName: "Key 2",
                    dailyUsageUSD: 2.76,
                    dailyLimitUSD: 10,
                    dailyUsageText: "$2.76",
                    dailyLimitText: "$10.00",
                    dailyPercentageText: "27.6%",
                    balanceText: "$51.00",
                    planName: "Pro",
                    expiryText: "2026-06-03",
                    expiryDate: Date(timeIntervalSince1970: 80_006_500),
                    remainingDaysText: "926天",
                    alerts: []
                ),
            ]
        )

        let rendered = CompactDashboardRenderer.render(
            snapshot,
            mode: .lite,
            theme: .mono,
            colorEnabled: false,
            intervalSeconds: 60,
            now: Date(timeIntervalSince1970: 100)
        )

        let lines = rendered.split(separator: "\n")
        XCTAssertEqual(lines.count, 4)
        XCTAssertTrue(lines[0].hasPrefix("总额度  ["))
        XCTAssertTrue(lines[0].contains("█"))
        XCTAssertTrue(lines[0].contains("░"))
        XCTAssertTrue(lines[0].contains("$6.00 / $20.00"))
        XCTAssertTrue(lines[0].contains("剩余 926天"))
        XCTAssertTrue(lines[0].contains("00:01:40 ↻ 60s"))
        XCTAssertTrue(lines[1].contains("Key 1"))
        XCTAssertTrue(lines[1].contains("$3.24 / $10.00"))
        XCTAssertTrue(lines[1].contains("余额 $42.12"))
        XCTAssertTrue(lines[2].contains("Key 2"))
        XCTAssertTrue(lines[2].contains("$2.76 / $10.00"))
        XCTAssertTrue(lines[3].contains("渠道健康 1/1 OK"))
        XCTAssertTrue(lines[3].contains(Self.battery(["○"])))
    }

    func testColorRenderUsesAnsiColoredStatusDotsAndTimeline() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [
                DashboardServiceRow(
                    model: "gpt-5.5",
                    kind: .yellow,
                    statusText: "高延迟",
                    uptimeText: "98.00%",
                    samplesText: "4/60",
                    cells: [
                        ServiceStatusDisplayCell(kind: .green, probe: nil),
                        ServiceStatusDisplayCell(kind: .yellow, probe: nil),
                        ServiceStatusDisplayCell(kind: .red, probe: nil),
                        ServiceStatusDisplayCell(kind: .gray, probe: nil),
                    ]
                ),
            ],
            usageRows: []
        )

        let rendered = CompactDashboardRenderer.render(
            snapshot,
            mode: .detail,
            theme: .contrast,
            colorEnabled: true,
            intervalSeconds: 60,
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertTrue(rendered.contains("\u{001B}[92m○\u{001B}[0m"))
        XCTAssertTrue(rendered.contains("\u{001B}[38;5;214m◐\u{001B}[0m"))
        XCTAssertTrue(rendered.contains("\u{001B}[91m●\u{001B}[0m"))
        XCTAssertTrue(rendered.contains("\u{001B}[90m·\u{001B}[0m"))
    }

    func testClassicThemeKeepsStandardGreenYellowRed() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [
                DashboardServiceRow(
                    model: "gpt-5.5",
                    kind: .yellow,
                    statusText: "高延迟",
                    cells: [
                        ServiceStatusDisplayCell(kind: .green, probe: nil),
                        ServiceStatusDisplayCell(kind: .yellow, probe: nil),
                        ServiceStatusDisplayCell(kind: .red, probe: nil),
                    ]
                ),
            ],
            usageRows: []
        )

        let rendered = CompactDashboardRenderer.render(
            snapshot,
            mode: .detail,
            theme: .classic,
            colorEnabled: true,
            intervalSeconds: 60,
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertTrue(rendered.contains("\u{001B}[32m○\u{001B}[0m"))
        XCTAssertTrue(rendered.contains("\u{001B}[33m◐\u{001B}[0m"))
        XCTAssertTrue(rendered.contains("\u{001B}[31m●\u{001B}[0m"))
    }

    func testDraculaThemeUsesTrueColorPalette() {
        let colored = CLITheme.dracula.color("█", for: .green, colorMode: .trueColor)

        XCTAssertEqual(colored, "\u{001B}[38;2;80;250;123m█\u{001B}[0m")
    }

    func testExplicitColorModeOverridesNoColorEnvironment() {
        let detected = TerminalColorMode.detected(environment: [
            "NO_COLOR": "1",
            "USAGE_MONITOR_COLOR_MODE": "truecolor",
        ])

        XCTAssertEqual(detected, .trueColor)
    }

    func testStatusRowsUseDisplayWidthPaddingForChineseStatuses() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [
                DashboardServiceRow(model: "gpt-5.5", kind: .green, statusText: "正常", uptimeText: "100.00%", samplesText: "12/12"),
                DashboardServiceRow(model: "gpt-5.4", kind: .yellow, statusText: "高延迟", uptimeText: "100.00%", samplesText: "12/12"),
                DashboardServiceRow(model: "gpt-5.4-mini", kind: .green, statusText: "正常", uptimeText: "100.00%", samplesText: "12/12"),
            ],
            usageRows: []
        )

        let rendered = CompactDashboardRenderer.render(
            snapshot,
            mode: .detail,
            theme: .mono,
            colorEnabled: false,
            intervalSeconds: 5,
            now: Date(timeIntervalSince1970: 100)
        )

        let rows = rendered
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.contains("可用率") }

        XCTAssertEqual(rows.count, 3)
        let uptimeColumns = rows.compactMap { row -> Int? in
            guard let range = row.range(of: "可用率") else { return nil }
            return Self.displayWidth(String(row[..<range.lowerBound]))
        }
        XCTAssertEqual(Set(uptimeColumns).count, 1)
    }

    func testHealthLineUsesBatteryShapeForMixedStatusCells() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [
                DashboardServiceRow(
                    model: "gpt-5.5",
                    kind: .yellow,
                    statusText: "高延迟",
                    uptimeText: "75.00%",
                    samplesText: "3/4",
                    cells: [
                        ServiceStatusDisplayCell(kind: .green, probe: ServiceStatusProbe(ts: 80, ok: true, latencyMS: 900, error: nil)),
                        ServiceStatusDisplayCell(kind: .yellow, probe: ServiceStatusProbe(ts: 90, ok: true, latencyMS: 1800, error: nil)),
                        ServiceStatusDisplayCell(kind: .red, probe: ServiceStatusProbe(ts: 95, ok: false, latencyMS: nil, error: "failed")),
                        ServiceStatusDisplayCell(kind: .gray, probe: nil),
                    ]
                ),
            ],
            usageRows: []
        )

        let rendered = CompactDashboardRenderer.render(
            snapshot,
            mode: .lite,
            theme: .mono,
            colorEnabled: false,
            intervalSeconds: 5,
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertTrue(rendered.contains("gpt-5.5 \(Self.battery(["○", "◐", "●", "·"])) 高延迟 (首T-1.8s)"))
    }

    func testLiteQuotaBalanceColumnAlignsAcrossDifferentAmountWidths() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [],
            usageRows: [
                Self.usageRow(
                    keyName: "Leo",
                    dailyUsageUSD: 2,
                    dailyLimitUSD: 10,
                    dailyUsageText: "$2.00",
                    dailyLimitText: "$10.00",
                    dailyPercentageText: "20.0%",
                    balanceText: "$8.00"
                ),
                Self.usageRow(
                    keyName: "Wizard",
                    dailyUsageUSD: 123.45,
                    dailyLimitUSD: 1000,
                    dailyUsageText: "$123.45",
                    dailyLimitText: "$1000.00",
                    dailyPercentageText: "12.3%",
                    balanceText: "$876.55"
                ),
            ]
        )

        let rendered = CompactDashboardRenderer.render(
            snapshot,
            mode: .lite,
            theme: .mono,
            colorEnabled: false,
            intervalSeconds: 5,
            now: Date(timeIntervalSince1970: 100)
        )

        let balanceColumns = rendered
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.contains("余额") }
            .compactMap { Self.displayColumn(of: "余额", in: $0) }

        XCTAssertEqual(balanceColumns.count, 2)
        XCTAssertEqual(Set(balanceColumns).count, 1)
    }

    func testBatteryCellsUseTerminalSafeCircleSeparatorsInLiteAndDetailModes() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [
                DashboardServiceRow(
                    model: "gpt-5.5",
                    kind: .yellow,
                    statusText: "高延迟",
                    uptimeText: "75.00%",
                    samplesText: "3/4",
                    cells: [
                        ServiceStatusDisplayCell(kind: .green, probe: nil),
                        ServiceStatusDisplayCell(kind: .yellow, probe: nil),
                        ServiceStatusDisplayCell(kind: .red, probe: nil),
                        ServiceStatusDisplayCell(kind: .gray, probe: nil),
                    ]
                ),
            ],
            usageRows: []
        )

        let lite = CompactDashboardRenderer.render(
            snapshot,
            mode: .lite,
            theme: .mono,
            colorEnabled: false,
            intervalSeconds: 5,
            now: Date(timeIntervalSince1970: 100)
        )
        let detail = CompactDashboardRenderer.render(
            snapshot,
            mode: .detail,
            theme: .mono,
            colorEnabled: false,
            intervalSeconds: 5,
            now: Date(timeIntervalSince1970: 100)
        )

        let compactBattery = Self.battery(["○", "◐", "●", "·"])
        XCTAssertTrue(lite.contains(compactBattery))
        XCTAssertTrue(detail.contains(compactBattery))
        XCTAssertTrue(detail.contains("(首T---)"))
        XCTAssertEqual(compactBattery, "○|◐|●|·")
        XCTAssertFalse(lite.contains("○◐●·"))
        XCTAssertFalse(detail.contains("○◐●·"))
        XCTAssertFalse(lite.contains("▕"))
        XCTAssertFalse(detail.contains("▕"))
        XCTAssertFalse(lite.contains("▏"))
        XCTAssertFalse(detail.contains("▏"))
        XCTAssertFalse(lite.contains("▕▪◆×·▏"))
        XCTAssertFalse(detail.contains("▕▪◆×·▏"))
        XCTAssertFalse(lite.contains("▕G Y R .▏"))
        XCTAssertFalse(detail.contains("▕G Y R .▏"))
        XCTAssertFalse(lite.contains("▕GYR.▏"))
        XCTAssertFalse(detail.contains("▕GYR.▏"))
    }

    func testOnelineModeRendersTotalUsageGpt55HealthAndRefreshText() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [
                DashboardServiceRow(
                    model: "gpt-5.5",
                    kind: .yellow,
                    statusText: "高延迟",
                    uptimeText: "100.00%",
                    samplesText: "2/12",
                    cells: [
                        ServiceStatusDisplayCell(kind: .green, probe: ServiceStatusProbe(ts: 90, ok: true, latencyMS: 1200, error: nil)),
                        ServiceStatusDisplayCell(kind: .yellow, probe: ServiceStatusProbe(ts: 100, ok: true, latencyMS: 2300, error: nil)),
                    ]
                ),
                DashboardServiceRow(
                    model: "gpt-5.4",
                    kind: .yellow,
                    statusText: "高延迟",
                    uptimeText: "100.00%",
                    samplesText: "2/12",
                    cells: [
                        ServiceStatusDisplayCell(kind: .yellow, probe: ServiceStatusProbe(ts: 100, ok: true, latencyMS: 3600, error: nil)),
                    ]
                ),
            ],
            usageRows: [
                Self.usageRow(
                    keyName: "Key 1",
                    dailyUsageUSD: 3.24,
                    dailyLimitUSD: 10,
                    dailyUsageText: "$3.24",
                    dailyLimitText: "$10.00",
                    dailyPercentageText: "32.4%",
                    balanceText: "$42.12"
                ),
            ]
        )

        let rendered = CompactDashboardRenderer.render(
            snapshot,
            mode: .oneline,
            theme: .mono,
            colorEnabled: false,
            intervalSeconds: 60,
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(
            rendered,
            "总额度  [██████░░░░░░░░░░░░]  32.4%  $3.24 / $10.00  渠道健康 2/2 OK  gpt-5.5 \(Self.battery(["○", "◐"])) (首T-2.3s)  00:01:40 ↻ 60s"
        )
        XCTAssertFalse(rendered.contains("gpt-5.4"))
        XCTAssertFalse(rendered.contains("剩余"))
    }

    func testDetailUsagePanelAlignsPrimaryAndPlanColumns() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [],
            usageRows: [
                Self.usageRow(
                    keyName: "Leo",
                    dailyUsageUSD: 2,
                    dailyLimitUSD: 10,
                    dailyUsageText: "$2.00",
                    dailyLimitText: "$10.00",
                    dailyPercentageText: "20.0%",
                    balanceText: "$8.00",
                    planName: "Air"
                ),
                Self.usageRow(
                    keyName: "Wizard",
                    dailyUsageUSD: 123.45,
                    dailyLimitUSD: 1000,
                    dailyUsageText: "$123.45",
                    dailyLimitText: "$1000.00",
                    dailyPercentageText: "12.3%",
                    balanceText: "$876.55",
                    planName: "CodeX Plus 年度"
                ),
            ]
        )

        let rendered = CompactDashboardRenderer.render(
            snapshot,
            mode: .detail,
            theme: .mono,
            colorEnabled: false,
            intervalSeconds: 5,
            now: Date(timeIntervalSince1970: 100)
        )

        let lines = rendered.split(separator: "\n").map(String.init)
        let primaryRows = lines.filter { $0.contains(" 今日 ") && $0.contains(" 余额 ") }
        let planRows = lines.filter { $0.contains(" 订阅 ") && $0.contains(" 周 ") && $0.contains(" 月 ") }

        XCTAssertEqual(primaryRows.count, 2)
        XCTAssertEqual(Set(primaryRows.compactMap { Self.displayColumn(of: "今日", in: $0) }).count, 1)
        XCTAssertEqual(Set(primaryRows.compactMap { Self.displayColumn(of: "余额", in: $0) }).count, 1)
        XCTAssertEqual(Set(primaryRows.compactMap { Self.displayColumn(of: "剩余", in: $0) }).count, 1)

        XCTAssertEqual(planRows.count, 2)
        XCTAssertEqual(Set(planRows.compactMap { Self.displayColumn(of: "订阅", in: $0) }).count, 1)
        XCTAssertEqual(Set(planRows.compactMap { Self.displayColumn(of: "周", in: $0) }).count, 1)
        XCTAssertEqual(Set(planRows.compactMap { Self.displayColumn(of: "月", in: $0) }).count, 1)
    }

    private static func usageRow(
        keyName: String,
        dailyUsageUSD: Double,
        dailyLimitUSD: Double,
        dailyUsageText: String,
        dailyLimitText: String,
        dailyPercentageText: String,
        balanceText: String,
        planName: String = "Pro"
    ) -> DashboardUsageRow {
        DashboardUsageRow(
            keyName: keyName,
            dailyUsageUSD: dailyUsageUSD,
            dailyLimitUSD: dailyLimitUSD,
            dailyUsageText: dailyUsageText,
            dailyLimitText: dailyLimitText,
            dailyPercentageText: dailyPercentageText,
            balanceText: balanceText,
            planName: planName,
            expiryText: "2026-06-03",
            expiryDate: Date(timeIntervalSince1970: 80_006_500),
            remainingDaysText: "926天",
            weeklyUsageText: "$12.00 / ∞",
            monthlyUsageText: "$123.00 / ∞",
            todayBucketText: "1 次 · 100 tokens · $0.01",
            totalBucketText: "2 次 · 200 tokens · $0.02",
            tokenBreakdownText: "输入 10 · 输出 20",
            costBreakdownText: "输入 $0.00 · 输出 $0.00",
            rateText: "RPM 0.00 · TPM 0.00",
            alerts: []
        )
    }

    private static func displayColumn(of needle: String, in text: String) -> Int? {
        guard let range = text.range(of: needle) else { return nil }
        return displayWidth(String(text[..<range.lowerBound]))
    }

    private static func battery(_ symbols: [String]) -> String {
        symbols.joined(separator: "|")
    }

    private static func displayWidth(_ text: String) -> Int {
        text.unicodeScalars.reduce(0) { width, scalar in
            switch scalar.value {
            case 0x2E80...0xA4CF, 0xAC00...0xD7A3, 0xF900...0xFAFF, 0xFE10...0xFE19, 0xFE30...0xFE6F, 0xFF00...0xFF60, 0xFFE0...0xFFE6:
                return width + 2
            default:
                return width + 1
            }
        }
    }
}
