import Foundation

struct Sign: Identifiable, Codable, Hashable {
    enum Category: String, CaseIterable, Codable {
        case warning
        case regulatory
        case priority
        case information
        case supplementary
    }

    let id: UUID
    let catalogNumber: String
    let title: LocalizedField
    let summary: String
    let category: Category
    let svgAssetName: String
    let relatedQuestions: [String]

    init(id: UUID = UUID(),
         catalogNumber: String,
         title: LocalizedField,
         summary: String,
         category: Category,
         svgAssetName: String,
         relatedQuestions: [String]) {
        self.id = id
        self.catalogNumber = catalogNumber
        self.title = title
        self.summary = summary
        self.category = category
        self.svgAssetName = svgAssetName
        self.relatedQuestions = relatedQuestions
    }
}
