import Foundation

public enum InAppDisplayState {
    case show, skip
}

public protocol InAppDelegate: AnyObject {
    var autoShow: Bool { get }
    func onNew(notification: ParcelvoyNotification) -> InAppDisplayState
    func handle(action: InAppAction, context: [String: AnyObject], notification: ParcelvoyNotification)
    func onError(error: Error)
}

extension InAppDelegate {
    public var autoShow: Bool { true }
    public func onNew(notification: ParcelvoyNotification) -> InAppDisplayState {
        return .show
    }
    public func onError(error: Error) {}
}
