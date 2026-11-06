// ~/workspace/AdminDashboard/Sources/AdminDashboard/SystemAPIClient.swift

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import AdminDashboardShared

// MARK: - Errors

enum SystemAPIClientError: Error {
    case invalidResponse
    case unexpectedStatusCode(Int)
}

// MARK: - System API Client

/// HTTP client for the AdminDashboard system API.
///
/// All requests are asynchronous and independent of UI objects.
/// Additional System endpoints can be added without duplicating
/// HTTP request and JSON decoding logic.
struct SystemAPIClient: Sendable {

    let baseURL: URL

    init(
        baseURL: URL = URL(
            string: "http://127.0.0.1:18071"
        )!
    ) {
        self.baseURL = baseURL
    }

    // MARK: - Endpoints

    func fetchHostInformation() async throws -> HostInformation {
        try await get("api/system/host")
    }

    func fetchResources() async throws -> SystemResources {
        try await get("api/system/resources")
    }

    func fetchNetwork() async throws -> SystemNetwork {
        try await get("api/system/network")
    }
    
    func fetchRuntime() async throws -> SystemRuntime {
        try await get("api/system/runtime")
    }

    // MARK: - HTTP

    private func get<T: Decodable>(
        _ path: String
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)

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
            throw SystemAPIClientError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw SystemAPIClientError.unexpectedStatusCode(
                httpResponse.statusCode
            )
        }

        return try JSONDecoder().decode(
            T.self,
            from: data
        )
    }
}
