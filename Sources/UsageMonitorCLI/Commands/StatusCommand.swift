import Foundation
import UsageMonitorCore

enum StatusCommand {
    static let monitoredModels = ServiceStatusConfiguration.monitoredModels
    private static let timelineCellCount = 12

    static func makeServiceRows(response: ServiceStatusResponse) -> [DashboardServiceRow] {
        response.timelineRows(for: monitoredModels, count: timelineCellCount).map { row in
            DashboardServiceRow(
                model: row.model,
                kind: row.latestKind,
                statusText: row.statusText,
                uptimeText: row.uptimeText,
                samplesText: row.samplesText,
                cells: row.cells
            )
        }
    }

    static func run(
        json: Bool,
        colorEnabled: Bool = true,
        theme: CLITheme = .contrast,
        output: CLIOutput = .standard,
        client: ServiceStatusFetching = StatusAPIClient()
    ) async throws {
        let result = try await client.fetchStatus()
        if json {
            output.write(result.prettyRawJSON)
            return
        }

        let rows = makeServiceRows(response: result.response)
        let snapshot = DashboardSnapshot(generatedAt: Date(), serviceRows: rows, usageRows: [])
        output.write(
            CompactDashboardRenderer.renderStatus(
                snapshot,
                colorEnabled: colorEnabled,
                theme: theme,
                now: Date()
            )
        )
    }
}
