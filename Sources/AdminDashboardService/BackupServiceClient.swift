
 // ~/workspace/AdminDashboard/Sources/AdminDashboardService/BackupServiceClient.swift

import Foundation
import AsyncHTTPClient

// MARK: - Response

/// Raw HTTP response returned by Mini Backup Service.
///
/// HTTP error statuses are preserved so that the
/// AdminDashboardService router can forward them.
struct BackupServiceResponse: Sendable {

    let statusCode: Int
    let body: Data
}

// MARK: - Errors

enum BackupServiceClientError: Error, CustomStringConvertible {

    case invalidHistoryLimit(Int)
    case transportFailure(String)

    var description: String {
        switch self {
        case .invalidHistoryLimit(let limit):
            return "Invalid backup history limit: \(limit)"

        case .transportFailure(let message):
            return "Mini Backup Service request failed: \(message)"
        }
    }
}

private enum BackupHTTPMethod {
    case GET
    case POST
}

// MARK: - Backup Service Client

/// HTTP client for ZIKUU Mini Backup Service.
///
/// Connects through the local Unix Domain Socket.
/// No TCP port or external network connection is used.
///
/// This component handles transport only.
/// History persistence and backup execution belong
/// entirely to Mini Backup Service.
struct BackupServiceClient: Sendable {

    // MARK: - Configuration

    let socketPath: String

    init(
        socketPath: String = ProcessInfo.processInfo.environment[
            "ADMIN_DASHBOARD_BACKUP_SOCKET"
        ] ?? "/run/mini-backup/mini-backup.sock"
    ) {
        self.socketPath = socketPath
    }

    // MARK: - Execution Status

    func status() async throws -> BackupServiceResponse {
        try await request(
            method: .GET,
            path: "/status"
        )
    }

    // MARK: - Backup Generations

    func current() async throws -> BackupServiceResponse {
        try await request(
            method: .GET,
            path: "/backups/current"
        )
    }

    func previous() async throws -> BackupServiceResponse {
        try await request(
            method: .GET,
            path: "/backups/previous"
        )
    }

    // MARK: - Execution History

    func history(
        limit: Int = 10
    ) async throws -> BackupServiceResponse {
        guard (1...500).contains(limit) else {
            throw BackupServiceClientError
                .invalidHistoryLimit(limit)
        }

        return try await request(
            method: .GET,
            path: "/history?limit=\(limit)"
        )
    }

    // MARK: - Backup Execution

    func run() async throws -> BackupServiceResponse {
        try await request(
            method: .POST,
            path: "/backup"
        )
    }

    // MARK: - HTTP Transport

private func request(
        method: BackupHTTPMethod,
        path: String
    ) async throws -> BackupServiceResponse {
        guard let url = URL(
            httpURLWithSocketPath: socketPath,
            uri: path
        ) else {
            throw BackupServiceClientError.transportFailure(
                "Invalid Unix Domain Socket URL"
            )
        }

        do {
            var request = HTTPClientRequest(
                url: url.absoluteString
            )

            switch method {
            case .GET:
                request.method = .GET

            case .POST:
                request.method = .POST
            }

            request.headers.add(
                name: "Accept",
                value: "application/json"
            )

            let response = try await HTTPClient.shared.execute(
                request,
                timeout: .seconds(10)
            )

            let buffer = try await response.body.collect(
                upTo: 1024 * 1024
            )

            return BackupServiceResponse(
                statusCode: Int(response.status.code),
                body: Data(buffer.readableBytesView)
            )
        } catch {
            throw BackupServiceClientError.transportFailure(
                String(describing: error)
            )
        }
    }
}
