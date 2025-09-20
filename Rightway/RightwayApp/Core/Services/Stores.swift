import Combine
import Foundation

final class QuestionStore: ObservableObject {
    @Published private(set) var questions: [Question] = SampleData.questions
    @Published private(set) var favoriteQuestionIDs: Set<UUID> = []
    @Published private(set) var wrongQuestionIDs: Set<UUID> = []

    func apply(snapshot: [Question]) {
        questions = snapshot
    }

    func toggleFavorite(for question: Question) {
        if favoriteQuestionIDs.contains(question.id) {
            favoriteQuestionIDs.remove(question.id)
        } else {
            favoriteQuestionIDs.insert(question.id)
        }
    }

    func registerAnswer(for question: Question, confidence: SRSEngine.Confidence) {
        if confidence == .again {
            wrongQuestionIDs.insert(question.id)
        } else {
            wrongQuestionIDs.remove(question.id)
        }
    }

    func favoriteQuestions() -> [Question] {
        questions.filter { favoriteQuestionIDs.contains($0.id) }
    }

    func wrongQuestions() -> [Question] {
        questions.filter { wrongQuestionIDs.contains($0.id) }
    }
}

final class SignStore: ObservableObject {
    @Published private(set) var signs: [Sign] = SampleData.signs

    func apply(signs: [Sign]) {
        self.signs = signs
    }
}

final class NotesStore: ObservableObject {
    @Published private(set) var notes: [UserNote] = []

    func apply(notes: [UserNote]) {
        self.notes = notes
    }

    func add(note: UserNote) {
        notes.append(note)
    }

    func notes(for category: NoteCategory) -> [UserNote] {
        notes.filter { $0.category == category }
    }
}

final class DrivingSessionStore: ObservableObject {
    @Published private(set) var sessions: [DrivingSession] = []
    @Published private(set) var activeSession: DrivingSession?

    func startSession(routeTracking: Bool, recordAudio: Bool) {
        guard activeSession == nil else { return }
        let nextIndex = sessions.count + 1
        activeSession = DrivingSession(sequenceNumber: nextIndex,
                                       audio: .init(isEnabled: recordAudio, fileURL: nil, startTimestamp: nil),
                                       routeTrackingEnabled: routeTracking)
    }

    func appendRouteSample(_ sample: DrivingSession.RouteSample) {
        guard var session = activeSession, session.routeTrackingEnabled else { return }
        session.routeSamples.append(sample)
        activeSession = session
    }

    func updateAudioFileURL(_ url: URL?) {
        guard var session = activeSession else { return }
        session.audio.fileURL = url
        activeSession = session
    }

    func markAudioRecordingStarted(at timestamp: Date) {
        guard var session = activeSession else { return }
        session.audio.startTimestamp = timestamp
        activeSession = session
    }

    func markActiveSessionEnded() {
        guard var session = activeSession else { return }
        session.endedAt = Date()
        activeSession = session
    }

    func finishSession(amountPaid: Decimal?, noteID: UUID?, audioURL: URL?) -> DrivingSession? {
        guard var session = activeSession else { return nil }
        session.amountPaid = amountPaid
        session.noteID = noteID
        if session.audio.isEnabled {
            session.audio.fileURL = audioURL
            session.audioWaypoints = buildAudioWaypoints(for: session)
        }
        sessions.append(session)
        activeSession = nil
        return session
    }

    func session(with id: UUID) -> DrivingSession? {
        sessions.first { $0.id == id }
    }

    private func buildAudioWaypoints(for session: DrivingSession) -> [DrivingSession.AudioWaypoint] {
        guard session.audio.isEnabled,
              let start = session.audio.startTimestamp else { return [] }
        let samples = session.routeSamples.sorted { $0.timestamp < $1.timestamp }
        guard !samples.isEmpty else { return [] }

        var waypoints: [DrivingSession.AudioWaypoint] = []
        var lastAddedOffset: TimeInterval = -.infinity

        for sample in samples where sample.timestamp >= start {
            let offset = sample.timestamp.timeIntervalSince(start)
            if offset < 0 { continue }
            if offset - lastAddedOffset < 30 && !waypoints.isEmpty {
                continue
            }
            let waypoint = DrivingSession.AudioWaypoint(timestamp: sample.timestamp,
                                                         timeOffset: offset,
                                                         latitude: sample.latitude,
                                                         longitude: sample.longitude)
            waypoints.append(waypoint)
            lastAddedOffset = offset
        }

        if let lastSample = samples.last {
            let finalOffset = max(0, lastSample.timestamp.timeIntervalSince(start))
            if finalOffset - lastAddedOffset > 10 {
                let waypoint = DrivingSession.AudioWaypoint(timestamp: lastSample.timestamp,
                                                             timeOffset: finalOffset,
                                                             latitude: lastSample.latitude,
                                                             longitude: lastSample.longitude)
                waypoints.append(waypoint)
            }
        }

        let maxCount = 20
        if waypoints.count > maxCount {
            let step = Double(waypoints.count - 1) / Double(maxCount - 1)
            return (0..<maxCount).compactMap { index in
                let sourceIndex = Int((Double(index) * step).rounded())
                return waypoints.indices.contains(sourceIndex) ? waypoints[sourceIndex] : nil
            }
        }

        return waypoints
    }
}

final class ExamStore: ObservableObject {
    @Published private(set) var blueprint: ExamBlueprint = .placeholder

    func apply(blueprint: ExamBlueprint) {
        self.blueprint = blueprint
    }
}

final class UserPreferencesStore: ObservableObject {
    @Published var learningBaseLanguage: QuestionLanguage = .german
    @Published var showChineseTranslation: Bool = true
    @Published var examLocale: AppLocale = .german
    @Published var enableVoiceOver: Bool = true
}

final class GlossaryStore: ObservableObject {
    @Published private(set) var terms: [GlossaryTerm] = SampleData.glossaryTerms

    func search(keyword: String) -> [GlossaryTerm] {
        guard !keyword.isEmpty else { return terms }
        return terms.filter { $0.matches(keyword: keyword) }
    }
}

struct SampleData {
    static let questions: [Question] = {
        let stem = LocalizedField(de: "Wie verhalten Sie sich?",
                                  en: "How do you react?",
                                  zhHans: "你应该如何应对？")
        let explanation = Question.Explanation(headline: "优先权判断",
                                               body: "观察路口标志，并按照优先权顺序行驶。",
                                               tips: ["留意三角形让行标志", "减速进入路口"])
        let options = [
            Question.Option(text: LocalizedField(de: "Ich fahre sofort.",
                                                 en: "Drive immediately.",
                                                 zhHans: "立即通行"), isCorrect: false),
            Question.Option(text: LocalizedField(de: "Ich gewähre Vorfahrt.",
                                                 en: "Yield the right of way.",
                                                 zhHans: "让出优先通行权"), isCorrect: true)
        ]
        return [Question(catalogID: "1.1.02-001",
                         chapter: "Vorfahrt",
                         points: 5,
                         localizedStem: stem,
                         options: options,
                         explanation: explanation,
                         metadata: .init(type: .singleChoice,
                                         difficulty: 2,
                                         tags: ["priority", "intersection"],
                                         lastUpdated: .init()))]
    }()

    static let signs: [Sign] = [
        Sign(catalogNumber: "205",
             title: LocalizedField(de: "Vorfahrt gewähren",
                                   en: "Yield",
                                   zhHans: "让行"),
             summary: "Vorfahrtsregel an Kreuzungen.",
             category: .priority,
             svgAssetName: "205_Vorfahrt_gewaehren",
             relatedQuestions: ["1.1.02-001"]),
        Sign(catalogNumber: "206",
             title: LocalizedField(de: "Halt! Vorfahrt gewähren",
                                   en: "Stop and yield",
                                   zhHans: "停车让行"),
             summary: "Anhalten an der Haltelinie Pflicht.",
             category: .priority,
             svgAssetName: "206_Halt_Vorfahrt",
             relatedQuestions: ["1.1.02-002"])
    ]

    static let glossaryTerms: [GlossaryTerm] = [
        GlossaryTerm(term: "Vorfahrt", zhDefinition: "优先通行权。表示某个方向的车辆拥有优先通过交叉口的权利。", examples: ["Du musst die Vorfahrt achten."], relatedQuestionIDs: ["1.1.02-001"]),
        GlossaryTerm(term: "Gefahrenbremsung", zhDefinition: "紧急制动。为了避免事故而进行的最大力度制动。", examples: ["Bei Gefahr sofort Gefahrenbremsung ausführen."], relatedQuestionIDs: [])
    ]
}

struct ExamBlueprint: Codable, Hashable {
    let durationMinutes: Int
    let passingScore: Int
    let questionCount: Int
    let languageCodes: [String]

    static let placeholder = ExamBlueprint(durationMinutes: 45,
                                           passingScore: 110,
                                           questionCount: 30,
                                           languageCodes: ["de", "en", "fr"])
}

enum NoteCategory: String, Codable, Hashable {
    case study
    case practice
}

struct NoteAttachment: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case image
        case sketch
        case audio
    }

    let id: UUID
    let kind: Kind
    let resourceURL: URL?

    init(id: UUID = UUID(), kind: Kind, resourceURL: URL? = nil) {
        self.id = id
        self.kind = kind
        self.resourceURL = resourceURL
    }
}

struct UserNote: Identifiable, Codable, Hashable {
    let id: UUID
    let category: NoteCategory
    let createdAt: Date
    let body: String
    let questionID: UUID?
    let practiceSessionID: UUID?
    let attachments: [NoteAttachment]

    init(id: UUID = UUID(),
         category: NoteCategory,
         createdAt: Date = .init(),
         body: String,
         questionID: UUID? = nil,
         practiceSessionID: UUID? = nil,
         attachments: [NoteAttachment] = []) {
        self.id = id
        self.category = category
        self.createdAt = createdAt
        self.body = body
        self.questionID = questionID
        self.practiceSessionID = practiceSessionID
        self.attachments = attachments
    }
}
