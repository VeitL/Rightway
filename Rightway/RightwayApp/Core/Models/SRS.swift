import Foundation

struct SRSCard: Identifiable, Codable, Hashable {
    let id: UUID
    let questionID: UUID
    let dueDate: Date
    let interval: Int
    let easeFactor: Double
    let streak: Int

    init(id: UUID = UUID(), questionID: UUID, dueDate: Date, interval: Int, easeFactor: Double, streak: Int) {
        self.id = id
        self.questionID = questionID
        self.dueDate = dueDate
        self.interval = interval
        self.easeFactor = easeFactor
        self.streak = streak
    }
}

final class SRSEngine {
    func review(result: ReviewResult, card: SRSCard, now: Date = .init()) -> SRSCard {
        var ease = max(1.3, card.easeFactor + result.easeDelta)
        let interval = max(1, Int(Double(card.interval) * ease * result.intervalMultiplier))
        let streak = result.isCorrect ? card.streak + 1 : 0
        let due = Calendar.current.date(byAdding: .day, value: interval, to: now) ?? now
        return SRSCard(id: card.id,
                       questionID: card.questionID,
                       dueDate: due,
                       interval: interval,
                       easeFactor: ease,
                       streak: streak)
    }

    func newCard(for questionID: UUID, now: Date = .init()) -> SRSCard {
        SRSCard(questionID: questionID, dueDate: now, interval: 1, easeFactor: 2.5, streak: 0)
    }

    struct ReviewResult {
        let confidence: Confidence
        let responseTime: TimeInterval
        let isCorrect: Bool

        var easeDelta: Double {
            switch confidence {
            case .again: return -0.3
            case .hard: return -0.15
            case .good: return 0
            case .easy: return 0.15
            }
        }

        var intervalMultiplier: Double {
            switch confidence {
            case .again: return 0.5
            case .hard: return 0.8
            case .good: return 1.0
            case .easy: return 1.3
            }
        }
    }

    enum Confidence: String, CaseIterable {
        case again, hard, good, easy
    }
}
