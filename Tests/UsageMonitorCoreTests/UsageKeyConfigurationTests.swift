import XCTest
@testable import UsageMonitorCore

final class UsageKeyConfigurationTests: XCTestCase {
    func testMultiKeyConfigurationEncodesAndDecodes() throws {
        let original = [
            UsageKeyConfiguration(
                id: "a",
                name: "Work",
                symbolName: "bolt.fill",
                symbolColorHex: "#38BDF8",
                showsInMenuBar: true,
                apiKey: "key-a",
                baseURLMode: .inherited,
                baseURLOverride: ""
            ),
            UsageKeyConfiguration(
                id: "b",
                name: "Home",
                symbolName: "house.fill",
                symbolColorHex: "#F97316",
                showsInMenuBar: false,
                apiKey: "key-b",
                baseURLMode: .independent,
                baseURLOverride: "https://home.example.com"
            ),
        ]

        let data = try JSONEncoder.sub2api.encode(original)
        let decoded = try JSONDecoder.sub2api.decode([UsageKeyConfiguration].self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testOldKeyConfigurationJSONDefaultsTopbarDisplayAndSymbolColor() throws {
        let json = """
        [
          {
            "id": "a",
            "name": "Work",
            "symbolName": "bolt.fill",
            "apiKey": "key-a",
            "baseURLMode": "inherited",
            "baseURLOverride": ""
          }
        ]
        """

        let decoded = try JSONDecoder.sub2api.decode([UsageKeyConfiguration].self, from: Data(json.utf8))

        XCTAssertEqual(decoded[0].symbolColorHex, UsageKeyConfiguration.defaultSymbolColorHex)
        XCTAssertTrue(decoded[0].showsInMenuBar)
    }
}
