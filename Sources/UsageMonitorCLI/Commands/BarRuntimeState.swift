import Foundation

enum BarKeyboardAction: Equatable {
    case mode(BarMode)
    case nextTheme

    static func parse(byte: UInt8) -> BarKeyboardAction? {
        switch byte {
        case UInt8(ascii: "o"), UInt8(ascii: "O"):
            return .mode(.oneline)
        case UInt8(ascii: "d"), UInt8(ascii: "D"):
            return .mode(.detail)
        case UInt8(ascii: "l"), UInt8(ascii: "L"):
            return .mode(.lite)
        case UInt8(ascii: "c"), UInt8(ascii: "C"):
            return .nextTheme
        default:
            return nil
        }
    }
}

protocol BarKeyboardReading: AnyObject {
    func readAction() -> BarKeyboardAction?
    func receivedTerminationSignal() -> Int32?
    func restore()
}

struct BarRuntimeState: Equatable {
    var mode: BarMode
    var theme: CLITheme

    mutating func apply(_ action: BarKeyboardAction) {
        switch action {
        case .mode(let nextMode):
            mode = nextMode
        case .nextTheme:
            theme = Self.nextTheme(after: theme)
        }
    }

    private static func nextTheme(after theme: CLITheme) -> CLITheme {
        let themes: [CLITheme] = [
            .contrast,
            .classic,
            .mono,
            .dracula,
            .catppuccin,
            .tokyonight,
            .nord,
            .gruvbox,
        ]
        guard let index = themes.firstIndex(of: theme) else {
            return themes[0]
        }
        return themes[(index + 1) % themes.count]
    }
}
