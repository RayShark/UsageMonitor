import XCTest
@testable import UsageMonitorCLI

final class CLIArgumentsTests: XCTestCase {
    func testNoArgumentsEnterInteractiveMode() throws {
        let arguments = try CLIArguments.parse([])

        XCTAssertEqual(arguments.command, .interactive)
    }

    func testParsesSetupAndConfigCommands() throws {
        XCTAssertEqual(try CLIArguments.parse(["setup"]).command, .setup)
        XCTAssertEqual(try CLIArguments.parse(["config"]).command, .config)
    }

    func testParsesBarCommandWithIntervalModeThemeAndOnce() throws {
        let arguments = try CLIArguments.parse([
            "bar",
            "--interval", "60",
            "--once",
            "--key", "main",
            "--mode", "detail",
            "--theme", "catppuccin",
        ])

        XCTAssertEqual(arguments.command, .bar)
        XCTAssertEqual(arguments.intervalSeconds, 60)
        XCTAssertTrue(arguments.once)
        XCTAssertEqual(arguments.keyID, "main")
        XCTAssertEqual(arguments.barMode, .detail)
        XCTAssertEqual(arguments.theme, .catppuccin)
    }

    func testParsesBarCommandWithOnelineMode() throws {
        let arguments = try CLIArguments.parse(["bar", "--mode", "oneline"])

        XCTAssertEqual(arguments.command, .bar)
        XCTAssertEqual(arguments.barMode, .oneline)
    }

    func testParsesMainstreamThemeNames() throws {
        XCTAssertEqual(try CLIArguments.parse(["bar", "--theme", "dracula"]).theme, .dracula)
        XCTAssertEqual(try CLIArguments.parse(["bar", "--theme", "tokyonight"]).theme, .tokyonight)
        XCTAssertEqual(try CLIArguments.parse(["bar", "--theme", "nord"]).theme, .nord)
        XCTAssertEqual(try CLIArguments.parse(["bar", "--theme", "gruvbox"]).theme, .gruvbox)
    }

    func testTopCommandIsKeptAsHiddenAliasForBar() throws {
        let arguments = try CLIArguments.parse(["top", "--compact"])

        XCTAssertEqual(arguments.command, .bar)
        XCTAssertEqual(arguments.barMode, .lite)
    }

    func testParsesUsageCommandWithCredentials() throws {
        let arguments = try CLIArguments.parse([
            "usage",
            "--base-url", "https://example.com",
            "--api-key", "sk-test",
            "--json",
        ])

        XCTAssertEqual(arguments.command, .usage)
        XCTAssertEqual(arguments.baseURL, "https://example.com")
        XCTAssertEqual(arguments.apiKey, "sk-test")
        XCTAssertTrue(arguments.json)
    }
}
