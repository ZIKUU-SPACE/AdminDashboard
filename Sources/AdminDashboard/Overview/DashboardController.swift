
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/DashboardController.swift

import Foundation
import Application
import AdminDashboardShared

/// Coordinates metrics retrieval and UI state.
///
/// Mutable state and callbacks are confined to the designated UI thread.
/// Background tasks perform network I/O only.
///
/// @unchecked Sendable is used because the ZIKUU UI event loop
/// is not integrated with Swift's MainActor.
final class DashboardController: @unchecked Sendable {

    // MARK: - Dependencies

    private let application: Application
    private let client: SystemMetricsClient
    private let uiThread: Thread

    // MARK: - State

    private var pollingTask: Task<Void, Never>?
    private var isActive = false

    private(set) var currentMetrics: SystemMetrics = .empty
    private(set) var lastError: String?

    // MARK: - UI Callbacks

    /// Called on the designated UI thread after state changes.
    ///
    /// The callback must not perform blocking operations.
    var onMetricsChanged: ((SystemMetrics) -> Void)?
    var onErrorChanged: ((String?) -> Void)?

    // MARK: - Initialization

    init(
        application: Application = .shared,
        client: SystemMetricsClient = SystemMetricsClient()
    ) {
        self.application = application
        self.client = client
        self.uiThread = Thread.current
    }

    // MARK: - Lifecycle

    func start() {
        assertUIThread()

        guard !isActive else {
            return
        }

        isActive = true

        let application = self.application
        let client = self.client

        pollingTask = Task.detached(
            priority: .utility
        ) { [weak self] in

            while !Task.isCancelled {
                do {
                    let metrics = try await client.fetchMetrics()

                    guard !Task.isCancelled else {
                        break
                    }

                    application.performOnUIThread { [weak self] in
                        self?.receive(metrics)
                    }
                } catch {
                    guard !Task.isCancelled else {
                        break
                    }

                    let message = String(describing: error)

                    application.performOnUIThread { [weak self] in
                        self?.receiveError(message)
                    }
                }

                do {
                    try await Task.sleep(
                        for: .seconds(3)
                    )
                } catch {
                    break
                }
            }
        }
    }

    func stop() {
        assertUIThread()

        isActive = false

        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - State Updates

    private func receive(_ metrics: SystemMetrics) {
        assertUIThread()

        guard isActive else {
            return
        }

        currentMetrics = metrics

        onMetricsChanged?(metrics)

        if lastError != nil {
            lastError = nil
            onErrorChanged?(nil)
        }
    }

    private func receiveError(_ message: String) {
        assertUIThread()

        guard isActive else {
            return
        }

        // Preserve the last successfully retrieved metrics.
        lastError = message
        onErrorChanged?(message)
    }

    // MARK: - Thread Validation

    private func assertUIThread() {
        precondition(
            Thread.current === uiThread,
            "DashboardController must be accessed on its UI thread"
        )
    }
}
