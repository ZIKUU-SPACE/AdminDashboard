
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/main.swift

import Foundation
import ZIKUU
import Application
import Core
import AdminDashboardShared

// MARK: - Application Configuration

let app = Application.shared

let profile = ApplicationProfile.desktop(
    windowSystem: .auto,
    decoration: .zikuu,
    renderer: .cairo
)

guard app.configure(profile) else {
    fatalError("Failed to configure AdminDashboard")
}

guard app.installDesktopBackend() else {
    fatalError("Failed to install desktop backend")
}

// MARK: - Main Window

let (
    window,
    tabView,
    overviewView,
    storageView,
    systemView,
    inferenceView
) = makeMainWindow()

// MARK: - Overview Controller

let dashboardController = DashboardController(
    application: app
)

dashboardController.onMetricsChanged = { [weak overviewView] metrics in
    overviewView?.update(metrics: metrics)
}

dashboardController.onErrorChanged = { [weak overviewView] message in
    overviewView?.updateError(message)
}

// MARK: - System Controller

let systemController = SystemController(
    application: app
)

systemController.onInformationChanged = { [weak systemView] information in
    systemView?.update(information: information)
}

systemController.onLoadingChanged = { [weak systemView] loading in
    systemView?.updateLoading(loading)
}

systemController.onErrorChanged = { [weak systemView] message in
    systemView?.updateError(message)
}

systemController.onResourcesChanged = { [weak systemView] resources in
    systemView?.update(resources: resources)
}

systemController.onResourcesLoadingChanged = { [weak systemView] loading in
    systemView?.updateResourcesLoading(loading)
}

systemController.onResourcesErrorChanged = { [weak systemView] message in
    systemView?.updateResourcesError(message)
}

systemController.onNetworkChanged = { [weak systemView] network in
    systemView?.update(network: network)
}

systemController.onNetworkLoadingChanged = { [weak systemView] loading in
    systemView?.updateNetworkLoading(loading)
}

systemController.onNetworkErrorChanged = { [weak systemView] message in
    systemView?.updateNetworkError(message)
}

systemController.onRuntimeChanged = { [weak systemView] runtime in
    systemView?.update(runtime: runtime)
}

systemController.onRuntimeLoadingChanged = { [weak systemView] loading in
    systemView?.updateRuntimeLoading(loading)
}

systemController.onRuntimeErrorChanged = { [weak systemView] message in
    systemView?.updateRuntimeError(message)
}

// MARK: - Storage Controller

let storageController = StorageController(
    application: app
)

storageController.onServicesChanged = { [weak storageView] services in
    storageView?.update(services: services)
}

storageController.onLoadingChanged = { [weak storageView] loading in
    storageView?.updateLoading(loading)
}

storageController.onErrorChanged = { [weak storageView] message in
    storageView?.updateError(message)
}

// MARK: - Storage Web UI Actions

storageView.onOpenRequested = { service in
    guard let webPath = service.webPath,
          webPath.hasPrefix("/"),
          !webPath.hasPrefix("//") else {
        return
    }

    var components = URLComponents()

    components.scheme = "http"
    components.host = "127.0.0.1"
    components.port = service.port
    components.path = webPath

    guard let url = components.url else {
        return
    }

    do {
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/usr/bin/xdg-open"
        )
        process.arguments = [
            url.absoluteString
        ]

        try process.run()
    } catch {
        print(
            "Failed to open Storage Web UI: \(error)"
        )
    }
}

// MARK: - Backup Controller

let backupController = BackupController(
    application: app
)

// MARK: - Backup Status

backupController.onStatusChanged = {
    [weak storageView] status in

    storageView?.updateBackupStatus(status)
}

backupController.onLoadingChanged = {
    [weak storageView] loading in

    if loading {
        storageView?.updateBackupStatus(nil)
    }
}

backupController.onExecutingChanged = {
    [weak storageView] executing in

    storageView?.updateBackupExecuting(executing)
}

backupController.onCanRunChanged = {
    [weak storageView] enabled in

    storageView?.updateBackupCanRun(enabled)
}

// MARK: - Backup Generations

backupController.onCurrentChanged = {
    [weak storageView] generation in

    storageView?.updateBackupCurrent(generation)
}

backupController.onPreviousChanged = {
    [weak storageView] generation in

    storageView?.updateBackupPrevious(generation)
}

// MARK: - Backup History

backupController.onHistoryChanged = {
    [weak storageView] history in

    storageView?.updateBackupHistory(history)
}

// MARK: - Backup Errors

backupController.onErrorChanged = { message in
    if let message {
        print("Backup error: \(message)")
    }
}

// MARK: - Backup Actions

storageView.onBackupRunRequested = {
    [weak backupController] in

    backupController?.runBackup()
}

// MARK: - Inference Controller

let inferenceController = InferenceController(
    application: app
)

inferenceController.onBackendsChanged = { [weak inferenceView] backends in
    inferenceView?.update(backends: backends)
}

inferenceController.onLoadingChanged = { [weak inferenceView] loading in
    inferenceView?.updateLoading(loading)
}

inferenceController.onErrorChanged = { [weak inferenceView] message in
    inferenceView?.updateError(message)
}

// MARK: - Inference Runtime Actions

// Forward SwitchCell operations to the controller.

inferenceView.onStartRequested = { [weak inferenceController] name in
    inferenceController?.startBackend(name)
}

inferenceView.onStopRequested = { [weak inferenceController] name in
    inferenceController?.stopBackend(name)
}

// Disable runtime switches while an action is in progress.

inferenceController.onBusyBackendsChanged = { [weak inferenceView] names in
    inferenceView?.updateBusyBackends(names)
}

// Display runtime action failures without replacing
// the last successfully retrieved backend list.

inferenceController.onActionErrorChanged = { [weak inferenceView] message in
    inferenceView?.updateActionError(message)
}

// MARK: - Tab Selection

tabView.onSelectionChange = { index in
    guard tabView.items.indices.contains(index) else {
        return
    }

    let identifier = tabView.items[index].identifier

    if identifier == "system" {
        systemController.activate()
    } else {
        systemController.deactivate()
    }

    if identifier == "storage" {
        storageController.activate()
        backupController.activate()
    } else {
        storageController.deactivate()
        backupController.deactivate()
    }

    if identifier == "inference" {
        inferenceController.activate()
    } else {
        inferenceController.deactivate()
    }
}

// MARK: - Application Lifecycle

window.makeKeyAndOrderFront(nil)

guard window.isVisible else {
    fatalError("Failed to open AdminDashboard window")
}

dashboardController.start()

// Account for the selected tab before entering the event loop.

if let selectedIndex = tabView.selectedIndex,
   tabView.items.indices.contains(selectedIndex) {

    let identifier = tabView.items[selectedIndex].identifier

    if identifier == "system" {
        systemController.activate()
    }

    if identifier == "storage" {
        storageController.activate()
        backupController.activate()
    }

    if identifier == "inference" {
        inferenceController.activate()
    }
}

app.run()

inferenceController.deactivate()
backupController.deactivate()
storageController.deactivate()
systemController.deactivate()
dashboardController.stop()

// MARK: - Window Factory

func makeMainWindow() -> (
    Window,
    TabView,
    OverviewView,
    StorageView,
    SystemView,
    InferenceView
) {
    let window = Window()

    window.title = "AdminDashboard"
    window.initialSize = (
        width: 1200,
        height: 800
    )

    let tabView = TabView(
        frame: Rect(
            x: 0,
            y: 0,
            width: 1200,
            height: 800
        )
    )

    tabView.autoresizingMask = [
        .flexibleWidth,
        .flexibleHeight
    ]

    // MARK: Overview

    let overviewView = OverviewView(
        frame: tabView.pageFrame
    )

    tabView.addTabViewItem(
        TabViewItem(
            label: "Overview",
            view: overviewView,
            identifier: "overview"
        )
    )

    // MARK: Storage

    let storageView = StorageView(
        frame: tabView.pageFrame
    )

    tabView.addTabViewItem(
        TabViewItem(
            label: "Storage",
            view: storageView,
            identifier: "storage"
        )
    )

    // MARK: Inference

    let inferenceView = InferenceView(
        frame: tabView.pageFrame
    )

    tabView.addTabViewItem(
        TabViewItem(
            label: "Inference",
            view: inferenceView,
            identifier: "inference"
        )
    )

    // MARK: System

    let systemView = SystemView(
        frame: tabView.pageFrame
    )

    tabView.addTabViewItem(
        TabViewItem(
            label: "System",
            view: systemView,
            identifier: "system"
        )
    )

    window.contentView = tabView

    return (
        window,
        tabView,
        overviewView,
        storageView,
        systemView,
        inferenceView
    )
}
