
// ~/workspace/AdminDashboard/Sources/AdminDashboard/SystemEndpointTask.swift

import Foundation
import Application

/// Runs an asynchronous System API request once or periodically.
///
/// The owner must access start(), stop(), and callbacks only
/// from the designated ZIKUU UI thread.
///
/// Network requests run in a detached task.
/// Results are delivered through Application.performOnUIThread.
///
/// Each instance owns its cancellation and generation state.
/// Different endpoints therefore cannot invalidate each other.
final class SystemEndpointTask<Value: Sendable>: @unchecked Sendable {

    // MARK: - Dependencies

    private let application: Application
    private let uiThread: Thread

    private let fetch: @Sendable () async throws -> Value
    private let interval: Duration?

    // MARK: - State

    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var isActive = false

    private(set) var isLoading = false

    // MARK: - Callbacks

    var onValue: ((Value) -> Void)?
    var onError: ((String) -> Void)?
    var onLoadingChanged: ((Bool) -> Void)?

    // MARK: - Initialization

    /// A nil interval performs one request.
    ///
    /// A non-nil interval repeats after each completed request.
    /// Requests never overlap within the same instance.
    init(
        application: Application = .shared,
        interval: Duration? = nil,
        fetch: @escaping @Sendable () async throws -> Value
    ) {
        self.application = application
        self.uiThread = Thread.current
        self.interval = interval
        self.fetch = fetch
    }

    // MARK: - Lifecycle

    func start() {
        assertUIThread()

        guard !isActive else {
            return
        }

        isActive = true
        generation &+= 1

        let requestGeneration = generation
        let application = self.application
        let fetch = self.fetch
        let interval = self.interval

        setLoading(true)

        task = Task.detached(priority: .utility) {
            [weak self] in

            while !Task.isCancelled {
                do {
                    let value = try await fetch()

                    guard !Task.isCancelled else {
                        break
                    }

                    application.performOnUIThread {
                        [weak self] in

                        self?.receive(
                            value,
                            generation: requestGeneration
                        )
                    }
                } catch {
                    guard !Task.isCancelled else {
                        break
                    }

                    let message = String(describing: error)

                    application.performOnUIThread {
                        [weak self] in

                        self?.receiveError(
                            message,
                            generation: requestGeneration
                        )
                    }
                }

                guard let interval else {
                    break
                }

                do {
                    try await Task.sleep(for: interval)
                } catch {
                    break
                }
            }
        }
    }

    func stop() {
        assertUIThread()

        guard isActive else {
            return
        }

        isActive = false
        generation &+= 1

        task?.cancel()
        task = nil

        setLoading(false)
    }

    func restart() {
        assertUIThread()

        stop()
        start()
    }

    // MARK: - Result Handling

    private func receive(
        _ value: Value,
        generation requestGeneration: UInt64
    ) {
        assertUIThread()

        guard isCurrent(requestGeneration) else {
            return
        }

        setLoading(false)
        onValue?(value)
    }

    private func receiveError(
        _ message: String,
        generation requestGeneration: UInt64
    ) {
        assertUIThread()

        guard isCurrent(requestGeneration) else {
            return
        }

        setLoading(false)
        onError?(message)
    }

    // MARK: - Loading

    private func setLoading(_ loading: Bool) {
        assertUIThread()

        guard isLoading != loading else {
            return
        }

        isLoading = loading
        onLoadingChanged?(loading)
    }

    // MARK: - Validation

    private func isCurrent(
        _ requestGeneration: UInt64
    ) -> Bool {
        isActive && generation == requestGeneration
    }

    private func assertUIThread() {
        precondition(
            Thread.current === uiThread,
            "SystemEndpointTask must be accessed on its UI thread"
        )
    }
}
