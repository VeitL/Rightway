import Foundation

protocol AudioRecordingService {
    var isRecordingSupported: Bool { get }
    func requestPermission() async -> Bool
    func startRecording() throws -> URL
    func stopRecording() -> URL?
    func cancelRecording()
}

#if canImport(AVFoundation) && !os(macOS)
import AVFoundation

final class AVAudioRecorderService: NSObject, AudioRecordingService {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    var isRecordingSupported: Bool { true }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: [])

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("driving_practice_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        recorder.record()
        self.recorder = recorder
        self.recordingURL = url
        return url
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        return recordingURL
    }

    func cancelRecording() {
        recorder?.stop()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recorder = nil
        recordingURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
#else
final class StubAudioRecorderService: AudioRecordingService {
    var isRecordingSupported: Bool { false }
    func requestPermission() async -> Bool { false }
    func startRecording() throws -> URL { throw NSError(domain: "Audio", code: -1) }
    func stopRecording() -> URL? { nil }
    func cancelRecording() {}
}
#endif
