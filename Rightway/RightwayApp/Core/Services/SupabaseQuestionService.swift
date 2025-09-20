import Foundation

final class SupabaseQuestionService {
    private let configuration: SupabaseConfiguration

    init(configuration: SupabaseConfiguration = .current) {
        self.configuration = configuration
    }

    func loadAuthorizedQuestionSet() async throws -> [Question] {
        if let remote = try await fetchFromRemote() {
            return remote
        }
        return try loadFromBundle()
    }

    private func fetchFromRemote() async throws -> [Question]? {
        guard let baseURL = configuration.baseURL else { return nil }
        guard var components = URLComponents(url: baseURL.appendingPathComponent(configuration.questionEndpointPath), resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "select", value: "*")]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        supabaseHeaders().forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            return try decodeQuestion(data: data)
        } catch {
            return nil
        }
    }

    private func loadFromBundle() throws -> [Question] {
        guard let url = Bundle.main.url(forResource: configuration.fallbackQuestionFilename, withExtension: "json") else {
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Data/\(configuration.fallbackQuestionFilename).json")
            let data = try Data(contentsOf: root)
            return try decodeQuestion(data: data)
        }
        let data = try Data(contentsOf: url)
        return try decodeQuestion(data: data)
    }

    private func decodeQuestion(data: Data) throws -> [Question] {
        let response = try JSONDecoder().decode(SupabaseQuestionResponse.self, from: data)
        return response.questions.map(Question.init(payload:))
    }

    private func supabaseHeaders() -> [String: String] {
        guard let key = configuration.anonKey else { return [:] }
        return [
            "apikey": key,
            "Authorization": "Bearer \(key)"
        ]
    }

    private struct SupabaseQuestionResponse: Decodable {
        let questions: [QuestionPayload]
    }
}
