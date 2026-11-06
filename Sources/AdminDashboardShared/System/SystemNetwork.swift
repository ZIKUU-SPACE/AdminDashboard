
// ~/workspace/AdminDashboard/Sources/AdminDashboardShared/SystemNetwork.swift

import Foundation

// MARK: - Network Interface

public struct NetworkInterfaceDetails:
    Codable,
    Sendable,
    Equatable
{
    public let name: String
    public let state: String?
    public let macAddress: String?
    public let mtu: Int?
    public let ipv6Addresses: [String]

    private enum CodingKeys: String, CodingKey {
        case name
        case state
        case macAddress = "mac_address"
        case mtu
        case ipv6Addresses = "ipv6_addresses"
    }

    public init(
        name: String,
        state: String?,
        macAddress: String?,
        mtu: Int?,
        ipv6Addresses: [String]
    ) {
        self.name = name
        self.state = state
        self.macAddress = macAddress
        self.mtu = mtu
        self.ipv6Addresses = ipv6Addresses
    }

    // Explicitly preserve null fields in JSON.

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(name, forKey: .name)
        try container.encode(state, forKey: .state)
        try container.encode(macAddress, forKey: .macAddress)
        try container.encode(mtu, forKey: .mtu)
        try container.encode(
            ipv6Addresses,
            forKey: .ipv6Addresses
        )
    }
}

// MARK: - System Network

public struct SystemNetwork:
    Codable,
    Sendable,
    Equatable
{
    public let interfaces: [NetworkInterfaceDetails]

    public init(
        interfaces: [NetworkInterfaceDetails]
    ) {
        self.interfaces = interfaces
    }

    public static let empty = SystemNetwork(
        interfaces: []
    )
}
