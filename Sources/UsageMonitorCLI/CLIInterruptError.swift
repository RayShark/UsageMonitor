struct CLIInterruptError: Error, Equatable {
    let signalNumber: Int32

    var exitCode: Int32 {
        128 + signalNumber
    }
}
