import Foundation

struct Question: Identifiable, Codable, Hashable {
    struct Option: Identifiable, Codable, Hashable {
        let id: UUID
        let text: LocalizedField
        let isCorrect: Bool

        init(id: UUID = UUID(), text: LocalizedField, isCorrect: Bool) {
            self.id = id
            self.text = text
            self.isCorrect = isCorrect
        }
    }

    struct Explanation: Codable, Hashable {
        let headline: String
        let body: String
        let tips: [String]
    }

    enum Media: Codable, Hashable {
        case none
        case image(URL)
        case video(URL)
    }

    let id: UUID
    let catalogID: String
    let chapter: String
    let points: Int
    let localizedStem: LocalizedField
    let options: [Option]
    let explanation: Explanation
    let media: Media
    let metadata: QuestionMetadata

    init(id: UUID = UUID(),
         catalogID: String,
         chapter: String,
         points: Int,
         localizedStem: LocalizedField,
         options: [Option],
         explanation: Explanation,
         media: Media = .none,
         metadata: QuestionMetadata) {
        self.id = id
        self.catalogID = catalogID
        self.chapter = chapter
        self.points = points
        self.localizedStem = localizedStem
        self.options = options
        self.explanation = explanation
        self.media = media
        self.metadata = metadata
    }
}

struct LocalizedField: Codable, Hashable {
    let de: String
    let en: String
    let zhHans: String

    init(de: String, en: String, zhHans: String) {
        self.de = de
        self.en = en
        self.zhHans = zhHans
    }

    func text(for locale: AppLocale) -> String {
        switch locale {
        case .german: return de
        case .english: return en
        case .simplifiedChinese: return zhHans
        }
    }

    func text(for language: QuestionLanguage) -> String {
        switch language {
        case .german: return de
        case .english: return en
        }
    }
}

struct QuestionPayload: Decodable {
    struct LocalizedFieldPayload: Decodable {
        let de: String
        let en: String
        let zhHans: String

        func toField() -> LocalizedField {
            LocalizedField(de: de, en: en, zhHans: zhHans)
        }
    }

    struct OptionPayload: Decodable {
        let text: LocalizedFieldPayload
        let isCorrect: Bool
    }

    struct ExplanationPayload: Decodable {
        let headline: String
        let body: String
        let tips: [String]
    }

    struct MetadataPayload: Decodable {
        let type: QuestionMetadata.QuestionType
        let difficulty: Int
        let tags: [String]
        let lastUpdated: String

        func toMetadata() -> QuestionMetadata {
            let formatter = ISO8601DateFormatter()
            let date = formatter.date(from: lastUpdated) ?? Date()
            return QuestionMetadata(type: type,
                                    difficulty: difficulty,
                                    tags: tags,
                                    lastUpdated: date)
        }
    }

    let id: String
    let chapter: String
    let points: Int
    let stem: LocalizedFieldPayload
    let options: [OptionPayload]
    let explanation: ExplanationPayload
    let metadata: MetadataPayload
}

extension Question {
    init(payload: QuestionPayload) {
        self.init(catalogID: payload.id,
                  chapter: payload.chapter,
                  points: payload.points,
                  localizedStem: payload.stem.toField(),
                  options: payload.options.map { option in
                      Option(text: option.text.toField(), isCorrect: option.isCorrect)
                  },
                  explanation: Explanation(headline: payload.explanation.headline,
                                           body: payload.explanation.body,
                                           tips: payload.explanation.tips),
                  metadata: payload.metadata.toMetadata())
    }
}

enum AppLocale: String, CaseIterable, Codable {
    case german
    case english
    case simplifiedChinese
}

struct QuestionMetadata: Codable, Hashable {
    enum QuestionType: String, Codable {
        case singleChoice
        case multipleChoice
        case numeric
        case media
    }

    let type: QuestionType
    let difficulty: Int
    let tags: [String]
    let lastUpdated: Date
}

enum QuestionLanguage: String, CaseIterable, Codable {
    case german
    case english

    var appLocale: AppLocale {
        switch self {
        case .german: return .german
        case .english: return .english
        }
    }

    var displayName: String {
        switch self {
        case .german: return "Deutsch"
        case .english: return "English"
        }
    }
}
