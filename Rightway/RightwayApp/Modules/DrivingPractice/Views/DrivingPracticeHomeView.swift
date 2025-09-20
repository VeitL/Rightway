import Combine
import SwiftUI
import Foundation
#if canImport(MapKit)
import MapKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if os(iOS)
import PhotosUI
#endif

private let distanceFormatter: MeasurementFormatter = {
    let formatter = MeasurementFormatter()
    formatter.unitOptions = .naturalScale
    formatter.numberFormatter.maximumFractionDigits = 2
    formatter.numberFormatter.minimumFractionDigits = 0
    formatter.unitStyle = .medium
    formatter.locale = Locale.current
    return formatter
}()

private func formatDistance(_ meters: Double) -> String {
    let measurement = Measurement(value: meters, unit: UnitLength.meters)
    return distanceFormatter.string(from: measurement)
}

struct DrivingPracticeHomeView: View {
    @StateObject var viewModel: DrivingPracticeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let active = viewModel.activeSession {
                        ActiveSessionCard(session: active,
                                          elapsed: viewModel.elapsedTime,
                                          stopAction: viewModel.stopSession)
                    } else {
                        StartSessionCard(wantsRouteTracking: $viewModel.wantsRouteTracking,
                                         wantsAudioRecording: $viewModel.wantsAudioRecording,
                                         startAction: viewModel.startSession,
                                         sessionCount: viewModel.totalSessionsCount,
                                         locationAvailable: viewModel.isLocationServiceAvailable,
                                         audioAvailable: viewModel.isAudioRecordingAvailable)
                    }

                    if !viewModel.sessions.isEmpty {
                        SessionHistoryList(sessions: viewModel.sessions,
                                           noteProvider: viewModel.note(for:))
                    }
                }
                .padding()
            }
            .navigationTitle("练车记录")
            .sheet(isPresented: $viewModel.showCompletionSheet, onDismiss: viewModel.cancelCompletion) {
                CompletionSheet(viewModel: viewModel)
            }
        }
    }
}

private struct ActiveSessionCard: View {
    let session: DrivingSession
    let elapsed: TimeInterval
    let stopAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("第\(session.sequenceNumber)次练车", systemImage: "steeringwheel")
                    .font(.headline)
                Spacer()
                Text(session.startedAt, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Text(elapsed.formattedElapsed)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("已计时")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label(session.routeTrackingEnabled ? "正在追踪路线" : "未追踪路线",
                      systemImage: session.routeTrackingEnabled ? "map" : "map.slash")
                    .foregroundStyle(session.routeTrackingEnabled ? .blue : .secondary)
                Label(session.audio.isEnabled ? "录音开启" : "录音关闭",
                      systemImage: session.audio.isEnabled ? "mic" : "mic.slash")
                    .foregroundStyle(session.audio.isEnabled ? .red : .secondary)
            }
            .font(.subheadline)

            Button(role: .destructive, action: stopAction) {
                Label("结束练车", systemImage: "stop.circle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 2)
    }
}

private struct StartSessionCard: View {
    @Binding var wantsRouteTracking: Bool
    @Binding var wantsAudioRecording: Bool
    let startAction: () -> Void
    let sessionCount: Int
    let locationAvailable: Bool
    let audioAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("准备开始练车", systemImage: "car.fill")
                .font(.title2)
                .bold()
            Text("已记录 \(sessionCount) 次练车")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle("追踪路线", isOn: $wantsRouteTracking)
                .disabled(!locationAvailable)
            if !locationAvailable {
                Text("定位不可用或未授予权限")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("录音练车过程", isOn: $wantsAudioRecording)
                .disabled(!audioAvailable)
            if !audioAvailable {
                Text("录音不可用或未授予权限")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: startAction) {
                Label("开始计时", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 2)
    }
}

private struct SessionHistoryList: View {
    let sessions: [DrivingSession]
    let noteProvider: (DrivingSession) -> UserNote?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史记录")
                .font(.headline)
            ForEach(sessions.sorted(by: { $0.sequenceNumber > $1.sequenceNumber })) { session in
                NavigationLink {
                    DrivingSessionDetailView(session: session,
                                              note: noteProvider(session))
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("第 \(session.sequenceNumber) 次练车")
                                .font(.subheadline)
                                .bold()
                            Spacer()
                            Text(session.startedAt, format: .dateTime.year().month().day())
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 16) {
                            Label(session.durationString, systemImage: "clock")
                            if let amount = session.amountPaid {
                                Label(amount.formattedCurrency, systemImage: "eurosign.circle")
                            }
                            Label(formatDistance(session.totalDistanceMeters), systemImage: "ruler")
                            Label("路线点: \(session.routeSamples.count)", systemImage: "map")
                            if session.audio.isEnabled {
                                Label(session.audio.fileURL != nil ? "录音已保存" : "录音未保存", systemImage: "waveform")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        #if canImport(MapKit)
                        if !session.routeSamples.isEmpty {
                            RouteMapView(session: session)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        #endif
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CompletionSheet: View {
    @ObservedObject var viewModel: DrivingPracticeViewModel
#if os(iOS)
    @State private var selectedItems: [PhotosPickerItem] = []
#endif

    var body: some View {
        NavigationStack {
            Form {
                Section("练车信息") {
                    TextField("支付金额 (可选)", text: $viewModel.amountInput)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                    Text("练车时长：\(viewModel.elapsedTime.formattedElapsed)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let session = viewModel.activeSession {
                        Text("行驶距离：\(formatDistance(session.totalDistanceMeters))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

#if canImport(MapKit)
                if let session = viewModel.activeSession, !session.routeSamples.isEmpty {
                    Section("路线预览") {
                        RouteMapView(session: session)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
#endif

                Section("练车笔记") {
                    if let status = viewModel.audioRecordingStatus {
                        Label(status, systemImage: "waveform")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let duration = viewModel.recordedAudioDurationText {
                        Text("录音时长：\(duration)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextEditor(text: $viewModel.noteDraft)
                        .frame(height: 140)

#if os(iOS)
                    PhotosPicker(selection: $selectedItems, matching: .images) {
                        Label("添加图片", systemImage: "photo")
                    }
                    .onChange(of: selectedItems) { _, items in
                        Task {
                            for item in items {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("practice_\(UUID().uuidString).img")
                                    do {
                                        try data.write(to: tempURL)
                                        viewModel.addImageAttachment(url: tempURL)
                                    } catch {
                                        NSLog("Failed to persist image: \(error.localizedDescription)")
                                    }
                                }
                            }
                            selectedItems.removeAll()
                        }
                    }
#endif
                    Button {
                        viewModel.addSketchAttachment()
                    } label: {
                        Label("添加画板", systemImage: "pencil.and.outline")
                    }

                    if !viewModel.attachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.attachments) { attachment in
                                    AttachmentPreview(attachment: attachment) {
                                        viewModel.removeAttachment(attachment)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("生成练车报告")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: viewModel.cancelCompletion)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: viewModel.confirmCompletion)
                }
            }
        }
    }
}

private struct AttachmentPreview: View {
    let attachment: NoteAttachment
    let onRemove: () -> Void

    var body: some View {
        VStack {
            Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Button("移除", action: onRemove)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var symbolName: String {
        switch attachment.kind {
        case .image: return "photo"
        case .sketch: return "scribble"
        case .audio: return "waveform"
        }
    }
}

#if canImport(MapKit)
private struct RouteMapView: View {
    let session: DrivingSession
    let showAudioAnnotations: Bool
    let isInteractive: Bool
    @Binding var selectedWaypoint: DrivingSession.AudioWaypoint?

    init(session: DrivingSession,
         showAudioAnnotations: Bool = false,
         isInteractive: Bool = false,
         selectedWaypoint: Binding<DrivingSession.AudioWaypoint?> = .constant(nil)) {
        self.session = session
        self.showAudioAnnotations = showAudioAnnotations
        self.isInteractive = isInteractive
        self._selectedWaypoint = selectedWaypoint
    }

    var body: some View {
        RouteMapRepresentable(coordinates: session.routeCoordinates,
                              audioWaypoints: showAudioAnnotations ? session.audioWaypoints : [],
                              isInteractive: isInteractive,
                              selectedWaypoint: $selectedWaypoint)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

private final class AudioWaypointAnnotation: NSObject, MKAnnotation {
    let waypoint: DrivingSession.AudioWaypoint
    var coordinate: CLLocationCoordinate2D { waypoint.coordinate }
    var title: String? { AudioWaypointAnnotation.timeFormatter.string(from: waypoint.timestamp) }
    var subtitle: String? { "音频片段" }

    init(waypoint: DrivingSession.AudioWaypoint) {
        self.waypoint = waypoint
        super.init()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

#if os(iOS)
private struct RouteMapRepresentable: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let audioWaypoints: [DrivingSession.AudioWaypoint]
    let isInteractive: Bool
    @Binding var selectedWaypoint: DrivingSession.AudioWaypoint?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = isInteractive
        mapView.showsCompass = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsUserLocation = isInteractive
        mapView.userTrackingMode = isInteractive ? .follow : .none
        configure(mapView)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self
        configure(uiView)
        syncSelection(on: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    private func configure(_ mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        let annotationsToRemove = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(annotationsToRemove)
        guard !coordinates.isEmpty else { return }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        if let first = coordinates.first {
            let start = MKPointAnnotation()
            start.coordinate = first
            start.title = "起点"
            mapView.addAnnotation(start)
        }

        if let last = coordinates.last, coordinates.count > 1 {
            let end = MKPointAnnotation()
            end.coordinate = last
            end.title = "终点"
            mapView.addAnnotation(end)
        }

        if !audioWaypoints.isEmpty {
            mapView.addAnnotations(audioWaypoints.map(AudioWaypointAnnotation.init))
        }

        if coordinates.count == 1 {
            mapView.setRegion(MKCoordinateRegion(center: coordinates[0], latitudinalMeters: 300, longitudinalMeters: 300), animated: false)
        } else {
            mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: false)
        }
    }

    private func syncSelection(on mapView: MKMapView) {
        guard let selectedWaypoint else {
            mapView.selectedAnnotations
                .filter { $0 is AudioWaypointAnnotation }
                .forEach { mapView.deselectAnnotation($0, animated: false) }
            return
        }
        if let annotation = mapView.annotations.compactMap({ $0 as? AudioWaypointAnnotation }).first(where: { $0.waypoint.id == selectedWaypoint.id }) {
            mapView.selectAnnotation(annotation, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteMapRepresentable

        init(parent: RouteMapRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let audioAnnotation = annotation as? AudioWaypointAnnotation {
                let identifier = "AudioWaypoint"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: audioAnnotation, reuseIdentifier: identifier)
                view.annotation = audioAnnotation
                view.markerTintColor = UIColor.systemIndigo
                view.glyphImage = UIImage(systemName: "waveform")
                view.canShowCallout = true
                return view
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? AudioWaypointAnnotation else { return }
            parent.selectedWaypoint = annotation.waypoint
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            if view.annotation is AudioWaypointAnnotation {
                parent.selectedWaypoint = nil
            }
        }
    }
}
#elseif os(macOS)
private struct RouteMapRepresentable: NSViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let audioWaypoints: [DrivingSession.AudioWaypoint]
    let isInteractive: Bool
    @Binding var selectedWaypoint: DrivingSession.AudioWaypoint?

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.isZoomEnabled = isInteractive
        mapView.isScrollEnabled = isInteractive
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsUserLocation = isInteractive
        configure(mapView)
        return mapView
    }

    func updateNSView(_ nsView: MKMapView, context: Context) {
        context.coordinator.parent = self
        configure(nsView)
        syncSelection(on: nsView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    private func configure(_ mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        let annotationsToRemove = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(annotationsToRemove)
        guard !coordinates.isEmpty else { return }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        if let first = coordinates.first {
            let start = MKPointAnnotation()
            start.coordinate = first
            start.title = "起点"
            mapView.addAnnotation(start)
        }

        if let last = coordinates.last, coordinates.count > 1 {
            let end = MKPointAnnotation()
            end.coordinate = last
            end.title = "终点"
            mapView.addAnnotation(end)
        }

        if !audioWaypoints.isEmpty {
            mapView.addAnnotations(audioWaypoints.map(AudioWaypointAnnotation.init))
        }

        if coordinates.count == 1 {
            let region = MKCoordinateRegion(center: coordinates[0], latitudinalMeters: 300, longitudinalMeters: 300)
            mapView.setRegion(region, animated: false)
        } else {
            mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: false)
        }
    }

    private func syncSelection(on mapView: MKMapView) {
        guard let selectedWaypoint else {
            mapView.selectedAnnotations
                .filter { $0 is AudioWaypointAnnotation }
                .forEach { mapView.deselectAnnotation($0, animated: false) }
            return
        }
        if let annotation = mapView.annotations.compactMap({ $0 as? AudioWaypointAnnotation }).first(where: { $0.waypoint.id == selectedWaypoint.id }) {
            mapView.selectAnnotation(annotation, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteMapRepresentable

        init(parent: RouteMapRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor.systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if annotation is AudioWaypointAnnotation {
                let identifier = "AudioWaypoint"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = annotation
                view.markerTintColor = NSColor.systemIndigo
                view.glyphImage = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
                view.canShowCallout = true
                return view
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? AudioWaypointAnnotation else { return }
            parent.selectedWaypoint = annotation.waypoint
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            if view.annotation is AudioWaypointAnnotation {
                parent.selectedWaypoint = nil
            }
        }
    }
}
#endif
#endif

#if canImport(AVFoundation)
private struct AudioAttachmentPlayer: View {
    let url: URL
    let startOffset: TimeInterval?

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var errorMessage: String?
    @State private var playbackTime: Double = 0
    @State private var duration: Double = 0
    @State private var pendingSeek: TimeInterval?
    @State private var timer: Timer?

    init(url: URL, startOffset: TimeInterval? = nil) {
        self.url = url
        self.startOffset = startOffset
        _pendingSeek = State(initialValue: startOffset)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: togglePlayback) {
                    Label(isPlaying ? "暂停" : "播放录音", systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .disabled(player == nil && errorMessage != nil)

                Text("\(formatTime(playbackTime)) / \(formatTime(duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: Binding(
                get: { playbackTime },
                set: { newValue in
                    playbackTime = newValue
                    player?.currentTime = newValue
                }
            ), in: 0...max(duration, 0.1), onEditingChanged: { editing in
                if editing {
                    stopTimer()
                } else {
                    player?.currentTime = playbackTime
                    if isPlaying {
                        player?.play()
                        startTimer()
                    }
                }
            })
            .disabled(player == nil)

            if let message = errorMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .onAppear(perform: preparePlayer)
        .onDisappear(perform: stopPlayback)
    }

    private func preparePlayer() {
        guard player == nil else {
            updateFromPlayer()
            return
        }
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.prepareToPlay()
            player = audioPlayer
            errorMessage = nil
            updateFromPlayer()
        } catch {
            errorMessage = "无法加载录音"
        }
    }

    private func togglePlayback() {
        guard let player else {
            preparePlayer()
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.currentTime = playbackTime
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    private func stopPlayback() {
        player?.stop()
        isPlaying = false
        stopTimer()
        updateFromPlayer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            guard let player else { return }
            playbackTime = player.currentTime
            duration = player.duration
            if !player.isPlaying && isPlaying {
                isPlaying = false
                stopTimer()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateFromPlayer() {
        if let player {
            duration = player.duration
            if let seek = pendingSeek {
                let clamped = min(max(0, seek), duration.isFinite ? duration : seek)
                playbackTime = clamped
                player.currentTime = clamped
                pendingSeek = nil
            } else {
                playbackTime = player.currentTime
            }
        } else {
            playbackTime = 0
            duration = 0
        }
    }

    private func formatTime(_ value: Double) -> String {
        guard value.isFinite else { return "--:--" }
        return AudioAttachmentPlayer.timeFormatter.string(from: value) ?? "--:--"
    }

    static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        formatter.unitsStyle = .positional
        return formatter
    }()
}
#endif

private struct DrivingSessionDetailView: View {
    let session: DrivingSession
    let note: UserNote?
    @State private var selectedWaypoint: DrivingSession.AudioWaypoint?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

#if canImport(MapKit)
                if !session.routeSamples.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("路线")
                            .font(.headline)
                        RouteMapView(session: session,
                                     showAudioAnnotations: true,
                                     selectedWaypoint: $selectedWaypoint)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
#endif

                metadata

                if let note {
                    noteSection(note)
                } else {
                    Text("暂无练车笔记")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("练车报告")
        }
        .sheet(item: $selectedWaypoint) { waypoint in
            AudioWaypointDetailSheet(session: session, waypoint: waypoint)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("第 \(session.sequenceNumber) 次练车")
                .font(.title2)
                .bold()
            Text(session.startedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Label(session.durationString, systemImage: "clock")
                if let amount = session.amountPaid {
                    Label(amount.formattedCurrency, systemImage: "eurosign.circle")
                }
                Label("行驶距离：\(formatDistance(session.totalDistanceMeters))", systemImage: "ruler")
                Label("路线点：\(session.routeSamples.count)", systemImage: "map")
                if session.audio.isEnabled {
                    if let url = session.audio.fileURL {
                        Label(url.lastPathComponent, systemImage: "waveform")
                    } else {
                        Label("录音未保存", systemImage: "waveform.slash")
                    }
                }
            }
            .font(.subheadline)
        }
    }

    private func noteSection(_ note: UserNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("练车笔记")
                .font(.headline)
            Text(note.body.isEmpty ? "--" : note.body)
                .font(.body)
            if !note.attachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("附件")
                        .font(.subheadline)
                    ForEach(note.attachments) { attachment in
                        switch attachment.kind {
                        case .audio:
                            if let url = attachment.resourceURL {
                                AudioAttachmentPlayer(url: url)
                            } else {
                                Label("音频不可用", systemImage: "waveform.slash")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        case .image, .sketch:
                            Label(attachmentLabel(for: attachment), systemImage: symbolName(for: attachment))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func attachmentLabel(for attachment: NoteAttachment) -> String {
        switch attachment.kind {
        case .image: return attachment.resourceURL?.lastPathComponent ?? "照片"
        case .sketch: return "手写速记"
        case .audio: return attachment.resourceURL?.lastPathComponent ?? "语音记录"
        }
    }

    private func symbolName(for attachment: NoteAttachment) -> String {
        switch attachment.kind {
        case .image: return "photo"
        case .sketch: return "scribble"
        case .audio: return "waveform"
        }
    }
}

#if canImport(AVFoundation)
private struct AudioWaypointDetailSheet: View {
    let session: DrivingSession
    let waypoint: DrivingSession.AudioWaypoint

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(waypoint.timestamp, format: .dateTime.hour().minute().second())
                    .font(.headline)
                Text("录音偏移：\(AudioAttachmentPlayer.timeFormatter.string(from: waypoint.timeOffset) ?? "--:--")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let url = session.audio.fileURL {
                    AudioAttachmentPlayer(url: url, startOffset: waypoint.timeOffset)
                } else {
                    Label("录音文件不可用", systemImage: "waveform.slash")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("路线片段")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}
#else
private struct AudioWaypointDetailSheet: View {
    let session: DrivingSession
    let waypoint: DrivingSession.AudioWaypoint

    var body: some View {
        VStack(spacing: 12) {
            Text("此平台不支持音频播放")
                .font(.headline)
            Text(waypoint.timestamp, format: .dateTime.hour().minute().second())
        }
        .padding()
    }
}
#endif

private extension DrivingSession {
    var durationString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "--"
    }

    #if canImport(MapKit)
    var routeCoordinates: [CLLocationCoordinate2D] {
        routeSamples.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
    #endif
}

private extension TimeInterval {
    var formattedElapsed: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: self) ?? "00:00"
    }
}

private extension Decimal {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(for: self) ?? "--"
    }
}

#Preview {
    final class PreviewLocationService: LocationService {
        var isAvailable: Bool { true }
        var authorizationStatus: LocationAuthorizationStatus { .authorized }
        var routeSamplePublisher: AnyPublisher<DrivingSession.RouteSample, Never> {
            Empty().eraseToAnyPublisher()
        }
        func requestAuthorization() async -> Bool { true }
        func startTracking() {}
        func stopTracking() {}
    }

    final class PreviewAudioService: AudioRecordingService {
        var isRecordingSupported: Bool { true }
        func requestPermission() async -> Bool { true }
        func startRecording() throws -> URL { FileManager.default.temporaryDirectory }
        func stopRecording() -> URL? { nil }
        func cancelRecording() {}
    }

    let store = DrivingSessionStore()
    var sampleSession = DrivingSession(sequenceNumber: 1,
                                       routeSamples: [
                                           .init(timestamp: Date(), latitude: 48.137, longitude: 11.576),
                                           .init(timestamp: Date(), latitude: 48.138, longitude: 11.58),
                                           .init(timestamp: Date(), latitude: 48.139, longitude: 11.584)
                                       ],
                                       audio: .init(isEnabled: true, fileURL: nil, startTimestamp: Date()),
                                       routeTrackingEnabled: true,
                                       audioWaypoints: [
                                           DrivingSession.AudioWaypoint(timestamp: Date(), timeOffset: 5, latitude: 48.138, longitude: 11.58)
                                       ])
    sampleSession.endedAt = Date()
    store.finishSession(amountPaid: 25, noteID: nil, audioURL: nil)

    return DrivingPracticeHomeView(viewModel: DrivingPracticeViewModel(sessionStore: store,
                                                                        notesStore: NotesStore(),
                                                                        locationService: PreviewLocationService(),
                                                                        audioService: PreviewAudioService()))
}
