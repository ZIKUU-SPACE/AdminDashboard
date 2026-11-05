
// ~/workspace/AdminDashboard/Sources/AdminDashboard/SystemView.swift

import Foundation
import Application
import Core
import AdminDashboardShared

/// Displays host information and expandable system sections.
///
/// The entire page is scrollable. Individual sections may contain
/// their own scroll views, such as the Network table.
///
/// Data retrieval is handled by SystemController.
/// All view operations must run on the ZIKUU UI thread.
final class SystemView: View {

    // MARK: - Page Scrolling

    private let pageScrollView = ScrollView()

    /// Document containing all System page sections.
    private let pageContentView = View()

    // MARK: - Views

    private let hostBox = Box()
    private let resourcesSection = CollapsibleView()
    private let networkSection = NetworkSection()

    private let hostStatusField = TextField()
    private let resourcesStatusField = TextField()

    private let runtimeSection = CollapsibleView()
    private let runtimeStatusField = TextField()

    private let runtimeLabels = [
        "Init System",
        "Execution",
        "Container Runtime",
        "Architecture",
        "Cgroup"
    ]

    private var runtimeLabelFields: [TextField] = []
    private var runtimeValueFields: [TextField] = []

    // MARK: - Host Information

    private let hostLabels = [
        "Hostname",
        "Operating System",
        "Kernel",
        "CPU",
        "Memory",
        "Uptime"
    ]

    private var hostLabelFields: [TextField] = []
    private var hostValueFields: [TextField] = []

    // MARK: - Resources

    private let resourceLabels = [
        "CPU",
        "Load Average",
        "Memory",
        "Memory Available",
        "Memory Cache",
        "Swap",
        "Disk",
        "Disk Available",
        "GPU"
    ]

    private var resourceLabelFields: [TextField] = []
    private var resourceValueFields: [TextField] = []

    // MARK: - Layout Constants

    private let margin: Float = 24
    private let boxHeight: Float = 250

    private let hostRowHeight: Float = 32
    private let resourceRowHeight: Float = 32

    private let sectionSpacing: Float = 12
    private let statusHeight: Float = 28

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

        configureHostBox()
        configureHostFields()
        configureHostStatus()

        configureResourcesSection()
        configureNetworkSection()
        configureRuntimeSection()

        pageContentView.addSubview(hostBox)
        pageContentView.addSubview(hostStatusField)
        pageContentView.addSubview(resourcesSection)
        pageContentView.addSubview(networkSection.view)
        pageContentView.addSubview(runtimeSection)

        pageScrollView.documentView = pageContentView

        addSubview(pageScrollView)

        layoutContent()
    }

    private func configurePageScrollView() {
        pageScrollView.hasBorder = false
        pageScrollView.hasVerticalScroller = true
        pageScrollView.hasHorizontalScroller = false
    }

    private func configureHostBox() {
        hostBox.title = "Host Information"
        hostBox.borderStyle = .line
        hostBox.titlePosition = .atTop
        hostBox.contentInsets = 20
        hostBox.titleHeight = 24
    }

    private func configureHostFields() {
        for label in hostLabels {
            let labelField = makeLabelField(label)
            let valueField = makeValueField()

            hostLabelFields.append(labelField)
            hostValueFields.append(valueField)

            hostBox.contentView.addSubview(labelField)
            hostBox.contentView.addSubview(valueField)
        }
    }

    private func configureHostStatus() {
        configureField(hostStatusField)

        hostStatusField.stringValue =
            "Waiting for host information..."

        hostStatusField.font = Font(
            family: "sans-serif",
            size: 12
        )
    }

    // MARK: - Resources Configuration

    private func configureResourcesSection() {
        resourcesSection.title = "Resources"
        resourcesSection.isExpanded = false

        resourcesSection.headerHeight = 36
        resourcesSection.contentSpacing = 8

        resourcesSection.contentHeight =
            16
            + Float(resourceLabels.count) * resourceRowHeight
            + statusHeight

        for label in resourceLabels {
            let labelField = makeLabelField(label)
            let valueField = makeValueField()

            resourceLabelFields.append(labelField)
            resourceValueFields.append(valueField)

            resourcesSection.contentView.addSubview(
                labelField
            )

            resourcesSection.contentView.addSubview(
                valueField
            )
        }

        configureField(resourcesStatusField)

        resourcesStatusField.stringValue =
            "Waiting for resource information..."

        resourcesStatusField.font = Font(
            family: "sans-serif",
            size: 12
        )

        resourcesSection.contentView.addSubview(
            resourcesStatusField
        )

        resourcesSection.onExpansionChanged = {
            [weak self] _ in
            self?.layoutContent()
        }

        resourcesSection.onLayoutChanged = {
            [weak self] in
            self?.layoutContent()
        }
    }

    // MARK: - Network Configuration

    private func configureNetworkSection() {
        networkSection.onHeightChanged = {
            [weak self] in
            self?.layoutContent()
        }
    }

    // MARK: - Runtime Configuration

    private func configureRuntimeSection() {
        runtimeSection.title = "Runtime"
        runtimeSection.isExpanded = false

        runtimeSection.headerHeight = 36
        runtimeSection.contentSpacing = 8

        runtimeSection.contentHeight =
            16
            + Float(runtimeLabels.count) * resourceRowHeight
            + statusHeight

        for label in runtimeLabels {
            let labelField = makeLabelField(label)
            let valueField = makeValueField()

            runtimeLabelFields.append(labelField)
            runtimeValueFields.append(valueField)

            runtimeSection.contentView.addSubview(labelField)
            runtimeSection.contentView.addSubview(valueField)
        }

        configureField(runtimeStatusField)

        runtimeStatusField.stringValue =
            "Waiting for runtime information..."

        runtimeStatusField.font = Font(
            family: "sans-serif",
            size: 12
        )

        runtimeSection.contentView.addSubview(runtimeStatusField)

        runtimeSection.onExpansionChanged = { [weak self] _ in
            self?.layoutContent()
        }

        runtimeSection.onLayoutChanged = { [weak self] in
            self?.layoutContent()
        }
    }

    // MARK: - Field Factory

    private func makeLabelField(
        _ title: String
    ) -> TextField {
        let field = TextField()

        configureField(field)

        field.stringValue = title
        field.font = Font(
            family: "sans-serif",
            size: 13,
            weight: .medium
        )

        return field
    }

    private func makeValueField() -> TextField {
        let field = TextField()

        configureField(field)

        field.stringValue = "—"
        field.font = Font(
            family: "sans-serif",
            size: 14
        )

        return field
    }

    private func configureField(
        _ field: TextField
    ) {
        field.isEditable = false
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
    }

    // MARK: - Layout

    override func resizeSubviews(
        withOldSize oldSize: Size
    ) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutContent()
    }

    private func layoutContent() {
        // The page scroll view always fills SystemView.

        pageScrollView.frame = Rect(
            x: 0,
            y: 0,
            width: max(0, bounds.size.width),
            height: max(0, bounds.size.height)
        )

        // Use the actual viewport width, excluding the
        // vertical scroller, for document layout.

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

        // MARK: Host Information

        hostBox.frame = Rect(
            x: margin,
            y: margin,
            width: contentWidth,
            height: boxHeight
        )

        layoutHostFields()

        // MARK: Host Status

        let hostStatusY = margin + boxHeight

        hostStatusField.frame = Rect(
            x: margin,
            y: hostStatusY,
            width: contentWidth,
            height: statusHeight
        )

        // MARK: Resources

        let resourcesY =
            hostStatusY
            + statusHeight
            + sectionSpacing

        resourcesSection.frame = Rect(
            x: margin,
            y: resourcesY,
            width: contentWidth,
            height: resourcesSection.preferredHeight
        )

        layoutResourceFields()

        // MARK: Network

        let networkY =
            resourcesY
            + resourcesSection.preferredHeight
            + sectionSpacing

        networkSection.view.frame = Rect(
            x: margin,
            y: networkY,
            width: contentWidth,
            height: networkSection.preferredHeight
        )

networkSection.layoutContent()

        // MARK: Runtime

        let runtimeY =
            networkY
            + networkSection.preferredHeight
            + sectionSpacing

        runtimeSection.frame = Rect(
            x: margin,
            y: runtimeY,
            width: contentWidth,
            height: runtimeSection.preferredHeight
        )

        layoutRuntimeFields()

        // MARK: Document Size

        let requiredHeight =
            runtimeY
            + runtimeSection.preferredHeight
            + margin

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

    private func layoutHostFields() {
        layoutFields(
            labels: hostLabelFields,
            values: hostValueFields,
            contentWidth:
                hostBox.contentView.bounds.size.width,
            rowHeight: hostRowHeight,
            horizontalInset: 0,
            topInset: 0
        )
    }

    private func layoutResourceFields() {
        layoutFields(
            labels: resourceLabelFields,
            values: resourceValueFields,
            contentWidth:
                resourcesSection.contentView.bounds.size.width,
            rowHeight: resourceRowHeight,
            horizontalInset: 12,
            topInset: 8
        )

        resourcesStatusField.frame = Rect(
            x: 12,
            y: 8
                + Float(resourceLabels.count) * resourceRowHeight,
            width: max(
                0,
                resourcesSection.contentView.bounds.size.width - 24
            ),
            height: statusHeight
        )
    }

    private func layoutRuntimeFields() {
        layoutFields(
            labels: runtimeLabelFields,
            values: runtimeValueFields,
            contentWidth: runtimeSection.contentView.bounds.size.width,
            rowHeight: resourceRowHeight,
            horizontalInset: 12,
            topInset: 8
        )

        runtimeStatusField.frame = Rect(
            x: 12,
            y: 8 + Float(runtimeLabels.count) * resourceRowHeight,
            width: max(
                0,
                runtimeSection.contentView.bounds.size.width - 24
            ),
            height: statusHeight
        )
    }

    private func layoutFields(
        labels: [TextField],
        values: [TextField],
        contentWidth: Float,
        rowHeight: Float,
        horizontalInset: Float,
        topInset: Float
    ) {
        let availableWidth = max(
            0,
            contentWidth - horizontalInset * 2
        )

        let labelWidth = min(
            180,
            availableWidth * 0.35
        )

        let valueX =
            horizontalInset + labelWidth + 12

        let valueWidth = max(
            0,
            availableWidth - labelWidth - 12
        )

        for index in labels.indices {
            let y =
                topInset + Float(index) * rowHeight

            labels[index].frame = Rect(
                x: horizontalInset,
                y: y,
                width: labelWidth,
                height: 30
            )

            values[index].frame = Rect(
                x: valueX,
                y: y,
                width: valueWidth,
                height: 30
            )
        }
    }

    // MARK: - Host Updates

    func update(information: HostInformation) {
        let values: [String] = [
            information.hostname ?? "—",
            information.osName ?? "—",
            information.kernel ?? "—",
            information.cpuModel ?? "—",
            formatGiB(information.memoryTotalGiB),
            formatUptime(information.uptimeSeconds)
        ]

        for (field, value) in zip(
            hostValueFields,
            values
        ) {
            field.stringValue = value
        }

        hostStatusField.stringValue = "Connected"
    }

    func updateLoading(_ loading: Bool) {
        if loading {
            hostStatusField.stringValue =
                "Loading host information..."
        }
    }

    func updateError(_ message: String?) {
        if let message {
            hostStatusField.stringValue =
                "Connection error: \(message)"
        } else {
            hostStatusField.stringValue = "Connected"
        }
    }

    // MARK: - Resources Updates

    func update(resources: SystemResources) {
        let cpu = resources.cpu
        let memory = resources.memory
        let swap = resources.swap
        let disk = resources.disk
        let gpu = resources.gpu

        let cpuDetails = [
            cpu.physicalCores.map {
                "\($0) physical"
            },
            cpu.logicalCores.map {
                "\($0) logical"
            }
        ].compactMap { $0 }

        let cpuDescription = cpuDetails.isEmpty
            ? formatPercent(cpu.usagePercent)
            : formatPercent(cpu.usagePercent)
                + "  ·  "
                + cpuDetails.joined(separator: " / ")

        let loadAverage = [
            cpu.loadAverage1m,
            cpu.loadAverage5m,
            cpu.loadAverage15m
        ].map {
            formatNumber($0, decimals: 2)
        }.joined(separator: " / ")

        let gpuDescription: String

        if let gpuUsage = gpu.usagePercent {
            gpuDescription =
                "\(gpu.device ?? "GPU")  ·  "
                + formatPercent(gpuUsage)
        } else {
            gpuDescription =
                "\(gpu.device ?? "Unavailable")"
        }

        let values: [String] = [
            cpuDescription,
            loadAverage,
            formatUsage(
                used: memory.usedGiB,
                total: memory.totalGiB,
                percent: memory.usagePercent
            ),
            formatGiB(memory.availableGiB),
            formatGiB(memory.cachedGiB),
            formatUsage(
                used: swap.usedGiB,
                total: swap.totalGiB,
                percent: swap.usagePercent
            ),
            formatUsage(
                used: disk.usedGiB,
                total: disk.totalGiB,
                percent: disk.usagePercent
            ),
            formatGiB(disk.freeGiB),
            gpuDescription
        ]

        for (field, value) in zip(
            resourceValueFields,
            values
        ) {
            field.stringValue = value
        }

        resourcesStatusField.stringValue = "Connected"
    }

    func updateResourcesLoading(_ loading: Bool) {
        if loading {
            resourcesStatusField.stringValue =
                "Loading resource information..."
        }
    }

    func updateResourcesError(_ message: String?) {
        if let message {
            resourcesStatusField.stringValue =
                "Resources error: \(message)"
        } else {
            resourcesStatusField.stringValue = "Connected"
        }
    }

    // MARK: - Network Updates

    func update(network: SystemNetwork) {
        networkSection.update(network: network)
    }

    func updateNetworkLoading(_ loading: Bool) {
        networkSection.updateLoading(loading)
    }

    func updateNetworkError(_ message: String?) {
        networkSection.updateError(message)
    }

    // MARK: - Runtime Updates

    func update(runtime: SystemRuntime) {
        let values = [
            runtime.initSystem ?? "—",
            runtime.execution,
            runtime.containerRuntime ?? "—",
            runtime.architecture,
            runtime.cgroup ?? "—"
        ]

        for (field, value) in zip(runtimeValueFields, values) {
            field.stringValue = value
        }

        runtimeStatusField.stringValue = "Connected"
    }

    func updateRuntimeLoading(_ loading: Bool) {
        if loading {
            runtimeStatusField.stringValue =
                "Loading runtime information..."
        }
    }

    func updateRuntimeError(_ message: String?) {
        if let message {
            runtimeStatusField.stringValue =
                "Runtime error: \(message)"
        } else {
            runtimeStatusField.stringValue = "Connected"
        }
    }

    // MARK: - Formatting

    private func formatNumber(
        _ value: Double?,
        decimals: Int
    ) -> String {
        guard let value, value.isFinite else {
            return "—"
        }

        return String(
            format: "%.\(decimals)f",
            value
        )
    }

    private func formatPercent(
        _ value: Double?
    ) -> String {
        guard let value, value.isFinite else {
            return "—"
        }

        return String(
            format: "%.1f%%",
            value
        )
    }

    private func formatGiB(
        _ value: Double?
    ) -> String {
        guard let value, value.isFinite else {
            return "—"
        }

        return String(
            format: "%.1f GiB",
            value
        )
    }

    private func formatUsage(
        used: Double,
        total: Double,
        percent: Double
    ) -> String {
        "\(formatGiB(used)) / \(formatGiB(total))"
            + "  (\(formatPercent(percent)))"
    }

    private func formatUptime(
        _ value: Double?
    ) -> String {
        guard let value,
              value.isFinite,
              value >= 0 else {
            return "—"
        }

        let totalSeconds = Int(value)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60

        return "\(days)d \(hours)h \(minutes)m"
    }
}
