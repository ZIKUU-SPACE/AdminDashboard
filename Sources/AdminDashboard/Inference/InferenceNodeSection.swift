
// ~/workspace/AdminDashboard/Sources/AdminDashboard/InferenceNodeSection.swift

import Foundation
import Application
import Core
import AdminDashboardShared

/// Displays inference backends belonging to one node.
///
/// The Status column uses ButtonCell for runtime actions.
/// Backend selection is preserved by name across updates.
///
/// All access must occur on the ZIKUU UI thread.
final class InferenceNodeSection: TableViewDelegate {

    // MARK: - Views

    let view = Box()

    private let countField = TextField()

    private let scrollView = ScrollView()
    private let tableView = TableView()
    private let headerView = TableHeaderView()

    // MARK: - Actions

    private let actionTarget = InferenceButtonActionTarget()

    /// Reserved for connection to InferenceController.
    var onStartRequested: ((String) -> Void)?
    var onStopRequested: ((String) -> Void)?

    var onSelectionChanged: ((InferenceBackend?) -> Void)?
    var onHeightChanged: (() -> Void)?

    // MARK: - Data

    let nodeName: String

    private let dataSource = InferenceTableDataSource()

    private var busyBackends: Set<String> = []
    private var isUpdatingTable = false

    // MARK: - Layout

    private let contentInset: Float = 12
    private let countHeight: Float = 26
    private let rowHeight: Float = 26

    private let minimumVisibleRows = 2
    private let maximumVisibleRows = 8

    // MARK: - Properties

    var preferredHeight: Float {
        let visibleRows = min(
            maximumVisibleRows,
            max(minimumVisibleRows, dataSource.backends.count)
        )

        let tableHeight =
            headerView.preferredHeight
            + Float(visibleRows) * rowHeight

        return view.titleHeight
            + contentInset * 4
            + countHeight
            + 8
            + tableHeight
    }

    var selectedBackend: InferenceBackend? {
        dataSource.backend(at: tableView.selectedRow)
    }

    // MARK: - Initialization

    init(nodeName: String) {
        self.nodeName = nodeName
        configure()
    }

    // MARK: - Configuration

    private func configure() {
        configureBox()
        configureCount()
        configureTable()
        configureActions()

        view.contentView.addSubview(countField)
        view.contentView.addSubview(scrollView)

        layoutContent()
    }

    private func configureBox() {
        view.title = nodeName
        view.borderStyle = .line
        view.titlePosition = .atTop
        view.titleHeight = 24
        view.contentInsets = 12
    }

    private func configureCount() {
        countField.isEditable = false
        countField.isBordered = false
        countField.isBezeled = false
        countField.drawsBackground = false

        countField.font = Font(
            family: "sans-serif",
            size: 12
        )

        countField.stringValue = "0 backends"
    }

    private func configureTable() {
        tableView.rowHeight = rowHeight
        tableView.allowsMultipleSelection = false

        addColumn(
            identifier: "name",
            title: "Backend",
            width: 175
        )

        addColumn(
            identifier: "kind",
            title: "Kind",
            width: 155
        )

        addColumn(
            identifier: "runtime",
            title: "Runtime",
            width: 130
        )

        addColumn(
            identifier: "model",
            title: "Model",
            width: 250
        )

        let statusColumn = TableColumn(identifier: "status")
        statusColumn.width = 100
        statusColumn.isEditable = false
        statusColumn.headerCell = TextFieldCell(text: "Status")

        let statusCell = SwitchCell()
        statusCell.target = actionTarget
        statusCell.action =
            InferenceButtonActionTarget.actionSelector

        statusColumn.dataCell = statusCell

        tableView.addTableColumn(statusColumn)

        tableView.dataSource = dataSource
        tableView.delegate = self

        headerView.tableView = tableView

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        scrollView.headerView = headerView
        scrollView.headerHeight = headerView.preferredHeight

        scrollView.onScrollPositionChange = {
            [weak self] position in

            self?.headerView.horizontalOffset = position.x
        }
    }

    private func configureActions() {
        actionTarget.onAction = { [weak self] sender in
            self?.handleCellAction(sender)
        }
    }

    private func addColumn(
        identifier: String,
        title: String,
        width: Float
    ) {
        let column = TableColumn(identifier: identifier)

        column.width = width
        column.isEditable = false
        column.headerCell = TextFieldCell(text: title)

        if let cell = column.dataCell as? TextFieldCell {
            cell.contentInsets = (
                horizontal: 8,
                vertical: 3
            )
        }

        tableView.addTableColumn(column)
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

        countField.frame = Rect(
            x: contentInset,
            y: contentInset,
            width: availableWidth,
            height: countHeight
        )

        let tableY = contentInset + countHeight + 8

        let visibleRows = min(
            maximumVisibleRows,
            max(minimumVisibleRows, dataSource.backends.count)
        )

        let tableHeight =
            headerView.preferredHeight
            + Float(visibleRows) * rowHeight

        scrollView.frame = Rect(
            x: contentInset,
            y: tableY,
            width: availableWidth,
            height: tableHeight
        )
    }

    // MARK: - Data Updates

    func update(backends: [InferenceBackend]) {
        let previousSelection = selectedBackend?.name
        let previousHeight = preferredHeight

        isUpdatingTable = true

        _ = tableView.deselectAll()

        dataSource.update(backends)
        tableView.reloadData()

        let count = backends.count

        countField.stringValue = count == 1
            ? "1 backend"
            : "\(count) backends"

        if backends.isEmpty {
            scrollView.documentView = nil
        } else {
            if scrollView.documentView !== tableView {
                scrollView.documentView = tableView
            }

            if let previousSelection,
               let row = dataSource.row(
                    forBackendNamed: previousSelection
               ) {
                _ = tableView.selectRow(row)
            }
        }

        isUpdatingTable = false

        headerView.setNeedsDisplay()
        tableView.setNeedsDisplay()

        layoutContent()

        if preferredHeight != previousHeight {
            onHeightChanged?()
        }

        if previousSelection != selectedBackend?.name {
            onSelectionChanged?(selectedBackend)
        }
    }

    // MARK: - Busy State

    func updateBusyBackends(_ names: Set<String>) {
        guard busyBackends != names else {
            return
        }

        busyBackends = names
        tableView.setNeedsDisplay()
    }

    // MARK: - Cell Display

    func tableView(
        _ tableView: TableView,
        willDisplayCell cell: Cell,
        for column: TableColumn,
        row: Int
    ) {
        guard tableView === self.tableView,
            column.identifier == "status",
            let switchCell = cell as? SwitchCell,
            let backend = dataSource.backend(at: row) else {
            return
        }

        switch backend.status {
        case "running":
            switchCell.state = 1

        case "stopped":
            switchCell.state = 0

        default:
            switchCell.state = 0
        }

        switchCell.title = ""

        switchCell.isEnabled =
            !busyBackends.contains(backend.name)
                && (
                    backend.status == "running"
                    || backend.status == "stopped"
                )
    }

    // MARK: - Cell Actions

    private func handleCellAction(_ sender: View) {
        guard sender === tableView else {
            return
        }

        let row = tableView.actionRow
        let column = tableView.actionColumn

        guard row >= 0,
            column >= 0,
            column < tableView.numberOfColumns,
            tableView.tableColumns[column].identifier == "status",
            let backend = dataSource.backend(at: row),
            !busyBackends.contains(backend.name) else {
            return
        }

        switch backend.status {
        case "running":
            onStopRequested?(backend.name)

        case "stopped":
            onStartRequested?(backend.name)

        default:
            break
        }
    }

    // MARK: - Selection

    func tableViewSelectionDidChange(
        _ tableView: TableView
    ) {
        guard tableView === self.tableView,
              !isUpdatingTable else {
            return
        }

        onSelectionChanged?(selectedBackend)
    }
}
