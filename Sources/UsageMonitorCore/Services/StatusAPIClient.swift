import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

package protocol StatusAPIRequestLoading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: StatusAPIRequestLoading {}

package protocol ServiceStatusFetching {
    func fetchStatus() async throws -> StatusAPIResult
}

package struct StatusAPIResult: Equatable {
    package let response: ServiceStatusResponse
    package let prettyRawJSON: String

    package init(response: ServiceStatusResponse, prettyRawJSON: String) {
        self.response = response
        self.prettyRawJSON = prettyRawJSON
    }
}

package enum StatusAPIClientError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int, String?)
    case decoding
    case network(String)

    package var userMessage: String {
        switch self {
        case .invalidResponse, .decoding:
            return "状态响应格式异常"
        case let .httpStatus(status, message):
            if let message, !message.isEmpty {
                return message
            }
            return "状态接口 HTTP \(status)"
        case .network:
            return "状态请求失败"
        }
    }
}

package final class StatusAPIClient: ServiceStatusFetching {
    package static let endpoint = URL(string: "https://status.input.im/api/status")!

    private let requestLoader: StatusAPIRequestLoading
    private let decoder = JSONDecoder.serviceStatus

    package init(requestLoader: StatusAPIRequestLoading = URLSession.shared) {
        self.requestLoader = requestLoader
    }

    package func fetchStatus() async throws -> StatusAPIResult {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await requestLoader.data(for: request)
        } catch let error as StatusAPIClientError {
            throw error
        } catch {
            throw StatusAPIClientError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StatusAPIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw StatusAPIClientError.httpStatus(httpResponse.statusCode, decodeMessage(from: data))
        }

        do {
            let decoded = try decoder.decode(ServiceStatusResponse.self, from: data)
            return StatusAPIResult(response: decoded, prettyRawJSON: prettyJSONString(from: data))
        } catch {
            throw StatusAPIClientError.decoding
        }
    }

    private func decodeMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["message"] as? String,
            !message.isEmpty
        else {
            return nil
        }
        return message
    }

    private func prettyJSONString(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            ),
            let prettyText = String(data: prettyData, encoding: .utf8)
        else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return prettyText
    }
}
