import Foundation

#if canImport(Glibc)
import Glibc

private let terminalStdin = STDIN_FILENO
private func terminalIsTTY(_ fileDescriptor: Int32) -> Bool { isatty(fileDescriptor) == 1 }
private func terminalGetFlags(_ fileDescriptor: Int32) -> Int32 { fcntl(fileDescriptor, F_GETFL) }
private func terminalSetFlags(_ fileDescriptor: Int32, _ flags: Int32) -> Bool { fcntl(fileDescriptor, F_SETFL, flags) == 0 }
private func terminalRead(_ fileDescriptor: Int32, _ byte: inout UInt8) -> Int { read(fileDescriptor, &byte, 1) }
private func terminalCreatePipe(_ descriptors: inout [Int32]) -> Int32 { pipe(&descriptors) }
private func terminalWriteSignal(_ fileDescriptor: Int32, _ byte: UInt8) { var byte = byte; _ = write(fileDescriptor, &byte, 1) }
private func terminalClose(_ fileDescriptor: Int32) { _ = close(fileDescriptor) }
#elseif canImport(Darwin)
import Darwin

private let terminalStdin = STDIN_FILENO
private func terminalIsTTY(_ fileDescriptor: Int32) -> Bool { isatty(fileDescriptor) == 1 }
private func terminalGetFlags(_ fileDescriptor: Int32) -> Int32 { fcntl(fileDescriptor, F_GETFL) }
private func terminalSetFlags(_ fileDescriptor: Int32, _ flags: Int32) -> Bool { fcntl(fileDescriptor, F_SETFL, flags) == 0 }
private func terminalRead(_ fileDescriptor: Int32, _ byte: inout UInt8) -> Int { read(fileDescriptor, &byte, 1) }
private func terminalCreatePipe(_ descriptors: inout [Int32]) -> Int32 { pipe(&descriptors) }
private func terminalWriteSignal(_ fileDescriptor: Int32, _ byte: UInt8) { var byte = byte; _ = write(fileDescriptor, &byte, 1) }
private func terminalClose(_ fileDescriptor: Int32) { _ = close(fileDescriptor) }
#endif

#if canImport(Glibc) || canImport(Darwin)
final class TerminalBarKeyboardReader: BarKeyboardReading {
    private let fileDescriptor: Int32
    private var originalTermios: termios
    private let originalFlags: Int32
    private var isActive = false

    private static var installedSignalHandlers = false
    private static var signalPipeReadDescriptor: Int32 = -1
    private static var signalPipeWriteDescriptor: Int32 = -1

    static func standard() -> TerminalBarKeyboardReader? {
        TerminalBarKeyboardReader(fileDescriptor: terminalStdin)
    }

    private init?(fileDescriptor: Int32) {
        guard terminalIsTTY(fileDescriptor) else {
            return nil
        }

        var currentTermios = termios()
        guard tcgetattr(fileDescriptor, &currentTermios) == 0 else {
            return nil
        }

        let currentFlags = terminalGetFlags(fileDescriptor)
        guard currentFlags >= 0 else {
            return nil
        }

        self.fileDescriptor = fileDescriptor
        self.originalTermios = currentTermios
        self.originalFlags = currentFlags

        var rawTermios = currentTermios
        rawTermios.c_lflag &= ~tcflag_t(ECHO)
        rawTermios.c_lflag &= ~tcflag_t(ICANON)

        guard tcsetattr(fileDescriptor, TCSANOW, &rawTermios) == 0 else {
            return nil
        }
        guard terminalSetFlags(fileDescriptor, currentFlags | O_NONBLOCK) else {
            var termios = currentTermios
            _ = tcsetattr(fileDescriptor, TCSANOW, &termios)
            return nil
        }
        guard Self.installSignalNotification() else {
            var termios = currentTermios
            _ = tcsetattr(fileDescriptor, TCSANOW, &termios)
            _ = terminalSetFlags(fileDescriptor, currentFlags)
            return nil
        }

        isActive = true
    }

    func readAction() -> BarKeyboardAction? {
        var byte = UInt8(0)
        guard terminalRead(fileDescriptor, &byte) == 1 else {
            return nil
        }
        return BarKeyboardAction.parse(byte: byte)
    }

    func receivedTerminationSignal() -> Int32? {
        guard Self.signalPipeReadDescriptor >= 0 else {
            return nil
        }

        var byte = UInt8(0)
        guard terminalRead(Self.signalPipeReadDescriptor, &byte) == 1 else {
            return nil
        }
        return Int32(byte)
    }

    func restore() {
        guard isActive else { return }
        var termios = originalTermios
        _ = tcsetattr(fileDescriptor, TCSANOW, &termios)
        _ = terminalSetFlags(fileDescriptor, originalFlags)
        isActive = false
        Self.clearSignalNotification()
    }

    deinit {
        restore()
    }

    private static func installSignalNotification() -> Bool {
        guard !installedSignalHandlers else { return true }
        guard installSignalPipe() else { return false }
        installedSignalHandlers = true
        signal(SIGINT, signalHandler)
        signal(SIGTERM, signalHandler)
        return true
    }

    private static func installSignalPipe() -> Bool {
        var descriptors = [Int32](repeating: -1, count: 2)
        guard terminalCreatePipe(&descriptors) == 0 else {
            return false
        }

        let readFlags = terminalGetFlags(descriptors[0])
        let writeFlags = terminalGetFlags(descriptors[1])
        guard readFlags >= 0,
              writeFlags >= 0,
              terminalSetFlags(descriptors[0], readFlags | O_NONBLOCK),
              terminalSetFlags(descriptors[1], writeFlags | O_NONBLOCK) else {
            terminalClose(descriptors[0])
            terminalClose(descriptors[1])
            return false
        }

        signalPipeReadDescriptor = descriptors[0]
        signalPipeWriteDescriptor = descriptors[1]
        return true
    }

    private static func clearSignalNotification() {
        guard installedSignalHandlers else { return }
        signal(SIGINT, SIG_DFL)
        signal(SIGTERM, SIG_DFL)
        installedSignalHandlers = false

        if signalPipeReadDescriptor >= 0 {
            terminalClose(signalPipeReadDescriptor)
            signalPipeReadDescriptor = -1
        }
        if signalPipeWriteDescriptor >= 0 {
            terminalClose(signalPipeWriteDescriptor)
            signalPipeWriteDescriptor = -1
        }
    }

    // Signal handlers may only do async-signal-safe work; the main loop restores the terminal.
    private static let signalHandler: @convention(c) (Int32) -> Void = { signalNumber in
        let writeDescriptor = signalPipeWriteDescriptor
        guard writeDescriptor >= 0 else { return }
        terminalWriteSignal(writeDescriptor, UInt8(truncatingIfNeeded: signalNumber))
    }
}
#else
final class TerminalBarKeyboardReader: BarKeyboardReading {
    static func standard() -> TerminalBarKeyboardReader? { nil }
    func readAction() -> BarKeyboardAction? { nil }
    func receivedTerminationSignal() -> Int32? { nil }
    func restore() {}
}
#endif
