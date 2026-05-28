import Foundation

package struct ServiceStatusResponse: Codable, Equatable {
    package let allOK: Bool
    package let generatedAt: TimeInterval
    package let services: [ServiceStatusService]

    enum CodingKeys: String, CodingKey {
        case allOK = "all_ok"
        case generatedAt = "generated_at"
        case services
    }

    package init(allOK: Bool, generatedAt: TimeInterval, services: [ServiceStatusService]) {
        self.allOK = allOK
        self.generatedAt = generatedAt
        self.services = services
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allOK = try container.decode(Bool.self, forKey: .allOK)
        generatedAt = try container.decodeStatusTimeInterval(forKey: .generatedAt)
        services = try container.decodeIfPresent([ServiceStatusService].self, forKey: .services) ?? []
    }

    package func service(model: String) -> ServiceStatusService? {
        services.first { $0.model == model }
    }

    package func timelineRows(for models: [String], count: Int = 60) -> [ServiceStatusTimelineRow] {
        models.map { model in
            let service = service(model: model)
            return ServiceStatusTimelineRow(model: model, service: service, count: count)
        }
    }
}

package struct ServiceStatusService: Codable, Equatable {
    package let model: String
    package let uptimePct: Double?
    package let last: ServiceStatusProbe?
    package let history: [ServiceStatusProbe]

    enum CodingKeys: String, CodingKey {
        case model
        case uptimePct = "uptime_pct"
        case last
        case history
    }

    package init(
        model: String,
        uptimePct: Double?,
        last: ServiceStatusProbe?,
        history: [ServiceStatusProbe]
    ) {
        self.model = model
        self.uptimePct = uptimePct
        self.last = last
        self.history = history
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decode(String.self, forKey: .model)
        uptimePct = try container.decodeStatusDoubleIfPresent(forKey: .uptimePct)
        last = try container.decodeIfPresent(ServiceStatusProbe.self, forKey: .last)
        history = try container.decodeIfPresent([ServiceStatusProbe].self, forKey: .history) ?? []
    }

    package func latestDisplayCells(count: Int = 8) -> [ServiceStatusDisplayCell] {
        let recentHistory = history.suffix(count).map {
            ServiceStatusDisplayCell(kind: ServiceStatusCellKind.classify($0), probe: $0)
        }
        let missingCount = max(0, count - recentHistory.count)
        let missingCells = Array(repeating: ServiceStatusDisplayCell(kind: .gray, probe: nil), count: missingCount)
        return missingCells + recentHistory
    }
}

package struct ServiceStatusProbe: Codable, Equatable {
    package let ts: TimeInterval?
    package let ok: Bool?
    package let latencyMS: Int?
    package let error: String?

    enum CodingKeys: String, CodingKey {
        case ts
        case ok
        case latencyMS = "latency_ms"
        case error
    }

    package init(ts: TimeInterval?, ok: Bool?, latencyMS: Int?, error: String?) {
        self.ts = ts
        self.ok = ok
        self.latencyMS = latencyMS
        self.error = error
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ts = try container.decodeStatusTimeIntervalIfPresent(forKey: .ts)
        ok = try container.decodeIfPresent(Bool.self, forKey: .ok)
        latencyMS = try container.decodeStatusIntIfPresent(forKey: .latencyMS)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}

package struct ServiceStatusDisplayCell: Equatable {
    package let kind: ServiceStatusCellKind
    package let probe: ServiceStatusProbe?

    package init(kind: ServiceStatusCellKind, probe: ServiceStatusProbe?) {
        self.kind = kind
        self.probe = probe
    }

    package var helpText: String {
        guard let probe else { return "状态未知" }
        switch kind {
        case .green:
            return "正常 \(probe.latencyMS.map { "\($0) ms" } ?? "")".trimmingCharacters(in: .whitespaces)
        case .yellow:
            return "高延迟 \(probe.latencyMS.map { "\($0) ms" } ?? "")".trimmingCharacters(in: .whitespaces)
        case .red:
            if let error = probe.error, !error.isEmpty {
                return "失败：\(error)"
            }
            return "失败"
        case .gray:
            return "状态未知"
        }
    }
}

package struct ServiceStatusTimelineRow: Equatable, Identifiable {
    package let model: String
    package let service: ServiceStatusService?
    package let cells: [ServiceStatusDisplayCell]
    package let sampleCount: Int
    package let totalCount: Int

    package var id: String { model }

    package init(model: String, service: ServiceStatusService?, count: Int = 60) {
        self.model = model
        self.service = service
        cells = service?.latestDisplayCells(count: count)
            ?? Array(repeating: ServiceStatusDisplayCell(kind: .gray, probe: nil), count: count)
        sampleCount = service.map { min($0.history.count, count) } ?? 0
        totalCount = count
    }

    package var latestKind: ServiceStatusCellKind {
        ServiceStatusCellKind.classify(service?.last)
    }

    package var statusText: String {
        switch latestKind {
        case .green:
            return "在线"
        case .yellow:
            return "高延迟"
        case .red:
            return "失败"
        case .gray:
            return "缺少数据"
        }
    }

    package var uptimeText: String {
        service?.uptimePct.map { String(format: "%.2f%%", $0) } ?? "--"
    }

    package var samplesText: String {
        "\(sampleCount)/\(totalCount)"
    }
}

package enum ServiceStatusCellKind: Equatable {
    case green
    case yellow
    case red
    case gray

    package static func classify(_ probe: ServiceStatusProbe?) -> ServiceStatusCellKind {
        guard let probe, let ok = probe.ok else {
            return .gray
        }
        guard ok else {
            return .red
        }
        guard let latencyMS = probe.latencyMS else {
            return .gray
        }
        return latencyMS >= 3_000 ? .yellow : .green
    }
}

extension JSONDecoder {
    package static var serviceStatus: JSONDecoder {
        JSONDecoder()
    }
}

private extension KeyedDecodingContainer {
    func decodeStatusTimeInterval(forKey key: Key) throws -> TimeInterval {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return TimeInterval(value)
        }
        if let value = try? decode(String.self, forKey: key),
           let interval = TimeInterval(value) {
            return interval
        }
        return try decode(Double.self, forKey: key)
    }

    func decodeStatusTimeIntervalIfPresent(forKey key: Key) throws -> TimeInterval? {
        guard contains(key), !(try decodeNil(forKey: key)) else {
            return nil
        }
        return try decodeStatusTimeInterval(forKey: key)
    }

    func decodeStatusDoubleIfPresent(forKey key: Key) throws -> Double? {
        guard contains(key), !(try decodeNil(forKey: key)) else {
            return nil
        }
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decode(String.self, forKey: key),
           let double = Double(value) {
            return double
        }
        return try decode(Double.self, forKey: key)
    }

    func decodeStatusIntIfPresent(forKey key: Key) throws -> Int? {
        guard contains(key), !(try decodeNil(forKey: key)) else {
            return nil
        }
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decode(String.self, forKey: key),
           let double = Double(value) {
            return Int(double)
        }
        return try decode(Int.self, forKey: key)
    }
}
