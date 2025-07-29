import Foundation

public enum InAppDisplayState {
    case show, skip
}

public protocol InAppDelegate: AnyObject {
    var autoShow: Bool { get }
    func onNew(notification: ParcelvoyNotification) -> InAppDisplayState
    func handle(action: InAppAction, context: [String: AnyObject], notification: ParcelvoyNotification)
}

extension InAppDelegate {
    public var autoShow: Bool { true }
    public func onNew(notification: ParcelvoyNotification) -> InAppDisplayState {
        return .show
    }
}
