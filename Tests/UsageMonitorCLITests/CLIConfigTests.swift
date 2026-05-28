import XCTest
import UsageMonitorCore
@testable import UsageMonitorCLI

final class CLIConfigTests: XCTestCase {
    func testFlagsOverrideEnvironment() throws {
        let args = CLIArguments(
            command: .usage,
            baseURL: "https://flag.example.com",
            apiKey: "flag-key",
            keyID: nil,
            intervalSeconds: 60,
            json: false,
            once: false,
            compact: false,
            noColor: false
        )

        let config = try CLIConfig.resolve(
            arguments: args,
            environment: [
                "USAGE_MONITOR_BASE_URL": "https://env.example.com",
                "USAGE_MONITOR_API_KEY": "env-key",
            ],
            fileConfig: nil
        )

        XCTAssertEqual(config.defaultBaseURL, "https://flag.example.com")
        XCTAssertEqual(config.keys.first?.apiKey, "flag-key")
    }

    func testEnvironmentIsUsedWhenFlagsAreMissing() throws {
        let args = CLIArguments(
            command: .usage,
            baseURL: nil,
            apiKey: nil,
            keyID: nil,
            intervalSeconds: 60,
            json: false,
            once: false,
            compact: false,
            noColor: false
        )

        let config = try CLIConfig.resolve(
            arguments: args,
            environment: [
                "USAGE_MONITOR_BASE_URL": "https://env.example.com",
                "USAGE_MONITOR_API_KEY": "env-key",
            ],
            fileConfig: nil
        )

        XCTAssertEqual(config.defaultBaseURL, "https://env.example.com")
        XCTAssertEqual(config.keys.first?.apiKey, "env-key")
    }

    func testFileConfigPreservesMultipleKeysWhenFlagsAndEnvironmentAreMissing() throws {
        let args = CLIArguments(
            command: .usage,
            baseURL: nil,
            apiKey: nil,
            keyID: nil,
            intervalSeconds: 60,
            json: false,
            once: false,
            compact: false,
            noColor: false
        )
        let fileConfig = CLIConfig(
            defaultBaseURL: "https://file.example.com",
            refreshIntervalSeconds: 30,
            showColors: true,
            keys: [
                UsageKeyConfiguration(id: "main", name: "Main", apiKey: "main-key"),
                UsageKeyConfiguration(
                    id: "backup",
                    name: "Backup",
                    apiKey: "backup-key",
                    baseURLMode: .independent,
                    baseURLOverride: "https://backup.example.com/"
                ),
            ]
        )

        let config = try CLIConfig.resolve(arguments: args, environment: [:], fileConfig: fileConfig)

        XCTAssertEqual(config.keys.map(\.id), ["main", "backup"])
        XCTAssertEqual(config.keys[1].resolvedBaseURLText(defaultBaseURL: config.defaultBaseURL), "https://backup.example.com")
    }

    func testFlagsOverrideSelectedKeyWithoutDroppingOtherKeys() throws {
        let args = CLIArguments(
            command: .usage,
            baseURL: "https://flag.example.com",
            apiKey: "flag-key",
            keyID: "backup",
            intervalSeconds: 60,
            json: false,
            once: false,
            compact: false,
            noColor: false
        )
        let fileConfig = CLIConfig(
            defaultBaseURL: "https://file.example.com",
            refreshIntervalSeconds: 30,
            showColors: true,
            keys: [
                UsageKeyConfiguration(id: "main", name: "Main", apiKey: "main-key"),
                UsageKeyConfiguration(id: "backup", name: "Backup", apiKey: "backup-key"),
            ]
        )

        let config = try CLIConfig.resolve(arguments: args, environment: [:], fileConfig: fileConfig)
        let selected = try config.selectedKey(id: "backup")

        XCTAssertEqual(config.keys.map(\.id), ["main", "backup"])
        XCTAssertEqual(selected.apiKey, "flag-key")
        XCTAssertEqual(selected.resolvedBaseURLText(defaultBaseURL: config.defaultBaseURL), "https://flag.example.com")
    }

    func testMissingSelectedKeyIsConfigError() throws {
        let config = CLIConfig(
            defaultBaseURL: "https://file.example.com",
            refreshIntervalSeconds: 30,
            showColors: true,
            keys: [UsageKeyConfiguration(id: "main", name: "Main", apiKey: "main-key")]
        )

        XCTAssertThrowsError(try config.selectedKey(id: "missing")) { error in
            XCTAssertEqual(error as? CLIConfigError, .unknownKey("missing"))
        }
    }

    func testThemeResolvesFromFlagEnvironmentAndFileConfig() throws {
        let fileConfig = CLIConfig(
            defaultBaseURL: "https://file.example.com",
            refreshIntervalSeconds: 30,
            showColors: true,
            theme: .dracula,
            keys: [UsageKeyConfiguration(id: "main", name: "Main", apiKey: "main-key")]
        )
        let args = CLIArguments(
            command: .bar,
            baseURL: nil,
            apiKey: nil,
            keyID: nil,
            intervalSeconds: 60,
            json: false,
            once: false,
            compact: false,
            noColor: false,
            theme: .catppuccin
        )

        let flagConfig = try CLIConfig.resolve(arguments: args, environment: ["USAGE_MONITOR_THEME": "mono"], fileConfig: fileConfig)

        XCTAssertEqual(flagConfig.theme, .catppuccin)

        let envArgs = CLIArguments(
            command: .bar,
            baseURL: nil,
            apiKey: nil,
            keyID: nil,
            intervalSeconds: 60,
            json: false,
            once: false,
            compact: false,
            noColor: false
        )
        let envConfig = try CLIConfig.resolve(arguments: envArgs, environment: ["USAGE_MONITOR_THEME": "mono"], fileConfig: fileConfig)
        XCTAssertEqual(envConfig.theme, .mono)

        let fileResolvedConfig = try CLIConfig.resolve(arguments: envArgs, environment: [:], fileConfig: fileConfig)
        XCTAssertEqual(fileResolvedConfig.theme, .dracula)
    }
}
