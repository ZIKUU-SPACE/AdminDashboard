
// ~/workspace/AdminDashboard/Sources/AdminDashboard/main.swift

import Foundation
import ZIKUU
import Application
import Core

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

    if identifier == "inference" {
        inferenceController.activate()
    }
}

app.run()

inferenceController.deactivate()
systemController.deactivate()
dashboardController.stop()

// MARK: - Window Factory

func makeMainWindow() -> (
    Window,
    TabView,
    OverviewView,
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

    tabView.addTabViewItem(
        TabViewItem(
            label: "Storage",
            view: View(frame: tabView.pageFrame),
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
        systemView,
        inferenceView
    )
}
