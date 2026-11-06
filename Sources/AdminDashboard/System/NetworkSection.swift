
// ~/workspace/AdminDashboard/Sources/AdminDashboard/NetworkSection.swift

import Foundation
import Application
import Core
import AdminDashboardShared

/// Network section composed from standard ZIKUU framework controls.
///
/// No custom TableView or ScrollView subclasses are used.
/// Table data is supplied directly through TableViewDataSource.
///
/// All access must occur on the ZIKUU UI thread.
final class NetworkSection: TableViewDelegate {

    // MARK: - Views

    let view = CollapsibleView()

    private let scrollView = ScrollView()
    private let tableView = TableView()
    private let headerView = TableHeaderView()

    private let detailTitleField = TextField()
    private let detailValueFields: [TextField] = (0..<3).map { _ in
        TextField()
    }

    private let statusField = TextField()

    // MARK: - Data

    private let dataSource = NetworkTableDataSource()

    // MARK: - Layout

    private let tableHeight: Float = 300
    private let tableRowHeight: Float = 32
    private let detailHeight: Float = 112
    private let statusHeight: Float = 28
    private let contentInset: Float = 12

    private let detailRowHeight: Float = 24

    // MARK: - Callbacks

    var onHeightChanged: (() -> Void)?

    // MARK: - Properties

    var preferredHeight: Float {
        view.preferredHeight
    }

    // MARK: - Initialization

    init() {
        configure()
    }

    // MARK: - Configuration

    private func configure() {
        configureSection()
        configureTable()
        configureDetails()
        configureStatus()

        view.contentView.addSubview(scrollView)
        view.contentView.addSubview(detailTitleField)

        for field in detailValueFields {
            view.contentView.addSubview(field)
        }

        view.contentView.addSubview(statusField)

        layoutContent()
    }

    private func configureSection() {
        view.title = "Network"
        view.isExpanded = false

        view.headerHeight = 36
        view.contentSpacing = 8

        view.contentHeight =
            contentInset
            + tableHeight
            + detailHeight
            + statusHeight
            + contentInset

        view.onExpansionChanged = { [weak self] _ in
            self?.layoutContent()
            self?.onHeightChanged?()
        }

        view.onLayoutChanged = { [weak self] in
            self?.layoutContent()
            self?.onHeightChanged?()
        }
    }

    // MARK: - Table

    private func configureTable() {
        tableView.rowHeight = tableRowHeight
        tableView.allowsMultipleSelection = false

        addColumn(
            identifier: "name",
            title: "Interface",
            width: 190
        )

        addColumn(
            identifier: "state",
            title: "State",
            width: 90
        )

        addColumn(
            identifier: "mac_address",
            title: "MAC Address",
            width: 190
        )

        addColumn(
            identifier: "mtu",
            title: "MTU",
            width: 80
        )

        addColumn(
            identifier: "ipv6_addresses",
            title: "IPv6",
            width: 115
        )

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

        // Install the document only after receiving rows.
        // Avoid attaching an empty, zero-height document view.
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

        tableView.addTableColumn(column)
    }

    // MARK: - Details

    private func configureDetails() {
        configureField(detailTitleField)

        detailTitleField.stringValue =
            "IPv6 Addresses — Select an interface"

        detailTitleField.font = Font(
            family: "sans-serif",
            size: 13,
            weight: .medium
        )

        for field in detailValueFields {
            configureField(field)

            field.stringValue = "—"

            field.font = Font(
                family: "sans-serif",
                size: 13
            )
        }
    }

    private func configureStatus() {
        configureField(statusField)

        statusField.stringValue =
            "Waiting for network information..."

        statusField.font = Font(
            family: "sans-serif",
            size: 12
        )
    }

    private func configureField(_ field: TextField) {
        field.isEditable = false
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
    }

    // MARK: - Layout

    func layoutContent() {
        let width = max(
            0,
            view.contentView.bounds.size.width
        )

        let contentWidth = max(
            0,
            width - contentInset * 2
        )

        scrollView.frame = Rect(
            x: contentInset,
            y: contentInset,
            width: contentWidth,
            height: tableHeight
        )

        let detailY =
            contentInset + tableHeight + 12

        detailTitleField.frame = Rect(
            x: contentInset,
            y: detailY,
            width: contentWidth,
            height: 26
        )

        for index in detailValueFields.indices {
            detailValueFields[index].frame = Rect(
                x: contentInset + 12,
                y: detailY
                    + 28
                    + Float(index) * detailRowHeight,
                width: max(0, contentWidth - 12),
                height: detailRowHeight
            )
        }

        statusField.frame = Rect(
            x: contentInset,
            y: detailY + detailHeight,
            width: contentWidth,
            height: statusHeight
        )
    }

    // MARK: - Data Updates

    func update(network: SystemNetwork) {
        // Preserve selection by interface identity, not row number.
        let selectedName = dataSource.interface(
            at: tableView.selectedRow
        )?.name

        // Clear the old row-based selection before replacing the data.
        _ = tableView.deselectAll()

        dataSource.update(network)
        tableView.reloadData()

        if dataSource.interfaces.isEmpty {
            scrollView.documentView = nil

            detailTitleField.stringValue =
                "IPv6 Addresses — No interfaces"

            clearDetails()

            statusField.stringValue =
                "No network interfaces"
        } else {
            if scrollView.documentView !== tableView {
                scrollView.documentView = tableView
            }

            // Find the previous interface in the new snapshot.
            if let selectedName,
            let row = dataSource.interfaces.firstIndex(
                    where: { $0.name == selectedName }
            ) {
                _ = tableView.selectRow(row)
            }

            // Refresh details even when the selection did not change.
            updateSelectedInterfaceDetails()

            statusField.stringValue = String(
                format: "%d interfaces",
                dataSource.interfaces.count
            )
        }

        headerView.setNeedsDisplay()
    }

    func updateLoading(_ loading: Bool) {
        if loading {
            statusField.stringValue =
                "Loading network information..."
        }
    }

    func updateError(_ message: String?) {
        if let message {
            statusField.stringValue =
                "Network error: \(message)"
        }
    }

    // MARK: - Selection

    func tableViewSelectionDidChange(
        _ tableView: TableView
    ) {
        guard tableView === self.tableView else {
            return
        }

        updateSelectedInterfaceDetails()
    }

    private func updateSelectedInterfaceDetails() {
        guard let selected = dataSource.interface(
            at: tableView.selectedRow
        ) else {
            detailTitleField.stringValue =
                "IPv6 Addresses — Select an interface"

            clearDetails()
            return
        }

        detailTitleField.stringValue =
            "IPv6 Addresses — \(selected.name)"

        clearDetails()

        if selected.ipv6Addresses.isEmpty {
            detailValueFields[0].stringValue = "—"
            return
        }

        for (index, address) in selected.ipv6Addresses
            .prefix(detailValueFields.count)
            .enumerated() {
            detailValueFields[index].stringValue = address
        }
    }

    private func clearDetails() {
        for field in detailValueFields {
            field.stringValue = ""
        }
    }
}
