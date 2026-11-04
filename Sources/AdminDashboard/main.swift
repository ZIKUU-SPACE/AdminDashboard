
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

let (window, overviewView) = makeMainWindow()

// MARK: - Dashboard Controller

let controller = DashboardController(
    application: app
)

controller.onMetricsChanged = { [weak overviewView] metrics in
    overviewView?.update(metrics: metrics)
}

controller.onErrorChanged = { [weak overviewView] message in
    overviewView?.updateError(message)
}

// MARK: - Application Lifecycle

window.makeKeyAndOrderFront(nil)

guard window.isVisible else {
    fatalError("Failed to open AdminDashboard window")
}

controller.start()

app.run()

controller.stop()

// MARK: - Window Factory

func makeMainWindow() -> (Window, OverviewView) {
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

    tabView.addTabViewItem(
        TabViewItem(
            label: "Inference",
            view: View(frame: tabView.pageFrame),
            identifier: "inference"
        )
    )

    // MARK: System

    tabView.addTabViewItem(
        TabViewItem(
            label: "System",
            view: View(frame: tabView.pageFrame),
            identifier: "system"
        )
    )

    window.contentView = tabView

    return (window, overviewView)
}
