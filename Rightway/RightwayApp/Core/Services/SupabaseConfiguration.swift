import Foundation

struct SupabaseConfiguration {
    let baseURL: URL?
    let anonKey: String?
    let questionEndpointPath: String
    let fallbackQuestionFilename: String

    static let current: SupabaseConfiguration = {
        let env = ProcessInfo.processInfo.environment
        let urlString = env["SUPABASE_URL"]
        let key = env["SUPABASE_ANON_KEY"]
        let baseURL = urlString.flatMap(URL.init(string:))
        return SupabaseConfiguration(baseURL: baseURL,
                                     anonKey: key,
                                     questionEndpointPath: "/rest/v1/questions",
                                     fallbackQuestionFilename: "questions_authorized")
    }()
}
