import Foundation

/// Feature flag definitions allow toggling experimental functionality while matching the PRD's learning/exam separation.
enum FeatureFlags {
    static var enableChineseLearningLayer: Bool { true }
    static var enableExamOfficialMode: Bool { true }
    static var enableOfflineMode: Bool { true }
}
