import SwiftUI

struct GlossaryView: View {
    @StateObject var viewModel: GlossaryViewModel
    @State private var selectedCategory: GlossaryCategory? = nil

    var body: some View {
        List {
            Section {
                TextField("搜索术语", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
            }

            if !GlossaryCategory.allCases.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(title: "全部", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(GlossaryCategory.allCases, id: \.self) { category in
                            CategoryChip(title: category.displayName, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            Section {
                if viewModel.terms(by: selectedCategory).isEmpty {
                    ContentUnavailableView("暂无匹配术语",
                                             systemImage: "text.book.closed",
                                             description: Text("尝试其他关键词或分类"))
                } else {
                    ForEach(viewModel.terms(by: selectedCategory)) { term in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(term.term)
                                .font(.headline)
                            Text(term.zhDefinition)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !term.examples.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(term.examples, id: \.self) { example in
                                        Label(example, systemImage: "quote.closing")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("术语表")
    }
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GlossaryView(viewModel: GlossaryViewModel(store: GlossaryStore()))
}
