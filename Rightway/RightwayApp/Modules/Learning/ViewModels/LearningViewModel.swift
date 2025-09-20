import Combine
import Foundation

@MainActor
final class LearningViewModel: ObservableObject {
    @Published private(set) var queue: [Question]
    @Published var activeQuestion: Question?
    @Published var showChineseTranslation: Bool
    @Published var baseLanguage: QuestionLanguage
    @Published var isPresentingNoteComposer: Bool = false

    private let questionStore: QuestionStore
    private let notesStore: NotesStore
    private let srsEngine: SRSEngine
    private let preferences: UserPreferencesStore

    private var cancellables = Set<AnyCancellable>()

    init(questionStore: QuestionStore,
         notesStore: NotesStore,
         srsEngine: SRSEngine,
         preferences: UserPreferencesStore) {
        self.questionStore = questionStore
        self.notesStore = notesStore
        self.srsEngine = srsEngine
        self.preferences = preferences
        self.queue = questionStore.questions
        self.baseLanguage = preferences.learningBaseLanguage
        self.showChineseTranslation = preferences.showChineseTranslation && FeatureFlags.enableChineseLearningLayer
        self.activeQuestion = queue.first

        questionStore.$wrongQuestionIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        questionStore.$favoriteQuestionIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func toggleChineseTranslation() {
        guard FeatureFlags.enableChineseLearningLayer else { return }
        showChineseTranslation.toggle()
        preferences.showChineseTranslation = showChineseTranslation
    }

    func setChineseTranslation(enabled: Bool) {
        guard FeatureFlags.enableChineseLearningLayer else {
            showChineseTranslation = false
            preferences.showChineseTranslation = false
            return
        }
        guard showChineseTranslation != enabled else { return }
        showChineseTranslation = enabled
        preferences.showChineseTranslation = enabled
    }

    func select(baseLanguage: QuestionLanguage) {
        self.baseLanguage = baseLanguage
        preferences.learningBaseLanguage = baseLanguage
    }

    func mark(_ question: Question, confidence: SRSEngine.Confidence) {
        guard let active = activeQuestion else { return }
        let result = SRSEngine.ReviewResult(confidence: confidence,
                                            responseTime: 15,
                                            isCorrect: confidence != .again)
        _ = srsEngine.review(result: result, card: srsEngine.newCard(for: active.id))
        questionStore.registerAnswer(for: question, confidence: confidence)
        advance()
    }

    func advance() {
        guard !queue.isEmpty else {
            activeQuestion = nil
            return
        }
        let rotated = Array(queue.dropFirst()) + Array(queue.prefix(1))
        queue = rotated
        activeQuestion = queue.first
    }

    func startBlindSpotSession() {
        let blindSpots = questionStore.wrongQuestions()
        guard !blindSpots.isEmpty else { return }
        queue = blindSpots
        activeQuestion = queue.first
    }

    func toggleFavorite() {
        guard let question = activeQuestion else { return }
        questionStore.toggleFavorite(for: question)
    }

    func isFavorite(_ question: Question) -> Bool {
        questionStore.favoriteQuestionIDs.contains(question.id)
    }

    func isBlindSpot(_ question: Question) -> Bool {
        questionStore.wrongQuestionIDs.contains(question.id)
    }

    func createNote(body: String, attachments: [NoteAttachment]) {
        guard let question = activeQuestion else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && attachments.isEmpty { return }
        let note = UserNote(category: .study,
                            body: trimmed,
                            questionID: question.id,
                            attachments: attachments)
        notesStore.add(note: note)
    }

    var blindSpotQuestions: [Question] {
        questionStore.wrongQuestions()
    }
}
