
// ~/workspace/AdminDashboard/Sources/AdminDashboardService/StorageMonitor.swift

import Foundation
import Glibc
import AdminDashboardShared

/// Checks TCP accessibility of the storage services running
/// on the local ZIKUU Mini host.
///
/// A successful TCP connection means the port is reachable.
/// It does not guarantee application-level health.
struct StorageMonitor: Sendable {

    // MARK: - Configuration

    private struct ServiceDefinition: Sendable {
        let id: String
        let name: String
        let kind: String
        let port: Int
        let webPath: String?
    }

    private static let services: [ServiceDefinition] = [
        .init(
            id: "gitea",
            name: "Gitea",
            kind: "git",
            port: 8300,
            webPath: "/"
        ),
        .init(
            id: "qdrant",
            name: "Qdrant",
            kind: "vector",
            port: 6333,
            webPath: "/dashboard"
        ),
        .init(
            id: "postgres",
            name: "PostgreSQL",
            kind: "database",
            port: 5432,
            webPath: nil
        ),
        .init(
            id: "minio",
            name: "MinIO",
            kind: "object-storage",
            port: 9001,
            webPath: "/"
        ),
        .init(
            id: "nextcloud",
            name: "Nextcloud",
            kind: "file-storage",
            port: 8181,
            webPath: "/"
        )
    ]

    private static let connectTimeoutMilliseconds: Int32 = 1000

    // MARK: - Public API

    func status() async -> StorageStatusResponse {
        let definitions = Self.services

        let results = await withTaskGroup(
            of: (Int, StorageService).self
        ) { group in

            for (index, definition) in definitions.enumerated() {
                group.addTask {
                    let reachable = Self.isPortOpen(
                        definition.port
                    )

                    let service = StorageService(
                        id: definition.id,
                        name: definition.name,
                        kind: definition.kind,
                        port: definition.port,
                        status: reachable ? "running" : "stopped",
                        webPath: definition.webPath
                    )

                    return (index, service)
                }
            }

            var collected: [(Int, StorageService)] = []

            for await result in group {
                collected.append(result)
            }

            return collected
        }

        return StorageStatusResponse(
            services: results.sorted {
                $0.0 < $1.0
            }.map {
                $0.1
            }
        )
    }

    // MARK: - TCP Probe

    /// Attempts a nonblocking TCP connection to 127.0.0.1.
    ///
    /// This is intentionally limited to IPv4 loopback because
    /// the monitored Docker ports are published on the Mini host.
    private static func isPortOpen(_ port: Int) -> Bool {
        guard (1...65535).contains(port) else {
            return false
        }

        let descriptor = socket(
            AF_INET,
            Int32(SOCK_STREAM.rawValue),
            0
        )

        guard descriptor >= 0 else {
            return false
        }

        defer {
            _ = Glibc.close(descriptor)
        }

        let flags = fcntl(
            descriptor,
            F_GETFL,
            0
        )

        guard flags >= 0,
              fcntl(
                descriptor,
                F_SETFL,
                flags | O_NONBLOCK
              ) == 0 else {
            return false
        }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(
            s_addr: in_addr_t(0x7F000001).bigEndian
        )

        let result = withUnsafePointer(to: &address) {
            pointer in

            pointer.withMemoryRebound(
                to: sockaddr.self,
                capacity: 1
            ) { socketAddress in
                Glibc.connect(
                    descriptor,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }

        if result == 0 {
            return true
        }

        guard errno == EINPROGRESS else {
            return false
        }

        var pollDescriptor = pollfd(
            fd: descriptor,
            events: Int16(POLLOUT),
            revents: 0
        )

        let pollResult = Glibc.poll(
            &pollDescriptor,
            1,
            connectTimeoutMilliseconds
        )

        guard pollResult > 0 else {
            return false
        }

        var socketError: Int32 = 0
        var errorLength = socklen_t(
            MemoryLayout<Int32>.size
        )

        let optionResult = withUnsafeMutablePointer(
            to: &socketError
        ) { pointer in
            Glibc.getsockopt(
                descriptor,
                SOL_SOCKET,
                SO_ERROR,
                pointer,
                &errorLength
            )
        }

        return optionResult == 0 && socketError == 0
    }
}
