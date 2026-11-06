
// ~/workspace/AdminDashboard/Sources/AdminDashboardService/main.swift

import Foundation
import Hummingbird
import AdminDashboardShared

// MARK: - HTTP Response Models

private struct HealthResponse: ResponseCodable {
    let status: String
}

private struct SystemMetricsResponse: ResponseCodable {
    let cpu: Metric
    let memory: Metric
    let disk: Metric
    let gpu: Metric

    init(_ metrics: SystemMetrics) {
        self.cpu = metrics.cpu
        self.memory = metrics.memory
        self.disk = metrics.disk
        self.gpu = metrics.gpu
    }
}

private struct HostInformationResponse: ResponseCodable {
    let hostname: String?
    let osName: String?
    let kernel: String?
    let cpuModel: String?
    let memoryTotalGiB: Double?
    let uptimeSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case hostname
        case osName = "os_name"
        case kernel
        case cpuModel = "cpu_model"
        case memoryTotalGiB = "memory_total_gib"
        case uptimeSeconds = "uptime_seconds"
    }

    init(_ information: HostInformation) {
        hostname = information.hostname
        osName = information.osName
        kernel = information.kernel
        cpuModel = information.cpuModel
        memoryTotalGiB = information.memoryTotalGiB
        uptimeSeconds = information.uptimeSeconds
    }
}

private struct SystemResourcesResponse: ResponseCodable {
    let cpu: CPUResourceDetails
    let memory: MemoryResourceDetails
    let swap: SwapResourceDetails
    let disk: DiskResourceDetails
    let gpu: GPUResourceDetails

    init(_ resources: SystemResources) {
        cpu = resources.cpu
        memory = resources.memory
        swap = resources.swap
        disk = resources.disk
        gpu = resources.gpu
    }
}

private struct SystemNetworkResponse: ResponseCodable {
    let interfaces: [NetworkInterfaceDetails]

    init(_ network: SystemNetwork) {
        interfaces = network.interfaces
    }
}

private struct SystemRuntimeResponse: ResponseCodable {
    let initSystem: String?
    let containerRuntime: String?
    let execution: String
    let architecture: String
    let cgroup: String?

    enum CodingKeys: String, CodingKey {
        case initSystem = "init_system"
        case containerRuntime = "container_runtime"
        case execution
        case architecture
        case cgroup
    }

    init(_ runtime: SystemRuntime) {
        initSystem = runtime.initSystem
        containerRuntime = runtime.containerRuntime
        execution = runtime.execution
        architecture = runtime.architecture
        cgroup = runtime.cgroup
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(initSystem, forKey: .initSystem)
        try container.encode(containerRuntime, forKey: .containerRuntime)
        try container.encode(execution, forKey: .execution)
        try container.encode(architecture, forKey: .architecture)
        try container.encode(cgroup, forKey: .cgroup)
    }
}

// MARK: - Storage Response Models

private struct StorageStatusHTTPResponse: ResponseCodable {
    let services: [StorageService]

    init(_ response: StorageStatusResponse) {
        services = response.services
    }
}

// MARK: - Inference Response Models

private struct InferenceBackendsHTTPResponse: ResponseCodable {
    let backends: [InferenceBackend]

    init(_ response: InferenceBackendsResponse) {
        backends = response.backends
    }
}

private struct InferenceActionHTTPResponse: ResponseCodable {
    let backend: String
    let status: String

    init(_ response: InferenceRuntimeActionResponse) {
        backend = response.backend
        status = response.status
    }
}

// MARK: - Inference Error Mapping

private func inferenceHTTPError(_ error: Error) -> HTTPError {
    if let clientError = error as? InferenceBrokerClient.ClientError {
        switch clientError {
        case .httpStatus(let code, let message):
            // Preserve valid upstream error status codes.
            if (400...599).contains(code) {
                return HTTPError(
                    .init(code: code),
                    message: message
                )
            }

            return HTTPError(
                .badGateway,
                message: "Invalid upstream status: \(code)"
            )

        case .invalidURL, .invalidResponse:
            return HTTPError(
                .badGateway,
                message: clientError.description
            )
        }
    }

    return HTTPError(
        .badGateway,
        message: "Inference Broker request failed: \(error)"
    )
}

// MARK: - Backup Response Models

private struct BackupExecutionHTTPResponse: ResponseCodable {
    let state: String
    let started_at: String?
    let completed_at: String?
    let exit_code: Int?
    let stdout: String?
    let stderr: String?
}

private struct BackupTargetHTTPResponse: Codable, Sendable {
    let name: String
    let handler: String
    let status: String
    let reason: String?
}

private struct BackupReportHTTPResponse: Codable, Sendable {
    let version: Int
    let started_at: String
    let completed_at: String
    let status: String
    let targets: [BackupTargetHTTPResponse]
}

private struct BackupGenerationHTTPResponse: ResponseCodable {
    let generation: String
    let report: BackupReportHTTPResponse
}

private struct BackupHistoryEntryHTTPResponse: Codable, Sendable {
    let run_id: String?
    let started_at: String
    let completed_at: String?
    let execution_state: String
    let exit_code: Int?
    let status: String
    let targets: [BackupTargetHTTPResponse]?
    let report_started_at: String?
    let report_completed_at: String?
    let error: String?
}

private struct BackupHistoryHTTPResponse: ResponseCodable {
    let entries: [BackupHistoryEntryHTTPResponse]
}

private struct BackupStartHTTPResponse: ResponseCodable {
    let state: String
    let started_at: String
}

// MARK: - Application Entry Point

@main
struct AdminDashboardService {

    static func main() async throws {
        let host = "127.0.0.1"
        let port = 18071

        let monitor = SystemMonitor()
        await monitor.startSampling()

        let inferenceService = InferenceService()
        let storageMonitor = StorageMonitor()
        let backupClient = BackupServiceClient()

        let router = Router()

        // MARK: Health

        router.get("/health") { _, _ -> HealthResponse in
            HealthResponse(status: "ok")
        }

        // MARK: Host Information

        router.get("/api/system/host") {
            _, _ -> HostInformationResponse in

            let information = SystemInformation()
                .hostInformation()

            return HostInformationResponse(information)
        }

        // MARK: System Metrics

        router.get("/api/system/metrics") {
            _, _ -> SystemMetricsResponse in

            let metrics = await monitor.metrics()

            return SystemMetricsResponse(metrics)
        }

        // MARK: System Resources

        router.get("/api/system/resources") {
            _, _ -> SystemResourcesResponse in

            guard let resources = await monitor.resources() else {
                throw HTTPError(
                    .serviceUnavailable,
                    message: "System resources are not yet available"
                )
            }

            return SystemResourcesResponse(resources)
        }

        // MARK: System Network

        router.get("/api/system/network") {
            _, _ -> SystemNetworkResponse in

            let network = SystemNetworkInformation()
                .networkInformation()

            return SystemNetworkResponse(network)
        }

        // MARK: System Runtime

        router.get("/api/system/runtime") {
            _, _ -> SystemRuntimeResponse in

            let runtime = SystemInformation()
                .runtimeInformation()

            return SystemRuntimeResponse(runtime)
        }

        // MARK: Storage Services

        router.get("/api/storage/status") {
            _, _ -> StorageStatusHTTPResponse in

            let response = await storageMonitor.status()
            return StorageStatusHTTPResponse(response)
        }

        // MARK: Inference Backends

        router.get("/api/inference/backends") {
            _, _ -> InferenceBackendsHTTPResponse in

            do {
                let response = try await inferenceService.backends()
                return InferenceBackendsHTTPResponse(response)
            } catch {
                throw inferenceHTTPError(error)
            }
        }

        // MARK: Inference Backend Start

        router.post("/api/inference/backends/{backend_name}/up") {
            _, context -> InferenceActionHTTPResponse in

            guard let backendName = context.parameters.get(
                "backend_name"
            ), !backendName.isEmpty else {
                throw HTTPError(
                    .badRequest,
                    message: "Missing backend name"
                )
            }

            do {
                let response = try await inferenceService
                    .startBackend(backendName)

                return InferenceActionHTTPResponse(response)
            } catch {
                throw inferenceHTTPError(error)
            }
        }

        // MARK: Inference Backend Stop

        router.post("/api/inference/backends/{backend_name}/down") {
            _, context -> InferenceActionHTTPResponse in

            guard let backendName = context.parameters.get(
                "backend_name"
            ), !backendName.isEmpty else {
                throw HTTPError(
                    .badRequest,
                    message: "Missing backend name"
                )
            }

            do {
                let response = try await inferenceService
                    .stopBackend(backendName)

                return InferenceActionHTTPResponse(response)
            } catch {
                throw inferenceHTTPError(error)
            }
        }

        // MARK: - Backup Execution Status

        router.get("/api/backup/status") {
            _, _ -> BackupExecutionHTTPResponse in

            let response: BackupServiceResponse

            do {
                response = try await backupClient.status()
            } catch {
                throw HTTPError(
                    .badGateway,
                    message: "Mini Backup Service: \(error)"
                )
            }

            guard (200..<300).contains(response.statusCode) else {
                throw HTTPError(
                    .init(code: response.statusCode),
                    message: String(
                        decoding: response.body,
                        as: UTF8.self
                    )
                )
            }

            do {
                return try JSONDecoder().decode(
                    BackupExecutionHTTPResponse.self,
                    from: response.body
                )
            } catch {
                throw HTTPError(
                    .badGateway,
                    message: "Invalid backup status response: \(error)"
                )
            }
        }

        // MARK: - Backup Generations

        router.get("/api/backup/current") {
            _, _ -> BackupGenerationHTTPResponse in

            let response: BackupServiceResponse

            do {
                response = try await backupClient.current()
            } catch {
                throw HTTPError(
                    .badGateway,
                    message: "Mini Backup Service: \(error)"
                )
            }

            guard (200..<300).contains(response.statusCode) else {
                throw HTTPError(
                    .init(code: response.statusCode),
                    message: String(
                        decoding: response.body,
                        as: UTF8.self
                    )
                )
            }

            do {
                return try JSONDecoder().decode(
                    BackupGenerationHTTPResponse.self,
                    from: response.body
                )
            } catch {
                throw HTTPError(
                    .badGateway,
                    message: "Invalid current backup response: \(error)"
                )
            }
        }

        router.get("/api/backup/previous") {
            _, _ -> BackupGenerationHTTPResponse in

            let response: BackupServiceResponse

            do {
                response = try await backupClient.previous()
            } catch {
                throw HTTPError(
                    .badGateway,
                    message: "Mini Backup Service: \(error)"
                )
            }

            guard (200..<300).contains(response.statusCode) else {
                throw HTTPError(
                    .init(code: response.statusCode),
                    message: String(
                        decoding: response.body,
                        as: UTF8.self
                    )
                )
            }

            do {
                return try JSONDecoder().decode(
                    BackupGenerationHTTPResponse.self,
                    from: response.body
                )
            } catch {
                throw HTTPError(
                    .badGateway,
                    message: "Invalid previous backup response: \(error)"
                )
            }
        }

        // MARK: - Backup History

        router.get("/api/backup/history") {
            request, _ -> BackupHistoryHTTPResponse in

            let limit: Int

            if let rawLimit = request.uri.queryParameters.get("limit") {
                guard let parsed = Int(rawLimit),
                    (1...500).contains(parsed) else {
                    throw HTTPError(
                        .badRequest,
                        message: "limit must be between 1 and 500"
                    )
                }

                limit = parsed
            } else {
                limit = 10
            }

            let response: BackupServiceResponse

            do {
                response = try await backupClient.history(
                    limit: limit
                )
            } catch {
                throw HTTPError(
                    .badGateway,
                    message: "Mini Backup Service: \(error)"
                )
            }

            guard (200..<300).contains(response.statusCode) else {
                throw HTTPError(
                    .init(code: response.statusCode),
                    message: String(
                        decoding: response.body,
                        as: UTF8.self
                    )
                )
            }

            do {
                return try JSONDecoder().decode(
                    BackupHistoryHTTPResponse.self,
                    from: response.body
                )
            } catch {
                throw HTTPError(
                    .badGateway,
                    message: "Invalid backup history response: \(error)"
                )
            }
        }

        // MARK: - Backup Execution

        router.post("/api/backup/run") {
            _, _ -> BackupStartHTTPResponse in

            let response: BackupServiceResponse

            do {
                response = try await backupClient.run()
            } catch {
                throw HTTPError(
                    .badGateway,
                    message: "Mini Backup Service: \(error)"
                )
            }

            guard (200..<300).contains(response.statusCode) else {
                throw HTTPError(
                    .init(code: response.statusCode),
                    message: String(
                        decoding: response.body,
                        as: UTF8.self
                    )
                )
            }

            do {
                return try JSONDecoder().decode(
                    BackupStartHTTPResponse.self,
                    from: response.body
                )
            } catch {
                throw HTTPError(
                    .badGateway,
                    message: "Invalid backup start response: \(error)"
                )
            }
        }

        // MARK: HTTP Server

        let application = Application(
            router: router,
            configuration: .init(
                address: .hostname(host, port: port)
            )
        )

        print("AdminDashboardService 0.1.0")
        print("Listening on http://\(host):\(port)")

        try await application.runService()
    }
}
