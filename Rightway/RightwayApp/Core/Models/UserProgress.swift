import Foundation

struct UserProgress: Codable, Hashable {
    struct ChapterProgress: Codable, Hashable {
        let chapter: String
        let correctRate: Double
        let averageTime: TimeInterval
    }

    struct ExamSummary: Codable, Hashable {
        let recentAttempts: Int
        let passRate: Double
        let predictedScore: Double
    }

    let lastSyncedAt: Date
    let totalQuestionsSeen: Int
    let totalCorrect: Int
    let srsDueToday: Int
    let chapterStats: [ChapterProgress]
    let examSummary: ExamSummary
}

final class ProgressStore: ObservableObject {
    @Published private(set) var progress: UserProgress = .placeholder

    func apply(progress: UserProgress) {
        self.progress = progress
    }
}

extension UserProgress {
    static let placeholder = UserProgress(lastSyncedAt: .init(),
                                          totalQuestionsSeen: 24,
                                          totalCorrect: 19,
                                          srsDueToday: 12,
                                          chapterStats: [
                                              .init(chapter: "Verkehrszeichen", correctRate: 0.78, averageTime: 21),
                                              .init(chapter: "Gefahrenlehre", correctRate: 0.72, averageTime: 19)
                                          ],
                                          examSummary: .init(recentAttempts: 2,
                                                             passRate: 0.5,
                                                             predictedScore: 78))
}
