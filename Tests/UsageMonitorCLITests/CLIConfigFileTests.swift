import XCTest
@testable import UsageMonitorCLI

final class CLIConfigFileTests: XCTestCase {
    func testLoadsConfigFile() throws {
        let data = Data("""
        {
          "defaultBaseURL": "https://file.example.com",
          "refreshIntervalSeconds": 30,
          "showColors": false,
          "keys": [
            {
              "id": "main",
              "name": "Main",
              "symbolName": "key.fill",
              "symbolColorHex": "#66D9EF",
              "showsInMenuBar": true,
              "apiKey": "file-key",
              "baseURLMode": "inherited",
              "baseURLOverride": ""
            }
          ]
        }
        """.utf8)

        let config = try CLIConfig.decode(data: data)

        XCTAssertEqual(config.defaultBaseURL, "https://file.example.com")
        XCTAssertEqual(config.refreshIntervalSeconds, 30)
        XCTAssertEqual(config.showColors, false)
        XCTAssertEqual(config.keys.first?.name, "Main")
    }
}
