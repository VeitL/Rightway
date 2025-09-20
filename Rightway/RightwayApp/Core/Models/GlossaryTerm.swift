import Foundation

enum GlossaryCategory: String, Codable, Hashable, CaseIterable {
    case terminology
    case maneuver
    case regulation

    var displayName: String {
        switch self {
        case .terminology: return "术语"
        case .maneuver: return "驾驶动作"
        case .regulation: return "法规"
        }
    }
}

struct GlossaryTerm: Identifiable, Codable, Hashable {
    let id: UUID
    let term: String
    let category: GlossaryCategory
    let zhDefinition: String
    let examples: [String]
    let relatedQuestionIDs: [String]

    init(id: UUID = UUID(),
         term: String,
         category: GlossaryCategory = .terminology,
         zhDefinition: String,
         examples: [String] = [],
         relatedQuestionIDs: [String] = []) {
        self.id = id
        self.term = term
        self.category = category
        self.zhDefinition = zhDefinition
        self.examples = examples
        self.relatedQuestionIDs = relatedQuestionIDs
    }

    func matches(keyword: String) -> Bool {
        let lower = keyword.lowercased()
        return term.lowercased().contains(lower) || zhDefinition.lowercased().contains(lower)
    }
}
