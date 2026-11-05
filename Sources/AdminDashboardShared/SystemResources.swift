// ~/workspace/AdminDashboard/Sources/AdminDashboardShared/SystemResources.swift

import Foundation

// MARK: - CPU

public struct CPUResourceDetails: Codable, Sendable, Equatable {
    public let usagePercent: Double
    public let physicalCores: Int?
    public let logicalCores: Int?
    public let loadAverage1m: Double?
    public let loadAverage5m: Double?
    public let loadAverage15m: Double?

    enum CodingKeys: String, CodingKey {
        case usagePercent = "usage_percent"
        case physicalCores = "physical_cores"
        case logicalCores = "logical_cores"
        case loadAverage1m = "load_average_1m"
        case loadAverage5m = "load_average_5m"
        case loadAverage15m = "load_average_15m"
    }

    public init(
        usagePercent: Double,
        physicalCores: Int?,
        logicalCores: Int?,
        loadAverage1m: Double?,
        loadAverage5m: Double?,
        loadAverage15m: Double?
    ) {
        self.usagePercent = usagePercent
        self.physicalCores = physicalCores
        self.logicalCores = logicalCores
        self.loadAverage1m = loadAverage1m
        self.loadAverage5m = loadAverage5m
        self.loadAverage15m = loadAverage15m
    }
}

// MARK: - Memory

public struct MemoryResourceDetails: Codable, Sendable, Equatable {
    public let totalGiB: Double
    public let usedGiB: Double
    public let availableGiB: Double
    public let cachedGiB: Double?
    public let usagePercent: Double

    enum CodingKeys: String, CodingKey {
        case totalGiB = "total_gib"
        case usedGiB = "used_gib"
        case availableGiB = "available_gib"
        case cachedGiB = "cached_gib"
        case usagePercent = "usage_percent"
    }

    public init(
        totalGiB: Double,
        usedGiB: Double,
        availableGiB: Double,
        cachedGiB: Double?,
        usagePercent: Double
    ) {
        self.totalGiB = totalGiB
        self.usedGiB = usedGiB
        self.availableGiB = availableGiB
        self.cachedGiB = cachedGiB
        self.usagePercent = usagePercent
    }
}

// MARK: - Swap

public struct SwapResourceDetails: Codable, Sendable, Equatable {
    public let totalGiB: Double
    public let usedGiB: Double
    public let freeGiB: Double
    public let usagePercent: Double

    enum CodingKeys: String, CodingKey {
        case totalGiB = "total_gib"
        case usedGiB = "used_gib"
        case freeGiB = "free_gib"
        case usagePercent = "usage_percent"
    }

    public init(
        totalGiB: Double,
        usedGiB: Double,
        freeGiB: Double,
        usagePercent: Double
    ) {
        self.totalGiB = totalGiB
        self.usedGiB = usedGiB
        self.freeGiB = freeGiB
        self.usagePercent = usagePercent
    }
}

// MARK: - Disk

public struct DiskResourceDetails: Codable, Sendable, Equatable {
    public let totalGiB: Double
    public let usedGiB: Double
    public let freeGiB: Double
    public let usagePercent: Double

    enum CodingKeys: String, CodingKey {
        case totalGiB = "total_gib"
        case usedGiB = "used_gib"
        case freeGiB = "free_gib"
        case usagePercent = "usage_percent"
    }

    public init(
        totalGiB: Double,
        usedGiB: Double,
        freeGiB: Double,
        usagePercent: Double
    ) {
        self.totalGiB = totalGiB
        self.usedGiB = usedGiB
        self.freeGiB = freeGiB
        self.usagePercent = usagePercent
    }
}

// MARK: - GPU

public struct GPUResourceDetails: Codable, Sendable, Equatable {
    public let device: String?
    public let usagePercent: Double?

    enum CodingKeys: String, CodingKey {
        case device
        case usagePercent = "usage_percent"
    }

    public init(
        device: String?,
        usagePercent: Double?
    ) {
        self.device = device
        self.usagePercent = usagePercent
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(device, forKey: .device)
        try container.encode(usagePercent, forKey: .usagePercent)
    }
}

// MARK: - System Resources

public struct SystemResources: Codable, Sendable, Equatable {
    public let cpu: CPUResourceDetails
    public let memory: MemoryResourceDetails
    public let swap: SwapResourceDetails
    public let disk: DiskResourceDetails
    public let gpu: GPUResourceDetails

    public init(
        cpu: CPUResourceDetails,
        memory: MemoryResourceDetails,
        swap: SwapResourceDetails,
        disk: DiskResourceDetails,
        gpu: GPUResourceDetails
    ) {
        self.cpu = cpu
        self.memory = memory
        self.swap = swap
        self.disk = disk
        self.gpu = gpu
    }
}
