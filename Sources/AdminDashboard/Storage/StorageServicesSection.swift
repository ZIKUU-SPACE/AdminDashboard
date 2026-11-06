
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/StorageServicesSection.swift

import Foundation
import Application
import Core
import AdminDashboardShared

/// Bridges Storage table cell actions to a closure.
///
/// The table cell retains its target weakly, so the section
/// owns this instance for the lifetime of the table.
private final class StorageWebActionTarget: Monas {

    static let actionSelector = Selector(
        "storageWebPressed:",
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
                            target as? StorageWebActionTarget,
                          let sender = arguments.first as? View
                    else {
                        return nil
                    }

                    target.onAction?(sender)
                    return nil
                }
            )
        } catch {
            fatalError(
                "Failed to register storage web action: \(error)"
            )
        }
    }()

    var onAction: ((View) -> Void)?

    override init() {
        super.init()
        _ = Self.registration
    }
}

/// Displays the Storage Services table using standard
/// ZIKUU framework controls.
///
/// Web UI actions are passed to the owning view.
///
/// All access must occur on the ZIKUU UI thread.
final class StorageServicesSection: TableViewDelegate {

    // MARK: - Views

    let view = Box()

    private let countField = TextField()

    private let scrollView = ScrollView()
    private let tableView = TableView()
    private let headerView = TableHeaderView()

    // MARK: - Data

    private let dataSource = StorageTableDataSource()
    private var isUpdatingTable = false

    // MARK: - Actions

    private let actionTarget = StorageWebActionTarget()

    var onOpenRequested: ((StorageService) -> Void)?
    var onHeightChanged: (() -> Void)?

    // MARK: - Layout

    private let contentInset: Float = 12
    private let countHeight: Float = 26
    private let rowHeight: Float = 26

    private let minimumVisibleRows = 2
    private let maximumVisibleRows = 8

    var preferredHeight: Float {
        let visibleRows = min(
            maximumVisibleRows,
            max(
                minimumVisibleRows,
                dataSource.services.count
            )
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

    // MARK: - Initialization

    init() {
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
        view.title = "Storage Services"
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

        countField.stringValue = "0 services"
    }

    private func configureTable() {
        tableView.rowHeight = rowHeight
        tableView.allowsMultipleSelection = false

        addColumn(
            identifier: "name",
            title: "Service",
            width: 180
        )

        addColumn(
            identifier: "kind",
            title: "Kind",
            width: 155
        )

        addColumn(
            identifier: "port",
            title: "Port",
            width: 90
        )

        addColumn(
            identifier: "status",
            title: "Status",
            width: 125
        )

        let webColumn = TableColumn(
            identifier: "web"
        )

        webColumn.width = 100
        webColumn.isEditable = false
        webColumn.headerCell = TextFieldCell(
            text: "Web UI"
        )

        let webCell = ButtonCell(
            title: "Open"
        )

        webCell.buttonType = .momentaryPush
        webCell.isTransparent = true
        webCell.isBordered = false

        webCell.font = Font(
            family: "sans-serif",
            size: 12
        )

        webCell.titleColor = GraphicsColor(
            red: 0.12,
            green: 0.34,
            blue: 0.72
        )

        webCell.target = actionTarget
        webCell.action =
            StorageWebActionTarget.actionSelector

        webColumn.dataCell = webCell

        tableView.addTableColumn(webColumn)

        tableView.dataSource = dataSource
        tableView.delegate = self

        headerView.tableView = tableView

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        scrollView.headerView = headerView
        scrollView.headerHeight =
            headerView.preferredHeight

        scrollView.onScrollPositionChange = {
            [weak self] position in

            self?.headerView.horizontalOffset =
                position.x
        }
    }

    private func addColumn(
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

        tableView.addTableColumn(column)
    }

    private func configureActions() {
        actionTarget.onAction = {
            [weak self] sender in

            self?.handleWebAction(sender)
        }
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

        let tableY =
            contentInset + countHeight + 8

        let visibleRows = min(
            maximumVisibleRows,
            max(
                minimumVisibleRows,
                dataSource.services.count
            )
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

    func update(services: [StorageService]) {
        let previousHeight = preferredHeight

        let previousSelection =
            dataSource.service(
                at: tableView.selectedRow
            )?.id

        isUpdatingTable = true

        _ = tableView.deselectAll()

        dataSource.update(services)
        tableView.reloadData()

        let count = services.count

        countField.stringValue = count == 1
            ? "1 service"
            : "\(count) services"

        if services.isEmpty {
            scrollView.documentView = nil
        } else {
            if scrollView.documentView !== tableView {
                scrollView.documentView = tableView
            }

            if let previousSelection,
               let row = dataSource.row(
                   forServiceID: previousSelection
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
    }

    // MARK: - Cell Display

    func tableView(
        _ tableView: TableView,
        willDisplayCell cell: Cell,
        for column: TableColumn,
        row: Int
    ) {
        guard tableView === self.tableView,
              column.identifier == "web",
              let buttonCell = cell as? ButtonCell,
              let service = dataSource.service(
                  at: row
              ) else {
            return
        }

        let hasWebUI = service.webPath != nil

        buttonCell.title = hasWebUI
            ? "Open"
            : "—"

        buttonCell.isEnabled = hasWebUI
    }

    // MARK: - Cell Actions

    private func handleWebAction(_ sender: View) {
        guard sender === tableView else {
            return
        }

        let row = tableView.actionRow
        let column = tableView.actionColumn

        guard row >= 0,
              column >= 0,
              column < tableView.numberOfColumns,
              tableView.tableColumns[column].identifier
                  == "web",
              let service = dataSource.service(
                  at: row
              ),
              service.webPath != nil else {
            return
        }

        onOpenRequested?(service)
    }

    // MARK: - Selection

    func tableViewSelectionDidChange(
        _ tableView: TableView
    ) {
        guard tableView === self.tableView,
              !isUpdatingTable else {
            return
        }

        // Selection is currently visual only.
    }
}
