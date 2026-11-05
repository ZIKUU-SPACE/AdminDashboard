
// ~/workspace/AdminDashboard/Sources/AdminDashboardService/LinuxFileReader.swift

import Foundation
import Glibc

/// Reads text files from Linux virtual and regular filesystems.
///
/// Does not rely on file size metadata because /proc and /sys files
/// may report zero length despite containing readable data.
///
/// Uses POSIX open/read/close, retries interrupted reads,
/// and enforces a maximum input size.
enum LinuxFileReader {

    // MARK: - Raw Text

    /// Returns the file contents without trimming whitespace.
    ///
    /// Returns nil on I/O failure or when the size limit is exceeded.
    /// An empty file produces an empty string.
    static func read(
        _ url: URL,
        maximumBytes: Int = 1024 * 1024
    ) -> String? {
        guard maximumBytes > 0 else {
            return nil
        }

        let descriptor = url.path.withCString { path in
            Glibc.open(path, O_RDONLY | O_CLOEXEC)
        }

        guard descriptor >= 0 else {
            return nil
        }

        defer {
            _ = Glibc.close(descriptor)
        }

        var bytes: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 4096)

        while true {
            let readCount = buffer.withUnsafeMutableBytes {
                rawBuffer in

                Glibc.read(
                    descriptor,
                    rawBuffer.baseAddress,
                    rawBuffer.count
                )
            }

            if readCount == 0 {
                break
            }

            if readCount < 0 {
                if errno == EINTR {
                    continue
                }

                return nil
            }

            guard readCount <= maximumBytes - bytes.count else {
                return nil
            }

            bytes.append(
                contentsOf: buffer.prefix(readCount)
            )
        }

        return String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - Trimmed Text

    /// Returns whitespace-trimmed file contents.
    ///
    /// Empty or whitespace-only contents produce nil.
    static func readTrimmed(
        _ url: URL,
        maximumBytes: Int = 1024 * 1024
    ) -> String? {
        guard let contents = read(
            url,
            maximumBytes: maximumBytes
        ) else {
            return nil
        }

        let trimmed = contents.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }
}
