
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/StorageView.swift

import Foundation
import Application
import Core
import AdminDashboardShared

/// Displays storage services and backup management.
///
/// Uses standard ZIKUU framework controls.
///
/// Data retrieval belongs to StorageController and
/// BackupController.
///
/// All view operations must run on the ZIKUU UI thread.
final class StorageView: View {

    // MARK: - Page Scrolling

    private let pageScrollView = ScrollView()
    private let pageContentView = View()

    // MARK: - Status

    private let statusField = TextField()

    // MARK: - Sections

    private let servicesSection = StorageServicesSection()
    private let backupSection = BackupSection()

    // MARK: - Actions

    var onOpenRequested: ((StorageService) -> Void)?
    var onBackupRunRequested: (() -> Void)?

    // MARK: - Layout

    private let margin: Float = 24
    private let sectionSpacing: Float = 16
    private let statusHeight: Float = 28

    // MARK: - Storage State

    private var hasReceivedServices = false
    private var serviceCount = 0
    private var runningCount = 0
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
        configureSections()

        pageContentView.addSubview(statusField)
        pageContentView.addSubview(servicesSection.view)
        pageContentView.addSubview(backupSection.view)

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
            "Waiting for storage services..."
    }

    private func configureSections() {
        servicesSection.onHeightChanged = {
            [weak self] in

            self?.layoutContent()
        }

        servicesSection.onOpenRequested = {
            [weak self] service in

            self?.onOpenRequested?(service)
        }

        backupSection.onHeightChanged = {
            [weak self] in

            self?.layoutContent()
        }

        backupSection.onRunRequested = {
            [weak self] in

            self?.onBackupRunRequested?()
        }
    }

    // MARK: - Storage Service Updates

    func update(services: [StorageService]) {
        hasReceivedServices = true
        serviceCount = services.count

        runningCount = services.filter {
            $0.status == "running"
        }.count

        servicesSection.update(services: services)

        updateStatus()
        layoutContent()
    }

    // MARK: - Storage Loading and Errors

    func updateLoading(_ loading: Bool) {
        if loading && !hasReceivedServices {
            statusField.stringValue =
                "Loading storage services..."
        }
    }

    func updateError(_ message: String?) {
        currentError = message
        updateStatus()
    }

    private func updateStatus() {
        if let currentError {
            statusField.stringValue =
                "Storage error: \(currentError)"
            return
        }

        guard hasReceivedServices else {
            statusField.stringValue =
                "Waiting for storage services..."
            return
        }

        if serviceCount == 0 {
            statusField.stringValue =
                "No storage services"
            return
        }

        statusField.stringValue = String(
            format: "%d services · %d running",
            serviceCount,
            runningCount
        )
    }

    // MARK: - Backup Updates

    func updateBackupStatus(
        _ status: BackupExecutionStatus?
    ) {
        backupSection.updateStatus(status)
    }

    func updateBackupCurrent(
        _ generation: BackupGeneration?
    ) {
        backupSection.updateCurrent(generation)
    }

    func updateBackupPrevious(
        _ generation: BackupGeneration?
    ) {
        backupSection.updatePrevious(generation)
    }

    func updateBackupHistory(
        _ history: BackupHistory?
    ) {
        backupSection.updateHistory(history)
    }

    func updateBackupExecuting(_ executing: Bool) {
        backupSection.updateExecuting(executing)
    }

    func updateBackupCanRun(_ enabled: Bool) {
        backupSection.updateCanRun(enabled)
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

        // Storage Services

        servicesSection.view.frame = Rect(
            x: margin,
            y: y,
            width: contentWidth,
            height: servicesSection.preferredHeight
        )

        servicesSection.layoutContent()

        y += servicesSection.preferredHeight
            + sectionSpacing

        // Backup

        backupSection.view.frame = Rect(
            x: margin,
            y: y,
            width: contentWidth,
            height: backupSection.preferredHeight
        )

        backupSection.layoutContent()

        y += backupSection.preferredHeight
            + sectionSpacing

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
