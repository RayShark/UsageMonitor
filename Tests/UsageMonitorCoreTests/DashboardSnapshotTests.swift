import XCTest
@testable import UsageMonitorCore

final class DashboardSnapshotTests: XCTestCase {
    func testHealthSummaryCountsGreenAndYellowAsAvailable() {
        let snapshot = DashboardSnapshot(
            generatedAt: Date(timeIntervalSince1970: 100),
            serviceRows: [
                DashboardServiceRow(model: "gpt-5.5", kind: .green, statusText: "正常"),
                DashboardServiceRow(model: "gpt-5.4", kind: .yellow, statusText: "高延迟"),
                DashboardServiceRow(model: "gpt-5.4-mini", kind: .red, statusText: "失败"),
            ],
            usageRows: []
        )

        XCTAssertEqual(snapshot.healthSummaryText, "2/3 OK")
    }
}
