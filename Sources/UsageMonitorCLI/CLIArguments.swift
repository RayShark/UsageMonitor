import Foundation

enum CLICommand: String, Equatable {
    case interactive
    case setup
    case config
    case usage
    case status
    case bar
    case help

    static func named(_ value: String) -> CLICommand? {
        if value == "top" {
            return .bar
        }
        return CLICommand(rawValue: value)
    }
}

enum CLIArgumentError: Error, Equatable {
    case missingValue(String)
    case invalidValue(String)
    case unknownArgument(String)
}

extension CLIArgumentError: CustomStringConvertible {
    var description: String {
        switch self {
        case let .missingValue(flag):
            return "\(flag) requires a value"
        case let .invalidValue(flag):
            return "\(flag) has an invalid value"
        case .unknownArgument(let argument):
            return "unknown argument: \(argument)"
        }
    }
}

extension CLIArgumentError: LocalizedError {
    var errorDescription: String? {
        description
    }
}

struct CLIArguments {
    var command: CLICommand
    var baseURL: String?
    var apiKey: String?
    var keyID: String?
    var intervalSeconds: Int
    var json: Bool
    var once: Bool
    var compact: Bool
    var barMode: BarMode
    var theme: CLITheme?
    var noColor: Bool

    private var providedOptions: Set<CLIArgumentOption>

    init(
        command: CLICommand,
        baseURL: String?,
        apiKey: String?,
        keyID: String? = nil,
        intervalSeconds: Int,
        json: Bool,
        once: Bool,
        compact: Bool,
        noColor: Bool,
        barMode: BarMode = .lite,
        theme: CLITheme? = nil
    ) {
        self.command = command
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.keyID = keyID
        self.intervalSeconds = intervalSeconds
        self.json = json
        self.once = once
        self.compact = compact
        self.barMode = barMode
        self.theme = theme
        self.noColor = noColor
        self.providedOptions = []
        if baseURL != nil {
            self.providedOptions.insert(.baseURL)
        }
        if apiKey != nil {
            self.providedOptions.insert(.apiKey)
        }
        if intervalSeconds != 60 {
            self.providedOptions.insert(.interval)
        }
        if noColor {
            self.providedOptions.insert(.noColor)
        }
    }

    static func parse(_ rawArguments: [String]) throws -> CLIArguments {
        var parsedCommand: CLICommand?
        var baseURL: String?
        var apiKey: String?
        var keyID: String?
        var intervalSeconds = 60
        var json = false
        var once = false
        var compact = false
        var barMode = BarMode.lite
        var theme: CLITheme?
        var noColor = false
        var providedOptions = Set<CLIArgumentOption>()

        var index = 0
        while index < rawArguments.count {
            let argument = rawArguments[index]

            switch argument {
            case "--base-url":
                baseURL = try value(after: argument, in: rawArguments, currentIndex: index)
                providedOptions.insert(.baseURL)
                index += 2
            case "--api-key":
                apiKey = try value(after: argument, in: rawArguments, currentIndex: index)
                providedOptions.insert(.apiKey)
                index += 2
            case "--key":
                keyID = try value(after: argument, in: rawArguments, currentIndex: index)
                index += 2
            case "--interval":
                let rawValue = try value(after: argument, in: rawArguments, currentIndex: index)
                guard let value = Int(rawValue), value > 0 else {
                    throw CLIArgumentError.invalidValue(argument)
                }
                intervalSeconds = value
                providedOptions.insert(.interval)
                index += 2
            case "--json":
                json = true
                index += 1
            case "--once":
                once = true
                index += 1
            case "--compact":
                compact = true
                barMode = .lite
                index += 1
            case "--mode":
                let rawValue = try value(after: argument, in: rawArguments, currentIndex: index)
                guard let value = BarMode(rawValue: rawValue) else {
                    throw CLIArgumentError.invalidValue(argument)
                }
                barMode = value
                index += 2
            case "--theme":
                let rawValue = try value(after: argument, in: rawArguments, currentIndex: index)
                guard let value = CLITheme(rawValue: rawValue) else {
                    throw CLIArgumentError.invalidValue(argument)
                }
                theme = value
                index += 2
            case "--no-color":
                noColor = true
                providedOptions.insert(.noColor)
                index += 1
            case "--":
                index += 1
            case "-h", "--help":
                parsedCommand = .help
                index += 1
            default:
                guard !argument.hasPrefix("-") else {
                    throw CLIArgumentError.unknownArgument(argument)
                }
                guard parsedCommand == nil, let command = CLICommand.named(argument) else {
                    throw CLIArgumentError.unknownArgument(argument)
                }
                parsedCommand = command
                index += 1
            }
        }

        return CLIArguments(
            command: parsedCommand ?? .interactive,
            baseURL: baseURL,
            apiKey: apiKey,
            keyID: keyID,
            intervalSeconds: intervalSeconds,
            json: json,
            once: once,
            compact: compact,
            barMode: barMode,
            theme: theme,
            noColor: noColor,
            providedOptions: providedOptions
        )
    }

    func hasProvided(_ option: CLIArgumentOption) -> Bool {
        providedOptions.contains(option)
    }

    private init(
        command: CLICommand,
        baseURL: String?,
        apiKey: String?,
        keyID: String?,
        intervalSeconds: Int,
        json: Bool,
        once: Bool,
        compact: Bool,
        barMode: BarMode,
        theme: CLITheme?,
        noColor: Bool,
        providedOptions: Set<CLIArgumentOption>
    ) {
        self.command = command
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.keyID = keyID
        self.intervalSeconds = intervalSeconds
        self.json = json
        self.once = once
        self.compact = compact
        self.barMode = barMode
        self.theme = theme
        self.noColor = noColor
        self.providedOptions = providedOptions
    }

    private static func value(
        after argument: String,
        in rawArguments: [String],
        currentIndex: Int
    ) throws -> String {
        let valueIndex = currentIndex + 1
        guard valueIndex < rawArguments.count else {
            throw CLIArgumentError.missingValue(argument)
        }

        let value = rawArguments[valueIndex]
        guard !value.hasPrefix("-") else {
            throw CLIArgumentError.missingValue(argument)
        }
        return value
    }
}

extension CLIArguments: Equatable {
    static func == (lhs: CLIArguments, rhs: CLIArguments) -> Bool {
        lhs.command == rhs.command
            && lhs.baseURL == rhs.baseURL
            && lhs.apiKey == rhs.apiKey
            && lhs.keyID == rhs.keyID
            && lhs.intervalSeconds == rhs.intervalSeconds
            && lhs.json == rhs.json
            && lhs.once == rhs.once
            && lhs.compact == rhs.compact
            && lhs.barMode == rhs.barMode
            && lhs.theme == rhs.theme
            && lhs.noColor == rhs.noColor
    }
}

enum CLIArgumentOption: Hashable {
    case baseURL
    case apiKey
    case interval
    case noColor
}
