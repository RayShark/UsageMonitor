import XCTest
import UsageMonitorCore
@testable import UsageMonitorCLI

final class CLIExitCodeTests: XCTestCase {
    func testArgumentAndConfigErrorsUseUsageExitCode() {
        XCTAssertEqual(
            UsageMonitorCLIEntrypoint.exitCode(for: CLIArgumentError.unknownArgument("--bad")),
            2
        )
        XCTAssertEqual(
            UsageMonitorCLIEntrypoint.exitCode(for: CLIConfigError.missingAPIKey),
            2
        )
    }

    func testUnauthorizedUsageErrorUsesAuthExitCode() {
        XCTAssertEqual(
            UsageMonitorCLIEntrypoint.exitCode(for: Sub2APIClientError.authorizationFailure),
            3
        )
    }

    func testNetworkErrorsUseRuntimeExitCode() {
        XCTAssertEqual(
            UsageMonitorCLIEntrypoint.exitCode(for: Sub2APIClientError.network("offline")),
            1
        )
        XCTAssertEqual(
            UsageMonitorCLIEntrypoint.exitCode(for: StatusAPIClientError.network("offline")),
            1
        )
    }

    func testInterruptUsesSignalExitCode() {
        XCTAssertEqual(
            UsageMonitorCLIEntrypoint.exitCode(for: CLIInterruptError(signalNumber: 2)),
            130
        )
    }

    func testUserMessageUsesClientMessages() {
        XCTAssertEqual(
            UsageMonitorCLIEntrypoint.userMessage(for: Sub2APIClientError.authorizationFailure),
            "API Key 无效，请检查后重试"
        )
        XCTAssertEqual(
            UsageMonitorCLIEntrypoint.userMessage(for: StatusAPIClientError.decoding),
            "状态响应格式异常"
        )
    }
}
