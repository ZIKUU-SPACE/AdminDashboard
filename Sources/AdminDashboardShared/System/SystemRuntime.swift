// ~/workspace/AdminDashboard/Sources/AdminDashboardShared/SystemRuntime.swift

import Foundation

/// Describes the execution environment of AdminDashboardService.
///
/// Container runtime refers to the environment containing the
/// service process, not container software installed on the host.
public struct SystemRuntime: Codable, Sendable, Equatable {

    public let initSystem: String?
    public let containerRuntime: String?
    public let execution: String
    public let architecture: String
    public let cgroup: String?

    private enum CodingKeys: String, CodingKey {
        case initSystem = "init_system"
        case containerRuntime = "container_runtime"
        case execution
        case architecture
        case cgroup
    }

    public init(
        initSystem: String?,
        containerRuntime: String?,
        execution: String,
        architecture: String,
        cgroup: String?
    ) {
        self.initSystem = initSystem
        self.containerRuntime = containerRuntime
        self.execution = execution
        self.architecture = architecture
        self.cgroup = cgroup
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            initSystem,
            forKey: .initSystem
        )

        try container.encode(
            containerRuntime,
            forKey: .containerRuntime
        )

        try container.encode(
            execution,
            forKey: .execution
        )

        try container.encode(
            architecture,
            forKey: .architecture
        )

        try container.encode(
            cgroup,
            forKey: .cgroup
        )
    }
}