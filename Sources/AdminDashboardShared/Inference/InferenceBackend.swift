
// ~/workspace/AdminDashboard/Sources/AdminDashboardShared/InferenceBackend.swift

import Foundation

/// An inference backend managed by Inference Broker.
///
/// The status is retrieved separately from the backend's
/// runtime status endpoint.
public struct InferenceBackend: Codable, Sendable, Equatable {

    public let name: String
    public let node: String?
    public let url: String?
    public let kind: String?
    public let model: String?
    public let runtime: String?
    public let status: String

    public init(
        name: String,
        node: String? = nil,
        url: String? = nil,
        kind: String? = nil,
        model: String? = nil,
        runtime: String? = nil,
        status: String = "unknown"
    ) {
        self.name = name
        self.node = node
        self.url = url
        self.kind = kind
        self.model = model
        self.runtime = runtime
        self.status = status
    }
}

/// Response from GET /api/inference/backends.
public struct InferenceBackendsResponse:
    Codable, Sendable, Equatable {

    public let backends: [InferenceBackend]

    public init(backends: [InferenceBackend]) {
        self.backends = backends
    }
}

/// Response from a backend runtime start or stop action.
public struct InferenceRuntimeActionResponse:
    Codable, Sendable, Equatable {

    public let backend: String
    public let status: String

    public init(
        backend: String,
        status: String
    ) {
        self.backend = backend
        self.status = status
    }
}
