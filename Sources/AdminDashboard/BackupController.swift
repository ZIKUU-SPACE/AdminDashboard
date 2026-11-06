
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/BackupController.swift

import Foundation
import Application
import AdminDashboardShared

/// Coordinates backup status, generations, history,
/// and execution requests.
///
/// All mutable state and callbacks are confined to
/// the designated ZIKUU UI thread.
///
/// Backup execution itself belongs to Mini Backup Service.
/// Deactivating this controller never stops a running backup.
final class BackupController: @unchecked Sendable {

    // MARK: - Dependencies

    private let uiThread: Thread

    private let statusEndpoint:
        SystemEndpointTask<BackupExecutionStatus>

    private let runningStatusEndpoint:
        SystemEndpointTask<BackupExecutionStatus>

    private let currentEndpoint:
        SystemEndpointTask<BackupGeneration>

    private let previousEndpoint:
        SystemEndpointTask<BackupGeneration>

    private let historyEndpoint:
        SystemEndpointTask<BackupHistory>

    private let runEndpoint:
        SystemEndpointTask<BackupStartResponse>

    // MARK: - Lifecycle

    private var isActive = false
    private var hasLoadedStatus = false
    private var isSubmitting = false

    // MARK: - State

    private(set) var status: BackupExecutionStatus?
    private(set) var current: BackupGeneration?
    private(set) var previous: BackupGeneration?
    private(set) var history: BackupHistory?

    private(set) var lastError: String?

    var isRunning: Bool {
        status?.isRunning ?? false
    }

    var isLoading: Bool {
        !hasLoadedStatus &&
        (
            statusEndpoint.isLoading ||
            runningStatusEndpoint.isLoading
        )
    }

    var canRun: Bool {
        isActive && !isRunning && !isSubmitting && hasLoadedStatus
    }

    // MARK: - Callbacks

    var onStatusChanged: ((BackupExecutionStatus?) -> Void)?
    var onCurrentChanged: ((BackupGeneration?) -> Void)?
    var onPreviousChanged: ((BackupGeneration?) -> Void)?
    var onHistoryChanged: ((BackupHistory?) -> Void)?

    var onLoadingChanged: ((Bool) -> Void)?
    var onExecutingChanged: ((Bool) -> Void)?
    var onCanRunChanged: ((Bool) -> Void)?
    var onErrorChanged: ((String?) -> Void)?

    // MARK: - Initialization

    init(
        application: Application = .shared,
        client: BackupAPIClient = BackupAPIClient()
    ) {
        uiThread = Thread.current

        statusEndpoint = SystemEndpointTask(
            application: application
        ) {
            try await client.fetchStatus()
        }

        runningStatusEndpoint = SystemEndpointTask(
            application: application,
            interval: .milliseconds(1500)
        ) {
            try await client.fetchStatus()
        }

        currentEndpoint = SystemEndpointTask(
            application: application
        ) {
            try await client.fetchCurrent()
        }

        previousEndpoint = SystemEndpointTask(
            application: application
        ) {
            try await client.fetchPrevious()
        }

        historyEndpoint = SystemEndpointTask(
            application: application
        ) {
            try await client.fetchHistory(limit: 10)
        }

        runEndpoint = SystemEndpointTask(
            application: application
        ) {
            try await client.runBackup()
        }

        configureCallbacks()
    }

    // MARK: - Endpoint Callbacks

    private func configureCallbacks() {

        statusEndpoint.onValue = { [weak self] value in
            self?.receiveStatus(value)
        }

        runningStatusEndpoint.onValue = { [weak self] value in
            self?.receiveStatus(value)
        }

        statusEndpoint.onError = { [weak self] message in
            self?.receiveError(message)
        }

        runningStatusEndpoint.onError = { [weak self] message in
            self?.receiveError(message)
        }

        statusEndpoint.onLoadingChanged = { [weak self] _ in
            self?.notifyLoadingChanged()
        }

        runningStatusEndpoint.onLoadingChanged = { [weak self] _ in
            self?.notifyLoadingChanged()
        }

        currentEndpoint.onValue = { [weak self] value in
            self?.receiveCurrent(value)
        }

        previousEndpoint.onValue = { [weak self] value in
            self?.receivePrevious(value)
        }

        historyEndpoint.onValue = { [weak self] value in
            self?.receiveHistory(value)
        }

        currentEndpoint.onError = { [weak self] message in
            self?.receiveError(message)
        }

        previousEndpoint.onError = { [weak self] message in
            self?.receiveError(message)
        }

        historyEndpoint.onError = { [weak self] message in
            self?.receiveError(message)
        }

        runEndpoint.onValue = { [weak self] value in
            self?.receiveRunStarted(value)
        }

        runEndpoint.onError = { [weak self] message in
            self?.receiveRunError(message)
        }
    }

    // MARK: - Lifecycle

    func activate() {
        assertUIThread()

        guard !isActive else {
            return
        }

        isActive = true

        statusEndpoint.start()
        currentEndpoint.start()
        previousEndpoint.start()
        historyEndpoint.start()

        onCanRunChanged?(canRun)
    }

    func deactivate() {
        assertUIThread()

        guard isActive else {
            return
        }

        isActive = false

        statusEndpoint.stop()
        runningStatusEndpoint.stop()
        currentEndpoint.stop()
        previousEndpoint.stop()
        historyEndpoint.stop()
        runEndpoint.stop()

        isSubmitting = false

        onLoadingChanged?(false)
        onExecutingChanged?(isRunning)
        onCanRunChanged?(canRun)
    }

    // MARK: - Refresh

    func refresh() {
        assertUIThread()

        guard isActive else {
            return
        }

        refreshStatus()
        refreshReports()
    }

    private func refreshStatus() {
        assertUIThread()

        runningStatusEndpoint.stop()
        statusEndpoint.restart()
    }

    private func refreshReports() {
        assertUIThread()

        currentEndpoint.restart()
        previousEndpoint.restart()
        historyEndpoint.restart()
    }

    // MARK: - Backup Execution

    func runBackup() {
        assertUIThread()

        guard canRun else {
            return
        }

        isSubmitting = true

        onCanRunChanged?(canRun)
        runEndpoint.restart()
    }

    // MARK: - Status Results

    private func receiveStatus(
        _ value: BackupExecutionStatus
    ) {
        assertUIThread()

        guard isActive else {
            return
        }

        let wasRunning = isRunning
        let wasLoaded = hasLoadedStatus

        if !hasLoadedStatus {
            hasLoadedStatus = true
        }

        if status != value {
            status = value
            onStatusChanged?(value)
        }

        if !wasLoaded {
            onLoadingChanged?(false)
        }

        clearError()

        if value.isRunning {
            statusEndpoint.stop()
            runningStatusEndpoint.start()
        } else {
            runningStatusEndpoint.stop()

            if wasRunning {
                refreshReports()
            }
        }

        if wasRunning != value.isRunning {
            onExecutingChanged?(value.isRunning)
        }

        onCanRunChanged?(canRun)
    }

    // MARK: - Generation Results

    private func receiveCurrent(
        _ value: BackupGeneration
    ) {
        assertUIThread()

        guard isActive else {
            return
        }

        if current != value {
            current = value
            onCurrentChanged?(value)
        }

        clearError()
    }

    private func receivePrevious(
        _ value: BackupGeneration
    ) {
        assertUIThread()

        guard isActive else {
            return
        }

        if previous != value {
            previous = value
            onPreviousChanged?(value)
        }

        clearError()
    }

    // MARK: - History Results

    private func receiveHistory(
        _ value: BackupHistory
    ) {
        assertUIThread()

        guard isActive else {
            return
        }

        if history != value {
            history = value
            onHistoryChanged?(value)
        }

        clearError()
    }

    // MARK: - Execution Results

    private func receiveRunStarted(
        _ value: BackupStartResponse
    ) {
        assertUIThread()

        guard isActive else {
            return
        }

        isSubmitting = false

        let runningStatus = BackupExecutionStatus(
            state: value.state,
            startedAt: value.startedAt,
            completedAt: nil,
            exitCode: nil,
            stdout: nil,
            stderr: nil
        )

        receiveStatus(runningStatus)
    }

    private func receiveRunError(
        _ message: String
    ) {
        assertUIThread()

        guard isActive else {
            return
        }

        isSubmitting = false

        receiveError(message)

        // A failed request does not establish whether
        // the remote service started a backup.
        // Recheck the actual execution state.
        refreshStatus()

        onCanRunChanged?(canRun)
    }

    // MARK: - Errors

    private func receiveError(_ message: String) {
        assertUIThread()

        guard isActive else {
            return
        }

        if !hasLoadedStatus {
            hasLoadedStatus = true
            onLoadingChanged?(false)
        }

        if lastError != message {
            lastError = message
            onErrorChanged?(message)
        }

        onCanRunChanged?(canRun)
    }

    private func clearError() {
        assertUIThread()

        guard lastError != nil else {
            return
        }

        lastError = nil
        onErrorChanged?(nil)
    }

    // MARK: - Loading

    private func notifyLoadingChanged() {
        assertUIThread()

        guard isActive else {
            return
        }

        onLoadingChanged?(isLoading)
    }

    // MARK: - Thread Validation

    private func assertUIThread() {
        precondition(
            Thread.current === uiThread,
            "BackupController must be accessed on its UI thread"
        )
    }
}
