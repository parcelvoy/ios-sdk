import Foundation

class NetworkManager {
    var urlSession = URLSession.shared

    private let config: Config
    init(config: Config) {
        self.config = config
    }

    func get<T: Decodable> (path: String, user: Alias, handler: @escaping (Result<T, Error>) -> Void) {
        let headers = [
            "x-anonymous-id": user.anonymousId,
            "x-external-id": user.externalId
        ]
        let request = self.request(path: path, method: "GET", headers: headers)

        self.process(request: request, handler: handler)
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

    func post<T: Decodable>(path: String, object: Encodable, handler: @escaping (Result<T, Error>) -> Void) {
        let request = self.request(path: path, method: "POST", object: object)
        self.process(request: request, handler: handler)
    }

    func put(path: String, object: Encodable) {
        let request = self.request(path: path, method: "PUT", object: object)
        self.process(request: request)
    }

    func process(request: URLRequest, handler: ((Result<Data?, Error>) -> Void)? = nil) {
        URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            DispatchQueue.main.async {
                guard let response = response as? HTTPURLResponse, error == nil else {
                    handler?(.failure(error ?? URLError(.badServerResponse)))
                    return
                }

                guard (200 ... 299) ~= response.statusCode else {
                    print("PV | statusCode should be 2xx, but is \(response.statusCode)")
                    print("PV | response = \(response)")
                    return
                }

                handler?(.success(data))
            }
        }.resume()
    }

    func process<T: Decodable>(request: URLRequest, handler: ((Result<T, Error>) -> Void)? = nil) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.process(request: request) { (result: Result<Data?, Error>) in
            switch result {
            case .failure(let error): handler?(.failure(error))
            case .success(let data):
                if let data {
                    do {
                        let days = try decoder.decode(T.self, from: data)
                        handler?(.success(days))
                    } catch {
                        handler?(.failure(error))
                    }
                } else {
                    handler?(.failure(URLError(.badServerResponse)))
                }
            }
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
