import Foundation

public enum InAppDisplayState {
    case show, skip, consume
}

public protocol InAppDelegate: AnyObject {
    var autoShow: Bool { get }
    var useDarkMode: Bool { get }
    func onNew(notification: ParcelvoyNotification) -> InAppDisplayState
    func didDisplay(notification: ParcelvoyNotification)
    func handle(action: InAppAction, context: [String: Any], notification: ParcelvoyNotification)
    func onError(error: Error)
}

extension InAppDelegate {
    public var autoShow: Bool { true }
    public var useDarkMode: Bool { false }
    public func onNew(notification: ParcelvoyNotification) -> InAppDisplayState { .show }
    public func didDisplay(notification: ParcelvoyNotification) {}
    public func onError(error: Error) {}
}
