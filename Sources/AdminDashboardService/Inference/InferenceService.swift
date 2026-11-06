
// ~/workspace/AdminDashboard/Sources/AdminDashboardService/InferenceService.swift

import Foundation
import AdminDashboardShared

/// Provides inference backend management operations.
///
/// Combines backend configuration with runtime status.
/// Individual runtime status failures are represented as "unknown",
/// while backend listing failures are propagated to the caller.
struct InferenceService: Sendable {

    // MARK: - Dependencies

    private let client: InferenceBrokerClient

    init(
        client: InferenceBrokerClient = InferenceBrokerClient()
    ) {
        self.client = client
    }

    // MARK: - Backend Listing

    func backends() async throws -> InferenceBackendsResponse {
        let configurations = try await client.fetchBackends()

        let names = configurations.keys.sorted()

        let statuses = await fetchRuntimeStatuses(
            backendNames: names
        )

        let backends = names.compactMap { name -> InferenceBackend? in
            guard let configuration = configurations[name] else {
                return nil
            }

            return InferenceBackend(
                name: name,
                node: configuration.node,
                url: configuration.url,
                kind: configuration.kind,
                model: configuration.model,
                runtime: configuration.runtime,
                status: statuses[name] ?? "unknown"
            )
        }

        return InferenceBackendsResponse(
            backends: backends
        )
    }

    // MARK: - Runtime Status

    /// Fetches runtime statuses concurrently.
    ///
    /// Failure of one status request does not prevent other
    /// backends from being returned.
    private func fetchRuntimeStatuses(
        backendNames: [String]
    ) async -> [String: String] {
        let client = self.client

        return await withTaskGroup(
            of: (String, String).self,
            returning: [String: String].self
        ) { group in

            for name in backendNames {
                group.addTask {
                    do {
                        let status = try await
                            client.fetchRuntimeStatus(
                                backendName: name
                            )

                        return (name, status)
                    } catch {
                        return (name, "unknown")
                    }
                }
            }

            var statuses: [String: String] = [:]

            for await (name, status) in group {
                statuses[name] = status
            }

            return statuses
        }
    }

    // MARK: - Runtime Actions

    func startBackend(
        _ backendName: String
    ) async throws -> InferenceRuntimeActionResponse {
        let status = try await client.startBackend(
            backendName
        )

        return InferenceRuntimeActionResponse(
            backend: backendName,
            status: status
        )
    }

    func stopBackend(
        _ backendName: String
    ) async throws -> InferenceRuntimeActionResponse {
        let status = try await client.stopBackend(
            backendName
        )

        return InferenceRuntimeActionResponse(
            backend: backendName,
            status: status
        )
    }
}
