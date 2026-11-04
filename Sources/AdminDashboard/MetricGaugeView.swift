
 // ~/workspace/AdminDashboard/Sources/AdminDashboard/MetricGaugeView.swift

import Application
import Core

/// A circular utilization gauge for percentage metrics.
///
/// The gauge draws only its circular track and progress arc.
/// Labels and numerical values belong to the containing view.
///
/// All properties must be accessed on the application's UI thread.
final class MetricGaugeView: View {

    // MARK: - Value

    /// Percentage from 0 to 100.
    ///
    /// A nil value displays only the background track.
    var value: Double? {
        didSet {
            setNeedsDisplay()
        }
    }

    // MARK: - Appearance

    var trackColor = GraphicsColor(
        red: 0.87,
        green: 0.89,
        blue: 0.91
    ) {
        didSet {
            setNeedsDisplay()
        }
    }

    var progressColor = GraphicsColor(
        red: 0.25,
        green: 0.49,
        blue: 0.81
    ) {
        didSet {
            setNeedsDisplay()
        }
    }

    var lineWidth: Float = 10 {
        didSet {
            setNeedsDisplay()
        }
    }

    // MARK: - Initialization

    override init(frame: Rect) {
        value = nil
        super.init(frame: frame)
    }

    override init() {
        value = nil
        super.init()
    }

    // MARK: - Drawing

    override func draw(
        _ dirtyRect: Rect,
        in context: GraphicsContext
    ) {
        let bounds = self.bounds

        let diameter = min(
            bounds.size.width,
            bounds.size.height
        )

        guard diameter > 0 else {
            return
        }

        let strokeWidth = min(
            max(1, lineWidth),
            diameter / 4
        )

        let radius = (diameter - strokeWidth) / 2 - 2

        guard radius > 0 else {
            return
        }

        let center = Point(
            x: bounds.midX,
            y: bounds.midY
        )

        context.saveGraphicsState()
        defer {
            context.restoreGraphicsState()
        }

        context.setLineWidth(strokeWidth)
        context.setLineCapStyle(.round)

        // MARK: Background Track

        let track = BezierPath()

        track.appendArc(
            center: center,
            radius: radius,
            startAngle: -90,
            endAngle: 270
        )

        context.setStrokeColor(trackColor)
        context.stroke(track)

        // MARK: Progress

        guard let value, value.isFinite else {
            return
        }

        let percentage = min(
            100,
            max(0, value)
        )

        guard percentage > 0 else {
            return
        }

        let startAngle: Float = -90

        let endAngle = startAngle
            + Float(percentage / 100) * 360

        let progress = BezierPath()

        progress.appendArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle
        )

        context.setStrokeColor(progressColor)
        context.stroke(progress)
    }
}
