import Combine
import SwiftUI
import Foundation
#if canImport(MapKit)
import MapKit
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if os(iOS)
import PhotosUI
import UIKit
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
                VStack(alignment: .leading, spacing: RightwayTheme.verticalSpacing) {
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
                                           noteProvider: viewModel.note(for:),
                                           renameAction: viewModel.renameSession(_:to:),
                                           clearTitleAction: viewModel.clearCustomTitle(_:),
                                           deleteAction: viewModel.deleteSession(_:),
                                           videoExportAction: { session, includeAudio in
                                               viewModel.exportVideo(for: session, includeAudio: includeAudio)
                                           })
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 32)
            }
            .scrollIndicators(.hidden)
            .rightwayBackground()
            .navigationTitle("练车记录")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(isPresented: $viewModel.showCompletionSheet, onDismiss: viewModel.cancelCompletion) {
                CompletionSheet(viewModel: viewModel)
            }
        }
        .environmentObject(viewModel)
    }
}

private struct ActiveSessionCard: View {
    let session: DrivingSession
    let elapsed: TimeInterval
    let stopAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(session.displayTitle, systemImage: "steeringwheel")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(session.startedAt, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 10) {
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
            .tint(.red)
        }
        .frame(maxWidth: .infinity)
        .rightwayCard()
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
        VStack(alignment: .leading, spacing: 18) {
            Label("准备开始练车", systemImage: "car.fill")
                .font(.title2)
                .bold()
            Text("已记录 \(sessionCount) 次练车")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle("追踪路线", isOn: $wantsRouteTracking)
                .disabled(!locationAvailable)
                .tint(RightwayTheme.accent)
            if !locationAvailable {
                Text("定位不可用或未授予权限")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("录音练车过程", isOn: $wantsAudioRecording)
                .disabled(!audioAvailable)
                .tint(RightwayTheme.accent)
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
            .tint(RightwayTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .rightwayCard()
    }
}

private struct SessionHistoryList: View {
    let sessions: [DrivingSession]
    let noteProvider: (DrivingSession) -> UserNote?
    let renameAction: (DrivingSession, String) -> Void
    let clearTitleAction: (DrivingSession) -> Void
    let deleteAction: (DrivingSession) -> Void
    let videoExportAction: (DrivingSession, Bool) -> Void

    @State private var renamingSession: DrivingSession?
    @State private var renameText: String = ""
    @State private var sessionPendingDeletion: DrivingSession?
    @State private var isDeleteDialogPresented = false
    @State private var pendingVideoExportSession: DrivingSession?
    @State private var isVideoExportDialogPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("历史记录")
                .rightwaySectionHeader()
            ForEach(sessions.sorted(by: { $0.sequenceNumber > $1.sequenceNumber })) { session in
                NavigationLink {
                    DrivingSessionDetailView(session: session,
                                              note: noteProvider(session))
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.displayTitle)
                                    .font(.subheadline.weight(.semibold))
                                if let custom = session.customTitle,
                                   !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("第 \(session.sequenceNumber) 次练车")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rightwayCard(addShadow: false)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("重命名") {
                        renamingSession = session
                        renameText = session.customTitle ?? ""
                    }
                    if let custom = session.customTitle,
                       !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("恢复默认名称") {
                            clearTitleAction(session)
                        }
                    }
                    if session.routeSamples.count > 1 {
                        Button("导出视频") {
                            pendingVideoExportSession = session
                            isVideoExportDialogPresented = true
                        }
                    }
                    if let shareURL = shareURL(for: session) {
                        ShareLink(item: shareURL) {
                            Label("导出录音", systemImage: "square.and.arrow.up")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        sessionPendingDeletion = session
                        isDeleteDialogPresented = true
                    } label: {
                        Text("删除记录")
                    }
                }
            }
        }
        .sheet(item: $renamingSession) { session in
            SessionRenameSheet(session: session,
                                initialTitle: renameText,
                                onSave: { title in
                                    renameAction(session, title)
                                    renamingSession = nil
                                },
                                onReset: {
                                    clearTitleAction(session)
                                    renamingSession = nil
                                },
                                onCancel: {
                                    renamingSession = nil
                                })
        }
        .confirmationDialog("导出练车视频",
                            isPresented: $isVideoExportDialogPresented,
                            presenting: pendingVideoExportSession) { session in
            Button("导出视频（含音频）") {
                videoExportAction(session, true)
                pendingVideoExportSession = nil
            }
            Button("导出视频（无音频）") {
                videoExportAction(session, false)
                pendingVideoExportSession = nil
            }
            Button("取消", role: .cancel) {
                pendingVideoExportSession = nil
            }
        } message: { session in
            Text("将导出 \(session.displayTitle) 的行驶轨迹动画。")
        }
        .confirmationDialog("删除练车记录?", isPresented: $isDeleteDialogPresented) {
            Button("删除", role: .destructive) {
                if let session = sessionPendingDeletion {
                    deleteAction(session)
                }
                sessionPendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                sessionPendingDeletion = nil
            }
        } message: {
            Text("删除后将移除相关语音与笔记，且不可恢复。")
        }
    }

    private func shareURL(for session: DrivingSession) -> URL? {
        let url = session.audio.fileURL
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
}

private struct SessionRenameSheet: View {
    let session: DrivingSession
    let initialTitle: String
    let onSave: (String) -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    @State private var title: String = ""

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedTitle: String? {
        if trimmedTitle.isEmpty { return nil }
        if trimmedTitle == session.defaultTitle { return nil }
        return trimmedTitle
    }

    private var existingNormalizedTitle: String? {
        session.customTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSaveDisabled: Bool {
        trimmedTitle.isEmpty || normalizedTitle == existingNormalizedTitle
    }

    init(session: DrivingSession,
         initialTitle: String,
         onSave: @escaping (String) -> Void,
         onReset: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.session = session
        self.initialTitle = initialTitle
        self.onSave = onSave
        self.onReset = onReset
        self.onCancel = onCancel
        _title = State(initialValue: initialTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("自定义名称")) {
                    TextField("输入名称", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                    Text("默认名称：\(session.defaultTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if session.customTitle != nil {
                    Section {
                        Button("恢复默认名称") {
                            onReset()
                        }
                    }
                }
            }
            .navigationTitle("重命名记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(title)
                    }
                    .disabled(isSaveDisabled)
                }
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
                              transcriptSnippets: transcriptSnippets,
                              selectedWaypoint: $selectedWaypoint)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var transcriptSnippets: [UUID: String] {
        guard showAudioAnnotations else { return [:] }
        return session.audioWaypoints.reduce(into: [:]) { result, waypoint in
            if let snippet = session.transcriptSnippet(around: waypoint.timeOffset) {
                result[waypoint.id] = snippet
            }
        }
    }
}

private final class AudioWaypointAnnotation: NSObject, MKAnnotation {
    let waypoint: DrivingSession.AudioWaypoint
    let transcriptSnippet: String?
    var coordinate: CLLocationCoordinate2D { waypoint.coordinate }
    var title: String? { AudioWaypointAnnotation.timeFormatter.string(from: waypoint.timestamp) }
    var subtitle: String? {
        if let transcriptSnippet, !transcriptSnippet.isEmpty {
            return transcriptSnippet
        }
        return "音频片段"
    }

    init(waypoint: DrivingSession.AudioWaypoint, transcriptSnippet: String? = nil) {
        self.waypoint = waypoint
        if let snippet = transcriptSnippet?.trimmingCharacters(in: .whitespacesAndNewlines), !snippet.isEmpty {
            let limit = 80
            if snippet.count > limit {
                let index = snippet.index(snippet.startIndex, offsetBy: limit)
                let truncated = snippet[..<index]
                let trimmed = truncated.trimmingCharacters(in: .whitespacesAndNewlines)
                let base = trimmed.isEmpty ? String(truncated) : trimmed
                self.transcriptSnippet = base + "…"
            } else {
                self.transcriptSnippet = snippet
            }
        } else {
            self.transcriptSnippet = nil
        }
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
    let transcriptSnippets: [UUID: String]
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
            let annotations = audioWaypoints.map { waypoint in
                AudioWaypointAnnotation(waypoint: waypoint,
                                        transcriptSnippet: transcriptSnippets[waypoint.id])
            }
            mapView.addAnnotations(annotations)
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
    let transcriptSnippets: [UUID: String]
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
            let annotations = audioWaypoints.map { waypoint in
                AudioWaypointAnnotation(waypoint: waypoint,
                                        transcriptSnippet: transcriptSnippets[waypoint.id])
            }
            mapView.addAnnotations(annotations)
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
    enum Style {
        case standard
        case compact
    }

    let url: URL
    let startOffset: TimeInterval?
    private let style: Style

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var errorMessage: String?
    @Binding private var playbackTime: TimeInterval
    @State private var duration: TimeInterval = 0
    @State private var pendingSeek: TimeInterval?
    @State private var timer: Timer?

    init(url: URL,
         startOffset: TimeInterval? = nil,
         playbackTime: Binding<TimeInterval> = .constant(0),
         style: Style = .standard) {
        self.url = url
        self.startOffset = startOffset
        self.style = style
        _playbackTime = playbackTime
        _pendingSeek = State(initialValue: startOffset)
    }

    var body: some View {
        content
            .onAppear(perform: preparePlayer)
            .onDisappear(perform: stopPlayback)
            .onChange(of: playbackTime, perform: externalSeek)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .standard:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    standardPlayPauseButton

                    Text("\(formatTime(playbackTime)) / \(formatTime(duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                timelineSlider
                    .disabled(player == nil)

                if let message = errorMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

        case .compact:
            HStack(spacing: 10) {
                compactPlayPauseButton
                    .font(.title2)

                timelineSlider
                    .disabled(player == nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var standardPlayPauseButton: some View {
        Button(action: togglePlayback) {
            Label(isPlaying ? "暂停" : "播放录音", systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.plain)
        .disabled(player == nil && errorMessage != nil)
    }

    private var compactPlayPauseButton: some View {
        Button(action: togglePlayback) {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
        }
        .buttonStyle(.plain)
        .disabled(player == nil && errorMessage != nil)
    }

    private var timelineSlider: some View {
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

    private func externalSeek(_ newValue: TimeInterval) {
        guard let player, abs(player.currentTime - newValue) > 0.05 else { return }
        player.currentTime = newValue
        if isPlaying {
            player.play()
        }
    }

    private func formatTime(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "--:--" }
        return AudioAttachmentPlayer.timeFormatter.string(from: value) ?? "--:--"
    }

    static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}
#if canImport(AVFoundation)
private struct AudioWaypointDetailPanel: View {
    let session: DrivingSession
    let waypoint: DrivingSession.AudioWaypoint
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(waypoint.timestamp, format: .dateTime.hour().minute().second())
                        .font(.subheadline.weight(.semibold))
                    Text("录音偏移：\(AudioAttachmentPlayer.timeFormatter.string(from: waypoint.timeOffset) ?? "--:--")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除选中的录音标记")
            }

            if let highlightText {
                Text(highlightText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } else if !hasTranscript {
                Text("暂无该时间点的语音转写")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !transcriptSegments.isEmpty {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(transcriptSegments) { segment in
                            transcriptRow(for: segment,
                                          isActive: segment.id == activeTranscriptID)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var highlightText: String? {
        session.transcriptSnippet(around: waypoint.timeOffset, window: 8)
    }

    private var hasTranscript: Bool {
        let text = session.audio.transcript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !text.isEmpty || !session.audio.transcriptSegments.isEmpty
    }

    private var transcriptSegments: [DrivingSession.AudioTranscriptSegment] {
        session.transcriptSegments(around: waypoint.timeOffset, window: 12)
    }

    private var activeTranscriptID: UUID? {
        session.transcriptSegment(at: waypoint.timeOffset)?.id
    }

    @ViewBuilder
    private func transcriptRow(for segment: DrivingSession.AudioTranscriptSegment, isActive: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(AudioAttachmentPlayer.timeFormatter.string(from: segment.startOffset) ?? "--:--")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
            Text(segment.text)
                .font(.footnote)
                .foregroundStyle(isActive ? .primary : .secondary)
                .fontWeight(isActive ? .medium : .regular)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
#else
private struct AudioWaypointDetailPanel: View {
    let session: DrivingSession
    let waypoint: DrivingSession.AudioWaypoint
    let onDismiss: () -> Void

    var body: some View {
        let _ = onDismiss
        VStack(spacing: 12) {
            Text("此平台不支持音频播放")
                .font(.headline)
            Text(waypoint.timestamp, format: .dateTime.hour().minute().second())
        }
        .padding()
    }
}
#endif

#if canImport(MapKit)
private struct DetailRouteMapView: View {
    let session: DrivingSession
    let cursorCoordinate: CLLocationCoordinate2D?
    @Binding var selectedWaypoint: DrivingSession.AudioWaypoint?

    var body: some View {
#if os(iOS)
        DetailRouteMapRepresentable(session: session,
                                    cursorCoordinate: cursorCoordinate,
                                    selectedWaypoint: $selectedWaypoint)
#else
        RouteMapView(session: session,
                     showAudioAnnotations: true,
                     isInteractive: true,
                     selectedWaypoint: $selectedWaypoint)
#endif
    }
}

#if os(iOS)
private struct DetailRouteMapRepresentable: UIViewRepresentable {
    let session: DrivingSession
    let cursorCoordinate: CLLocationCoordinate2D?
    @Binding var selectedWaypoint: DrivingSession.AudioWaypoint?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isUserInteractionEnabled = true
        configure(mapView, coordinator: context.coordinator)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self
        configure(uiView, coordinator: context.coordinator)
        syncSelection(on: uiView)
        context.coordinator.updateCursor(on: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    private func configure(_ mapView: MKMapView, coordinator: Coordinator) {
        mapView.removeOverlays(mapView.overlays)
        let annotationsToRemove = mapView.annotations.filter { !($0 is MKUserLocation) && !($0 is CursorAnnotation) }
        mapView.removeAnnotations(annotationsToRemove)
        guard !session.routeSamples.isEmpty else { return }

        let coordinates = session.routeCoordinates
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

        if !session.audioWaypoints.isEmpty {
            let annotations = session.audioWaypoints.map { waypoint in
                AudioWaypointAnnotation(waypoint: waypoint,
                                        transcriptSnippet: session.transcriptSnippet(around: waypoint.timeOffset))
            }
            mapView.addAnnotations(annotations)
        }

        if !session.stops.isEmpty {
            mapView.addAnnotations(session.stops.map(StopAnnotation.init))
        }

        if !coordinator.hasConfiguredRegion {
            if coordinates.count == 1 {
                let region = MKCoordinateRegion(center: coordinates[0], latitudinalMeters: 300, longitudinalMeters: 300)
                mapView.setRegion(region, animated: false)
            } else {
                mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: false)
            }
            coordinator.hasConfiguredRegion = true
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
        var parent: DetailRouteMapRepresentable
        var hasConfiguredRegion = false
        private var cursorAnnotation: CursorAnnotation?

        init(parent: DetailRouteMapRepresentable) {
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
            if let stopAnnotation = annotation as? StopAnnotation {
                let identifier = "StopAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: stopAnnotation, reuseIdentifier: identifier)
                view.annotation = stopAnnotation
                view.markerTintColor = UIColor.systemRed
                view.glyphImage = UIImage(systemName: "pause.circle.fill")
                view.canShowCallout = true
                return view
            }
            if let cursor = annotation as? CursorAnnotation {
                let identifier = "CursorAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: cursor, reuseIdentifier: identifier)
                view.annotation = cursor
                view.markerTintColor = UIColor.systemOrange
                view.glyphImage = UIImage(systemName: "location.fill")
                view.canShowCallout = false
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

        func updateCursor(on mapView: MKMapView) {
            guard let coordinate = parent.cursorCoordinate else {
                if let annotation = cursorAnnotation {
                    mapView.removeAnnotation(annotation)
                    cursorAnnotation = nil
                }
                return
            }

            if let annotation = cursorAnnotation {
                annotation.coordinate = coordinate
                if mapView.annotations.contains(where: { $0 === annotation }) {
                    mapView.removeAnnotation(annotation)
                    mapView.addAnnotation(annotation)
                } else {
                    mapView.addAnnotation(annotation)
                }
            } else {
                let annotation = CursorAnnotation(coordinate: coordinate)
                cursorAnnotation = annotation
                mapView.addAnnotation(annotation)
            }
        }
    }
}
#elseif os(macOS)
private struct DetailRouteMapRepresentable: NSViewRepresentable {
    let session: DrivingSession
    let cursorCoordinate: CLLocationCoordinate2D?
    @Binding var selectedWaypoint: DrivingSession.AudioWaypoint?

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        configure(mapView, coordinator: context.coordinator)
        return mapView
    }

    func updateNSView(_ nsView: MKMapView, context: Context) {
        context.coordinator.parent = self
        configure(nsView, coordinator: context.coordinator)
        syncSelection(on: nsView)
        context.coordinator.updateCursor(on: nsView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    private func configure(_ mapView: MKMapView, coordinator: Coordinator) {
        mapView.removeOverlays(mapView.overlays)
        let annotationsToRemove = mapView.annotations.filter { !($0 is CursorAnnotation) }
        mapView.removeAnnotations(annotationsToRemove)
        guard !session.routeSamples.isEmpty else { return }

        let coordinates = session.routeCoordinates
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

        if !session.audioWaypoints.isEmpty {
            let annotations = session.audioWaypoints.map { waypoint in
                AudioWaypointAnnotation(waypoint: waypoint,
                                        transcriptSnippet: session.transcriptSnippet(around: waypoint.timeOffset))
            }
            mapView.addAnnotations(annotations)
        }

        if !session.stops.isEmpty {
            mapView.addAnnotations(session.stops.map(StopAnnotation.init))
        }

        if !coordinator.hasConfiguredRegion {
            if coordinates.count == 1 {
                let region = MKCoordinateRegion(center: coordinates[0], latitudinalMeters: 300, longitudinalMeters: 300)
                mapView.setRegion(region, animated: false)
            } else {
                mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: false)
            }
            coordinator.hasConfiguredRegion = true
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
        var parent: DetailRouteMapRepresentable
        var hasConfiguredRegion = false
        private var cursorAnnotation: CursorAnnotation?

        init(parent: DetailRouteMapRepresentable) {
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
            if let audioAnnotation = annotation as? AudioWaypointAnnotation {
                let identifier = "AudioWaypoint"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: audioAnnotation, reuseIdentifier: identifier)
                view.annotation = audioAnnotation
                view.markerTintColor = NSColor.systemIndigo
                view.glyphImage = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
                view.canShowCallout = true
                return view
            }
            if let stopAnnotation = annotation as? StopAnnotation {
                let identifier = "StopAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: stopAnnotation, reuseIdentifier: identifier)
                view.annotation = stopAnnotation
                view.markerTintColor = NSColor.systemRed
                view.glyphImage = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: nil)
                view.canShowCallout = true
                return view
            }
            if let cursor = annotation as? CursorAnnotation {
                let identifier = "CursorAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: cursor, reuseIdentifier: identifier)
                view.annotation = cursor
                view.markerTintColor = NSColor.systemOrange
                view.glyphImage = NSImage(systemSymbolName: "location.fill", accessibilityDescription: nil)
                view.canShowCallout = false
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

        func updateCursor(on mapView: MKMapView) {
            guard let coordinate = parent.cursorCoordinate else {
                if let annotation = cursorAnnotation {
                    mapView.removeAnnotation(annotation)
                    cursorAnnotation = nil
                }
                return
            }

            if let annotation = cursorAnnotation {
                annotation.coordinate = coordinate
                if mapView.annotations.contains(where: { $0 === annotation }) {
                    mapView.removeAnnotation(annotation)
                    mapView.addAnnotation(annotation)
                } else {
                    mapView.addAnnotation(annotation)
                }
            } else {
                let annotation = CursorAnnotation(coordinate: coordinate)
                cursorAnnotation = annotation
                mapView.addAnnotation(annotation)
            }
        }
    }
}
#endif

private final class StopAnnotation: NSObject, MKAnnotation {
    let stop: DrivingSession.Stop
    var coordinate: CLLocationCoordinate2D { stop.coordinate }
    var title: String? {
        let duration = stop.duration.formattedElapsed
        return "停留 \(duration)"
    }
    var subtitle: String? {
        let start = DateFormatter.shortTime.string(from: stop.startedAt)
        let end = DateFormatter.shortTime.string(from: stop.endedAt)
        return "\(start) - \(end)"
    }

    init(stop: DrivingSession.Stop) {
        self.stop = stop
        super.init()
    }
}

private final class CursorAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}
#endif

private struct DrivingSessionInfoSheet: View {
    let session: DrivingSession
    let note: UserNote?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section(title: "基本信息") {
                    Label { Text(session.startedAt, format: .dateTime.year().month().day().hour().minute()) } icon: { Image(systemName: "calendar") }
                    Label("名称：\(session.displayTitle)", systemImage: "textformat")
                    Label("序号：第 \(session.sequenceNumber) 次练车", systemImage: "number")
                    Label("用时：\(session.durationString)", systemImage: "clock")
                    Label("距离：\(formatDistance(session.totalDistanceMeters))", systemImage: "ruler")
                    if let amount = session.amountPaid {
                        Label("费用：\(amount.formattedCurrency)", systemImage: "eurosign.circle")
                    }
                    if session.totalStopDuration > 0 {
                        Label("总停留：\(session.totalStopDuration.formattedElapsed)", systemImage: "hourglass")
                    }
                }

                if !session.stops.isEmpty {
                    section(title: "停留记录") {
                        ForEach(Array(session.stops.enumerated()), id: \.element.id) { index, stop in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("第 \(index + 1) 处停留")
                                    .font(.subheadline).bold()
                                Text("时长：\(stop.duration.formattedElapsed)")
                                Text("时间：\(stop.startedAt, format: .dateTime.hour().minute().second()) - \(stop.endedAt, format: .dateTime.hour().minute().second())")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                if let note {
                    section(title: "练车笔记") {
                        Text(note.body.isEmpty ? "--" : note.body)
                            .font(.body)
                        if !note.attachments.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(note.attachments) { attachment in
                                    Label(attachmentLabel(for: attachment), systemImage: symbolName(for: attachment))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct DrivingTranscriptView: View {
    let transcript: String?
    let segments: [DrivingSession.AudioTranscriptSegment]
    let activeIndex: Int?

    var body: some View {
        if segments.isEmpty {
            if let transcript, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(transcript)
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("尚未生成转写。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(segments.enumerated()), id: \.element.id) { pair in
                            let index = pair.offset
                            let segment = pair.element
                            HStack(alignment: .top, spacing: 8) {
                                Text(AudioAttachmentPlayer.timeFormatter.string(from: segment.startOffset) ?? "--:--")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 48, alignment: .trailing)
                                Text(segment.text)
                                    .font(.body)
                                    .foregroundStyle(index == activeIndex ? .primary : .secondary)
                                    .fontWeight(index == activeIndex ? .medium : .regular)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(index == activeIndex ? Color.accentColor.opacity(0.15) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(segment.id)
                        }
                    }
                    .padding(4)
                }
                .onChange(of: activeIndex) { newValue in
                    if let newValue,
                       segments.indices.contains(newValue) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(segments[newValue].id, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

private struct TranscriptTimelineRibbon: View {
    let segments: [DrivingSession.AudioTranscriptSegment]
    let activeSegmentID: UUID?
    let onSelectSegment: (DrivingSession.AudioTranscriptSegment) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(segments) { segment in
                        let isActive = segment.id == activeSegmentID
                        Text(segment.text)
                            .font(.footnote)
                            .foregroundStyle(isActive ? Color.accentColor : Color.primary.opacity(0.75))
                            .contentShape(Rectangle())
                            .onTapGesture { onSelectSegment(segment) }
                            .padding(.horizontal, isActive ? 2 : 0)
                            .padding(.vertical, isActive ? 2 : 0)
                            .background {
                                if isActive {
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.15))
                                }
                            }
                            .id(segment.id)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
            .onAppear { scrollToActive(proxy: proxy) }
            .onChange(of: activeSegmentID) { _ in
                scrollToActive(proxy: proxy)
            }
        }
    }

    private func scrollToActive(proxy: ScrollViewProxy) {
        guard let activeSegmentID,
              segments.contains(where: { $0.id == activeSegmentID }) else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(activeSegmentID, anchor: .center)
            }
        }
    }
}

private struct DrivingSessionDetailView: View {
    @EnvironmentObject private var viewModel: DrivingPracticeViewModel
    let session: DrivingSession
    let note: UserNote?
    @State private var playbackTime: TimeInterval = 0
    @State private var selectedWaypoint: DrivingSession.AudioWaypoint?
    @State private var manuallyClearedWaypoint: (id: UUID, offset: TimeInterval)?
    @State private var showInfoSheet = false
    @State private var videoExportErrorMessage: String?
    @State private var videoExportSuccessMessage: String?
    @State private var showTranscriptionLanguagePicker = false
    @State private var isTranscribing = false
    @State private var transcriptionErrorMessage: String?

    private let waypointReselectionGraceWindow: TimeInterval = 6

    private var timelineStart: Date? {
        session.audio.startTimestamp ?? session.routeSamples.first?.timestamp
    }

    private var timelineEnd: Date? {
        session.routeSamples.last?.timestamp ?? session.audio.startTimestamp
    }

    private var timelineDuration: TimeInterval {
        guard let start = timelineStart, let end = timelineEnd else { return 0 }
        return max(end.timeIntervalSince(start), 0)
    }

    var body: some View {
        ZStack {
#if canImport(MapKit)
            DetailRouteMapView(session: session,
                               cursorCoordinate: cursorCoordinate(for: playbackTime),
                               selectedWaypoint: $selectedWaypoint)
                .ignoresSafeArea(edges: .bottom)
#else
            Color(.systemBackground)
#endif

            VStack {
                HStack {
                    Spacer()
                    infoButton
                }
                .padding([.top, .trailing])
                Spacer()
            }

            VStack {
                Spacer()
                bottomBar
            }
        }
        .navigationTitle("练车报告")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sheet(isPresented: $showInfoSheet) {
            DrivingSessionInfoSheet(session: session, note: note)
                .presentationDetents([.fraction(0.5), .large])
        }
        .alert(isPresented: Binding(get: { videoExportErrorMessage != nil },
                                    set: { value in if !value { videoExportErrorMessage = nil } })) {
            Alert(title: Text("导出失败"),
                  message: Text(videoExportErrorMessage ?? "未知错误"),
                  dismissButton: .default(Text("好的")))
        }
        .alert(isPresented: Binding(get: { videoExportSuccessMessage != nil },
                                    set: { value in if !value { videoExportSuccessMessage = nil } })) {
            Alert(title: Text("导出完成"),
                  message: Text(videoExportSuccessMessage ?? "视频已保存至相册"),
                  dismissButton: .default(Text("好的")))
        }
        .confirmationDialog("选择语音转文字语言",
                            isPresented: $showTranscriptionLanguagePicker,
                            titleVisibility: .visible) {
            ForEach(viewModel.supportedSpeechLanguages) { language in
                Button("\(language.flagEmoji) \(language.displayName)") {
                    beginTranscription(with: language)
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("将使用所选语言把录音内容转为文字")
        }
        .alert(isPresented: Binding(get: { transcriptionErrorMessage != nil },
                                    set: { value in if !value { transcriptionErrorMessage = nil } })) {
            Alert(title: Text("转写失败"),
                  message: Text(transcriptionErrorMessage ?? "未知错误"),
                  dismissButton: .default(Text("好的")))
        }
        .onAppear { playbackTime = 0 }
        .onChange(of: selectedWaypoint) { waypoint in
            if let offset = waypoint?.timeOffset {
                manuallyClearedWaypoint = nil
                playbackTime = clampedPlaybackTime(offset)
            }
        }
        .onChange(of: playbackTime) { offset in
            if let dismissed = manuallyClearedWaypoint {
                if abs(offset - dismissed.offset) <= waypointReselectionGraceWindow {
                    return
                } else {
                    manuallyClearedWaypoint = nil
                }
            }
            guard let nearest = nearestWaypoint(to: offset) else {
                if selectedWaypoint != nil {
                    selectedWaypoint = nil
                }
                manuallyClearedWaypoint = nil
                return
            }
            if selectedWaypoint?.id != nearest.id {
                selectedWaypoint = nearest
            }
        }
        .onChange(of: viewModel.videoExportError) { newValue in
            videoExportErrorMessage = newValue
        }
        .onChange(of: viewModel.videoExportSuccessMessage) { newValue in
            videoExportSuccessMessage = newValue
        }
    }

    private var infoButton: some View {
        Menu {
            Button("查看练车详情") { showInfoSheet = true }

            if viewModel.canExportVideo(for: session) {
                if viewModel.isVideoExportInProgress(for: session) {
                    ProgressView(value: viewModel.currentVideoExportProgress(for: session))
                } else {
                    Button("导出视频（含音频）") {
                        viewModel.exportVideo(for: session, includeAudio: true)
                    }
                    Button("导出视频（无音频）") {
                        viewModel.exportVideo(for: session, includeAudio: false)
                    }
                }
            }

            if let shareURL = shareableAudioURL {
                ShareLink(item: shareURL) {
                    Label("导出录音", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "list.bullet.rectangle")
                .font(.title2.weight(.semibold))
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(radius: 3)
        }
        .accessibilityLabel("练车详情与导出")
    }

    private var bottomBar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("时间：\(format(offset: playbackTime)) / \(format(offset: timelineDuration))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(session.audio.fileURL != nil ? "播放或拖动时间轴，地图将同步移动" : "使用时间轴滑块回放路线")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    transcriptionControl

                    if let url = session.audio.fileURL {
                        AudioAttachmentPlayer(url: url,
                                              startOffset: playbackTime,
                                              playbackTime: $playbackTime,
                                              style: .compact)
                    } else {
                        horizontalScrubber
                    }
                }

                if viewModel.isVideoExportInProgress(for: session) {
                    ProgressView(value: viewModel.currentVideoExportProgress(for: session))
                        .progressViewStyle(.linear)
                }

                if !orderedTranscriptSegments.isEmpty {
                    HStack {
                        Spacer(minLength: 0)
                        TranscriptTimelineRibbon(
                            segments: orderedTranscriptSegments,
                            activeSegmentID: activeTranscriptSegmentID
                        ) { segment in
                            playbackTime = clampedPlaybackTime(segment.startOffset)
                        }
                        Spacer(minLength: 0)
                    }
                } else if let snippet = currentTranscriptSnippet {
                    Text(snippet)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: bottomPanelMaxHeight, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .shadow(radius: 2, y: 1)
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }


    private var horizontalScrubber: some View {
        Slider(value: Binding(
            get: { playbackTime },
            set: { playbackTime = clampedPlaybackTime($0) }
        ), in: 0...max(timelineDuration, 0.1))
        .disabled(timelineDuration == 0)
        .frame(maxWidth: .infinity)
    }

    private var transcriptionControl: some View {
        Group {
            if canTranscribeAudio {
                ZStack {
                    Button {
                        showTranscriptionLanguagePicker = true
                    } label: {
                        Image(systemName: "text.badge.waveform")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTranscribing)

                    if isTranscribing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(width: 36, height: 36)
                            .allowsHitTesting(false)
                    }
                }
            } else {
                Spacer()
                    .frame(width: 36)
            }
        }
    }

    private func clampedPlaybackTime(_ value: TimeInterval) -> TimeInterval {
        let duration = timelineDuration
        guard duration > 0 else { return 0 }
        return min(max(0, value), duration)
    }

    private func nearestWaypoint(to offset: TimeInterval, tolerance: TimeInterval = 12) -> DrivingSession.AudioWaypoint? {
        guard !session.audioWaypoints.isEmpty else { return nil }
        return session.audioWaypoints.min { lhs, rhs in
            abs(lhs.timeOffset - offset) < abs(rhs.timeOffset - offset)
        }.flatMap { candidate in
            abs(candidate.timeOffset - offset) <= tolerance ? candidate : nil
        }
    }

    private func beginTranscription(with language: SpeechLanguage) {
        showTranscriptionLanguagePicker = false
        guard !isTranscribing, canTranscribeAudio else { return }
        isTranscribing = true
        transcriptionErrorMessage = nil

        Task {
            do {
                try await viewModel.transcribe(sessionID: session.id, language: language)
            } catch is CancellationError {
                // Ignore user cancellations but still reset the busy state below.
            } catch let error as SpeechRecognitionError {
                await MainActor.run {
                    transcriptionErrorMessage = speechRecognitionErrorDescription(for: error)
                }
            } catch {
                await MainActor.run {
                    transcriptionErrorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                isTranscribing = false
            }
        }
    }

    private func speechRecognitionErrorDescription(for error: SpeechRecognitionError) -> String {
        switch error {
        case .recognizerUnavailable:
            return "当前设备暂不支持所选语言的语音转写。"
        case .authorizationDenied:
            return "语音识别或麦克风权限未开启，请在系统设置中授权后重试。"
        }
    }

    private var currentTranscriptSnippet: String? {
        session.transcriptSnippet(around: playbackTime, window: 8)
    }

    private var canTranscribeAudio: Bool {
        viewModel.isSpeechServiceAvailable && session.audio.fileURL != nil && !viewModel.supportedSpeechLanguages.isEmpty
    }

    private var shareableAudioURL: URL? {
        viewModel.recordingURL(for: session)
    }

    private var bottomPanelMaxHeight: CGFloat {
#if os(iOS)
        UIScreen.main.bounds.height / 3.5
#else
        320
#endif
    }

    private var orderedTranscriptSegments: [DrivingSession.AudioTranscriptSegment] {
        session.audio.transcriptSegments.sorted { lhs, rhs in
            lhs.startOffset < rhs.startOffset
        }
    }

    private var activeTranscriptSegmentID: UUID? {
        session.transcriptSegment(at: playbackTime)?.id
    }

    private func cursorCoordinate(for offset: TimeInterval) -> CLLocationCoordinate2D? {
#if canImport(MapKit)
        guard let sample = routeSample(at: offset) else { return nil }
        return CLLocationCoordinate2D(latitude: sample.latitude, longitude: sample.longitude)
#else
        return nil
#endif
    }

    private func routeSample(at offset: TimeInterval) -> DrivingSession.RouteSample? {
        guard let start = timelineStart, !session.routeSamples.isEmpty else { return nil }
        let target = start.addingTimeInterval(offset)
        let samples = session.routeSamples
        var best = samples.first!
        var bestDelta = abs(best.timestamp.timeIntervalSince(target))
        for sample in samples.dropFirst() {
            let delta = abs(sample.timestamp.timeIntervalSince(target))
            if delta < bestDelta {
                best = sample
                bestDelta = delta
            }
        }
        return best
    }

    private func format(offset: TimeInterval) -> String {
        guard offset.isFinite else { return "--:--" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = offset >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: offset) ?? "--:--"
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

    var totalStopDuration: TimeInterval {
        stops.reduce(0) { $0 + $1.duration }
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

private extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

#Preview {
    Text("Driving Practice Preview")
}
