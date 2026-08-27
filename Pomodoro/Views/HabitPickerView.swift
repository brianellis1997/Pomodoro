import SwiftUI

/// Choose a JournalBuddy habit from a pushed, searchable list.
///
/// This replaced an inline `Picker`. With twenty-seven habits the menu scrolls
/// itself back to whatever is currently selected, so reaching anything else
/// means fighting it: scroll up, get yanked back down to the checkmark. A list
/// you can search does not do that, and twenty-seven options wanted a search
/// field anyway.
struct HabitPickerView: View {
    let title: String
    /// Shown as the top choice when this is a step that can defer to its
    /// routine, rather than a plain "Don't send".
    let inheritLabel: String?
    @Binding var selection: String?
    let habits: [JournalBuddySync.Habit]

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var matches: [JournalBuddySync.Habit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? habits : habits.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        List {
            Section {
                Button {
                    selection = nil
                    dismiss()
                } label: {
                    HStack {
                        Text(inheritLabel ?? "Don't send")
                            .foregroundColor(.primary)
                        Spacer()
                        if selection == nil {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                }
            }

            Section {
                ForEach(matches) { habit in
                    Button {
                        selection = habit.id
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name).foregroundColor(.primary)
                                if let summary = habit.targetSummary {
                                    Text(summary).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if selection == habit.id {
                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search habits")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One row that shows the current choice and pushes the picker.
struct HabitPickerRow: View {
    let label: String
    let subtitle: String?
    let inheritLabel: String?
    @Binding var selection: String?
    let habits: [JournalBuddySync.Habit]

    private var currentName: String? {
        guard let selection else { return nil }
        return habits.first { $0.id == selection }?.name
    }

    var body: some View {
        NavigationLink {
            HabitPickerView(title: label, inheritLabel: inheritLabel,
                            selection: $selection, habits: habits)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(currentName ?? (inheritLabel ?? "Don't send"))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
