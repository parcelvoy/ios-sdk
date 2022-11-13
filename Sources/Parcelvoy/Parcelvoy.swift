import Foundation

public class Parcelvoy {

    enum StoreKeyName: String {
        case externalId
        case anonymousId
    }

    public static let shared = Parcelvoy()

    private var externalId: String? {
        didSet {
            self.store?.set(externalId, forKey: StoreKeyName.externalId.rawValue)
        }
    }
    private var anonymousId: String {
        didSet {
            self.store?.set(anonymousId, forKey: StoreKeyName.anonymousId.rawValue)
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

    public init() {
        self.externalId = self.store?.string(forKey: StoreKeyName.externalId.rawValue)
        if let anonymousId = self.store?.string(forKey: StoreKeyName.anonymousId.rawValue) {
            self.anonymousId = anonymousId
        } else {
            self.anonymousId = UUID().uuidString
            store?.set(self.anonymousId, forKey: StoreKeyName.anonymousId.rawValue)
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
    public static func initialize(apiKey: String, urlEndpoint: String): Parcelvoy {
        return Self.shared.initialize(apiKey: apiKey, urlEndpoint: urlEndpoint)
    }

    public func initialize(apiKey: String, urlEndpoint: String): Parcelvoy {
        self.config = Config(apiKey: apiKey, urlEndpoint: urlEndpoint)
        return self
    }

    public func initialize(config: Config): Parcelvoy {
        self.config = config
        return self
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
            externalId: self.externalId,
            token: token?.hexString
        )
        self.network?.post(path: "devices", object: device)
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
