
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/HostInformationClient.swift

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import AdminDashboardShared

enum HostInformationClientError: Error {
    case invalidResponse
    case unexpectedStatusCode(Int)
}

/// HTTP client for retrieving information about the local host.
///
/// Network operations are asynchronous.
/// This type does not own or modify any UI objects.
struct HostInformationClient: Sendable {

    let baseURL: URL

    init(
        baseURL: URL = URL(
            string: "http://127.0.0.1:18071"
        )!
    ) {
        self.baseURL = baseURL
    }

    // MARK: - Host Information

    func fetchHostInformation() async throws -> HostInformation {
        let url = baseURL.appendingPathComponent(
            "api/system/host"
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
            throw HostInformationClientError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw HostInformationClientError.unexpectedStatusCode(
                httpResponse.statusCode
            )
        }

        return try JSONDecoder().decode(
            HostInformation.self,
            from: data
        )
    }
}
