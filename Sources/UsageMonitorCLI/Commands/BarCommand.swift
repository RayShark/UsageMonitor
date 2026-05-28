import Foundation
import UsageMonitorCore

protocol UsageFetching {
    func usage(baseURL: URL, apiKey: String) async throws -> UsageResponse
}

extension Sub2APIClient: UsageFetching {}

struct KeyedUsageResponse: Equatable {
    let keyName: String
    let response: UsageResponse
}

enum BarCommand {
    static func makeDashboardSnapshot(
        statusResponse: ServiceStatusResponse,
        usageResponses: [KeyedUsageResponse],
        now: Date
    ) -> DashboardSnapshot {
        DashboardSnapshot(
            generatedAt: now,
            serviceRows: StatusCommand.makeServiceRows(response: statusResponse),
            usageRows: usageResponses.map { result in
                UsageCommand.makeUsageRow(
                    keyName: result.keyName,
                    response: result.response,
                    now: now
                )
            }
        )
    }

    static func configuredUsageKeys(
        argumentsKeyID: String?,
        config: CLIConfig
    ) throws -> [UsageKeyConfiguration] {
        try config.selectedUsageKeys(id: argumentsKeyID)
    }

    static func run(
        arguments: CLIArguments,
        config: CLIConfig,
        output: CLIOutput = .standard,
        usageClient: UsageFetching = Sub2APIClient(),
        statusClient: ServiceStatusFetching = StatusAPIClient(),
        keyboardReader providedKeyboardReader: BarKeyboardReading? = nil
    ) async throws {
        var state = BarRuntimeState(mode: arguments.barMode, theme: config.theme)

        if arguments.once {
            let snapshot = try await makeSnapshot(
                arguments: arguments,
                config: config,
                usageClient: usageClient,
                statusClient: statusClient
            )
            output.write(render(snapshot, state: state, config: config))
            return
        }

        let keyboardReader = providedKeyboardReader ?? TerminalBarKeyboardReader.standard()
        defer { keyboardReader?.restore() }

        var snapshot = try await makeSnapshot(
            arguments: arguments,
            config: config,
            usageClient: usageClient,
            statusClient: statusClient
        )
        var nextRefresh = Date().addingTimeInterval(TimeInterval(config.refreshIntervalSeconds))

        while !Task.isCancelled {
            output.write(TerminalScreen.frame(render(snapshot, state: state, config: config), clear: true))

            switch try await waitForAction(
                keyboardReader: keyboardReader,
                until: nextRefresh
            ) {
            case .keyboard(let action):
                state.apply(action)
                continue
            case .terminationSignal(let signalNumber):
                throw CLIInterruptError(signalNumber: signalNumber)
            case .refresh:
                break
            }

            snapshot = try await makeSnapshot(
                arguments: arguments,
                config: config,
                usageClient: usageClient,
                statusClient: statusClient
            )
            nextRefresh = Date().addingTimeInterval(TimeInterval(config.refreshIntervalSeconds))
        }
    }

    private static func makeSnapshot(
        arguments: CLIArguments,
        config: CLIConfig,
        usageClient: UsageFetching,
        statusClient: ServiceStatusFetching
    ) async throws -> DashboardSnapshot {
        let keys = try configuredUsageKeys(argumentsKeyID: arguments.keyID, config: config)
        async let statusResult = statusClient.fetchStatus()
        let usageResponses = try await fetchUsageResponses(
            keys: keys,
            config: config,
            usageClient: usageClient
        )
        let now = Date()
        return try await makeDashboardSnapshot(
            statusResponse: statusResult.response,
            usageResponses: usageResponses,
            now: now
        )
    }

    private static func render(
        _ snapshot: DashboardSnapshot,
        state: BarRuntimeState,
        config: CLIConfig
    ) -> String {
        CompactDashboardRenderer.render(
            snapshot,
            mode: state.mode,
            theme: state.theme,
            colorEnabled: config.showColors,
            intervalSeconds: config.refreshIntervalSeconds,
            now: snapshot.generatedAt
        )
    }

    private enum BarWaitResult {
        case keyboard(BarKeyboardAction)
        case terminationSignal(Int32)
        case refresh
    }

    private static func waitForAction(
        keyboardReader: BarKeyboardReading?,
        until deadline: Date
    ) async throws -> BarWaitResult {
        while true {
            if let signal = keyboardReader?.receivedTerminationSignal() {
                return .terminationSignal(signal)
            }

            if let action = keyboardReader?.readAction() {
                return .keyboard(action)
            }

            let remainingSeconds = deadline.timeIntervalSinceNow
            guard remainingSeconds > 0 else {
                return .refresh
            }

            let sleepSeconds = min(remainingSeconds, 0.1)
            try await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
        }
    }

    private static func fetchUsageResponses(
        keys: [UsageKeyConfiguration],
        config: CLIConfig,
        usageClient: UsageFetching
    ) async throws -> [KeyedUsageResponse] {
        var responses: [KeyedUsageResponse] = []
        responses.reserveCapacity(keys.count)

        for key in keys {
            let apiKey = key.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiKey.isEmpty else { throw CLIConfigError.missingAPIKey }
            let url = try config.resolvedBaseURL(for: key)
            let response = try await usageClient.usage(baseURL: url, apiKey: apiKey)
            responses.append(KeyedUsageResponse(keyName: key.name, response: response))
        }

        return responses
    }
}
