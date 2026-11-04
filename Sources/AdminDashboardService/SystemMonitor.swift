
 // ~/workspace/AdminDashboard/Sources/AdminDashboardService/SystemMonitor.swift

import Foundation
import AdminDashboardShared
import Glibc

actor SystemMonitor {
    private let procRoot: URL

    private var previousCPU: CPUCounters?
    private var latestMetrics: SystemMetrics = .empty
    private var samplingTask: Task<Void, Never>?

    private let samplingInterval: Duration = .seconds(1)

    init(procRoot: URL = URL(fileURLWithPath: "/proc")) {
        self.procRoot = procRoot
    }

    // MARK: - Sampling Lifecycle

    func startSampling() {
        guard samplingTask == nil else {
            return
        }

        samplingTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                await self.collectMetrics()

                do {
                    try await Task.sleep(
                        for: self.samplingInterval
                    )
                } catch {
                    break
                }
            }
        }
    }

    func stopSampling() {
        samplingTask?.cancel()
        samplingTask = nil
        previousCPU = nil
    }

    // MARK: - Cached Metrics

    func metrics() -> SystemMetrics {
        latestMetrics
    }

    private func collectMetrics() {
        latestMetrics = SystemMetrics(
            cpu: cpuMetric(),
            memory: memoryMetric(),
            disk: diskMetric(),
            gpu: gpuMetric()
        )
    }

    // MARK: - CPU

    private struct CPUCounters {
        let idle: UInt64
        let total: UInt64
    }

    private func cpuMetric() -> Metric {
        guard let current = readCPUCounters() else {
            previousCPU = nil
            return Metric(value: nil, unit: "%")
        }

        defer {
            previousCPU = current
        }

        guard let previous = previousCPU,
              current.total >= previous.total,
              current.idle >= previous.idle else {
            return Metric(value: nil, unit: "%")
        }

        let totalDelta = current.total - previous.total
        let idleDelta = current.idle - previous.idle

        guard totalDelta > 0, idleDelta <= totalDelta else {
            return Metric(value: nil, unit: "%")
        }

        let usage = 100.0 * Double(totalDelta - idleDelta)
            / Double(totalDelta)

        return Metric(
            value: rounded(usage),
            unit: "%"
        )
    }

    private func readCPUCounters() -> CPUCounters? {
        let path = procRoot.appendingPathComponent("stat")

        guard let contents = try? String(
            contentsOf: path,
            encoding: .utf8
        ),
        let firstLine = contents.split(
            separator: "\n",
            omittingEmptySubsequences: true
        ).first else {
            return nil
        }

        let fields = firstLine.split(
            whereSeparator: \.isWhitespace
        )

        guard fields.first == "cpu",
              fields.count >= 5 else {
            return nil
        }

        let counters = fields.dropFirst().compactMap {
            UInt64($0)
        }

        guard counters.count == fields.count - 1,
              counters.count >= 4 else {
            return nil
        }

        let (total, overflow) = counters.reduce(
            into: (UInt64(0), false)
        ) { result, counter in
            let (sum, didOverflow) =
                result.0.addingReportingOverflow(counter)

            result.0 = sum
            result.1 = result.1 || didOverflow
        }

        guard !overflow else {
            return nil
        }

        let idleBase = counters[3]
        let idleWait = counters.count > 4 ? counters[4] : 0

        let (idle, idleOverflow) =
            idleBase.addingReportingOverflow(idleWait)

        guard !idleOverflow else {
            return nil
        }

        return CPUCounters(
            idle: idle,
            total: total
        )
    }

    // MARK: - Memory

    private func memoryMetric() -> Metric {
        let path = procRoot.appendingPathComponent("meminfo")

        guard let contents = try? String(
            contentsOf: path,
            encoding: .utf8
        ) else {
            return Metric(value: nil, unit: "%")
        }

        var values: [String: UInt64] = [:]

        for line in contents.split(separator: "\n") {
            let parts = line.split(
                whereSeparator: \.isWhitespace
            )

            guard parts.count >= 2,
                  let number = UInt64(parts[1]) else {
                continue
            }

            values[String(parts[0].dropLast())] = number
        }

        guard let total = values["MemTotal"],
              let available = values["MemAvailable"],
              total > 0,
              available <= total else {
            return Metric(value: nil, unit: "%")
        }

        let used = total - available
        let usage = 100.0 * Double(used) / Double(total)

        let usedGiB = Double(used) / (1024.0 * 1024.0)
        let totalGiB = Double(total) / (1024.0 * 1024.0)

        return Metric(
            value: rounded(usage),
            unit: "%",
            detail: String(
                format: "%.1f / %.1f GiB",
                usedGiB,
                totalGiB
            )
        )
    }

    // MARK: - Disk

    private func diskMetric() -> Metric {
        var filesystem = statvfs()

        let result = "/".withCString { path in
            statvfs(path, &filesystem)
        }

        guard result == 0 else {
            return Metric(value: nil, unit: "%")
        }

        let blockSize = Double(filesystem.f_frsize)
        let totalBlocks = Double(filesystem.f_blocks)
        let freeBlocks = Double(filesystem.f_bfree)
        let availableBlocks = Double(filesystem.f_bavail)

        guard blockSize > 0,
              totalBlocks > 0,
              freeBlocks <= totalBlocks,
              availableBlocks <= freeBlocks else {
            return Metric(value: nil, unit: "%")
        }

        let totalBytes = totalBlocks * blockSize
        let usedBytes = (totalBlocks - freeBlocks) * blockSize
        let availableBytes = availableBlocks * blockSize

        let usableBytes = usedBytes + availableBytes

        guard usableBytes > 0 else {
            return Metric(value: nil, unit: "%")
        }

        let usage = 100.0 * usedBytes / usableBytes
        let gib = 1024.0 * 1024.0 * 1024.0

        return Metric(
            value: rounded(usage),
            unit: "%",
            detail: String(
                format: "%.1f / %.1f GiB",
                usedBytes / gib,
                totalBytes / gib
            )
        )
    }

    // MARK: - GPU

    private func gpuMetric() -> Metric {
        let drmRoot = URL(
            fileURLWithPath: "/sys/class/drm",
            isDirectory: true
        )

        let fileManager = FileManager.default

        guard let entries = try? fileManager.contentsOfDirectory(
            at: drmRoot,
            includingPropertiesForKeys: nil
        ) else {
            return unavailableGPUMetric()
        }

        let cards = entries
            .filter {
                $0.lastPathComponent.hasPrefix("card")
            }
            .sorted {
                $0.lastPathComponent < $1.lastPathComponent
            }

        for card in cards {
            let path = card
                .appendingPathComponent("device")
                .appendingPathComponent("gpu_busy_percent")

            guard let contents = try? String(
                contentsOf: path,
                encoding: .utf8
            ),
            let value = Double(
                contents.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            ),
            value.isFinite,
            (0.0...100.0).contains(value) else {
                continue
            }

            return Metric(
                value: rounded(value),
                unit: "%",
                detail: card.lastPathComponent
            )
        }

        return unavailableGPUMetric()
    }

    private func unavailableGPUMetric() -> Metric {
        Metric(
            value: nil,
            unit: "%",
            detail: "GPU usage unavailable"
        )
    }

    // MARK: - Utilities

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
