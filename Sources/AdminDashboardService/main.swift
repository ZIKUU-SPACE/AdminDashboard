
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

// MARK: - Application Entry Point

@main
struct AdminDashboardService {

    static func main() async throws {
        let host = "127.0.0.1"
        let port = 18071

        let monitor = SystemMonitor()
        await monitor.startSampling()
        
        let router = Router()

        // MARK: Health

        router.get("/health") { _, _ -> HealthResponse in
            HealthResponse(status: "ok")
        }

        // MARK: System Metrics

        router.get("/api/system/metrics") {
            _, _ -> SystemMetricsResponse in

            let metrics = await monitor.metrics()

            return SystemMetricsResponse(metrics)
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
