import XCTest
@testable import RightwayApp

final class SRSEngineTests: XCTestCase {
    func testReviewProducesIncreasingIntervalForEasyAnswer() {
        let engine = SRSEngine()
        let card = engine.newCard(for: UUID())
        let result = SRSEngine.ReviewResult(confidence: .easy, responseTime: 10, isCorrect: true)

        let updated = engine.review(result: result, card: card, now: Date(timeIntervalSince1970: 0))

        XCTAssertGreaterThan(updated.interval, card.interval)
        XCTAssertEqual(updated.streak, 1)
    }
}
