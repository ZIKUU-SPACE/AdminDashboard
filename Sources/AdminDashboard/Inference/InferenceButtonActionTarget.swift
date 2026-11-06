// ~/workspace/AdminDashboard/Sources/AdminDashboard/InferenceButtonActionTarget.swift

import Application
import Core

/// Bridges the ZIKUU Target/Action mechanism to a closure.
///
/// The action method is registered once per class.
/// Each instance owns its callback independently.
///
/// Button retains its target weakly, so the owner must
/// retain this object for as long as its buttons exist.
final class InferenceButtonActionTarget: Monas {

    // MARK: - Selector

    static let actionSelector = Selector(
        "buttonPressed:",
        View.self
    )

    // MARK: - Registration

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
                            target as? InferenceButtonActionTarget,
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
                "Failed to register inference button action: \(error)"
            )
        }
    }()

    // MARK: - Callback

    var onAction: ((View) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()

        // Ensure registration before a Button uses the selector.
        _ = Self.registration
    }
}
