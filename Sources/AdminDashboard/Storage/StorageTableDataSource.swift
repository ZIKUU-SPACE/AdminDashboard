
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/StorageTableDataSource.swift

import Foundation
import Application
import AdminDashboardShared

/// Supplies storage service data to a read-only TableView.
///
/// All access is expected on the ZIKUU UI thread.
final class StorageTableDataSource: TableViewDataSource {

    // MARK: - Data

    private(set) var services: [StorageService] = []

    // MARK: - Updating

    func update(_ services: [StorageService]) {
        self.services = services
    }

    // MARK: - Row Access

    func service(at row: Int) -> StorageService? {
        guard services.indices.contains(row) else {
            return nil
        }

        return services[row]
    }

    func row(forServiceID id: String) -> Int? {
        services.firstIndex { $0.id == id }
    }

    // MARK: - TableViewDataSource

    func numberOfRows(in tableView: TableView) -> Int {
        services.count
    }

    func tableView(
        _ tableView: TableView,
        objectValueFor column: TableColumn,
        row: Int
    ) -> Any? {
        guard let service = service(at: row) else {
            return nil
        }

        switch column.identifier {
        case "name":
            return service.name

        case "kind":
            return service.kind

        case "port":
            return String(service.port)

        case "status":
            return service.status

        case "web":
            return service.webPath == nil ? "—" : "Open"

        default:
            return nil
        }
    }
}
