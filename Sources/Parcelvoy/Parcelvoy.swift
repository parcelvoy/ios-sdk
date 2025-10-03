import Foundation
import UIKit

public class Parcelvoy {

    enum StoreKey: String {
        case externalId
        case anonymousId
        case deviceId
    }

    public static let shared = Parcelvoy()

    private var externalId: String? {
        didSet {
            if externalId != nil {
                self.store?.set(externalId, forKey: StoreKey.externalId.rawValue)
            } else {
                self.store?.removeObject(forKey: StoreKey.externalId.rawValue)
            }
        }
    }
    private(set) var anonymousId: String {
        didSet {
            self.store?.set(anonymousId, forKey: StoreKey.anonymousId.rawValue)
        }
    }
    private(set) var deviceId: String {
        didSet {
            self.store?.set(deviceId, forKey: StoreKey.deviceId.rawValue)
        }
    }
    private var config: Config? {
        didSet {
            if let config = config {
                self.network = NetworkManager(config: config)
            }
        }
    }

    private var network: NetworkManager?
    private var store = UserDefaults(suiteName: "Parcelvoy")

    private var inAppDelegate: InAppDelegate? {
        get { config?.inAppDelegate }
    }
    private var inAppController: UIViewController?

    public init() {
        self.deviceId = UUID().uuidString
        self.externalId = self.store?.string(forKey: StoreKey.externalId.rawValue)
        if let anonymousId = self.store?.string(forKey: StoreKey.anonymousId.rawValue) {
            self.anonymousId = anonymousId
        } else {
            self.anonymousId = UUID().uuidString
            store?.set(self.anonymousId, forKey: StoreKey.anonymousId.rawValue)
        }
    }

    /// Initialize the library with the required API key and URL endpoint
    ///
    /// **This must be called before any other methods**
    ///
    /// - Parameters:
    ///     - apiKey: A generated public API key
    ///     - urlEndpoint: The based domain of the hosted Parcelvoy instance
    ///
    @discardableResult
    public static func initialize(
        apiKey: String,
        urlEndpoint: String,
        inAppDelegate: InAppDelegate? = nil,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Parcelvoy {
        return Self.shared.initialize(apiKey: apiKey, urlEndpoint: urlEndpoint, inAppDelegate: inAppDelegate, launchOptions: launchOptions)
    }

    @discardableResult
    public func initialize(
        apiKey: String,
        urlEndpoint: String,
        inAppDelegate: InAppDelegate? = nil,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Parcelvoy {
        return self.initialize(config: Config(
            apiKey: apiKey,
            urlEndpoint: urlEndpoint,
            inAppDelegate: inAppDelegate
        ), launchOptions: launchOptions)
    }

    @discardableResult
    public func initialize(
        config: Config,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Parcelvoy {
        self.config = config
        self.boot()
        return self
    }

    private func boot() {
        if inAppDelegate?.autoShow == true {
            Task { @MainActor in
                await self.showLatestNotification()
            }
        }
    }

    /// Identify a given user
    ///
    /// This can be used either for anonymous or known users. When a user transitions from
    /// anonymous to known, call identify again to automatically alias ther users together.
    ///
    /// Call identify whenever user traits (attributes) change to make sure they are updated.
    ///
    /// - Parameters:
    ///     - id: An optional known user identifier
    ///     - email: Optional email address of the user
    ///     - phone: Optional phone number of the user
    ///     - traits: Attributes of the user
    ///
    public func identify(id: String, email: String? = nil, phone: String? = nil, traits: [String: Any] = [:]) {
        self.identify(identity: Identity(
            anonymousId: self.anonymousId,
            externalId: id,
            phone: phone,
            email: email,
            traits: traits
        ))
    }

    /// Identify a given user
    ///
    /// This can be used either for anonymous or known users. When a user transitions from
    /// anonymous to known, call identify again to automatically alias ther users together.
    ///
    /// Call identify whenever user traits (attributes) change to make sure they are updated.
    ///
    /// - Parameters:
    ///     - identity: An object representing a Parcelvoy user identity
    ///
    public func identify(identity: Identity) {
        self.checkInit()

        if self.externalId == nil, let externalId = identity.externalId {
            self.alias(anonymousId: anonymousId, externalId: externalId)
        }
        
        self.externalId = identity.externalId
        self.network?.post(path: "identify", object: identity)
    }

    /// Alias an anonymous user to a known user
    ///
    /// Calling alias will only work once, repeated calls will do nothing.
    ///
    /// **This method is automatically called by `identify` and should not need
    /// to be manually called**
    ///
    /// - Parameters:
    ///     - anonymousId: The internal anonymous identifier of the user
    ///     - externalId: The known user identifier
    ///
    public func alias(anonymousId: String, externalId: String) {
        self.checkInit()
        self.externalId = externalId
        self.network?.post(path: "alias", object: Alias(anonymousId: anonymousId, externalId: externalId))
    }

    /// Track an event
    ///
    /// Send events for both anonymous and identified users to Parcelvoy to
    /// trigger journeys or lists.
    ///
    /// - Parameters:
    ///     - event: A string name of the event
    ///     - properties: A dictionary of attributes associated to the event
    ///
    public func track(event: String, properties: [String: Any]) {
        self.checkInit()
        let event = Event(
            name: event,
            anonymousId: self.anonymousId,
            externalId: self.externalId,
            data: properties
        )
        self.postEvent(event)
    }

    /// Register device and push notifications
    ///
    /// This method registers the current device. It is intended to send up the
    /// push notification token, but can also be used to know what device the
    /// user is using.
    ///
    /// - Parameters:
    ///     - token: An optional push notification token
    ///
    public func register(token: Data?) {
        self.checkInit()
        let device = Device(
            anonymousId: self.anonymousId,
            deviceId: self.deviceId,
            externalId: self.externalId,
            token: token?.hexString
        )
        self.network?.post(path: "devices", object: device)
    }

    public typealias Cursor = String
    public func getNofications() async throws -> Page<ParcelvoyNotification> {
        let user = Alias(anonymousId: self.anonymousId, externalId: self.externalId)
        guard let network = self.network else { throw NetworkError() }
        return try await network.get(path: "notifications", user: user)
    }

    public func showLatestNotification() async {
        do {
            let notifications = try await self.getNofications()

            // Run through all notifications to check if they should
            // be displayed or not
            for notification in notifications.results {
                if let response = self.inAppDelegate?.onNew(notification: notification) {
                    switch response {
                    case .show: await self.show(notification: notification)
                    case .consume: await self.consume(notification: notification)
                    case .skip: continue
                    }
                }
            }
        } catch {
            self.inAppDelegate?.onError(error: error)
        }
    }

    @MainActor
    public func show(notification: ParcelvoyNotification) async {
        let viewController = UIApplication
            .shared
            .connectedScenes
            .compactMap {$0 as? UIWindowScene}
            .flatMap { $0.windows }
            .last { $0.isKeyWindow }?
            .rootViewController
        guard let viewController,
                  viewController.presentedViewController == nil,
                  inAppController == nil,
                  let inAppController = InAppModalViewController(notification: notification, delegate: self) else { return }

        viewController.present(inAppController, animated: false)
        self.inAppController = inAppController

        if notification.content.readOnShow ?? false {
            await self.consume(notification: notification)
        }
    }

    public func consume(notification: ParcelvoyNotification) async {
        do {
            try await self.network?.put(path: "notifications/\(notification.id)", object: Alias(anonymousId: anonymousId, externalId: externalId))
        } catch let error {
            self.inAppDelegate?.onError(error: error)
        }
    }

    public func dismiss(notification: ParcelvoyNotification) async {
        await MainActor.run {
            inAppController?.dismiss(animated: false)
            inAppController = nil
        }

        await self.consume(notification: notification)
    }

    /// Handle deeplink navigation
    ///
    /// To allow for click tracking, all emails are click-wrapped in a Parcelvoy url
    /// that then needs to be unwrapped for navigation purposes. This method
    /// checks to see if a given URL is a Parcelvoy URL and if so, unwraps the url,
    /// triggers the unwrapped URL and calls the Parcelvoy API to register that the
    /// URL was executed.
    ///
    /// - Parameters:
    ///     - universalLink: The URL that the app is trying to open
    ///
    @discardableResult
    public func handle(universalLink: URL) -> Bool {
        guard isParcelvoyDeepLink(url: universalLink.absoluteString),
            let queryParams = universalLink.queryParameters,
              let redirect = queryParams["r"]?.removingPercentEncoding,
              let redirectUrl = URL(string: redirect) else {
            return false
        }

        /// Run the URL so that the redirect events get triggered at API
        var request = URLRequest(url: universalLink)
        request.httpMethod = "GET"
        self.network?.process(request: request)

        /// Manually redirect to the URL included in the parameter
        open(url: redirectUrl)
        return true
    }

    /// Handle push notification receipt
    ///
    /// Push notifications may come with an internal redirect to execute when
    /// the notification is opened. This method opens a URL if one is provided
    /// and returns if there was a match or not.
    ///
    /// - Parameters:
    ///     - application: The application surounding the context of the notification
    ///     - userInfo: The dictionary of attributes included in the notification
    ///
    @discardableResult
    public func handle(_ application: UIApplication, userInfo: [AnyHashable: Any]) -> Bool {

        /// Handle silent notifications that should only trigger in-app messages
        if let silentNotification = userInfo["aps"] as? [String: AnyObject],
           silentNotification["content-available"] as? Int == 1 {
            Task { @MainActor in
                await self.showLatestNotification()
            }
            return true
        }

        /// Handle opening the app from tapping on a notification
        if let _ = userInfo["method"] as? String,
           let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString) {
            if !handle(universalLink: url) {
                open(url: url)
            }
            return true
        }
        return false
    }

    public func isParcelvoyDeepLink(url: String) -> Bool {
        guard let endpoint = self.config?.urlEndpoint else {
            return false
        }
        return url.starts(with: "\(endpoint)/c")
    }

    private func open(url: URL) {

        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = url

        if #available(iOS 13.0, *) {
            // SceneDelegate apps
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let delegate = scene.delegate {
                delegate.scene?(scene, continue: activity)
            }
        } else {
            // AppDelegate-only apps
            let _ = UIApplication.shared.delegate?.application?(
                UIApplication.shared,
                continue: activity,
                restorationHandler: { _ in }
            )
        }
    }

    /// Reset session such that a new anonymous ID is generated
    ///
    public func reset() {
        self.anonymousId = UUID().uuidString
        self.externalId = nil
    }

    private func checkInit() {
        assert(self.config != nil, "You must initialize the Parcelvoy library before calling any methods")
    }

    private func postEvent(_ event: Event, retries: Int = 3) {
        self.network?.post(path: "events", object: [event]) { [weak self] error in
            if error != nil {
                if retries <= 0 { return }
                self?.postEvent(event, retries: (retries - 1))
            }
        }
    }
}

extension Parcelvoy: InAppModelViewControllerDelegate {
    var useDarkMode: Bool { inAppDelegate?.useDarkMode ?? false }

    func didDisplay(notification: ParcelvoyNotification) {
        inAppDelegate?.didDisplay(notification: notification)
    }

    func handle(action: InAppAction, context: [String : Any], notification: ParcelvoyNotification) {
        Task { @MainActor in
            if action == .dismiss {
                await self.dismiss(notification: notification)
            }
            self.inAppDelegate?.handle(action: action, context: context, notification: notification)
        }
    }

    func onError(error: any Error) {
        inAppDelegate?.onError(error: error)
    }
}
