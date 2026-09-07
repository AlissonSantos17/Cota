import Foundation
import ServiceManagement

/// How the store reaches the login item.
///
/// Injectable because `SMAppService` needs a real bundle, which a test process
/// does not have. The state of the switch is worth a test — it used to read
/// `false` on every open regardless of what the system held — and that test
/// cannot exist while the only way to ask is a call into ServiceManagement.
public struct LaunchAgent: Sendable {
    public let isEnabled: @Sendable () -> Bool
    public let setEnabled: @Sendable (Bool) throws -> Void

    public init(
        isEnabled: @escaping @Sendable () -> Bool,
        setEnabled: @escaping @Sendable (Bool) throws -> Void
    ) {
        self.isEnabled = isEnabled
        self.setEnabled = setEnabled
    }

    public static let system = LaunchAgent(
        isEnabled: { SMAppService.mainApp.status == .enabled },
        setEnabled: { enabled in
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        }
    )
}
