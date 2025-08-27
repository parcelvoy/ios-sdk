import Foundation

public enum InAppDisplayState {
    case show, skip, consume
}

public protocol InAppDelegate: AnyObject {
    var autoShow: Bool { get }
    func onNew(notification: ParcelvoyNotification) -> InAppDisplayState
    func handle(action: InAppAction, context: [String: Any], notification: ParcelvoyNotification)
    func onError(error: Error)
}

extension InAppDelegate {
    public var autoShow: Bool { true }
    public func onNew(notification: ParcelvoyNotification) -> InAppDisplayState {
        return .show
    }
    public func onError(error: Error) {}
}
