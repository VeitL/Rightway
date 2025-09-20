import SwiftUI
#if os(iOS)
import PhotosUI
#endif

struct LearnHomeView: View {
    @StateObject var viewModel: LearningViewModel
    let glossaryStore: GlossaryStore

    @State private var isPresentingNoteEditor = false
    @State private var noteDraft = ""
    @State private var noteAttachments: [NoteAttachment] = []
#if os(iOS)
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
#endif

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                languageControls
                if let question = viewModel.activeQuestion {
                    QuestionCardView(question: question,
                                     baseLanguage: viewModel.baseLanguage,
                                     showChineseTranslation: viewModel.showChineseTranslation,
                                     isFavorite: viewModel.isFavorite(question),
                                     isBlindSpot: viewModel.isBlindSpot(question),
                                     onToggleFavorite: viewModel.toggleFavorite,
                                     onAddNote: { isPresentingNoteEditor = true })
                } else {
                    ContentUnavailableView("All caught up",
                                             systemImage: "sparkles",
                                             description: Text("Great job!"))
                }
                Spacer(minLength: 0)
                footer
            }
            .padding()
            .navigationTitle("学习模式")
            .sheet(isPresented: $isPresentingNoteEditor) {
#if os(iOS)
                NoteComposer(note: $noteDraft,
                             attachments: $noteAttachments,
                             selectedPhotoItems: $selectedPhotoItems,
                             onSave: { body, attachments in
                                 viewModel.createNote(body: body, attachments: attachments)
                             },
                             onDismiss: resetNoteComposer)
#else
                NoteComposer(note: $noteDraft,
                             attachments: $noteAttachments,
                             onSave: { body, attachments in
                                 viewModel.createNote(body: body, attachments: attachments)
                             },
                             onDismiss: resetNoteComposer)
#endif
            }
        }
    }

    private var languageControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Language", selection: Binding(
                get: { viewModel.baseLanguage },
                set: { viewModel.select(baseLanguage: $0) }
            )) {
                ForEach(QuestionLanguage.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Toggle("中文翻译", isOn: Binding(
                get: { viewModel.showChineseTranslation },
                set: { viewModel.setChineseTranslation(enabled: $0) }
            ))
            .toggleStyle(.switch)

            Button {
                viewModel.startBlindSpotSession()
            } label: {
                Label("我的盲区训练", systemImage: "bolt.fill")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.blindSpotQuestions.isEmpty)

            NavigationLink(destination: GlossaryView(viewModel: GlossaryViewModel(store: glossaryStore))) {
                Label("术语表", systemImage: "book")
            }
            .buttonStyle(.bordered)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            confidenceButton(title: "Again", color: .red, confidence: .again)
            confidenceButton(title: "Hard", color: .orange, confidence: .hard)
            confidenceButton(title: "Good", color: .green, confidence: .good)
            confidenceButton(title: "Easy", color: .blue, confidence: .easy)
        }
        .buttonStyle(.bordered)
    }

    private func confidenceButton(title: String, color: Color, confidence: SRSEngine.Confidence) -> some View {
        Button(title) {
            if let question = viewModel.activeQuestion {
                viewModel.mark(question, confidence: confidence)
            }
        }
        .tint(color)
    }

    private func resetNoteComposer() {
        noteDraft = ""
        noteAttachments = []
#if os(iOS)
        selectedPhotoItems = []
#endif
        isPresentingNoteEditor = false
    }
}

#if os(iOS)
private struct NoteComposer: View {
    @Binding var note: String
    @Binding var attachments: [NoteAttachment]
    @Binding var selectedPhotoItems: [PhotosPickerItem]

    var onSave: (String, [NoteAttachment]) -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("题目笔记") {
                    TextEditor(text: $note)
                        .frame(height: 150)
                }
                Section("附件") {
                    PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
                        Label("添加图片", systemImage: "photo")
                    }
                    .onChange(of: selectedPhotoItems) { _, items in
                        Task {
                            for item in items {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let url = persistTemporary(data: data, extensionName: "img") {
                                    attachments.append(NoteAttachment(kind: .image, resourceURL: url))
                                }
                            }
                            selectedPhotoItems.removeAll()
                        }
                    }
                    if !attachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(attachments) { attachment in
                                    VStack {
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                        Button("移除") {
                                            attachments.removeAll { $0.id == attachment.id }
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("题目笔记")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(note, attachments)
                        onDismiss()
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty)
                }
            }
        }
    }

    private func persistTemporary(data: Data, extensionName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("study_\(UUID().uuidString).\(extensionName)")
        do {
            try data.write(to: url)
            return url
        } catch {
            NSLog("Failed to persist attachment: \(error.localizedDescription)")
            return nil
        }
    }
}
#else
private struct NoteComposer: View {
    @Binding var note: String
    @Binding var attachments: [NoteAttachment]
    var onSave: (String, [NoteAttachment]) -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("题目笔记") {
                    TextEditor(text: $note)
                        .frame(height: 150)
                }
            }
            .navigationTitle("题目笔记")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(note, attachments)
                        onDismiss()
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
#endif

#Preview {
    let questionStore = QuestionStore()
    let notesStore = NotesStore()
    return LearnHomeView(viewModel: LearningViewModel(questionStore: questionStore,
                                                      notesStore: notesStore,
                                                      srsEngine: SRSEngine(),
                                                      preferences: UserPreferencesStore()),
                         glossaryStore: GlossaryStore())
}
