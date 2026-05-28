import Foundation
import UsageMonitorCore

enum BarMode: String, Codable, Equatable {
    case lite
    case detail
    case oneline
}

enum TerminalColorMode: Equatable {
    case noColor
    case ansi256
    case trueColor

    static func detected(environment: [String: String] = ProcessInfo.processInfo.environment) -> TerminalColorMode {
        if let override = environment["USAGE_MONITOR_COLOR_MODE"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            switch override {
            case "none", "no-color":
                return .noColor
            case "ansi256", "ansi-256", "256", "256color", "256-color":
                return .ansi256
            case "rgb", "truecolor", "24bit", "24-bit":
                return .trueColor
            default:
                break
            }
        }

        if environment["NO_COLOR"] != nil {
            return .noColor
        }

        if let termProgram = environment["TERM_PROGRAM"], termProgram == "Apple_Terminal" {
            return .ansi256
        }

        if let colorTerm = environment["COLORTERM"]?.lowercased(),
           colorTerm.contains("truecolor") || colorTerm.contains("24bit") || colorTerm.contains("24-bit") {
            return .trueColor
        }

        if let term = environment["TERM"]?.lowercased(),
           term.contains("truecolor") || term.contains("24bit") || term.contains("24-bit") || term.contains("-direct") {
            return .trueColor
        }

        return .trueColor
    }
}

struct RGBColor: Equatable {
    let red: Int
    let green: Int
    let blue: Int
}

struct ThemePalette: Equatable {
    let ok: RGBColor
    let warn: RGBColor
    let err: RGBColor
    let dim: RGBColor
    let accent: RGBColor
}

enum CLITheme: String, Codable, Equatable {
    case contrast
    case classic
    case mono
    case dracula
    case catppuccin
    case tokyonight
    case nord
    case gruvbox

    func color(
        _ text: String,
        for kind: ServiceStatusCellKind,
        colorMode: TerminalColorMode = .detected()
    ) -> String {
        switch self {
        case .contrast:
            return contrastColor(text, for: kind)
        case .classic:
            return classicColor(text, for: kind)
        case .mono:
            return monoColor(text, for: kind)
        case .dracula, .catppuccin, .tokyonight, .nord, .gruvbox:
            return color(text, rgb: rgb(for: kind), colorMode: colorMode)
        }
    }

    var palette: ThemePalette {
        switch self {
        case .contrast:
            return ThemePalette(
                ok: RGBColor(red: 35, green: 215, blue: 95),
                warn: RGBColor(red: 255, green: 175, blue: 0),
                err: RGBColor(red: 255, green: 95, blue: 95),
                dim: RGBColor(red: 128, green: 128, blue: 128),
                accent: RGBColor(red: 95, green: 215, blue: 255)
            )
        case .classic:
            return ThemePalette(
                ok: RGBColor(red: 0, green: 170, blue: 0),
                warn: RGBColor(red: 170, green: 120, blue: 0),
                err: RGBColor(red: 170, green: 0, blue: 0),
                dim: RGBColor(red: 128, green: 128, blue: 128),
                accent: RGBColor(red: 0, green: 120, blue: 170)
            )
        case .mono:
            return ThemePalette(
                ok: RGBColor(red: 230, green: 230, blue: 230),
                warn: RGBColor(red: 230, green: 230, blue: 230),
                err: RGBColor(red: 230, green: 230, blue: 230),
                dim: RGBColor(red: 128, green: 128, blue: 128),
                accent: RGBColor(red: 230, green: 230, blue: 230)
            )
        case .dracula:
            return ThemePalette(
                ok: RGBColor(red: 80, green: 250, blue: 123),
                warn: RGBColor(red: 241, green: 250, blue: 140),
                err: RGBColor(red: 255, green: 85, blue: 85),
                dim: RGBColor(red: 98, green: 114, blue: 164),
                accent: RGBColor(red: 139, green: 233, blue: 253)
            )
        case .catppuccin:
            return ThemePalette(
                ok: RGBColor(red: 166, green: 227, blue: 161),
                warn: RGBColor(red: 249, green: 226, blue: 175),
                err: RGBColor(red: 243, green: 139, blue: 168),
                dim: RGBColor(red: 147, green: 153, blue: 178),
                accent: RGBColor(red: 137, green: 180, blue: 250)
            )
        case .tokyonight:
            return ThemePalette(
                ok: RGBColor(red: 158, green: 206, blue: 106),
                warn: RGBColor(red: 224, green: 175, blue: 104),
                err: RGBColor(red: 247, green: 118, blue: 142),
                dim: RGBColor(red: 86, green: 95, blue: 137),
                accent: RGBColor(red: 125, green: 207, blue: 255)
            )
        case .nord:
            return ThemePalette(
                ok: RGBColor(red: 163, green: 190, blue: 140),
                warn: RGBColor(red: 235, green: 203, blue: 139),
                err: RGBColor(red: 191, green: 97, blue: 106),
                dim: RGBColor(red: 76, green: 86, blue: 106),
                accent: RGBColor(red: 136, green: 192, blue: 208)
            )
        case .gruvbox:
            return ThemePalette(
                ok: RGBColor(red: 184, green: 187, blue: 38),
                warn: RGBColor(red: 250, green: 189, blue: 47),
                err: RGBColor(red: 251, green: 73, blue: 52),
                dim: RGBColor(red: 146, green: 131, blue: 116),
                accent: RGBColor(red: 131, green: 165, blue: 152)
            )
        }
    }

    private func rgb(for kind: ServiceStatusCellKind) -> RGBColor {
        switch kind {
        case .green:
            return palette.ok
        case .yellow:
            return palette.warn
        case .red:
            return palette.err
        case .gray:
            return palette.dim
        }
    }

    private func color(_ text: String, rgb: RGBColor, colorMode: TerminalColorMode) -> String {
        switch colorMode {
        case .noColor:
            return text
        case .trueColor:
            return "\u{001B}[38;2;\(rgb.red);\(rgb.green);\(rgb.blue)m\(text)\u{001B}[0m"
        case .ansi256:
            return "\u{001B}[38;5;\(rgbToAnsi256(rgb))m\(text)\u{001B}[0m"
        }
    }

    private func rgbToAnsi256(_ rgb: RGBColor) -> Int {
        let red = cubeIndex(rgb.red)
        let green = cubeIndex(rgb.green)
        let blue = cubeIndex(rgb.blue)
        return 16 + (36 * red) + (6 * green) + blue
    }

    private func cubeIndex(_ value: Int) -> Int {
        switch value {
        case ...47:
            return 0
        case 48...114:
            return 1
        default:
            return min(5, (value - 35) / 40)
        }
    }

    private func contrastColor(_ text: String, for kind: ServiceStatusCellKind) -> String {
        switch kind {
        case .green:
            return "\u{001B}[92m\(text)\u{001B}[0m"
        case .yellow:
            return "\u{001B}[38;5;214m\(text)\u{001B}[0m"
        case .red:
            return "\u{001B}[91m\(text)\u{001B}[0m"
        case .gray:
            return "\u{001B}[90m\(text)\u{001B}[0m"
        }
    }

    private func classicColor(_ text: String, for kind: ServiceStatusCellKind) -> String {
        switch kind {
        case .green:
            return "\u{001B}[32m\(text)\u{001B}[0m"
        case .yellow:
            return "\u{001B}[33m\(text)\u{001B}[0m"
        case .red:
            return "\u{001B}[31m\(text)\u{001B}[0m"
        case .gray:
            return "\u{001B}[90m\(text)\u{001B}[0m"
        }
    }

    private func monoColor(_ text: String, for kind: ServiceStatusCellKind) -> String {
        switch kind {
        case .green, .yellow, .red:
            return "\u{001B}[97m\(text)\u{001B}[0m"
        case .gray:
            return "\u{001B}[90m\(text)\u{001B}[0m"
        }
    }
}
