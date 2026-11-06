
 // ~/workspace/AdminDashboard/Sources/AdminDashboardService/SystemInformation.swift

import Foundation
import Glibc
import AdminDashboardShared

/// Collects basic information about the local Linux host.
///
/// No persistent sampling task is required.
/// Information is collected when requested.
///
/// Linux virtual files are read through POSIX APIs rather than
/// Foundation's String(contentsOf:), since /proc files may
/// report a file size of zero despite containing data.
struct SystemInformation {

    private let procRoot: URL
    private let etcRoot: URL
    private let sysRoot: URL
    private let hostRoot: URL

    init(
        procRoot: URL = URL(fileURLWithPath: "/proc"),
        etcRoot: URL = URL(fileURLWithPath: "/etc"),
        sysRoot: URL = URL(fileURLWithPath: "/sys"),
        hostRoot: URL = URL(fileURLWithPath: "/")
    ) {
        self.procRoot = procRoot
        self.etcRoot = etcRoot
        self.sysRoot = sysRoot
        self.hostRoot = hostRoot
    }

    // MARK: - Host Information

    func hostInformation() -> HostInformation {
        HostInformation(
            hostname: hostname(),
            osName: osName(),
            kernel: kernelVersion(),
            cpuModel: cpuModel(),
            memoryTotalGiB: memoryTotalGiB(),
            uptimeSeconds: uptimeSeconds()
        )
    }

    // MARK: - Hostname

    private func hostname() -> String? {
        LinuxFileReader.readTrimmed(etcRoot.appendingPathComponent("hostname"))
    }

    // MARK: - Operating System

    private func osName() -> String? {
        let path = etcRoot.appendingPathComponent("os-release")

        guard let contents = LinuxFileReader.readTrimmed(path) else {
            return nil
        }

        var values: [String: String] = [:]

        for line in contents.split(separator: "\n") {
            guard let separator = line.firstIndex(of: "=") else {
                continue
            }

            let key = String(line[..<separator])
            let rawValue = String(line[line.index(after: separator)...])

            values[key] = unquote(rawValue)
        }

        return values["PRETTY_NAME"] ?? values["NAME"]
    }

    private func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        guard trimmed.count >= 2,
              let first = trimmed.first,
              let last = trimmed.last,
              (first == "\"" && last == "\"")
                || (first == "'" && last == "'") else {
            return trimmed
        }

        return String(trimmed.dropFirst().dropLast())
    }

    // MARK: - Kernel

    private func kernelVersion() -> String? {
        LinuxFileReader.readTrimmed(
            procRoot
            .appendingPathComponent("sys")
            .appendingPathComponent("kernel")
            .appendingPathComponent("osrelease")
        )
    }

    // MARK: - CPU

    private func cpuModel() -> String? {
        let path = procRoot.appendingPathComponent("cpuinfo")

        guard let contents = LinuxFileReader.readTrimmed(path) else {
            return nil
        }

        let candidates = [
            "model name",
            "hardware",
            "processor"
        ]

        let lines = contents.split(separator: "\n")

        for candidate in candidates {
            for line in lines {
                guard let separator = line.firstIndex(of: ":") else {
                    continue
                }

                let key = line[..<separator]
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()

                guard key == candidate else {
                    continue
                }

                let value = line[line.index(after: separator)...]
                    .trimmingCharacters(in: .whitespaces)

                if !value.isEmpty {
                    return value
                }
            }
        }

        return nil
    }

    // MARK: - Memory

    private func memoryTotalGiB() -> Double? {
        let path = procRoot.appendingPathComponent("meminfo")

        guard let contents = LinuxFileReader.readTrimmed(path) else {
            return nil
        }

        for line in contents.split(separator: "\n") {
            guard line.hasPrefix("MemTotal:") else {
                continue
            }

            let fields = line.split(
                whereSeparator: \.isWhitespace
            )

            guard fields.count >= 2,
                  let totalKiB = UInt64(fields[1]) else {
                return nil
            }

            let totalGiB = Double(totalKiB)
                / (1024.0 * 1024.0)

            return rounded(totalGiB)
        }

        return nil
    }

    // MARK: - Uptime

    private func uptimeSeconds() -> Double? {
        let path = procRoot.appendingPathComponent("uptime")

        guard let contents = LinuxFileReader.readTrimmed(path),
              let first = contents.split(
                whereSeparator: \.isWhitespace
              ).first,
              let seconds = Double(first),
              seconds.isFinite,
              seconds >= 0 else {
            return nil
        }

        return seconds
    }

// MARK: - Runtime Information

    func runtimeInformation() -> SystemRuntime {
        let runtime = containerRuntime()

        return SystemRuntime(
            initSystem: initSystem(),
            containerRuntime: runtime,
            execution: runtime == nil ? "Host" : "Container",
            architecture: architecture(),
            cgroup: cgroupVersion()
        )
    }

    // MARK: - Init System

    private func initSystem() -> String? {
        let path = hostRoot
            .appendingPathComponent("run")
            .appendingPathComponent("systemd")
            .appendingPathComponent("system")

        return FileManager.default.fileExists(atPath: path.path)
            ? "systemd"
            : nil
    }

    // MARK: - Container Runtime

    private func containerRuntime() -> String? {
        let dockerPath = hostRoot
            .appendingPathComponent(".dockerenv")

        if FileManager.default.fileExists(
            atPath: dockerPath.path
        ) {
            return "Docker"
        }

        let containerPath = hostRoot
            .appendingPathComponent("run")
            .appendingPathComponent(".containerenv")

        if FileManager.default.fileExists(
            atPath: containerPath.path
        ) {
            return "Container"
        }

        return nil
    }

    // MARK: - Architecture

    private func architecture() -> String {
        var information = utsname()

        guard Glibc.uname(&information) == 0 else {
            return "unknown"
        }

        let capacity = MemoryLayout.size(
            ofValue: information.machine
        )

        return withUnsafePointer(to: &information.machine) {
            pointer in

            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: capacity
            ) {
                String(cString: $0)
            }
        }
    }

    // MARK: - Cgroup

    private func cgroupVersion() -> String? {
        let cgroupRoot = sysRoot
            .appendingPathComponent("fs")
            .appendingPathComponent("cgroup")

        let controllersPath = cgroupRoot
            .appendingPathComponent("cgroup.controllers")

        if FileManager.default.fileExists(
            atPath: controllersPath.path
        ) {
            return "v2"
        }

        if FileManager.default.fileExists(
            atPath: cgroupRoot.path
        ) {
            return "v1"
        }

        return nil
    }

    // MARK: - Utilities

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
