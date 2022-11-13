import Foundation

public struct Config {
    let apiKey: String
    let urlEndpoint: String
}

public struct Identity: Encodable {
    let externalId: String
    let phone: String?
    let email: String?
    let traits: [String: Any]

    enum CodingKeys: String, CodingKey {
        case externalId, phone, email
        case traits = "data"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(externalId, forKey: .externalId)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(traits, forKey: .traits)
    }
}

struct Event: Encodable {
    let name: String
    let userId: String
    let data: [String: Any]

    enum CodingKeys: String, CodingKey {
        case name, userId, data
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(data, forKey: .data)
    }
}

struct User: Codable {
    let anonymousId: String
    let externalId: String
}

struct Device: Codable {
    let externalId: String
    let token: String?
    let os: String
    let osVersion: String
    let model: String
    let appBuild: String
    let appVersion: String

    static let stored = Device(
        externalId: "abcd",
        token: "dcfg",
        os: "iOS",
        osVersion: ProcessInfo().operatingSystemVersionString,
        model: model,
        appBuild: appBuild,
        appVersion: appVersion
    )

    static let model: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }()

    static let appBuild: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String

    static let appVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
}

public class Parcelvoy {

    public static let shared = Parcelvoy()

    // TODO: Store values inside of UserDefaults
    private var externalId: String?
    private var anonymousId: String = UUID().uuidString
    private var apiKey: String!
    private var urlEndpoint: String!
    private var config: Config!

    private lazy var network = NetworkManager(config: self.config)

    public init() {}

    public func initialize(apiKey: String, urlEndpoint: String) {
        self.config = Config(apiKey: apiKey, urlEndpoint: urlEndpoint)
    }

    public func initialize(config: Config) {
        self.config = config
    }

    public func identify(id: String, email: String? = nil, phone: String? = nil, traits: [String: Any]) {
        self.identify(identity: Identity(
            externalId: id,
            phone: phone,
            email: email,
            traits: traits
        ))
    }

    public func identify(identity: Identity) {
        if (externalId == nil) {
            self.alias(anonymousId: anonymousId, externalId: identity.externalId)
        }
        self.network.post(path: "identify", object: identity) { (error) in
            if let error = error {
                print(error)
            }
        }
        // TODO: Perform network request
        self.externalId = identity.externalId
    }

    public func alias(anonymousId: String, externalId: String) {
        // TODO: Perform network request
        // TODO: Store external ID as new identifier
    }

    public func track() {
        // TODO: Add item to internal queue
        // TODO: Perform network request
        // TODO: Flush queue at some interval
    }
}

fileprivate class NetworkManager {
    var urlSession = URLSession.shared

    private let config: Config
    init(config: Config) {
        self.config = config
    }

    func get(path: String) {

    }

    func post(path: String, object: Encodable, handler: @escaping (Error?) -> Void) {
        let url = URL(string: "\(config.urlEndpoint)/client/\(path)")!

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(DateFormatter.jsonDateFormat)
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try? encoder.encode(object)

        self.request(request: request, handler: handler)
    }

    func request(request: URLRequest, handler: @escaping (Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse,
                  error == nil
            else {
                print("error", error ?? URLError(.badServerResponse))
                return
            }

            guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
                print("statusCode should be 2xx, but is \(response.statusCode)")
                print("response = \(response)")
                return
            }

            handler(nil)
        }

        task.resume()
    }
}
