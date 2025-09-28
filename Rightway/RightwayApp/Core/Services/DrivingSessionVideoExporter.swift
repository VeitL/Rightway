import Foundation
#if os(iOS)
import AVFoundation
import UIKit
import MapKit
#endif

struct DrivingSessionVideoExportOptions {
    var includeAudio: Bool
    var canvasSize: CGSize
    var framesPerSecond: Int

    static let standard = DrivingSessionVideoExportOptions(includeAudio: true,
                                                           canvasSize: CGSize(width: 1080, height: 1920),
                                                           framesPerSecond: 30)
}

enum DrivingSessionVideoExportError: Error {
    case unsupportedPlatform
    case missingRouteData
    case failedToCreateWriter
    case audioFileMissing
    case exportCancelled
    case compositionFailure
}

#if os(iOS)
final class DrivingSessionVideoExporter {
    private let fileManager = FileManager.default

    fileprivate struct MapSnapshotData {
        let image: UIImage
        let points: [CGPoint]
    }

    func export(session: DrivingSession,
                options: DrivingSessionVideoExportOptions = .standard,
                progressHandler: ((Double) -> Void)? = nil) async throws -> URL {
        guard !session.routeSamples.isEmpty else {
            throw DrivingSessionVideoExportError.missingRouteData
        }
        let writerURL = try makeOutputURL(prefix: "session-video")
        let duration = max(session.duration, 1)
        let snapshot = await makeMapSnapshot(for: session,
                                             size: options.canvasSize)
        let renderer = RouteRenderer(session: session,
                                     canvasSize: options.canvasSize,
                                     snapshot: snapshot)
        let fps = max(options.framesPerSecond, 24)
        let totalFrames = max(Int(duration * Double(fps)), fps)

        let writer = try makeWriter(outputURL: writerURL,
                                    size: options.canvasSize)
        guard let adaptor = makeAdaptor(for: writer, size: options.canvasSize) else {
            throw DrivingSessionVideoExportError.failedToCreateWriter
        }

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        var currentPresentationTime = CMTime.zero

        for frameIndex in 0..<totalFrames {
            autoreleasepool {
                while !adaptor.assetWriterInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.002)
                }
                let progress = Double(frameIndex) / Double(totalFrames)
                let frameTime = min(Double(frameIndex) / Double(fps), duration)
                do {
                    if let buffer = renderer.makePixelBuffer(at: frameTime,
                                                             pixelBufferPool: adaptor.pixelBufferPool) {
                        adaptor.append(buffer, withPresentationTime: currentPresentationTime)
                    }
                }
                currentPresentationTime = currentPresentationTime + frameDuration
                progressHandler?(progress * (options.includeAudio ? 0.5 : 0.95))
            }
        }

        adaptor.assetWriterInput.markAsFinished()
        try await finishWriting(writer)

        var finalURL = writerURL

        if options.includeAudio, let audioURL = session.audio.fileURL {
            if fileManager.fileExists(atPath: audioURL.path) {
                progressHandler?(0.6)
                finalURL = try await mergeVideo(writerURL, withAudioAt: audioURL)
                progressHandler?(0.95)
            } else {
                throw DrivingSessionVideoExportError.audioFileMissing
            }
        }

        progressHandler?(1.0)
        return finalURL
    }

    private func makeMapSnapshot(for session: DrivingSession,
                                 size: CGSize) async -> MapSnapshotData? {
        let coordinates = session.routeSamples.map { CLLocationCoordinate2D(latitude: $0.latitude,
                                                                            longitude: $0.longitude) }
        guard !coordinates.isEmpty else { return nil }

        let options = MKMapSnapshotter.Options()
        options.size = size
        options.mapType = .mutedStandard
        options.region = makeSnapshotRegion(for: coordinates)
        options.showsBuildings = true
        options.pointOfInterestFilter = .excludingAll
        options.showsPointsOfInterest = false
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)

        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snapshot = try await snapshotter.start()
            let imageRect = CGRect(origin: .zero, size: size)
            let points = coordinates.map { coordinate -> CGPoint in
                let point = snapshot.point(for: coordinate)
                return CGPoint(x: min(max(point.x, imageRect.minX), imageRect.maxX),
                               y: min(max(point.y, imageRect.minY), imageRect.maxY))
            }
            return MapSnapshotData(image: snapshot.image, points: points)
        } catch {
            NSLog("DrivingSessionVideoExporter snapshot failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func makeSnapshotRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                      span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        let minLat = latitudes.min() ?? first.latitude
        let maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude
        let maxLon = longitudes.max() ?? first.longitude

        let paddingFactor: Double = 1.3
        let minimumSpan: Double = 0.002

        let latitudeDelta = max((maxLat - minLat) * paddingFactor, minimumSpan)
        let longitudeDelta = max((maxLon - minLon) * paddingFactor, minimumSpan)

        let center = CLLocationCoordinate2D(latitude: (maxLat + minLat) / 2,
                                            longitude: (maxLon + minLon) / 2)

        return MKCoordinateRegion(center: center,
                                  span: MKCoordinateSpan(latitudeDelta: latitudeDelta,
                                                          longitudeDelta: longitudeDelta))
    }

    private func makeOutputURL(prefix: String) throws -> URL {
        let documents = try fileManager.url(for: .documentDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true)
        let directory = documents.appendingPathComponent("PracticeExports", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(prefix)-\(UUID().uuidString).mp4"
        let url = directory.appendingPathComponent(name)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        return url
    }

    private func makeWriter(outputURL: URL, size: CGSize) throws -> AVAssetWriter {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else {
            throw DrivingSessionVideoExportError.failedToCreateWriter
        }
        writer.add(input)
        return writer
    }

    private func makeAdaptor(for writer: AVAssetWriter, size: CGSize) -> AVAssetWriterInputPixelBufferAdaptor? {
        guard let input = writer.inputs.first(where: { $0.mediaType == .video }) else { return nil }
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        return AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
                                                    sourcePixelBufferAttributes: attributes)
    }

    private func mergeVideo(_ videoURL: URL, withAudioAt audioURL: URL) async throws -> URL {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: videoURL)
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            throw DrivingSessionVideoExportError.compositionFailure
        }

        let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video,
                                                                preferredTrackID: kCMPersistentTrackID_Invalid)
        try videoCompositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration),
                                                  of: videoTrack,
                                                  at: .zero)

        let audioAsset = AVURLAsset(url: audioURL)
        if let audioTrack = audioAsset.tracks(withMediaType: .audio).first {
            let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio,
                                                                    preferredTrackID: kCMPersistentTrackID_Invalid)
            let duration = min(videoAsset.duration, audioAsset.duration)
            try audioCompositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration),
                                                       of: audioTrack,
                                                       at: .zero)
        }

        let exportURL = try makeOutputURL(prefix: "session-video")
        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        exporter?.outputURL = exportURL
        exporter?.outputFileType = .mp4
        exporter?.shouldOptimizeForNetworkUse = true

        guard let exportSession = exporter else {
            throw DrivingSessionVideoExportError.compositionFailure
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? DrivingSessionVideoExportError.compositionFailure)
                case .cancelled:
                    continuation.resume(throwing: DrivingSessionVideoExportError.exportCancelled)
                default:
                    break
                }
            }
        }

        try? fileManager.removeItem(at: videoURL)
        return exportURL
    }
}

private final class RouteRenderer {
    private let session: DrivingSession
    private let size: CGSize
    private let timelineDuration: TimeInterval
    private let points: [CGPoint]
    private let offsets: [TimeInterval]
    private let backgroundImage: UIImage?

    init(session: DrivingSession,
         canvasSize: CGSize,
         snapshot: DrivingSessionVideoExporter.MapSnapshotData?) {
        self.session = session
        self.size = canvasSize
        self.timelineDuration = max(session.duration, 1)
        let geometry = RouteRenderer.computeGeometry(for: session.routeSamples, canvas: canvasSize)
        self.offsets = geometry.offsets
        if let snapshot {
            self.points = snapshot.points
            self.backgroundImage = snapshot.image
        } else {
            self.points = geometry.points
            self.backgroundImage = nil
        }
    }

    func makePixelBuffer(at time: TimeInterval, pixelBufferPool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let pool = pixelBufferPool else { return nil }
        let normalizedTime = max(0, min(time, timelineDuration))
        guard let cgImage = drawFrame(at: normalizedTime) else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    private func drawFrame(at time: TimeInterval) -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            drawBackground(context: context.cgContext)

            guard !points.isEmpty else {
                drawHUD(context: context.cgContext, time: time)
                drawTranscript(context: context.cgContext, time: time)
                return
            }

            let currentIndex = RouteRenderer.currentSampleIndex(for: time,
                                                                offsets: offsets)

            if points.count > 1 {
                drawRoute(context: context.cgContext,
                          upTo: currentIndex)
                drawCursor(context: context.cgContext,
                           at: points[min(currentIndex, points.count - 1)])
            } else if let point = points.first {
                drawCursor(context: context.cgContext, at: point)
            }
            drawHUD(context: context.cgContext,
                    time: time)
            drawTranscript(context: context.cgContext,
                           time: time)
        }
        return image.cgImage
    }

    private func drawBackground(context: CGContext) {
        if let backgroundImage {
            backgroundImage.draw(in: CGRect(origin: .zero, size: size))
        } else {
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func drawRoute(context: CGContext, upTo index: Int) {
        guard points.count > 1 else { return }
        context.saveGState()
        context.setLineWidth(6)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.setStrokeColor(UIColor.systemGray4.withAlphaComponent(0.6).cgColor)
        context.addLines(between: points)
        context.strokePath()

        if index > 0 {
            context.setStrokeColor(UIColor.systemBlue.cgColor)
            let highlighted = Array(points.prefix(index + 1))
            context.addLines(between: highlighted)
            context.strokePath()
        }

        context.restoreGState()
    }

    private func drawCursor(context: CGContext, at point: CGPoint) {
        context.saveGState()
        let radius: CGFloat = 12
        let rect = CGRect(x: point.x - radius,
                          y: point.y - radius,
                          width: radius * 2,
                          height: radius * 2)
        context.setFillColor(UIColor.systemOrange.cgColor)
        context.fillEllipse(in: rect)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: rect)
        context.restoreGState()
    }

    private func drawHUD(context: CGContext, time: TimeInterval) {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = time >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        let text = formatter.string(from: time) ?? "00:00"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 42, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let rect = CGRect(x: 32,
                          y: 48,
                          width: textSize.width,
                          height: textSize.height)
        let backgroundRect = rect.insetBy(dx: -14, dy: -10)
        let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 14)
        UIColor.black.withAlphaComponent(0.35).setFill()
        path.fill()
        attributed.draw(in: rect)
    }

    private func drawTranscript(context: CGContext, time: TimeInterval) {
        guard let snippet = session.transcriptSnippet(around: time, window: 6)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !snippet.isEmpty else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]

        let maxWidth = size.width - 128
        let attributed = NSAttributedString(string: snippet, attributes: attributes)
        let bounding = attributed.boundingRect(with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude),
                                               options: [.usesLineFragmentOrigin, .usesFontLeading],
                                               context: nil)
        let textSize = CGSize(width: ceil(bounding.width), height: ceil(bounding.height))
        let originX = max((size.width - textSize.width) / 2, 32)
        let originY = size.height - textSize.height - 96
        let rect = CGRect(origin: CGPoint(x: originX, y: originY), size: textSize)
        let backgroundRect = rect.insetBy(dx: -24, dy: -18)
        let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 22)
        UIColor.black.withAlphaComponent(0.4).setFill()
        path.fill()
        attributed.draw(in: rect)
    }

    private static func computeGeometry(for samples: [DrivingSession.RouteSample],
                                        canvas: CGSize) -> (points: [CGPoint], offsets: [TimeInterval]) {
        guard let first = samples.first else { return ([], []) }
        let minLat = samples.map(\.latitude).min() ?? first.latitude
        let maxLat = samples.map(\.latitude).max() ?? first.latitude
        let minLon = samples.map(\.longitude).min() ?? first.longitude
        let maxLon = samples.map(\.longitude).max() ?? first.longitude

        let margin: CGFloat = 60
        let drawableWidth = max(canvas.width - margin * 2, 10)
        let drawableHeight = max(canvas.height - margin * 2, 10)
        let latDelta = max(maxLat - minLat, 0.0001)
        let lonDelta = max(maxLon - minLon, 0.0001)

        let start = samples.first?.timestamp ?? Date()

        let points = samples.map { sample -> CGPoint in
            let normalizedX = (sample.longitude - minLon) / lonDelta
            let normalizedY = (sample.latitude - minLat) / latDelta
            let x = margin + CGFloat(normalizedX) * drawableWidth
            let y = margin + (1 - CGFloat(normalizedY)) * drawableHeight
            return CGPoint(x: x, y: y)
        }

        let offsets = samples.map { sample in
            sample.timestamp.timeIntervalSince(start)
        }
        return (points, offsets)
    }

    private static func currentSampleIndex(for time: TimeInterval, offsets: [TimeInterval]) -> Int {
        guard !offsets.isEmpty else { return 0 }
        var index = 0
        for candidate in offsets.enumerated() {
            if candidate.element <= time {
                index = candidate.offset
            } else {
                break
            }
        }
        return index
    }
}

private func finishWriting(_ writer: AVAssetWriter) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        writer.finishWriting {
            if let error = writer.error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }
}
#else
final class DrivingSessionVideoExporter {
    func export(session: DrivingSession,
                options: DrivingSessionVideoExportOptions = .standard,
                progressHandler: ((Double) -> Void)? = nil) async throws -> URL {
        throw DrivingSessionVideoExportError.unsupportedPlatform
    }
}
#endif
