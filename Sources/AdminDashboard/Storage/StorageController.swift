
// ~/workspace/AdminDashboard/Sources/AdminDashboard/StorageController.swift

import Foundation
import Application
import AdminDashboardShared

/// Coordinates Storage Services monitoring.
///
/// Service status is refreshed every 10 seconds while
/// the Storage tab is active.
///
/// All mutable state and callbacks are confined to the
/// designated ZIKUU UI thread.
///
/// Network I/O is managed by SystemEndpointTask.
final class StorageController: @unchecked Sendable {

    // MARK: - Dependencies

    private let uiThread: Thread

    private let servicesEndpoint:
        SystemEndpointTask<StorageStatusResponse>

    // MARK: - Lifecycle

    private var isActive = false
    private var hasLoaded = false

    // MARK: - State

    private(set) var services: [StorageService] = []
    private(set) var lastError: String?

    var isLoading: Bool {
        !hasLoaded && servicesEndpoint.isLoading
    }

    // MARK: - Callbacks

    var onServicesChanged: (([StorageService]) -> Void)?
    var onLoadingChanged: ((Bool) -> Void)?
    var onErrorChanged: ((String?) -> Void)?

    // MARK: - Initialization

    init(
        application: Application = .shared,
        client: StorageAPIClient = StorageAPIClient()
    ) {
        uiThread = Thread.current

        servicesEndpoint = SystemEndpointTask(
            application: application,
            interval: .seconds(10)
        ) {
            try await client.fetchServices()
        }

        configureCallbacks()
    }

    // MARK: - Endpoint Callbacks

    private func configureCallbacks() {
        servicesEndpoint.onValue = { [weak self] response in
            self?.receiveServices(response)
        }

        servicesEndpoint.onError = { [weak self] message in
            self?.receiveError(message)
        }

        servicesEndpoint.onLoadingChanged = { [weak self] loading in
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

        servicesEndpoint.start()
    }

    func deactivate() {
        assertUIThread()

        guard isActive else {
            return
        }

        isActive = false

        servicesEndpoint.stop()
    }

    // MARK: - Refresh

    func refresh() {
        assertUIThread()

        guard isActive else {
            return
        }

        servicesEndpoint.restart()
    }

    // MARK: - Results

    private func receiveServices(
        _ response: StorageStatusResponse
    ) {
        assertUIThread()

        guard isActive else {
            return
        }

        if !hasLoaded {
            hasLoaded = true
            onLoadingChanged?(false)
        }

        let updated = response.services

        if services != updated {
            services = updated
            onServicesChanged?(updated)
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

    // MARK: - Thread Validation

    private func assertUIThread() {
        precondition(
            Thread.current === uiThread,
            "StorageController must be accessed on its UI thread"
        )
    }
}
