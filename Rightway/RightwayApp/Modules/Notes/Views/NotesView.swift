import SwiftUI

struct NotesView: View {
    @StateObject var viewModel: NotesViewModel
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    if !viewModel.notes(for: .study).isEmpty {
                        Section("习题笔记") {
                            ForEach(viewModel.notes(for: .study)) { note in
                                NoteRow(note: note)
                            }
                        }
                    }

                    if !viewModel.notes(for: .practice).isEmpty {
                        Section("练车笔记") {
                            ForEach(viewModel.notes(for: .practice)) { note in
                                NoteRow(note: note)
                            }
                        }
                    }

                    if viewModel.notes(for: .study).isEmpty && viewModel.notes(for: .practice).isEmpty {
                        ContentUnavailableView("暂无笔记",
                                                 systemImage: "square.and.pencil",
                                                 description: Text("开始记录你的学习或练车心得吧"))
                    }
                }

#if os(iOS)
                .listStyle(.insetGrouped)
#else
                .listStyle(.inset)
#endif

                VStack(alignment: .leading, spacing: 8) {
                    Text("快速笔记")
                        .font(.headline)
                    TextEditor(text: $draft)
                        .frame(height: 120)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.tertiary))
                    Button("保存笔记") {
                        let note = UserNote(category: .study, body: draft)
                        viewModel.add(note: note)
                        draft = ""
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("我的笔记")
        }
    }
}

private struct NoteRow: View {
    let note: UserNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if note.category == .practice, let sessionID = note.practiceSessionID {
                Text("练车记录 \(sessionID.uuidString.prefix(8))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !note.body.isEmpty {
                Text(note.body)
                    .font(.body)
            }
            if !note.attachments.isEmpty {
                HStack(spacing: 6) {
                    ForEach(note.attachments) { attachment in
                        Image(systemName: symbolName(for: attachment.kind))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(note.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

    private func symbolName(for kind: NoteAttachment.Kind) -> String {
        switch kind {
        case .image: return "photo"
        case .sketch: return "scribble"
        case .audio: return "waveform"
        }
    }

#Preview {
    NotesView(viewModel: NotesViewModel(store: NotesStore()))
}
