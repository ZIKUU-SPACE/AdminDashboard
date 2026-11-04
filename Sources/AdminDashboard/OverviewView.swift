
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/OverviewView.swift

import Foundation
import Core
import Application
import AdminDashboardShared

/// Overview page displaying system utilization gauges.
///
/// Metrics retrieval and polling belong to DashboardController.
/// All view operations run on the application's UI thread.
final class OverviewView: View {

    // MARK: - Gauges

    private let cpuGauge = MetricGaugeView()
    private let memoryGauge = MetricGaugeView()
    private let diskGauge = MetricGaugeView()
    private let gpuGauge = MetricGaugeView()

    // MARK: - Values

    private let cpuValue = TextField()
    private let memoryValue = TextField()
    private let diskValue = TextField()
    private let gpuValue = TextField()

    // MARK: - Labels

    private let cpuLabel = TextField()
    private let memoryLabel = TextField()
    private let diskLabel = TextField()
    private let gpuLabel = TextField()

    private let statusField = TextField()

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
        for field in valueFields {
            configureField(field)
            field.alignment = .center
        }

        for field in labelFields {
            configureField(field)
            field.alignment = .center
        }

        configureField(statusField)

        for field in labelFields {
            field.font = Font(
                family: "sans-serif",
                size: 14,
                weight: .medium
            )
        }

        statusField.font = Font(
            family: "sans-serif",
            size: 12
        )

        cpuValue.stringValue = "—"
        memoryValue.stringValue = "—"
        diskValue.stringValue = "—"
        gpuValue.stringValue = "—"

        cpuLabel.stringValue = "CPU"
        memoryLabel.stringValue = "Memory"
        diskLabel.stringValue = "Disk"
        gpuLabel.stringValue = "GPU"

        statusField.stringValue = "Waiting for metrics..."

        cpuGauge.progressColor = GraphicsColor(
            red: 0.25, green: 0.49, blue: 0.81
        )

        memoryGauge.progressColor = GraphicsColor(
            red: 0.26, green: 0.62, blue: 0.49
        )

        diskGauge.progressColor = GraphicsColor(
            red: 0.77, green: 0.55, blue: 0.26
        )

        gpuGauge.progressColor = GraphicsColor(
            red: 0.59, green: 0.42, blue: 0.72
        )

        for gauge in gauges {
            addSubview(gauge)
        }

        // Values are added after the gauges so that they
        // are drawn in front of the circular paths.
        for field in valueFields {
            addSubview(field)
        }

        for field in labelFields {
            addSubview(field)
        }

        addSubview(statusField)

        layoutContent()
    }

    private func configureField(_ field: TextField) {
        field.isEditable = false
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
    }

    // MARK: - Collections

    private var gauges: [MetricGaugeView] {
        [
            cpuGauge,
            memoryGauge,
            diskGauge,
            gpuGauge
        ]
    }

    private var valueFields: [TextField] {
        [
            cpuValue,
            memoryValue,
            diskValue,
            gpuValue
        ]
    }

    private var labelFields: [TextField] {
        [
            cpuLabel,
            memoryLabel,
            diskLabel,
            gpuLabel
        ]
    }

    // MARK: - Layout

    override func resizeSubviews(
        withOldSize oldSize: Size
    ) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutContent()
    }

    private func layoutContent() {
        let width = max(0, bounds.size.width)
        let height = max(0, bounds.size.height)

        let columns: Int

        if width >= 760 {
            columns = 4
        } else if width >= 400 {
            columns = 2
        } else {
            columns = 1
        }

        let rows = (gauges.count + columns - 1) / columns

        let marginX: Float = 20
        let marginTop: Float = 20
        let marginBottom: Float = 14

        let columnSpacing: Float = 12
        let rowSpacing: Float = 8

        let labelHeight: Float = 26
        let labelSpacing: Float = 8

        let statusHeight: Float = 26
        let statusSpacing: Float = 12

        let contentWidth = max(
            0,
            width - marginX * 2
        )

        let contentHeight = max(
            0,
            height
                - marginTop
                - marginBottom
                - statusHeight
                - statusSpacing
        )

        let columnWidth = max(
            0,
            (
                contentWidth
                - Float(columns - 1) * columnSpacing
            ) / Float(columns)
        )

        let rowHeight = max(
            0,
            (
                contentHeight
                - Float(rows - 1) * rowSpacing
            ) / Float(rows)
        )

        let gaugeSize = max(
            0,
            min(
                160,
                columnWidth - 12,
                rowHeight - labelHeight - labelSpacing
            )
        )

        let valueFont = Font(
            family: "sans-serif",
            size: max(10, min(28, gaugeSize * 0.20)),
            weight: .semibold
        )

        for field in valueFields {
            if field.font != valueFont {
                field.font = valueFont
            }
        }
        
        let valueHeight = min(
            36,
            gaugeSize
        )

        let gauges = self.gauges
        let values = valueFields
        let labels = labelFields

        for index in gauges.indices {
            let column = index % columns
            let row = index / columns

            let cellX = marginX
                + Float(column)
                * (columnWidth + columnSpacing)

            let cellY = marginTop
                + Float(row)
                * (rowHeight + rowSpacing)

            let groupHeight = gaugeSize
                + labelSpacing
                + labelHeight

            let groupY = cellY
                + max(0, (rowHeight - groupHeight) / 2)

            let gaugeX = cellX
                + (columnWidth - gaugeSize) / 2

            gauges[index].frame = Rect(
                x: gaugeX,
                y: groupY,
                width: gaugeSize,
                height: gaugeSize
            )

            values[index].frame = Rect(
                x: gaugeX,
                y: groupY + (gaugeSize - valueHeight) / 2,
                width: gaugeSize,
                height: valueHeight
            )

            labels[index].frame = Rect(
                x: cellX,
                y: groupY + gaugeSize + labelSpacing,
                width: columnWidth,
                height: labelHeight
            )
        }

        statusField.frame = Rect(
            x: marginX,
            y: max(
                0,
                height - marginBottom - statusHeight
            ),
            width: contentWidth,
            height: statusHeight
        )
    }

    // MARK: - Metrics

    func update(metrics: SystemMetrics) {
        cpuGauge.value = metrics.cpu.value
        memoryGauge.value = metrics.memory.value
        diskGauge.value = metrics.disk.value
        gpuGauge.value = metrics.gpu.value

        cpuValue.stringValue = format(metrics.cpu)
        memoryValue.stringValue = format(metrics.memory)
        diskValue.stringValue = format(metrics.disk)
        gpuValue.stringValue = format(metrics.gpu)

        statusField.stringValue = "Connected"
    }

    func updateError(_ message: String?) {
        if let message {
            statusField.stringValue = "Connection error: \(message)"
        } else {
            statusField.stringValue = "Connected"
        }
    }

    // MARK: - Formatting

    private func format(_ metric: Metric) -> String {
        guard let value = metric.value, value.isFinite else {
            return "—"
        }

        return String(
            format: "%.1f%@",
            value,
            metric.unit
        )
    }
}
