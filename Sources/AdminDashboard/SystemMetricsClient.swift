
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/SystemMetricsClient.swift

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import AdminDashboardShared

enum SystemMetricsClientError: Error {
    case invalidResponse
    case unexpectedStatusCode(Int)
}

struct SystemMetricsClient: Sendable {
    let baseURL: URL

    init(
        baseURL: URL = URL(
            string: "http://127.0.0.1:18071"
        )!
    ) {
        self.baseURL = baseURL
    }

    func fetchMetrics() async throws -> SystemMetrics {
        let url = baseURL.appendingPathComponent(
            "api/system/metrics"
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SystemMetricsClientError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw SystemMetricsClientError.unexpectedStatusCode(
                httpResponse.statusCode
            )
        }

        return try JSONDecoder().decode(
            SystemMetrics.self,
            from: data
        )
    }
}
