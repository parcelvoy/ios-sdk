import Foundation

public struct Config {
    let apiKey: String
    let urlEndpoint: String
}

public struct Identity: Encodable {
    let anonymousId: String
    let externalId: String?
    let phone: String?
    let email: String?
    let traits: [String: Any]

    enum CodingKeys: String, CodingKey {
        case anonymousId, externalId, phone, email
        case traits = "data"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(anonymousId, forKey: .anonymousId)
        try container.encodeIfPresent(externalId, forKey: .externalId)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(traits, forKey: .traits)
    }
}

struct Alias: Encodable {
    let anonymousId: String
    let externalId: String?
}

struct Event: Encodable {
    let name: String
    let anonymousId: String
    let externalId: String?
    let data: [String: Any]

    enum CodingKeys: String, CodingKey {
        case name, anonymousId, externalId, data
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(anonymousId, forKey: .anonymousId)
        try container.encodeIfPresent(externalId, forKey: .externalId)
        try container.encodeIfPresent(data, forKey: .data)
    }
}

struct Device: Codable {
    let anonymousId: String
    let externalId: String?
    let deviceId: String
    let token: String?
    let os: String
    let osVersion: String
    let model: String
    let appBuild: String
    let appVersion: String

    init(anonymousId: String, deviceId: String, externalId: String?, token: String?) {
        self.anonymousId = anonymousId
        self.deviceId = deviceId
        self.externalId = externalId
        self.token = token
        self.os = "iOS"
        self.osVersion = ProcessInfo().operatingSystemVersionString
        self.model = Self.model
        self.appBuild = Self.appBuild
        self.appVersion = Self.appVersion
    }

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
