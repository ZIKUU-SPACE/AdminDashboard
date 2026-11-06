
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/BackupSection.swift

import Foundation
import Application
import Core
import AdminDashboardShared

// MARK: - Backup Action Target

/// Bridges the Run Backup button to a closure.
///
/// The button retains its target weakly, so BackupSection
/// owns the target for the lifetime of the control.
private final class BackupActionTarget: Monas {

    static let actionSelector = Selector(
        "backupRunPressed:",
        View.self
    )

    private static let registration: Void = {
        do {
            try registerMethod(
                actionSelector,
                signature: MethodSignature.signature(
                    argumentTypes: [
                        MethodType(View.self)
                    ],
                    returnType: MethodType(Void.self)
                ),
                handler: { target, arguments in
                    guard let target =
                            target as? BackupActionTarget,
                          let sender =
                            arguments.first as? View
                    else {
                        return nil
                    }

                    target.onAction?(sender)
                    return nil
                }
            )
        } catch {
            fatalError(
                "Failed to register backup action: \(error)"
            )
        }
    }()

    var onAction: ((View) -> Void)?

    override init() {
        super.init()
        _ = Self.registration
    }
}

// MARK: - Backup History Data Source

private final class BackupHistoryTableDataSource:
    TableViewDataSource {

    private(set) var entries: [BackupHistoryEntry] = []

    func update(_ entries: [BackupHistoryEntry]) {
        self.entries = entries
    }

    func numberOfRows(
        in tableView: TableView
    ) -> Int {
        entries.count
    }

    func tableView(
        _ tableView: TableView,
        objectValueFor column: TableColumn,
        row: Int
    ) -> Any? {
        guard entries.indices.contains(row) else {
            return nil
        }

        let entry = entries[row]

        switch column.identifier {
        case "started":
            return Self.displayDate(entry.startedAt)

        case "result":
            if entry.executionState == "running" {
                return "Running"
            }

            return entry.status
                ?? entry.executionState.capitalized

        case "targets":
            guard let targets = entry.targets else {
                return "—"
            }

            let successful = targets.filter {
                $0.status == "success"
            }.count

            let skipped = targets.filter {
                $0.status == "skipped"
            }.count

            let failed = targets.filter {
                $0.status == "failed"
            }.count

            var parts = [
                "\(successful) success",
                "\(skipped) skipped"
            ]

            if failed > 0 {
                parts.append("\(failed) failed")
            }

            return parts.joined(separator: " / ")

        default:
            return nil
        }
    }

    private static func displayDate(
        _ value: String
    ) -> String {
        String(value.prefix(19))
            .replacingOccurrences(of: "T", with: " ")
    }
}

// MARK: - Backup Section

/// Displays backup execution, generations, and history.
///
/// Uses standard ZIKUU framework controls.
/// All access must occur on the ZIKUU UI thread.
///
/// Backup execution is requested through a closure.
/// The section never communicates with the API directly.
final class BackupSection {

    // MARK: - Views

    let view = Box()

    private let executionField = TextField()
    private let runButton = Button()

    private let currentField = TextField()
    private let previousField = TextField()

    private let historyLabel = TextField()
    private let historyScrollView = ScrollView()
    private let historyTableView = TableView()
    private let historyHeaderView = TableHeaderView()

    // MARK: - Dependencies

    private let historyDataSource =
        BackupHistoryTableDataSource()

    private let actionTarget = BackupActionTarget()

    // MARK: - Actions

    var onRunRequested: (() -> Void)?
    var onHeightChanged: (() -> Void)?

    // MARK: - State

    private var canRun = false
    private var isExecuting = false

    // MARK: - Layout

    private let contentInset: Float = 12
    private let rowHeight: Float = 26

    private let executionHeight: Float = 32
    private let generationHeight: Float = 28
    private let historyLabelHeight: Float = 24

    private let minimumVisibleRows = 2
    private let maximumVisibleRows = 10

    var preferredHeight: Float {
        let tableHeight =
            historyHeaderView.preferredHeight
            + Float(visibleHistoryRows) * rowHeight

        return view.titleHeight
            + contentInset * 2
            + executionHeight
            + 8
            + generationHeight * 2
            + 12
            + historyLabelHeight
            + tableHeight
            + 12
    }

    private var visibleHistoryRows: Int {
        min(
            maximumVisibleRows,
            max(
                minimumVisibleRows,
                historyDataSource.entries.count
            )
        )
    }

    // MARK: - Initialization

    init() {
        configure()
    }

    // MARK: - Configuration

    private func configure() {
        configureBox()
        configureFields()
        configureRunButton()
        configureHistoryTable()
        configureActions()

        view.contentView.addSubview(executionField)
        view.contentView.addSubview(runButton)

        view.contentView.addSubview(currentField)
        view.contentView.addSubview(previousField)

        view.contentView.addSubview(historyLabel)
        view.contentView.addSubview(historyScrollView)

        layoutContent()
    }

    private func configureBox() {
        view.title = "Backup"
        view.borderStyle = .line
        view.titlePosition = .atTop
        view.titleHeight = 24
        view.contentInsets = 12
    }

    private func configureFields() {
        let fields = [
            executionField,
            currentField,
            previousField,
            historyLabel
        ]

        for field in fields {
            field.isEditable = false
            field.isBordered = false
            field.isBezeled = false
            field.drawsBackground = false

            field.font = Font(
                family: "sans-serif",
                size: 12
            )
        }

        executionField.stringValue =
            "Execution: Waiting for status..."

        currentField.stringValue =
            "Current: Waiting for report..."

        previousField.stringValue =
            "Previous: Waiting for report..."

        historyLabel.stringValue =
            "Execution History"
    }

    private func configureRunButton() {
        runButton.title = "Run Backup"
        runButton.buttonType = .momentaryPush

        runButton.buttonCell?.font = Font(
            family: "sans-serif",
            size: 12
        )

        runButton.isEnabled = false

        runButton.target = actionTarget
        runButton.action =
            BackupActionTarget.actionSelector
    }

    private func configureHistoryTable() {
        historyTableView.rowHeight = rowHeight
        historyTableView.allowsMultipleSelection = false

        addHistoryColumn(
            identifier: "started",
            title: "Started",
            width: 190
        )

        addHistoryColumn(
            identifier: "result",
            title: "Result",
            width: 120
        )

        addHistoryColumn(
            identifier: "targets",
            title: "Targets",
            width: 235
        )

        historyTableView.dataSource = historyDataSource

        historyHeaderView.tableView = historyTableView

        historyScrollView.hasVerticalScroller = true
        historyScrollView.hasHorizontalScroller = true

        historyScrollView.headerView = historyHeaderView
        historyScrollView.headerHeight =
            historyHeaderView.preferredHeight

        historyScrollView.onScrollPositionChange = {
            [weak self] position in

            self?.historyHeaderView.horizontalOffset =
                position.x
        }
    }

    private func addHistoryColumn(
        identifier: String,
        title: String,
        width: Float
    ) {
        let column = TableColumn(
            identifier: identifier
        )

        column.width = width
        column.isEditable = false
        column.headerCell = TextFieldCell(
            text: title
        )

        if let cell = column.dataCell as? TextFieldCell {
            cell.contentInsets = (
                horizontal: 8,
                vertical: 3
            )
        }

        historyTableView.addTableColumn(column)
    }

    private func configureActions() {
        actionTarget.onAction = {
            [weak self] sender in

            guard let self,
                  sender === self.runButton,
                  self.canRun,
                  !self.isExecuting else {
                return
            }

            self.onRunRequested?()
        }
    }

    // MARK: - Execution Status

    func updateStatus(
        _ status: BackupExecutionStatus?
    ) {
        guard let status else {
            executionField.stringValue =
                "Execution: Status unavailable"
            return
        }

        if status.isRunning {
            let started = status.startedAt.map {
                Self.displayDate($0)
            } ?? "—"

            executionField.stringValue =
                "Execution: Running · Started \(started)"
            return
        }

        let completed = status.completedAt.map {
            Self.displayDate($0)
        } ?? "—"

        let state = status.state.capitalized

        executionField.stringValue =
            "Execution: \(state) · Last run \(completed)"
    }

    func updateExecuting(_ executing: Bool) {
        isExecuting = executing

        runButton.title = executing
            ? "Running..."
            : "Run Backup"

        updateButtonAvailability()
    }

    func updateCanRun(_ enabled: Bool) {
        canRun = enabled
        updateButtonAvailability()
    }

    private func updateButtonAvailability() {
        runButton.isEnabled = canRun && !isExecuting
        runButton.setNeedsDisplay()
    }

    // MARK: - Generations

    func updateCurrent(
        _ generation: BackupGeneration?
    ) {
        currentField.stringValue = generation.map {
            Self.generationSummary("Current", $0)
        } ?? "Current: No report available"
    }

    func updatePrevious(
        _ generation: BackupGeneration?
    ) {
        previousField.stringValue = generation.map {
            Self.generationSummary("Previous", $0)
        } ?? "Previous: No report available"
    }

    private static func generationSummary(
        _ title: String,
        _ generation: BackupGeneration
    ) -> String {
        let report = generation.report

        let successCount = report.targets.filter {
            $0.status == "success"
        }.count

        let skippedCount = report.targets.filter {
            $0.status == "skipped"
        }.count

        return "\(title): "
            + "\(displayDate(report.completedAt))"
            + " · \(report.status.capitalized)"
            + " · \(successCount) success"
            + " / \(skippedCount) skipped"
    }

    // MARK: - History

    func updateHistory(_ history: BackupHistory?) {
        let previousHeight = preferredHeight

        let entries = history?.entries ?? []

        historyDataSource.update(entries)
        historyTableView.reloadData()

        historyLabel.stringValue =
            "Execution History (\(entries.count))"

        if entries.isEmpty {
            historyScrollView.documentView = nil
        } else {
            if historyScrollView.documentView
                !== historyTableView {

                historyScrollView.documentView =
                    historyTableView
            }
        }

        historyHeaderView.setNeedsDisplay()
        historyTableView.setNeedsDisplay()

        layoutContent()

        if preferredHeight != previousHeight {
            onHeightChanged?()
        }
    }

    // MARK: - Formatting

    private static func displayDate(
        _ value: String
    ) -> String {
        String(value.prefix(19))
            .replacingOccurrences(of: "T", with: " ")
    }

    // MARK: - Layout

    func layoutContent() {
        let contentWidth = max(
            0,
            view.contentView.bounds.size.width
        )

        let availableWidth = max(
            0,
            contentWidth - contentInset * 2
        )

        let buttonWidth: Float = 120
        let buttonHeight: Float = 28

        var y = contentInset

        executionField.frame = Rect(
            x: contentInset,
            y: y,
            width: max(
                0,
                availableWidth - buttonWidth - 12
            ),
            height: executionHeight
        )

        runButton.frame = Rect(
            x: max(
                contentInset,
                contentWidth - contentInset - buttonWidth
            ),
            y: y + 2,
            width: buttonWidth,
            height: buttonHeight
        )

        y += executionHeight + 8

        currentField.frame = Rect(
            x: contentInset,
            y: y,
            width: availableWidth,
            height: generationHeight
        )

        y += generationHeight

        previousField.frame = Rect(
            x: contentInset,
            y: y,
            width: availableWidth,
            height: generationHeight
        )

        y += generationHeight + 12

        historyLabel.frame = Rect(
            x: contentInset,
            y: y,
            width: availableWidth,
            height: historyLabelHeight
        )

        y += historyLabelHeight

        let tableHeight =
            historyHeaderView.preferredHeight
            + Float(visibleHistoryRows) * rowHeight

        historyScrollView.frame = Rect(
            x: contentInset,
            y: y,
            width: availableWidth,
            height: tableHeight
        )
    }
}
