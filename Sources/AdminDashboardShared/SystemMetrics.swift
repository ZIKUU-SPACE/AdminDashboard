
 // ~/workspace/AdminDashboard/Sources/AdminDashboardShared/SystemMetrics.swift
import Foundation

public struct Metric: Codable, Sendable, Equatable {
    public let value: Double?
    public let unit: String
    public let detail: String?

    public init(
        value: Double?,
        unit: String,
        detail: String? = nil
    ) {
        self.value = value
        self.unit = unit
        self.detail = detail
    }

    // MARK: - Encoding

    private enum CodingKeys: String, CodingKey {
        case value
        case unit
        case detail
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            value,
            forKey: .value
        )

        try container.encode(
            unit,
            forKey: .unit
        )

        try container.encode(
            detail,
            forKey: .detail
        )
    }
}

public struct SystemMetrics: Codable, Sendable, Equatable {
    public let cpu: Metric
    public let memory: Metric
    public let disk: Metric
    public let gpu: Metric

    public init(
        cpu: Metric,
        memory: Metric,
        disk: Metric,
        gpu: Metric
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.gpu = gpu
    }

    public static let empty = SystemMetrics(
        cpu: Metric(value: nil, unit: "%"),
        memory: Metric(value: nil, unit: "%"),
        disk: Metric(value: nil, unit: "%"),
        gpu: Metric(value: nil, unit: "%")
    )
}
