import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@testable import UsageMonitorCore
@testable import UsageMonitor

enum UsageMonitorTestFixtures {
    static let invalidUsageJSON = """
    {
      "isValid": false,
      "mode": "api-key",
      "model_stats": [],
      "planName": "Free",
      "remaining": 0,
      "subscription": {
        "daily_usage_usd": 0,
        "daily_limit_usd": 0,
        "weekly_usage_usd": 0,
        "weekly_limit_usd": 0,
        "monthly_usage_usd": 0,
        "monthly_limit_usd": 0,
        "expires_at": null
      },
      "unit": "usd",
      "usage": {
        "today": 0,
        "total": 0,
        "average_duration_ms": 0,
        "rpm": 0,
        "tpm": 0
      }
    }
    """
}

final class RequestRecordingLoader: Sub2APIRequestLoading {
    struct Response {
        var statusCode: Int
        var body: String
    }

    var requests: [URLRequest] = []
    var responses: [Response] = []
    var thrownError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if let thrownError {
            throw thrownError
        }
        let response = responses.removeFirst()
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(response.body.utf8), httpResponse)
    }
}

final class ManualTimerFactory: RefreshTimerFactory {
    private(set) var scheduledIntervals: [TimeInterval] = []
    private(set) var timers: [ManualRefreshTimer] = []

    func schedule(interval: TimeInterval, action: @escaping @Sendable () -> Void) -> RefreshTimer {
        scheduledIntervals.append(interval)
        let timer = ManualRefreshTimer(action: action)
        timers.append(timer)
        return timer
    }
}

final class ManualRefreshTimer: RefreshTimer {
    private let action: @Sendable () -> Void
    private(set) var isInvalidated = false

    init(action: @escaping @Sendable () -> Void = {}) {
        self.action = action
    }

    func invalidate() {
        isInvalidated = true
    }

    func fire() {
        guard !isInvalidated else { return }
        action()
    }
}

actor BlockingRequestLoader: Sub2APIRequestLoading {
    struct Response {
        var statusCode: Int
        var body: String
    }

    private var requests: [URLRequest] = []
    private var continuation: CheckedContinuation<(Data, URLResponse), Error>?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func requestCount() -> Int {
        requests.count
    }

    func lastRequest() -> URLRequest? {
        requests.last
    }

    func resume(statusCode: Int = 200, body: String) {
        guard let request = requests.last, let continuation else { return }
        self.continuation = nil
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        continuation.resume(returning: (Data(body.utf8), response))
    }

    func fail(_ error: Error) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: error)
    }
}
