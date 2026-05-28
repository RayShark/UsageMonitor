import Foundation

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

struct InteractiveTerminal {
    var readLine: () -> String?
    var write: (String) -> Void
    var clearScreen: () -> Void
    var isTTY: () -> Bool

    static let standard = InteractiveTerminal(
        readLine: { Swift.readLine() },
        write: { print($0) },
        clearScreen: {
            print("\u{001B}[2J\u{001B}[H", terminator: "")
            fflush(stdout)
        },
        isTTY: {
            isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
        }
    )
}

enum InteractiveMode {
    case auto
    case setup
    case config
}
