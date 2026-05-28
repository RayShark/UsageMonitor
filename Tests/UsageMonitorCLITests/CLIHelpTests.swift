import XCTest
@testable import UsageMonitorCLI

final class CLIHelpTests: XCTestCase {
    func testHelpDocumentsBarModesHotkeysAndDataSources() {
        let help = UsageMonitorCLIEntrypoint.helpText

        XCTAssertTrue(help.contains("--mode lite|detail|oneline"))
        XCTAssertTrue(help.contains("Hotkeys"))
        XCTAssertTrue(help.contains("o oneline"))
        XCTAssertTrue(help.contains("d detail"))
        XCTAssertTrue(help.contains("l lite"))
        XCTAssertTrue(help.contains("c cycle theme"))
        XCTAssertTrue(help.contains("Ctrl-C exit"))
        XCTAssertTrue(help.contains("status.input.im/api/status"))
        XCTAssertTrue(help.contains("GET /v1/usage"))
    }
}
