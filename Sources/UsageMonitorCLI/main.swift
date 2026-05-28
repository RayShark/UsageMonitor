import Foundation
import UsageMonitorCore

enum UsageMonitorCLIEntrypoint {
    static func main() async {
        let output = CLIOutput.standard
        do {
            let arguments = try CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))
            let fileConfig = CLIConfig.loadDefaultFile()
            let config = try CLIConfig.resolve(arguments: arguments, fileConfig: fileConfig)
            switch arguments.command {
            case .interactive:
                try UsageMonitorInteractive.run(mode: .auto)
            case .setup:
                try UsageMonitorInteractive.run(mode: .setup)
            case .config:
                try UsageMonitorInteractive.run(mode: .config)
            case .help:
                output.write(Self.helpText)
            case .usage:
                try await UsageCommand.run(config: config, json: arguments.json, keyID: arguments.keyID, output: output)
            case .status:
                try await StatusCommand.run(json: arguments.json, colorEnabled: config.showColors, theme: config.theme, output: output)
            case .bar:
                try await BarCommand.run(arguments: arguments, config: config, output: output)
            }
        } catch let error as CLIInterruptError {
            Foundation.exit(error.exitCode)
        } catch {
            output.writeError(Self.userMessage(for: error))
            Foundation.exit(Self.exitCode(for: error))
        }
    }

    static func userMessage(for error: Error) -> String {
        if let error = error as? CLIArgumentError {
            return error.description
        }
        if let error = error as? CLIConfigError {
            return error.description
        }
        if let error = error as? InteractiveError {
            return error.description
        }
        if let error = error as? Sub2APIClientError {
            return error.userMessage
        }
        if let error = error as? StatusAPIClientError {
            return error.userMessage
        }
        return "请求失败：\(error.localizedDescription)"
    }

    static func exitCode(for error: Error) -> Int32 {
        if error is CLIArgumentError { return 2 }
        if error is CLIConfigError { return 2 }
        if error is InteractiveError { return 2 }
        if let error = error as? Sub2APIClientError, error.isUnauthorized { return 3 }
        if error is Sub2APIClientError { return 1 }
        if error is StatusAPIClientError { return 1 }
        if let error = error as? CLIInterruptError { return error.exitCode }
        return 1
    }

    static let helpText = """
    usage-monitor
    usage-monitor setup
    usage-monitor config
    usage-monitor usage [--key ID_OR_NAME] [--base-url URL] [--api-key KEY] [--json]
    usage-monitor status [--json] [--no-color]
    usage-monitor bar [--key ID_OR_NAME] [--interval SECONDS] [--once] [--mode lite|detail|oneline] [--theme contrast|classic|mono|dracula|catppuccin|tokyonight|nord|gruvbox] [--no-color]

    Commands:
      setup      guided setup for URL and API keys
      config     manage saved URL, keys, refresh interval, and theme
      usage      print one-shot usage/quota data from GET /v1/usage
      status     print one-shot channel status from https://status.input.im/api/status
      bar        live terminal dashboard; top is kept as a hidden alias

    Bar modes:
      lite       total quota, each key quota, and channel health
      detail     lite plus service and usage detail panels
      oneline    one-row total quota and gpt-5.5 health for status bars

    Hotkeys in live bar mode:
      o oneline
      d detail
      l lite
      c cycle theme
      Ctrl-C exit

    Data sources:
      first-token latency comes from https://status.input.im/api/status history latencyMS
      quota and plan data come from your configured Base URL with GET /v1/usage
    """
}

await UsageMonitorCLIEntrypoint.main()
