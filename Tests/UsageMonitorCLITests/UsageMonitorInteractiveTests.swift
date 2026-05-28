import XCTest
@testable import UsageMonitorCLI

final class UsageMonitorInteractiveTests: XCTestCase {
    func testSetupDoesNotSaveEmptyRequiredFields() throws {
        let store = makeStore()
        let terminal = testTerminal(inputs: ["", "", "", ""])

        try UsageMonitorInteractive.run(mode: .setup, store: store, terminal: terminal)

        XCTAssertNil(store.load())
    }

    func testSetupSavesValidConfig() throws {
        let store = makeStore()
        let terminal = testTerminal(inputs: ["https://example.com", "Main", "sk-test", ""])

        try UsageMonitorInteractive.run(mode: .setup, store: store, terminal: terminal)
        let config = try XCTUnwrap(store.load())

        XCTAssertEqual(config.defaultBaseURL, "https://example.com")
        XCTAssertEqual(config.keys.first?.name, "Main")
        XCTAssertEqual(config.keys.first?.apiKey, "sk-test")
    }

    private func makeStore() -> CLIConfigStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return CLIConfigStore(url: root.appendingPathComponent("config.json"))
    }

    private func testTerminal(inputs: [String]) -> InteractiveTerminal {
        let queue = InputQueue(inputs)
        return InteractiveTerminal(
            readLine: { queue.next() },
            write: { _ in },
            clearScreen: {},
            isTTY: { true }
        )
    }

    private final class InputQueue {
        private var values: [String]

        init(_ values: [String]) {
            self.values = values
        }

        func next() -> String? {
            values.isEmpty ? nil : values.removeFirst()
        }
    }
}
