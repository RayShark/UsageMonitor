import XCTest
import UsageMonitorCore
@testable import UsageMonitorCLI

final class StatusCommandTests: XCTestCase {
    func testMakeServiceRowsUsesKnownModelOrder() {
        let response = ServiceStatusResponse(
            allOK: false,
            generatedAt: 100,
            services: [
                ServiceStatusService(
                    model: "gpt-5.5",
                    uptimePct: 100,
                    last: ServiceStatusProbe(ts: 100, ok: true, latencyMS: 100, error: nil),
                    history: []
                ),
                ServiceStatusService(
                    model: "gpt-5.4",
                    uptimePct: 100,
                    last: ServiceStatusProbe(ts: 100, ok: true, latencyMS: 3500, error: nil),
                    history: []
                ),
                ServiceStatusService(
                    model: "gpt-5.4-mini",
                    uptimePct: 90,
                    last: ServiceStatusProbe(ts: 100, ok: false, latencyMS: nil, error: "failed"),
                    history: []
                ),
            ]
        )

        let rows = StatusCommand.makeServiceRows(response: response)

        XCTAssertEqual(rows.map(\.model), ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini"])
        XCTAssertEqual(rows.map(\.statusText), ["在线", "高延迟", "失败"])
        XCTAssertEqual(rows.map(\.uptimeText), ["100.00%", "100.00%", "90.00%"])
        XCTAssertEqual(rows.map(\.samplesText), ["0/12", "0/12", "0/12"])
    }
}
