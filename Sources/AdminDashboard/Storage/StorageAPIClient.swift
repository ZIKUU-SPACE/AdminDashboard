// ~/workspace/AdminDashboard/Sources/AdminDashboard/StorageAPIClient.swift

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import AdminDashboardShared

// MARK: - Errors

enum StorageAPIClientError: Error, CustomStringConvertible {
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

// MARK: - Storage API Client

/// HTTP client for the AdminDashboard Storage API.
///
/// Connects to the local AdminDashboardService.
/// Does not depend on UI objects.
struct StorageAPIClient: Sendable {

    let baseURL: URL

    init(
        baseURL: URL = URL(
            string: "http://127.0.0.1:18071"
        )!
    ) {
        self.baseURL = baseURL
    }

    // MARK: - Storage Services

    func fetchServices() async throws -> StorageStatusResponse {
        var url = baseURL
        url.appendPathComponent("api")
        url.appendPathComponent("storage")
        url.appendPathComponent("status")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageAPIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(
                decoding: data,
                as: UTF8.self
            )

            throw StorageAPIClientError.unexpectedStatusCode(
                httpResponse.statusCode,
                message
            )
        }

        return try JSONDecoder().decode(
            StorageStatusResponse.self,
            from: data
        )
    }
}
