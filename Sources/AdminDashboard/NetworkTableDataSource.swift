// ~/workspace/AdminDashboard/Sources/AdminDashboard/NetworkTableDataSource.swift

import Foundation
import Application
import AdminDashboardShared

/// Supplies network interface data to a read-only TableView.
///
/// The data source owns its row data.
/// TableView maintains selection and presentation state.
///
/// All access is expected on the ZIKUU UI thread.
final class NetworkTableDataSource: TableViewDataSource {

    // MARK: - Data

    private(set) var interfaces: [NetworkInterfaceDetails] = []

    // MARK: - Updating

    func update(_ network: SystemNetwork) {
        interfaces = network.interfaces
    }

    // MARK: - Row Access

    func interface(at row: Int) -> NetworkInterfaceDetails? {
        guard interfaces.indices.contains(row) else {
            return nil
        }

        return interfaces[row]
    }

    // MARK: - TableViewDataSource

    func numberOfRows(in tableView: TableView) -> Int {
        interfaces.count
    }

    func tableView(
        _ tableView: TableView,
        objectValueFor column: TableColumn,
        row: Int
    ) -> Any? {
        guard let item = interface(at: row) else {
            return nil
        }

        switch column.identifier {
        case "name":
            return item.name

        case "state":
            return item.state ?? "—"

        case "mac_address":
            return item.macAddress ?? "—"

        case "mtu":
            return item.mtu.map(String.init) ?? "—"

        case "ipv6_addresses":
            let count = item.ipv6Addresses.count

            if count == 0 {
                return "—"
            }

            return count == 1
                ? "1 address"
                : "\(count) addresses"

        default:
            return nil
        }
    }
}