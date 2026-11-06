
// ~/workspace/AdminDashboard/Sources/AdminDashboard/CollapsibleView.swift

import Application
import Core

/// A reusable expandable/collapsible content container.
///
/// Uses the framework's standard Button and target/action mechanism.
///
/// The parent view determines the frame using preferredHeight.
/// Content views remain retained while collapsed, but are detached
/// from the view hierarchy to avoid unnecessary rendering.
final class CollapsibleView: View {

    // MARK: - Action

    private static let headerSelector = Selector(
        "headerAction(_:)",
        Button.self
    )

    // MARK: - Views

    private let headerButton = Button()

    /// Container for arbitrary application views.
    ///
    /// Add children here rather than directly to CollapsibleView.
    let contentView = View()

    // MARK: - Properties

    var title: String = "" {
        didSet {
            updateHeader()
        }
    }

    /// Expansion state is owned by the toggle Button.
    var isExpanded: Bool {
        get {
            headerButton.state != 0
        }
        set {
            setExpanded(newValue)
        }
    }

    var contentHeight: Float = 200 {
        didSet {
            guard contentHeight.isFinite,
                  contentHeight >= 0 else {
                contentHeight = oldValue
                return
            }

            layoutContent()
            onLayoutChanged?()
        }
    }

    var headerHeight: Float = 32 {
        didSet {
            guard headerHeight.isFinite,
                  headerHeight > 0 else {
                headerHeight = oldValue
                return
            }

            layoutContent()
            onLayoutChanged?()
        }
    }

    var contentSpacing: Float = 8 {
        didSet {
            guard contentSpacing.isFinite,
                  contentSpacing >= 0 else {
                contentSpacing = oldValue
                return
            }

            layoutContent()
            onLayoutChanged?()
        }
    }

    // MARK: - Callbacks

    var onExpansionChanged: ((Bool) -> Void)?
    var onLayoutChanged: (() -> Void)?

    // MARK: - Dimensions

    var preferredHeight: Float {
        guard isExpanded else {
            return headerHeight
        }

        return headerHeight + contentSpacing + contentHeight
    }

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
        registerHeaderAction()

        headerButton.buttonType = .toggle
        headerButton.target = self
        headerButton.action = Self.headerSelector

        addSubview(headerButton)

        updateHeader()
        layoutContent()
    }

    // MARK: - Target / Action

    private func registerHeaderAction() {
        guard !responds(to: Self.headerSelector) else {
            return
        }

        let signature = MethodSignature.signature(
            argumentTypes: [
                MethodType(Button.self)
            ],
            returnType: MethodType(Void.self)
        )

        do {
            try Self.registerMethod(
                Self.headerSelector,
                signature: signature
            ) { target, arguments in

                guard let collapsible = target as? CollapsibleView,
                    let button = arguments.first as? Button else {
                    return nil
                }

                collapsible.headerAction(button)
                return nil
            }
        } catch {
            preconditionFailure(
                "Failed to register CollapsibleView action: \(error)"
            )
        }
    }

    private func headerAction(_ sender: Button) {
        guard sender === headerButton else {
            return
        }

        // ButtonCell.activate() has already updated the toggle state.
        // Do not toggle it again here.
        expansionDidChange()
    }

    // MARK: - Header

    private func updateHeader() {
        let collapsedTitle = title.isEmpty
            ? "▶"
            : "▶  \(title)"

        let expandedTitle = title.isEmpty
            ? "▼"
            : "▼  \(title)"

        headerButton.title = collapsedTitle
        headerButton.alternateTitle = expandedTitle
    }

    // MARK: - Expansion

    func toggle() {
        setExpanded(!isExpanded)
    }

    func expand() {
        setExpanded(true)
    }

    func collapse() {
        setExpanded(false)
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else {
            return
        }

        headerButton.state = expanded ? 1 : 0
        expansionDidChange()
    }

    private func expansionDidChange() {
        layoutContent()
        onExpansionChanged?(isExpanded)
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

        headerButton.frame = Rect(
            x: 0,
            y: 0,
            width: width,
            height: headerHeight
        )

        if isExpanded {
            if contentView.superview !== self {
                addSubview(contentView)
            }

            contentView.frame = Rect(
                x: 0,
                y: headerHeight + contentSpacing,
                width: width,
                height: contentHeight
            )
        } else {
            if contentView.superview === self {
                contentView.removeFromSuperview()
            }
        }

        setNeedsDisplay()
    }
}
