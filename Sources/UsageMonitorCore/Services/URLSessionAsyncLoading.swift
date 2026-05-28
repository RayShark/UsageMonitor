import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking

private final class URLSessionTaskCancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var isCancelled = false

    // Cancellation can arrive before the continuation creates its URLSession task.
    func setTask(_ task: URLSessionDataTask) {
        lock.lock()
        defer { lock.unlock() }

        if isCancelled {
            task.cancel()
        } else {
            self.task = task
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let task = task
        lock.unlock()

        task?.cancel()
    }
}

extension URLSession {
    package func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let cancellation = URLSessionTaskCancellationBox()

        return try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    let task = dataTask(with: request) { data, response, error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }

                        guard let data, let response else {
                            continuation.resume(throwing: URLError(.badServerResponse))
                            return
                        }

                        continuation.resume(returning: (data, response))
                    }
                    cancellation.setTask(task)
                    task.resume()
                }
            },
            onCancel: {
                cancellation.cancel()
            }
        )
    }
}
#endif
