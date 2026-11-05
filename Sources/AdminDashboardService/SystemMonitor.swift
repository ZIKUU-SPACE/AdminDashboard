// ~/workspace/AdminDashboard/Sources/AdminDashboardService/SystemMonitor.swift

import Foundation
import AdminDashboardShared
import Glibc

actor SystemMonitor {

    // MARK: - Configuration

    private let procRoot: URL
    private let sysRoot: URL

    private let samplingInterval: Duration = .seconds(1)

    // MARK: - State

    private var previousCPU: CPUCounters?
    private var latestMetrics: SystemMetrics = .empty
    private var latestResources: SystemResources?
    private var samplingTask: Task<Void, Never>?

    init(
        procRoot: URL = URL(fileURLWithPath: "/proc"),
        sysRoot: URL = URL(fileURLWithPath: "/sys")
    ) {
        self.procRoot = procRoot
        self.sysRoot = sysRoot
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
                await self.collect()

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
        latestResources = nil
    }

    // MARK: - Cached Data

    func metrics() -> SystemMetrics {
        latestMetrics
    }

    /// Returns nil until a complete resource snapshot is available.
    ///
    /// GPU usage and optional hardware properties may still be nil
    /// within a valid snapshot.
    func resources() -> SystemResources? {
        latestResources
    }

    // MARK: - Sampling

    private func collect() {
        cachedMemoryValues = memoryValues()

        let cpu = cpuMetric()
        let memory = memorySnapshot()
        let swap = swapSnapshot()
        let disk = diskSnapshot()
        let gpu = gpuSnapshot()

        latestMetrics = SystemMetrics(
            cpu: cpu,
            memory: memory?.metric
                ?? Metric(value: nil, unit: "%"),
            disk: disk?.metric
                ?? Metric(value: nil, unit: "%"),
            gpu: Metric(
                value: gpu.usagePercent,
                unit: "%",
                detail: gpu.device ?? "GPU usage unavailable"
            )
        )

        guard let cpuUsage = cpu.value,
              let memory,
              let swap,
              let disk else {
            latestResources = nil
            return
        }

        let (load1, load5, load15) = loadAverage()

        latestResources = SystemResources(
            cpu: CPUResourceDetails(
                usagePercent: cpuUsage,
                physicalCores: physicalCoreCount(),
                logicalCores: logicalCoreCount(),
                loadAverage1m: load1,
                loadAverage5m: load5,
                loadAverage15m: load15
            ),
            memory: memory.details,
            swap: swap,
            disk: disk.details,
            gpu: gpu
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

        guard totalDelta > 0,
              idleDelta <= totalDelta else {
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

        guard let contents = LinuxFileReader.read(path),
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

    private func logicalCoreCount() -> Int? {
        let count = sysconf(Int32(_SC_NPROCESSORS_ONLN))
        return count > 0 ? Int(count) : nil
    }

    private func physicalCoreCount() -> Int? {
        let path = procRoot.appendingPathComponent("cpuinfo")

        guard let contents = LinuxFileReader.read(path) else {
            return nil
        }

        var cores = Set<String>()

        for block in contents.components(
            separatedBy: "\n\n"
        ) {
            var physicalID: String?
            var coreID: String?

            for line in block.split(separator: "\n") {
                guard let separator = line.firstIndex(
                    of: ":"
                ) else {
                    continue
                }

                let key = line[..<separator]
                    .trimmingCharacters(in: .whitespaces)

                let value = line[
                    line.index(after: separator)...
                ].trimmingCharacters(in: .whitespaces)

                switch key {
                case "physical id":
                    physicalID = value
                case "core id":
                    coreID = value
                default:
                    break
                }
            }

            if let physicalID, let coreID {
                cores.insert("\(physicalID):\(coreID)")
            }
        }

        return cores.isEmpty ? nil : cores.count
    }

    private func loadAverage() -> (
        Double?,
        Double?,
        Double?
    ) {
        let path = procRoot.appendingPathComponent("loadavg")

        guard let text = LinuxFileReader.read(path) else {
            return (nil, nil, nil)
        }

        let fields = text.split(
            whereSeparator: \.isWhitespace
        )

        guard fields.count >= 3 else {
            return (nil, nil, nil)
        }

        return (
            Double(fields[0]),
            Double(fields[1]),
            Double(fields[2])
        )
    }

    // MARK: - Memory and Swap

    private struct MemorySnapshot {
        let details: MemoryResourceDetails
        let metric: Metric
    }

    private func memoryValues() -> [String: UInt64]? {
        let path = procRoot.appendingPathComponent("meminfo")

        guard let contents = LinuxFileReader.read(path) else {
            return nil
        }

        var values: [String: UInt64] = [:]

        for line in contents.split(separator: "\n") {
            let fields = line.split(
                whereSeparator: \.isWhitespace
            )

            guard fields.count >= 2,
                  fields[0].hasSuffix(":"),
                  let number = UInt64(fields[1]) else {
                continue
            }

            let key = String(fields[0].dropLast())
            values[key] = number
        }

        return values
    }

    private func memorySnapshot() -> MemorySnapshot? {
        guard let values = cachedMemoryValues,
              let total = values["MemTotal"],
              let available = values["MemAvailable"],
              total > 0,
              available <= total else {
            return nil
        }

        let used = total - available

        let usage = rounded(
            100.0 * Double(used) / Double(total)
        )

        let totalGiB = rounded(kibToGiB(total))
        let usedGiB = rounded(kibToGiB(used))
        let availableGiB = rounded(kibToGiB(available))

        let cachedGiB = values["Cached"].map {
            rounded(kibToGiB($0))
        }

        return MemorySnapshot(
            details: MemoryResourceDetails(
                totalGiB: totalGiB,
                usedGiB: usedGiB,
                availableGiB: availableGiB,
                cachedGiB: cachedGiB,
                usagePercent: usage
            ),
            metric: Metric(
                value: usage,
                unit: "%",
                detail: String(
                    format: "%.1f / %.1f GiB",
                    usedGiB,
                    totalGiB
                )
            )
        )
    }

    private func swapSnapshot() -> SwapResourceDetails? {
        guard let values = cachedMemoryValues,
              let total = values["SwapTotal"],
              let free = values["SwapFree"],
              free <= total else {
            return nil
        }

        let used = total - free

        let usage = total > 0
            ? rounded(100.0 * Double(used) / Double(total))
            : 0.0

        return SwapResourceDetails(
            totalGiB: rounded(kibToGiB(total)),
            usedGiB: rounded(kibToGiB(used)),
            freeGiB: rounded(kibToGiB(free)),
            usagePercent: usage
        )
    }

    /// Memory and Swap share one /proc/meminfo read per sample.
    private var cachedMemoryValues: [String: UInt64]?

    // MARK: - Disk

    private struct DiskSnapshot {
        let details: DiskResourceDetails
        let metric: Metric
    }

    private func diskSnapshot() -> DiskSnapshot? {
        var filesystem = statvfs()

        let result = "/".withCString { path in
            statvfs(path, &filesystem)
        }

        guard result == 0 else {
            return nil
        }

        let blockSize = Double(filesystem.f_frsize)
        let totalBlocks = Double(filesystem.f_blocks)
        let freeBlocks = Double(filesystem.f_bfree)
        let availableBlocks = Double(filesystem.f_bavail)

        guard blockSize > 0,
              totalBlocks > 0,
              freeBlocks <= totalBlocks,
              availableBlocks <= freeBlocks else {
            return nil
        }

        let totalBytes = totalBlocks * blockSize
        let usedBytes = (totalBlocks - freeBlocks) * blockSize
        let availableBytes = availableBlocks * blockSize

        // Match psutil's convention for the usage percentage:
        // reserved blocks are excluded from available capacity.
        let usableBytes = usedBytes + availableBytes

        guard usableBytes > 0 else {
            return nil
        }

        let usage = rounded(
            100.0 * usedBytes / usableBytes
        )

        let gib = 1024.0 * 1024.0 * 1024.0

        let totalGiB = rounded(totalBytes / gib)
        let usedGiB = rounded(usedBytes / gib)
        let freeGiB = rounded(availableBytes / gib)

        return DiskSnapshot(
            details: DiskResourceDetails(
                totalGiB: totalGiB,
                usedGiB: usedGiB,
                freeGiB: freeGiB,
                usagePercent: usage
            ),
            metric: Metric(
                value: usage,
                unit: "%",
                detail: String(
                    format: "%.1f / %.1f GiB",
                    usedGiB,
                    totalGiB
                )
            )
        )
    }

    // MARK: - GPU

    private func gpuSnapshot() -> GPUResourceDetails {
        let drmRoot = sysRoot
            .appendingPathComponent("class")
            .appendingPathComponent("drm")

        guard let entries = try? FileManager.default
            .contentsOfDirectory(
                at: drmRoot,
                includingPropertiesForKeys: nil
            ) else {
            return GPUResourceDetails(
                device: nil,
                usagePercent: nil
            )
        }

        let cards = entries
            .filter {
                $0.lastPathComponent.hasPrefix("card")
                    && !$0.lastPathComponent.contains("-")
            }
            .sorted {
                $0.lastPathComponent < $1.lastPathComponent
            }

        for card in cards {
            let path = card
                .appendingPathComponent("device")
                .appendingPathComponent("gpu_busy_percent")

            guard let contents = LinuxFileReader.read(path),
                  let value = Double(
                    contents.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                  ),
                  value.isFinite,
                  (0.0...100.0).contains(value) else {
                continue
            }

            return GPUResourceDetails(
                device: card.lastPathComponent,
                usagePercent: rounded(value)
            )
        }

        return GPUResourceDetails(
            device: nil,
            usagePercent: nil
        )
    }

    // MARK: - Utilities

    private func kibToGiB(_ kib: UInt64) -> Double {
        Double(kib) / (1024.0 * 1024.0)
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
