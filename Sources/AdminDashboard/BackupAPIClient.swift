
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/BackupAPIClient.swift

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import AdminDashboardShared

// MARK: - Errors

enum BackupAPIClientError: Error, CustomStringConvertible {
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

// MARK: - Backup API Client

/// HTTP client for the AdminDashboard Backup API.
///
/// Connects to the local AdminDashboardService.
/// Does not depend on UI objects.
///
/// Backup execution and history persistence are handled
/// by Mini Backup Service, not by this client.
struct BackupAPIClient: Sendable {

    let baseURL: URL

    init(
        baseURL: URL = URL(
            string: "http://127.0.0.1:18071"
        )!
    ) {
        self.baseURL = baseURL
    }

    // MARK: - Execution Status

    func fetchStatus() async throws -> BackupExecutionStatus {
        try await send(
            method: "GET",
            path: ["api", "backup", "status"]
        )
    }

    // MARK: - Backup Generations

    func fetchCurrent() async throws -> BackupGeneration {
        try await send(
            method: "GET",
            path: ["api", "backup", "current"]
        )
    }

    func fetchPrevious() async throws -> BackupGeneration {
        try await send(
            method: "GET",
            path: ["api", "backup", "previous"]
        )
    }

    // MARK: - Execution History

    func fetchHistory(
        limit: Int = 10
    ) async throws -> BackupHistory {
        guard (1...500).contains(limit) else {
            throw BackupAPIClientError.unexpectedStatusCode(
                400,
                "limit must be between 1 and 500"
            )
        }

        return try await send(
            method: "GET",
            path: ["api", "backup", "history"],
            queryItems: [
                URLQueryItem(
                    name: "limit",
                    value: String(limit)
                )
            ]
        )
    }

    // MARK: - Backup Execution

    func runBackup() async throws -> BackupStartResponse {
        try await send(
            method: "POST",
            path: ["api", "backup", "run"]
        )
    }

    // MARK: - HTTP Transport

    private func send<Response: Decodable>(
        method: String,
        path: [String],
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {

        var url = baseURL

        for component in path {
            url.appendPathComponent(component)
        }

        if !queryItems.isEmpty {
            guard var components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            ) else {
                throw BackupAPIClientError.invalidResponse
            }

            components.queryItems = queryItems

            guard let resolvedURL = components.url else {
                throw BackupAPIClientError.invalidResponse
            }

            url = resolvedURL
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
            throw BackupAPIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(
                decoding: data,
                as: UTF8.self
            )

            throw BackupAPIClientError.unexpectedStatusCode(
                httpResponse.statusCode,
                message
            )
        }

        return try JSONDecoder().decode(
            Response.self,
            from: data
        )
    }
}
