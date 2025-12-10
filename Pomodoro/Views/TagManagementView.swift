import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionTag.createdAt, order: .forward) private var tags: [SessionTag]
    @State private var showingAddTag = false
    @State private var tagToEdit: SessionTag?

    var body: some View {
        List {
            if tags.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tag.fill")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No tags yet")
                        .font(.headline)
                    Text("Create tags to categorize your study sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Add Default Tags") {
                        addDefaultTags()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pomodoroRed)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(tags) { tag in
                    Button {
                        tagToEdit = tag
                    } label: {
                        HStack {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 24, height: 24)
                            Text(tag.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteTags)
            }
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddTag = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            if !tags.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingAddTag) {
            AddEditTagView(mode: .add)
        }
        .sheet(item: $tagToEdit) { tag in
            AddEditTagView(mode: .edit(tag))
        }
    }

    private func addDefaultTags() {
        for defaultTag in SessionTag.defaultTags {
            let tag = SessionTag(name: defaultTag.name, colorHex: defaultTag.colorHex)
            modelContext.insert(tag)
        }
        try? modelContext.save()
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tags[index])
        }
        try? modelContext.save()
    }
}

struct AddEditTagView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    enum Mode: Identifiable {
        case add
        case edit(SessionTag)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let tag): return tag.id.uuidString
            }
        }
    }

    let mode: Mode
    @State private var name: String = ""
    @State private var selectedColor: Color = .pomodoroRed

    private let colorOptions: [(name: String, color: Color)] = [
        ("Red", Color(hex: "FF6B6B")!),
        ("Coral", Color(hex: "FF8A80")!),
        ("Orange", Color(hex: "FFAB40")!),
        ("Yellow", Color(hex: "FFEAA7")!),
        ("Green", Color(hex: "96CEB4")!),
        ("Teal", Color(hex: "4ECDC4")!),
        ("Blue", Color(hex: "45B7D1")!),
        ("Purple", Color(hex: "DDA0DD")!),
        ("Pink", Color(hex: "F8BBD9")!),
        ("Gray", Color(hex: "95A5A6")!)
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Tag Name") {
                    TextField("Enter tag name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(colorOptions, id: \.name) { option in
                            Button {
                                selectedColor = option.color
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == option.color ? 3 : 0)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    HStack {
                        Text("Preview")
                        Spacer()
                        TagBadge(name: name.isEmpty ? "Tag" : name, color: selectedColor)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Tag" : "New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTag()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if case .edit(let tag) = mode {
                    name = tag.name
                    selectedColor = tag.color
                }
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func saveTag() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        switch mode {
        case .add:
            let tag = SessionTag(name: trimmedName, colorHex: selectedColor.hexString)
            modelContext.insert(tag)
        case .edit(let tag):
            tag.name = trimmedName
            tag.colorHex = selectedColor.hexString
        }

        try? modelContext.save()
        dismiss()
    }
}

struct TagBadge: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color))
    }
}

struct TagSelectionView: View {
    @Query(sort: \SessionTag.createdAt, order: .forward) private var availableTags: [SessionTag]
    @Binding var selectedTags: Set<String>

    var body: some View {
        if availableTags.isEmpty {
            Text("No tags available")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            FlowLayout(spacing: 8) {
                ForEach(availableTags) { tag in
                    TagToggleButton(
                        tag: tag,
                        isSelected: selectedTags.contains(tag.name)
                    ) {
                        if selectedTags.contains(tag.name) {
                            selectedTags.remove(tag.name)
                        } else {
                            selectedTags.insert(tag.name)
                        }
                    }
                }
            }
        }
    }
}

struct TagToggleButton: View {
    let tag: SessionTag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : tag.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? tag.color : tag.color.opacity(0.2))
                )
                .overlay(
                    Capsule()
                        .stroke(tag.color, lineWidth: 1)
                )
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
