// ~/workspace/AdminDashboard/Sources/AdminDashboardShared/StorageService.swift

import Foundation

public struct StorageService: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let kind: String
    public let port: Int
    public let status: String
    public let webPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case port
        case status
        case webPath = "web_path"
    }

    public init(
        id: String,
        name: String,
        kind: String,
        port: Int,
        status: String,
        webPath: String?
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.port = port
        self.status = status
        self.webPath = webPath
    }
}

public struct StorageStatusResponse: Codable, Sendable, Equatable {
    public let services: [StorageService]

    public init(services: [StorageService]) {
        self.services = services
    }
}