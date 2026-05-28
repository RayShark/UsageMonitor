import Foundation

enum TerminalScreen {
    static let clearAndHome = "\u{001B}[2J\u{001B}[H"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"

    static func frame(_ text: String, clear: Bool) -> String {
        clear ? clearAndHome + text : text
    }
}
