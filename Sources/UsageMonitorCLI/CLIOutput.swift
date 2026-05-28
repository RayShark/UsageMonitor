import Foundation

struct CLIOutput {
    var write: (String) -> Void
    var writeError: (String) -> Void

    static let standard = CLIOutput(
        write: { print($0) },
        writeError: { message in
            FileHandle.standardError.write(Data((message + "\n").utf8))
        }
    )
}
