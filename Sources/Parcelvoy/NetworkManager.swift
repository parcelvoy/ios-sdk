import Foundation

class NetworkManager {
    var urlSession = URLSession.shared

    private let config: Config
    init(config: Config) {
        self.config = config
    }

    func get<T: Decodable> (path: String, user: Alias) async throws -> T {
        let headers = [
            "x-anonymous-id": user.anonymousId,
            "x-external-id": user.externalId
        ]
        let request = self.request(path: path, method: "GET", headers: headers)
        return try await self.process(request: request)
    }

    func post(path: String, object: Encodable, handler: ((Error?) -> Void)? = nil) {
        let request = self.request(path: path, method: "POST", object: object)
        self.process(request: request) { (result: Result<Data?, Error>) in
            switch result {
            case .failure(let error): handler?(error)
            case .success: handler?(nil)
            }
        }
    }

    func post<T: Decodable>(path: String, object: Encodable) async throws -> T {
        let request = self.request(path: path, method: "POST", object: object)
        return try await self.process(request: request)
    }

    @discardableResult func put(path: String, object: Encodable) async throws -> Data? {
        let request = self.request(path: path, method: "PUT", object: object)
        return try await self.process(request: request)
    }

    @available(*, renamed: "process()")
    func process(request: URLRequest, handler: ((Result<Data?, Error>) -> Void)? = nil) {
        Task {
            do {
                let result = try await process(request: request)
                handler?(.success(result))
            } catch {
                handler?(.failure(error))
            }
        }
    }

    func process(request: URLRequest) async throws -> Data? {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("PV | statusCode should be 2xx, but is \(httpResponse.statusCode)")
            print("PV | response = \(httpResponse)")
            throw URLError(.badServerResponse)
        }

        return data
    }

    func process<T: Decodable>(request: URLRequest) async throws -> T {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let data = try await self.process(request: request)
        if let data {
            return try decoder.decode(T.self, from: data)
        } else {
            throw URLError(.badServerResponse)
        }
    }

    func request(
        path: String,
        method: String,
        headers: [String: String?] = [:],
        object: Encodable? = nil
    ) -> URLRequest {
        let url = URL(string: "\(config.urlEndpoint)/api/client/\(path)")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }
        request.httpMethod = method
        if let object = object {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .formatted(DateFormatter.jsonDateFormat)
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try? encoder.encode(object)
        }
        return request
    }
}
