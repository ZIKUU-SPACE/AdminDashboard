
// ~/workspace/AdminDashboard/Sources/AdminDashboardShared/HostInformation.swift

import Foundation

/// Basic information about the host running AdminDashboardService.
///
/// JSON field names are compatible with the existing Python backend's
/// GET /api/system/host response.
public struct HostInformation: Codable, Sendable, Equatable {

    public let hostname: String?
    public let osName: String?
    public let kernel: String?
    public let cpuModel: String?
    public let memoryTotalGiB: Double?
    public let uptimeSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case hostname
        case osName = "os_name"
        case kernel
        case cpuModel = "cpu_model"
        case memoryTotalGiB = "memory_total_gib"
        case uptimeSeconds = "uptime_seconds"
    }

    public init(
        hostname: String?,
        osName: String?,
        kernel: String?,
        cpuModel: String?,
        memoryTotalGiB: Double?,
        uptimeSeconds: Double?
    ) {
        self.hostname = hostname
        self.osName = osName
        self.kernel = kernel
        self.cpuModel = cpuModel
        self.memoryTotalGiB = memoryTotalGiB
        self.uptimeSeconds = uptimeSeconds
    }

    /// Encodes unavailable values explicitly as JSON null,
    /// matching the existing Python API response.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(hostname, forKey: .hostname)
        try container.encode(osName, forKey: .osName)
        try container.encode(kernel, forKey: .kernel)
        try container.encode(cpuModel, forKey: .cpuModel)
        try container.encode(memoryTotalGiB, forKey: .memoryTotalGiB)
        try container.encode(uptimeSeconds, forKey: .uptimeSeconds)
    }
}
