import Combine
import Foundation

protocol APIClient {
    func perform<T: Decodable>(_ request: APIRequest) -> AnyPublisher<T, Error>
}

struct APIRequest {
    enum Method: String { case get, post, put, delete }

    let path: String
    let method: Method
    let body: Data?
    let headers: [String: String]

    init(path: String, method: Method = .get, body: Data? = nil, headers: [String: String] = [:]) {
        self.path = path
        self.method = method
        self.body = body
        self.headers = headers
    }
}

final class RemoteAPIClient: APIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func perform<T>(_ request: APIRequest) -> AnyPublisher<T, Error> where T : Decodable {
        guard let url = URL(string: "https://api.rightway.local" + request.path) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue.uppercased()
        urlRequest.httpBody = request.body
        request.headers.forEach { urlRequest.addValue($0.value, forHTTPHeaderField: $0.key) }

        return session.dataTaskPublisher(for: urlRequest)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
