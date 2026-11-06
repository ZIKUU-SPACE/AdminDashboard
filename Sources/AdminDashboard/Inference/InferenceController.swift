
// ~/workspace/AdminDashboard/Sources/AdminDashboard/InferenceController.swift

import Foundation
import Application
import AdminDashboardShared

/// Coordinates inference backend listing and runtime operations.
///
/// Runtime actions are tracked independently by backend name.
/// Different backends may be operated concurrently.
///
/// Polling continues during runtime actions. In-flight backends
/// retain their previous displayed status until their action
/// finishes, preventing stale snapshots from changing their UI.
///
/// All mutable state and callbacks are confined to the ZIKUU
/// UI thread. Network I/O runs in detached tasks.
///
/// @unchecked Sendable is necessary because the designated
/// ZIKUU UI thread is not represented by Swift MainActor.
final class InferenceController: @unchecked Sendable {

    // MARK: - Dependencies

    private let application: Application
    private let client: InferenceAPIClient
    private let uiThread: Thread

    // MARK: - Polling

    private let backendsEndpoint:
        SystemEndpointTask<InferenceBackendsResponse>

    // MARK: - Lifecycle

    private var isActive = false
    private var generation: UInt64 = 0

    // MARK: - Runtime Actions

    private var actionTasks: [String: Task<Void, Never>] = [:]

    private(set) var busyBackends: Set<String> = []
    private(set) var actionError: String?

    // MARK: - Backend State

    private(set) var backends: [InferenceBackend] = []
    private(set) var lastError: String?

    private var hasLoaded = false

    var isLoading: Bool {
        !hasLoaded && backendsEndpoint.isLoading
    }

    // MARK: - Callbacks

    var onBackendsChanged: (([InferenceBackend]) -> Void)?
    var onLoadingChanged: ((Bool) -> Void)?
    var onErrorChanged: ((String?) -> Void)?

    /// New callback for independent runtime actions.
    var onBusyBackendsChanged: ((Set<String>) -> Void)?

    var onActionErrorChanged: ((String?) -> Void)?

    // MARK: - Initialization

    init(
        application: Application = .shared,
        client: InferenceAPIClient = InferenceAPIClient()
    ) {
        self.application = application
        self.client = client
        self.uiThread = Thread.current

        backendsEndpoint = SystemEndpointTask(
            application: application,
            interval: .seconds(5)
        ) {
            try await client.fetchBackends()
        }

        configureCallbacks()
    }

    // MARK: - Endpoint Callbacks

    private func configureCallbacks() {
        backendsEndpoint.onValue = { [weak self] response in
            self?.receiveBackends(response)
        }

        backendsEndpoint.onError = { [weak self] message in
            self?.receiveError(message)
        }

        backendsEndpoint.onLoadingChanged = { [weak self] loading in
            guard let self else {
                return
            }

            if !self.hasLoaded {
                self.onLoadingChanged?(loading)
            }
        }
    }

    // MARK: - Lifecycle

    func activate() {
        assertUIThread()

        guard !isActive else {
            return
        }

        isActive = true
        generation &+= 1

        backendsEndpoint.start()
    }

    func deactivate() {
        assertUIThread()

        guard isActive else {
            return
        }

        isActive = false
        generation &+= 1

        backendsEndpoint.stop()

        for task in actionTasks.values {
            task.cancel()
        }

        actionTasks.removeAll()
        setBusyBackends([])
    }

    // MARK: - Refresh

    func refresh() {
        assertUIThread()

        guard isActive else {
            return
        }

        backendsEndpoint.restart()
    }

    // MARK: - Runtime Actions

    func startBackend(_ backendName: String) {
        performAction(
            backendName: backendName,
            start: true
        )
    }

    func stopBackend(_ backendName: String) {
        performAction(
            backendName: backendName,
            start: false
        )
    }

    private func performAction(
        backendName: String,
        start: Bool
    ) {
        assertUIThread()

        guard isActive,
              !busyBackends.contains(backendName) else {
            return
        }

        guard let backend = backends.first(
            where: { $0.name == backendName }
        ) else {
            return
        }

        if start {
            guard backend.status == "stopped" else {
                return
            }
        } else {
            guard backend.status == "running" else {
                return
            }
        }

        actionError = nil
        onActionErrorChanged?(nil)

        var updatedBusy = busyBackends
        updatedBusy.insert(backendName)
        setBusyBackends(updatedBusy)

        let requestGeneration = generation
        let application = self.application
        let client = self.client

        let task = Task.detached(priority: .utility) {
            [weak self] in

            do {
                if start {
                    _ = try await client.startBackend(backendName)
                } else {
                    _ = try await client.stopBackend(backendName)
                }

                guard !Task.isCancelled else {
                    return
                }

                application.performOnUIThread { [weak self] in
                    self?.receiveActionSuccess(
                        backendName: backendName,
                        generation: requestGeneration
                    )
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                let message = String(describing: error)

                application.performOnUIThread { [weak self] in
                    self?.receiveActionError(
                        message,
                        backendName: backendName,
                        generation: requestGeneration
                    )
                }
            }
        }

        actionTasks[backendName] = task
    }

    // MARK: - Backend Results

    private func receiveBackends(
        _ response: InferenceBackendsResponse
    ) {
        assertUIThread()

        guard isActive else {
            return
        }

        // Retain the previously displayed status for backends
        // whose runtime actions are currently in progress.
        //
        // A polling response can have been generated before
        // an action started, so its status may be stale.

        let previousByName = Dictionary(
            uniqueKeysWithValues: backends.map {
                ($0.name, $0)
            }
        )

        let updated = response.backends.map { backend in
            guard busyBackends.contains(backend.name),
                  let previous = previousByName[backend.name]
            else {
                return backend
            }

            return InferenceBackend(
                name: backend.name,
                node: backend.node,
                url: backend.url,
                kind: backend.kind,
                model: backend.model,
                runtime: backend.runtime,
                status: previous.status
            )
        }

        if !hasLoaded {
            hasLoaded = true
            onLoadingChanged?(false)
        }

        if backends != updated {
            backends = updated
            onBackendsChanged?(updated)
        }

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

        if !hasLoaded {
            hasLoaded = true
            onLoadingChanged?(false)
        }

        if lastError != message {
            lastError = message
            onErrorChanged?(message)
        }
    }

    // MARK: - Action Results

    private func receiveActionSuccess(
        backendName: String,
        generation requestGeneration: UInt64
    ) {
        assertUIThread()

        guard isCurrent(requestGeneration),
              busyBackends.contains(backendName) else {
            return
        }

        finishAction(backendName)

        // An accepted start request does not prove readiness.
        // Retrieve actual runtime status from the service.
        backendsEndpoint.restart()
    }

    private func receiveActionError(
        _ message: String,
        backendName: String,
        generation requestGeneration: UInt64
    ) {
        assertUIThread()

        guard isCurrent(requestGeneration),
              busyBackends.contains(backendName) else {
            return
        }

        actionError = "\(backendName): \(message)"
        onActionErrorChanged?(actionError)

        finishAction(backendName)

        // Refresh even if the runtime request failed.
        backendsEndpoint.restart()
    }

    private func finishAction(_ backendName: String) {
        assertUIThread()

        actionTasks.removeValue(forKey: backendName)

        var updatedBusy = busyBackends
        updatedBusy.remove(backendName)

        setBusyBackends(updatedBusy)
    }

    // MARK: - State Helpers

    private func setBusyBackends(_ names: Set<String>) {
        assertUIThread()

        guard busyBackends != names else {
            return
        }

        busyBackends = names

        onBusyBackendsChanged?(names)

    }

    private func isCurrent(
        _ requestGeneration: UInt64
    ) -> Bool {
        isActive && generation == requestGeneration
    }

    // MARK: - Thread Validation

    private func assertUIThread() {
        precondition(
            Thread.current === uiThread,
            "InferenceController must be accessed on its UI thread"
        )
    }
}

