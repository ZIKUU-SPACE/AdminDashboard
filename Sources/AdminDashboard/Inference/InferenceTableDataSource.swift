
// ~/workspace/AdminDashboard/Sources/AdminDashboard/InferenceTableDataSource.swift

import Foundation
import Application
import AdminDashboardShared

/// Supplies inference backend data to a read-only TableView.
///
/// Each instance represents the backends belonging to one node.
/// TableView maintains selection and presentation state.
///
/// All access is expected on the ZIKUU UI thread.
final class InferenceTableDataSource: TableViewDataSource {

    // MARK: - Data

    private(set) var backends: [InferenceBackend] = []

    // MARK: - Updating

    func update(_ backends: [InferenceBackend]) {
        self.backends = backends
    }

    // MARK: - Row Access

    func backend(at row: Int) -> InferenceBackend? {
        guard backends.indices.contains(row) else {
            return nil
        }

        return backends[row]
    }

    func row(forBackendNamed name: String) -> Int? {
        backends.firstIndex { $0.name == name }
    }

    // MARK: - TableViewDataSource

    func numberOfRows(in tableView: TableView) -> Int {
        backends.count
    }

    func tableView(
        _ tableView: TableView,
        objectValueFor column: TableColumn,
        row: Int
    ) -> Any? {
        guard let backend = backend(at: row) else {
            return nil
        }

        switch column.identifier {
        case "name":
            return backend.name

        case "kind":
            return backend.kind ?? "—"

        case "runtime":
            return backend.runtime ?? "—"

        case "model":
            return backend.model ?? "—"

        case "status":
            return backend.status

        default:
            return nil
        }
    }
}
