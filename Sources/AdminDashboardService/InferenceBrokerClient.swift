// ~/workspace/AdminDashboard/Sources/AdminDashboardService/InferenceBrokerClient.swift

import Foundation
import FoundationNetworking

/// HTTP client for Inference Broker.
///
/// This client handles transport and JSON decoding only.
/// Backend aggregation and error fallback belong to InferenceService.
struct InferenceBrokerClient: Sendable {

    // MARK: - Broker Models

    struct BackendConfiguration: Decodable, Sendable {
        let node: String?
        let url: String?
        let kind: String?
        let model: String?
        let runtime: String?
    }

    struct BackendsResponse: Decodable, Sendable {
        let backends: [String: BackendConfiguration]
    }

    private struct RuntimeStatusResponse: Decodable {
        let status: String?
    }

    private struct RuntimeActionResponse: Decodable {
        let status: String?
    }

    // MARK: - Errors

    enum ClientError: Error, CustomStringConvertible {
        case invalidURL(String)
        case invalidResponse
        case httpStatus(Int, String)

        var description: String {
            switch self {
            case .invalidURL(let value):
                return "Invalid Inference Broker URL: \(value)"

            case .invalidResponse:
                return "Invalid response from Inference Broker"

            case .httpStatus(let status, let message):
                return "Inference Broker HTTP \(status): \(message)"
            }
        }
    }

    // MARK: - Configuration

    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL? = nil,
        session: URLSession = .shared
    ) {
        let configuredURL = ProcessInfo.processInfo
            .environment["ADMIN_DASHBOARD_INFERENCE_BROKER_URL"]

        self.baseURL = baseURL
            ?? configuredURL.flatMap(URL.init(string:))
            ?? URL(string: "http://127.0.0.1:19090")!

        self.session = session
    }

    // MARK: - Backends

    func fetchBackends() async throws -> [String: BackendConfiguration] {
        let response: BackendsResponse = try await get(
            path: ["backends"]
        )

        return response.backends
    }

    // MARK: - Runtime Status

    func fetchRuntimeStatus(
        backendName: String
    ) async throws -> String {
        let response: RuntimeStatusResponse = try await get(
            path: [
                "backends",
                backendName,
                "runtime",
                "status"
            ]
        )

        return response.status ?? "unknown"
    }

    // MARK: - Runtime Actions

    func startBackend(
        _ backendName: String
    ) async throws -> String {
        try await performRuntimeAction(
            backendName: backendName,
            action: "start"
        )
    }

    func stopBackend(
        _ backendName: String
    ) async throws -> String {
        try await performRuntimeAction(
            backendName: backendName,
            action: "stop"
        )
    }

    private func performRuntimeAction(
        backendName: String,
        action: String
    ) async throws -> String {
        let response: RuntimeActionResponse = try await post(
            path: [
                "backends",
                backendName,
                "runtime",
                action
            ]
        )

        return response.status ?? "unknown"
    }

    // MARK: - HTTP

    private func get<T: Decodable>(
        path: [String]
    ) async throws -> T {
        try await request(
            path: path,
            method: "GET"
        )
    }

    private func post<T: Decodable>(
        path: [String]
    ) async throws -> T {
        try await request(
            path: path,
            method: "POST"
        )
    }

    private func request<T: Decodable>(
        path: [String],
        method: String
    ) async throws -> T {
        var url = baseURL

        for component in path {
            url.appendPathComponent(component)
        }

        guard let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            throw ClientError.invalidURL(
                url.absoluteString
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 5
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(
                decoding: data,
                as: UTF8.self
            )

            throw ClientError.httpStatus(
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
