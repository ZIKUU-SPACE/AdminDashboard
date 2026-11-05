
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

// MARK: - Application Entry Point

@main
struct AdminDashboardService {

    static func main() async throws {
        let host = "127.0.0.1"
        let port = 18071

        let monitor = SystemMonitor()
        await monitor.startSampling()

        let inferenceService = InferenceService()

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
