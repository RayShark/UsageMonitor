import XCTest
import UsageMonitorCore
@testable import UsageMonitorCLI

final class CLIConfigStoreTests: XCTestCase {
    func testDefaultConfigURLUsesHomeConfigDirectory() {
        let url = CLIConfigStore.defaultConfigURL(environment: ["HOME": "/tmp/user"])

        XCTAssertEqual(url.path, "/tmp/user/.config/usage-monitor/config.json")
    }

    func testSaveCreatesParentDirectoryAndRoundTripsConfig() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("nested/config.json")
        let store = CLIConfigStore(url: url)
        let config = CLIConfig(
            defaultBaseURL: "https://example.com/",
            refreshIntervalSeconds: 60,
            showColors: true,
            keys: [
                UsageKeyConfiguration(
                    id: "main",
                    name: "Main",
                    apiKey: "sk-main",
                    baseURLMode: .independent,
                    baseURLOverride: "https://key.example.com/"
                ),
            ]
        )

        try store.save(config)
        let loaded = try XCTUnwrap(store.load())

        XCTAssertEqual(loaded.defaultBaseURL, "https://example.com")
        XCTAssertEqual(loaded.keys.first?.baseURLOverride, "https://key.example.com")
        XCTAssertEqual(loaded.keys.first?.apiKey, "sk-main")
    }
}
