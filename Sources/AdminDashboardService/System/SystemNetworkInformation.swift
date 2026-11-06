
// ~/workspace/AdminDashboard/Sources/AdminDashboardService/SystemNetworkInformation.swift

import Foundation
import Glibc
import AdminDashboardShared

/// Collects network interface information from the local Linux host.
///
/// Network information is read on demand, without periodic sampling.
/// The response format matches the existing Python implementation.
struct SystemNetworkInformation {

    // MARK: - Configuration

    private let procRoot: URL
    private let sysRoot: URL

    init(
        procRoot: URL = URL(fileURLWithPath: "/proc"),
        sysRoot: URL = URL(fileURLWithPath: "/sys")
    ) {
        self.procRoot = procRoot
        self.sysRoot = sysRoot
    }

    // MARK: - Public API

    func networkInformation() -> SystemNetwork {
        let networkRoot = sysRoot
            .appendingPathComponent("class")
            .appendingPathComponent("net")

        let ipv6Addresses = readIPv6Addresses()

        guard let names = try? FileManager.default
            .contentsOfDirectory(atPath: networkRoot.path) else {
            return .empty
        }

        // Keep the loopback interface at the end.
        let sortedNames = names.sorted { lhs, rhs in
            if lhs == "lo" {
                return false
            }

            if rhs == "lo" {
                return true
            }

            return lhs < rhs
        }

        var interfaces: [NetworkInterfaceDetails] = []

        for name in sortedNames {
            let directory = networkRoot
                .appendingPathComponent(name)

            var isDirectory: ObjCBool = false

            guard FileManager.default.fileExists(
                atPath: directory.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue else {
                continue
            }

            let state = LinuxFileReader.readTrimmed(directory.appendingPathComponent("operstate"))

            let macAddress = LinuxFileReader.readTrimmed(directory.appendingPathComponent("address"))

            let mtu = LinuxFileReader.readTrimmed(directory.appendingPathComponent("mtu")).flatMap(Int.init)

            interfaces.append(
                NetworkInterfaceDetails(
                    name: name,
                    state: state,
                    macAddress: macAddress,
                    mtu: mtu,
                    ipv6Addresses: ipv6Addresses[name] ?? []
                )
            )
        }

        return SystemNetwork(interfaces: interfaces)
    }

    // MARK: - IPv6

    /// Reads /proc/net/if_inet6.
    ///
    /// Each record contains:
    /// address, interface index, prefix length, scope,
    /// flags, and interface name.
    private func readIPv6Addresses() -> [String: [String]] {
        let path = procRoot
            .appendingPathComponent("net")
            .appendingPathComponent("if_inet6")

        guard let contents = LinuxFileReader.readTrimmed(path) else {
            return [:]
        }

        var result: [String: [String]] = [:]

        for line in contents.split(separator: "\n") {
            let fields = line.split(
                whereSeparator: \.isWhitespace
            )

            guard fields.count == 6 else {
                continue
            }

            let rawAddress = String(fields[0])
            let rawPrefix = String(fields[2])
            let interfaceName = String(fields[5])

            guard let address = formatIPv6(rawAddress),
                  let prefix = UInt8(rawPrefix, radix: 16),
                  prefix <= 128 else {
                continue
            }

            result[interfaceName, default: []].append(
                "\(address)/\(prefix)"
            )
        }

        return result
    }

    /// Converts a 32-digit hexadecimal IPv6 address to its
    /// canonical textual representation using inet_ntop().
    private func formatIPv6(_ rawAddress: String) -> String? {
        let characters = Array(rawAddress.utf8)

        guard characters.count == 32 else {
            return nil
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(16)

        for index in stride(from: 0, to: 32, by: 2) {
            guard let high = hexValue(characters[index]),
                  let low = hexValue(characters[index + 1]) else {
                return nil
            }

            bytes.append((high << 4) | low)
        }

        var output = [CChar](
            repeating: 0,
            count: Int(INET6_ADDRSTRLEN)
        )

        let converted = bytes.withUnsafeBytes { source in
            output.withUnsafeMutableBufferPointer { destination in
                inet_ntop(
                    Int32(AF_INET6),
                    source.baseAddress,
                    destination.baseAddress,
                    socklen_t(destination.count)
                )
            }
        }

        guard converted != nil else {
            return nil
        }

        return output.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else {
                return nil
            }

            return String(cString: base)
        }
    }

    private func hexValue(_ character: UInt8) -> UInt8? {
        switch character {
        case 48...57:
            return character - 48
        case 65...70:
            return character - 65 + 10
        case 97...102:
            return character - 97 + 10
        default:
            return nil
        }
    }

}
