// ~/workspace/AdminDashboard/Sources/AdminDashboard/SystemController.swift

import AdminDashboardShared
import Application
import Foundation

/// Coordinates data retrieval and UI state for the System page.
///
/// Mutable state and callbacks are confined to the ZIKUU UI thread.
/// SystemEndpointTask handles asynchronous requests, cancellation,
/// and generation validation independently for each endpoint.
///
/// @unchecked Sendable is necessary because the designated ZIKUU
/// UI thread is not represented by Swift MainActor.
final class SystemController: @unchecked Sendable {

    // MARK: - Dependencies

    private let uiThread: Thread

    // MARK: - Endpoint Tasks

    private let hostEndpoint: SystemEndpointTask<HostInformation>
    private let resourcesEndpoint: SystemEndpointTask<SystemResources>
    private let networkEndpoint: SystemEndpointTask<SystemNetwork>
    private let runtimeEndpoint: SystemEndpointTask<SystemRuntime>

    // MARK: - Lifecycle State

    private var isActive = false

    // MARK: - Host State

    private(set) var currentInformation: HostInformation?
    private(set) var lastError: String?

    var isLoading: Bool {
        hostEndpoint.isLoading
    }

    // MARK: - Resources State

    private(set) var currentResources: SystemResources?
    private(set) var resourcesError: String?

    var isResourcesLoading: Bool {
        resourcesEndpoint.isLoading
    }

    // MARK: - Network State

    private(set) var currentNetwork: SystemNetwork?
    private(set) var networkError: String?

    var isNetworkLoading: Bool {
        networkEndpoint.isLoading
    }

    // MARK: - Runtime State

    private(set) var currentRuntime: SystemRuntime?
    private(set) var runtimeError: String?

    var isRuntimeLoading: Bool {
        runtimeEndpoint.isLoading
    }

    // MARK: - Host Callbacks

    var onInformationChanged: ((HostInformation) -> Void)?
    var onLoadingChanged: ((Bool) -> Void)?
    var onErrorChanged: ((String?) -> Void)?

    // MARK: - Resources Callbacks

    var onResourcesChanged: ((SystemResources) -> Void)?
    var onResourcesLoadingChanged: ((Bool) -> Void)?
    var onResourcesErrorChanged: ((String?) -> Void)?

    // MARK: - Network Callbacks

    var onNetworkChanged: ((SystemNetwork) -> Void)?
    var onNetworkLoadingChanged: ((Bool) -> Void)?
    var onNetworkErrorChanged: ((String?) -> Void)?

    // MARK: - Runtime Callbacks

    var onRuntimeChanged: ((SystemRuntime) -> Void)?
    var onRuntimeLoadingChanged: ((Bool) -> Void)?
    var onRuntimeErrorChanged: ((String?) -> Void)?

    // MARK: - Initialization

    init(
        application: Application = .shared,
        client: SystemAPIClient = SystemAPIClient()
    ) {
        uiThread = Thread.current

        hostEndpoint = SystemEndpointTask(
            application: application
        ) {
            try await client.fetchHostInformation()
        }

        resourcesEndpoint = SystemEndpointTask(
            application: application,
            interval: .seconds(3)
        ) {
            try await client.fetchResources()
        }

        networkEndpoint = SystemEndpointTask(
            application: application,
            interval: .seconds(10)
        ) {
            try await client.fetchNetwork()
        }

        runtimeEndpoint = SystemEndpointTask(
            application: application
        ) {
            try await client.fetchRuntime()
        }

        configureCallbacks()
    }

    // MARK: - Endpoint Callbacks

    private func configureCallbacks() {

        // Host

        hostEndpoint.onValue = { [weak self] information in
            self?.receiveHost(information)
        }

        hostEndpoint.onError = { [weak self] message in
            self?.receiveHostError(message)
        }

        hostEndpoint.onLoadingChanged = { [weak self] loading in
            self?.onLoadingChanged?(loading)
        }

        // Resources

        resourcesEndpoint.onValue = { [weak self] resources in
            self?.receiveResources(resources)
        }

        resourcesEndpoint.onError = { [weak self] message in
            self?.receiveResourcesError(message)
        }

        resourcesEndpoint.onLoadingChanged = { [weak self] loading in
            self?.onResourcesLoadingChanged?(loading)
        }

        // Network

        networkEndpoint.onValue = { [weak self] network in
            self?.receiveNetwork(network)
        }

        networkEndpoint.onError = { [weak self] message in
            self?.receiveNetworkError(message)
        }

        networkEndpoint.onLoadingChanged = { [weak self] loading in
            self?.onNetworkLoadingChanged?(loading)
        }

        // Runtime

        runtimeEndpoint.onValue = { [weak self] runtime in
            self?.receiveRuntime(runtime)
        }

        runtimeEndpoint.onError = { [weak self] message in
            self?.receiveRuntimeError(message)
        }

        runtimeEndpoint.onLoadingChanged = { [weak self] loading in
            self?.onRuntimeLoadingChanged?(loading)
        }
    }

    // MARK: - Lifecycle

    func activate() {
        assertUIThread()

        guard !isActive else {
            return
        }

        isActive = true

        startEndpoints()
    }

    func deactivate() {
        assertUIThread()

        guard isActive else {
            return
        }

        isActive = false

        hostEndpoint.stop()
        resourcesEndpoint.stop()
        networkEndpoint.stop()
        runtimeEndpoint.stop()
    }

    // MARK: - Refresh

    /// Restarts all endpoint requests.
    ///
    /// Host and Runtime are retrieved once.
    /// Resources and Network resume their polling loops.
    func refresh() {
        assertUIThread()

        guard isActive else {
            return
        }

        hostEndpoint.stop()
        resourcesEndpoint.stop()
        networkEndpoint.stop()
        runtimeEndpoint.stop()

        startEndpoints()
    }

    private func startEndpoints() {
        assertUIThread()

        clearErrors()

        hostEndpoint.start()
        resourcesEndpoint.start()
        networkEndpoint.start()
        runtimeEndpoint.start()
    }

    private func clearErrors() {
        assertUIThread()

        if lastError != nil {
            lastError = nil
            onErrorChanged?(nil)
        }

        if resourcesError != nil {
            resourcesError = nil
            onResourcesErrorChanged?(nil)
        }

        if networkError != nil {
            networkError = nil
            onNetworkErrorChanged?(nil)
        }

        if runtimeError != nil {
            runtimeError = nil
            onRuntimeErrorChanged?(nil)
        }
    }

    // MARK: - Host Results

    private func receiveHost(_ information: HostInformation) {
        assertUIThread()

        currentInformation = information
        onInformationChanged?(information)

        if lastError != nil {
            lastError = nil
            onErrorChanged?(nil)
        }
    }

    private func receiveHostError(_ message: String) {
        assertUIThread()

        lastError = message
        onErrorChanged?(message)
    }

    // MARK: - Resources Results

    private func receiveResources(_ resources: SystemResources) {
        assertUIThread()

        currentResources = resources
        onResourcesChanged?(resources)

        if resourcesError != nil {
            resourcesError = nil
            onResourcesErrorChanged?(nil)
        }
    }

    private func receiveResourcesError(_ message: String) {
        assertUIThread()

        resourcesError = message
        onResourcesErrorChanged?(message)
    }

    // MARK: - Network Results

    private func receiveNetwork(_ network: SystemNetwork) {
        assertUIThread()

        // Avoid unnecessary table updates when the network
        // interface snapshot has not changed.
        if let previous = currentNetwork,
           networksEqual(previous, network) {
            if networkError != nil {
                networkError = nil
                onNetworkErrorChanged?(nil)
            }
            return
        }

        currentNetwork = network
        onNetworkChanged?(network)

        if networkError != nil {
            networkError = nil
            onNetworkErrorChanged?(nil)
        }
    }

    private func receiveNetworkError(_ message: String) {
        assertUIThread()

        networkError = message
        onNetworkErrorChanged?(message)
    }

    /// Compares the displayed network interface information.
    ///
    /// This avoids requiring Equatable conformance on the shared
    /// network models solely for UI refresh suppression.
    private func networksEqual(
        _ lhs: SystemNetwork,
        _ rhs: SystemNetwork
    ) -> Bool {
        let left = lhs.interfaces
        let right = rhs.interfaces

        guard left.count == right.count else {
            return false
        }

        return zip(left, right).allSatisfy { a, b in
            a.name == b.name
                && a.state == b.state
                && a.macAddress == b.macAddress
                && a.mtu == b.mtu
                && a.ipv6Addresses == b.ipv6Addresses
        }
    }

    // MARK: - Runtime Results

    private func receiveRuntime(_ runtime: SystemRuntime) {
        assertUIThread()

        currentRuntime = runtime
        onRuntimeChanged?(runtime)

        if runtimeError != nil {
            runtimeError = nil
            onRuntimeErrorChanged?(nil)
        }
    }

    private func receiveRuntimeError(_ message: String) {
        assertUIThread()

        runtimeError = message
        onRuntimeErrorChanged?(message)
    }

    // MARK: - Thread Validation

    private func assertUIThread() {
        precondition(
            Thread.current === uiThread,
            "SystemController must be accessed on its UI thread"
        )
    }
}
