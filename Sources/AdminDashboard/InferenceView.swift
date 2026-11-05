
// ~/workspace/AdminDashboard/Sources/AdminDashboard/InferenceView.swift

import Foundation
import Application
import Core
import AdminDashboardShared

/// Displays inference backends grouped by node.
///
/// Each node is represented by an InferenceNodeSection
/// composed from standard ZIKUU framework controls.
///
/// The entire page scrolls vertically. Individual backend
/// tables manage their own horizontal and vertical scrolling.
///
/// Data retrieval and runtime actions belong to
/// InferenceController.
///
/// All view operations must run on the ZIKUU UI thread.
final class InferenceView: View {

    // MARK: - Page Scrolling

    private let pageScrollView = ScrollView()
    private let pageContentView = View()

    // MARK: - Status

    private let statusField = TextField()

    // MARK: - Runtime Actions

    var onStartRequested: ((String) -> Void)?
    var onStopRequested: ((String) -> Void)?

    private var busyBackends: Set<String> = []
    private var actionError: String?

    // MARK: - Node Sections

    private var sections: [String: InferenceNodeSection] = [:]
    private var nodeOrder: [String] = []

    // MARK: - Layout

    private let margin: Float = 24
    private let sectionSpacing: Float = 16
    private let statusHeight: Float = 28

    // MARK: - State

    private var hasReceivedBackends = false
    private var backendCount = 0
    private var currentError: String?

    // MARK: - Initialization

    override init(frame: Rect) {
        super.init(frame: frame)
        configure()
    }

    override init() {
        super.init()
        configure()
    }

    // MARK: - Configuration

    private func configure() {
        configurePageScrollView()
        configureStatus()

        pageContentView.addSubview(statusField)

        pageScrollView.documentView = pageContentView
        addSubview(pageScrollView)

        layoutContent()
    }

    private func configurePageScrollView() {
        pageScrollView.hasBorder = false
        pageScrollView.hasVerticalScroller = true
        pageScrollView.hasHorizontalScroller = false
    }

    private func configureStatus() {
        statusField.isEditable = false
        statusField.isBordered = false
        statusField.isBezeled = false
        statusField.drawsBackground = false

        statusField.font = Font(
            family: "sans-serif",
            size: 12
        )

        statusField.stringValue =
            "Waiting for inference backends..."
    }

    // MARK: - Backend Updates

    func update(backends: [InferenceBackend]) {
        hasReceivedBackends = true
        backendCount = backends.count

        let grouped = Dictionary(
            grouping: backends
        ) { backend in
            backend.node ?? "unknown"
        }

        let newNodeOrder = grouped.keys.sorted()

        // Remove sections belonging to nodes that disappeared.
        let removedNodes = nodeOrder.filter {
            grouped[$0] == nil
        }

        for node in removedNodes {
            if let section = sections.removeValue(
                forKey: node
            ) {
                section.view.removeFromSuperview()
            }
        }

        // Create sections only for newly discovered nodes.
        for node in newNodeOrder {
            if sections[node] == nil {
                let section = InferenceNodeSection(
                    nodeName: node
                )

                section.onHeightChanged = {
                    [weak self] in

                    self?.layoutContent()
                }

                section.onStartRequested = { [weak self] name in
                    self?.onStartRequested?(name)
                }

                section.onStopRequested = { [weak self] name in
                    self?.onStopRequested?(name)
                }

                section.updateBusyBackends(busyBackends)

                sections[node] = section

                pageContentView.addSubview(
                    section.view
                )
            }
        }

        nodeOrder = newNodeOrder

        // Update existing sections without replacing their views.
        for node in nodeOrder {
            guard let section = sections[node] else {
                continue
            }

            let nodeBackends = (
                grouped[node] ?? []
            ).sorted {
                $0.name < $1.name
            }

            section.update(backends: nodeBackends)
        }

        updateStatus()
        layoutContent()
    }

    // MARK: - Runtime Action State

    func updateBusyBackends(_ names: Set<String>) {
        busyBackends = names

        for section in sections.values {
            section.updateBusyBackends(names)
        }

        updateStatus()
    }

    func updateActionError(_ message: String?) {
        actionError = message
        updateStatus()
    }

    // MARK: - Loading and Errors

    func updateLoading(_ loading: Bool) {
        if loading && !hasReceivedBackends {
            statusField.stringValue =
                "Loading inference backends..."
        }
    }

    func updateError(_ message: String?) {
        currentError = message
        updateStatus()
    }

    private func updateStatus() {
        if let actionError {
            statusField.stringValue =
                "Runtime action error: \(actionError)"
            return
        }

        if let currentError {
            statusField.stringValue =
                "Inference error: \(currentError)"
            return
        }

        if !busyBackends.isEmpty {
            statusField.stringValue =
                "Operating: \(busyBackends.sorted().joined(separator: ", "))"
            return
        }

        guard hasReceivedBackends else {
            statusField.stringValue =
                "Waiting for inference backends..."
            return
        }

        if backendCount == 0 {
            statusField.stringValue =
                "No inference backends"
            return
        }

        statusField.stringValue = String(
            format: "%d nodes · %d backends",
            nodeOrder.count,
            backendCount
        )
    }

    // MARK: - Layout

    override func resizeSubviews(
        withOldSize oldSize: Size
    ) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutContent()
    }

    private func layoutContent() {
        pageScrollView.frame = Rect(
            x: 0,
            y: 0,
            width: max(0, bounds.size.width),
            height: max(0, bounds.size.height)
        )

        let viewportSize =
            pageScrollView.contentView.bounds.size

        let documentWidth = max(
            1,
            viewportSize.width
        )

        let contentWidth = max(
            0,
            documentWidth - margin * 2
        )

        // Status appears above the node sections.
        statusField.frame = Rect(
            x: margin,
            y: margin,
            width: contentWidth,
            height: statusHeight
        )

        var y =
            margin
            + statusHeight
            + sectionSpacing

        // Lay out the node sections vertically.
        for node in nodeOrder {
            guard let section = sections[node] else {
                continue
            }

            let height = section.preferredHeight

            section.view.frame = Rect(
                x: margin,
                y: y,
                width: contentWidth,
                height: height
            )

            section.layoutContent()

            y += height + sectionSpacing
        }

        let requiredHeight = y + margin

        let documentHeight = max(
            1,
            viewportSize.height,
            requiredHeight
        )

        let newDocumentFrame = Rect(
            x: 0,
            y: 0,
            width: documentWidth,
            height: documentHeight
        )

        if pageContentView.frame != newDocumentFrame {
            pageContentView.frame = newDocumentFrame
            pageScrollView.documentFrameChanged()
        }
    }
}
