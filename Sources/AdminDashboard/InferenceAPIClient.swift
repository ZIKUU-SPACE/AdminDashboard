
// ~/workspace/AdminDashboard/Sources/AdminDashboard/InferenceAPIClient.swift

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import AdminDashboardShared

// MARK: - Errors

enum InferenceAPIClientError: Error, CustomStringConvertible {
    case invalidResponse
    case unexpectedStatusCode(Int, String)

    var description: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from AdminDashboardService"

        case .unexpectedStatusCode(let status, let message):
            if message.isEmpty {
                return "HTTP \(status)"
            }

            return "HTTP \(status): \(message)"
        }
    }
}

// MARK: - Inference API Client

/// HTTP client for the AdminDashboard Inference API.
///
/// Connects to the local AdminDashboardService, not directly
/// to Inference Broker.
///
/// Does not depend on UI objects.
struct InferenceAPIClient: Sendable {

    let baseURL: URL

    init(
        baseURL: URL = URL(
            string: "http://127.0.0.1:18071"
        )!
    ) {
        self.baseURL = baseURL
    }

    // MARK: - Backend Listing

    func fetchBackends() async throws -> InferenceBackendsResponse {
        try await request(
            path: [
                "api",
                "inference",
                "backends"
            ],
            method: "GET"
        )
    }

    // MARK: - Runtime Actions

    func startBackend(
        _ backendName: String
    ) async throws -> InferenceRuntimeActionResponse {
        try await request(
            path: [
                "api",
                "inference",
                "backends",
                backendName,
                "up"
            ],
            method: "POST"
        )
    }

    func stopBackend(
        _ backendName: String
    ) async throws -> InferenceRuntimeActionResponse {
        try await request(
            path: [
                "api",
                "inference",
                "backends",
                backendName,
                "down"
            ],
            method: "POST"
        )
    }

    // MARK: - HTTP

    private func request<T: Decodable>(
        path: [String],
        method: String
    ) async throws -> T {
        var url = baseURL

        for component in path {
            url.appendPathComponent(component)
        }

        var request = URLRequest(url: url)

        request.httpMethod = method
        request.timeoutInterval = 10

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InferenceAPIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(
                decoding: data,
                as: UTF8.self
            )

            throw InferenceAPIClientError.unexpectedStatusCode(
                httpResponse.statusCode,
                message
            )
        }

        return try JSONDecoder().decode(
            T.self,
            from: data
        )
    }
}
