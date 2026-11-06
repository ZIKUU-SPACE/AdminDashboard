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

    // MARK: - Container

    private let metricsBox = Box()

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

    // MARK: - Layout Constants

    private let margin: Float = 20
    private let boxInsets: Float = 16
    private let boxTitleHeight: Float = 24

    private let maximumGaugeSize: Float = 160

    private let columnSpacing: Float = 12
    private let rowSpacing: Float = 12

    private let labelHeight: Float = 26
    private let labelSpacing: Float = 8

    private let statusHeight: Float = 26
    private let statusSpacing: Float = 12

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
        configureBox()
        configureFields()
        configureGauges()

        addSubview(metricsBox)
        addSubview(statusField)

        layoutContent()
    }

    private func configureBox() {
        metricsBox.title = "System Metrics"
        metricsBox.borderStyle = .line
        metricsBox.titlePosition = .atTop
        metricsBox.contentInsets = boxInsets
        metricsBox.titleHeight = boxTitleHeight
    }

    private func configureFields() {
        for field in valueFields {
            configureField(field)
            field.alignment = .center
        }

        for field in labelFields {
            configureField(field)
            field.alignment = .center

            field.font = Font(
                family: "sans-serif",
                size: 14,
                weight: .medium
            )
        }

        configureField(statusField)

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
    }

    private func configureGauges() {
        cpuGauge.progressColor = GraphicsColor(
            red: 0.25,
            green: 0.49,
            blue: 0.81
        )

        memoryGauge.progressColor = GraphicsColor(
            red: 0.26,
            green: 0.62,
            blue: 0.49
        )

        diskGauge.progressColor = GraphicsColor(
            red: 0.77,
            green: 0.55,
            blue: 0.26
        )

        gpuGauge.progressColor = GraphicsColor(
            red: 0.59,
            green: 0.42,
            blue: 0.72
        )

        // Gauges are drawn first.
        for gauge in gauges {
            metricsBox.contentView.addSubview(gauge)
        }

        // Values are drawn over the circular gauges.
        for field in valueFields {
            metricsBox.contentView.addSubview(field)
        }

        for field in labelFields {
            metricsBox.contentView.addSubview(field)
        }
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

        let boxWidth = max(
            0,
            width - margin * 2
        )

        // Determine the number of gauge columns.
        let columns: Int

        if boxWidth >= 760 {
            columns = 4
        } else if boxWidth >= 400 {
            columns = 2
        } else {
            columns = 1
        }

        let rows = (gauges.count + columns - 1) / columns

        // Available space inside Box.contentView.
        let contentWidth = max(
            0,
            boxWidth - boxInsets * 2
        )

        let columnWidth = max(
            0,
            (
                contentWidth
                - Float(columns - 1) * columnSpacing
            ) / Float(columns)
        )

        let gaugeWidthLimit = max(
            0,
            columnWidth - 12
        )

        // The Box is top-aligned, but its content must still
        // fit when the window becomes shorter.
        let availableBoxHeight = max(
            0,
            height
                - margin * 2
                - statusHeight
                - statusSpacing
        )

        let availableContentHeight = max(
            0,
            availableBoxHeight
                - boxTitleHeight
                - boxInsets * 2
        )

        let availableRowHeight = max(
            0,
            (
                availableContentHeight
                - Float(rows - 1) * rowSpacing
            ) / Float(rows)
        )

        let gaugeHeightLimit = max(
            0,
            availableRowHeight
                - labelHeight
                - labelSpacing
        )

        let gaugeSize = max(
            0,
            min(
                maximumGaugeSize,
                gaugeWidthLimit,
                gaugeHeightLimit
            )
        )

        let groupHeight = gaugeSize
            + labelSpacing
            + labelHeight

        let contentHeight = Float(rows) * groupHeight
            + Float(rows - 1) * rowSpacing

        let boxHeight = boxTitleHeight
            + boxInsets * 2
            + contentHeight

        // MARK: Box Frame

        metricsBox.frame = Rect(
            x: margin,
            y: margin,
            width: boxWidth,
            height: boxHeight
        )

        // MARK: Value Font

        let valueFont = Font(
            family: "sans-serif",
            size: max(
                10,
                min(28, gaugeSize * 0.20)
            ),
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

        // MARK: Gauge Layout

        let gauges = self.gauges
        let values = valueFields
        let labels = labelFields

        for index in gauges.indices {
            let column = index % columns
            let row = index / columns

            let cellX = Float(column)
                * (columnWidth + columnSpacing)

            let cellY = Float(row)
                * (groupHeight + rowSpacing)

            let gaugeX = cellX
                + (columnWidth - gaugeSize) / 2

            let gaugeY = cellY

            gauges[index].frame = Rect(
                x: gaugeX,
                y: gaugeY,
                width: gaugeSize,
                height: gaugeSize
            )

            values[index].frame = Rect(
                x: gaugeX,
                y: gaugeY + (gaugeSize - valueHeight) / 2,
                width: gaugeSize,
                height: valueHeight
            )

            labels[index].frame = Rect(
                x: cellX,
                y: gaugeY + gaugeSize + labelSpacing,
                width: columnWidth,
                height: labelHeight
            )
        }

        // MARK: Status

        statusField.frame = Rect(
            x: margin,
            y: margin + boxHeight + statusSpacing,
            width: boxWidth,
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
            statusField.stringValue =
                "Connection error: \(message)"
        } else {
            statusField.stringValue = "Connected"
        }
    }

    // MARK: - Formatting

    private func format(_ metric: Metric) -> String {
        guard let value = metric.value,
              value.isFinite else {
            return "—"
        }

        return String(
            format: "%.1f%@",
            value,
            metric.unit
        )
    }
}
