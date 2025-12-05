import SwiftUI
import SwiftData

struct RoutineBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]

    @State private var showingCreateSheet = false
    @State private var selectedRoutine: Routine?

    var onSelectRoutine: ((Routine) -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                presetsSection

                if !routines.isEmpty {
                    customRoutinesSection
                }

                createNewButton
            }
            .padding()
        }
        .background(Color.backgroundPrimary)
        .sheet(isPresented: $showingCreateSheet) {
            RoutineEditorView(routine: nil) { newRoutine in
                modelContext.insert(newRoutine)
                try? modelContext.save()
            }
        }
        .sheet(item: $selectedRoutine) { routine in
            RoutineEditorView(routine: routine) { updatedRoutine in
                routine.name = updatedRoutine.name
                routine.workDuration = updatedRoutine.workDuration
                routine.shortBreakDuration = updatedRoutine.shortBreakDuration
                routine.longBreakDuration = updatedRoutine.longBreakDuration
                routine.roundsBeforeLongBreak = updatedRoutine.roundsBeforeLongBreak
                routine.totalRounds = updatedRoutine.totalRounds
                try? modelContext.save()
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Presets")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(RoutineConfiguration.presets, id: \.name) { preset in
                    RoutinePresetCard(config: preset) {
                        let routine = Routine(
                            name: preset.name,
                            workDuration: preset.workDuration,
                            shortBreakDuration: preset.shortBreakDuration,
                            longBreakDuration: preset.longBreakDuration,
                            roundsBeforeLongBreak: preset.roundsBeforeLongBreak,
                            totalRounds: preset.totalRounds
                        )
                        onSelectRoutine?(routine)
                    }
                }
            }
        }
    }

    private var customRoutinesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Routines")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(routines) { routine in
                    RoutineCard(routine: routine) {
                        onSelectRoutine?(routine)
                    } onEdit: {
                        selectedRoutine = routine
                    } onDelete: {
                        modelContext.delete(routine)
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    private var createNewButton: some View {
        Button(action: { showingCreateSheet = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Create Custom Routine")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.pomodoroRed)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

struct RoutinePresetCard: View {
    let config: RoutineConfiguration
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(config.workDuration)m focus • \(config.shortBreakDuration)m break • \(config.totalRounds) rounds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.pomodoroRed)
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
        }
    }
}

struct RoutineCard: View {
    let routine: Routine
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(routine.workDuration)m focus • \(routine.shortBreakDuration)m break • \(routine.totalRounds) rounds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Menu {
                Button(action: onSelect) {
                    Label("Start", systemImage: "play.fill")
                }
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
}

struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let routine: Routine?
    let onSave: (Routine) -> Void

    @State private var name: String = ""
    @State private var workDuration: Double = 25
    @State private var shortBreakDuration: Double = 5
    @State private var longBreakDuration: Double = 20
    @State private var roundsBeforeLongBreak: Double = 4
    @State private var totalRounds: Double = 4

    init(routine: Routine?, onSave: @escaping (Routine) -> Void) {
        self.routine = routine
        self.onSave = onSave

        if let r = routine {
            _name = State(initialValue: r.name)
            _workDuration = State(initialValue: Double(r.workDuration))
            _shortBreakDuration = State(initialValue: Double(r.shortBreakDuration))
            _longBreakDuration = State(initialValue: Double(r.longBreakDuration))
            _roundsBeforeLongBreak = State(initialValue: Double(r.roundsBeforeLongBreak))
            _totalRounds = State(initialValue: Double(r.totalRounds))
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Routine Name") {
                    TextField("e.g., Deep Work Session", text: $name)
                }

                Section("Focus Duration") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Work Duration")
                            Spacer()
                            Text("\(Int(workDuration)) min")
                                .foregroundColor(.pomodoroRed)
                                .fontWeight(.semibold)
                        }
                        Slider(value: $workDuration, in: 5...120, step: 5)
                            .tint(.pomodoroRed)
                    }
                }

                Section("Break Durations") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Short Break")
                            Spacer()
                            Text("\(Int(shortBreakDuration)) min")
                                .foregroundColor(.pomodoroGreen)
                                .fontWeight(.semibold)
                        }
                        Slider(value: $shortBreakDuration, in: 1...30, step: 1)
                            .tint(.pomodoroGreen)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Long Break")
                            Spacer()
                            Text("\(Int(longBreakDuration)) min")
                                .foregroundColor(.pomodoroBlue)
                                .fontWeight(.semibold)
                        }
                        Slider(value: $longBreakDuration, in: 5...60, step: 5)
                            .tint(.pomodoroBlue)
                    }
                }

                Section("Rounds") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Rounds before long break")
                            Spacer()
                            Text("\(Int(roundsBeforeLongBreak))")
                                .fontWeight(.semibold)
                        }
                        Slider(value: $roundsBeforeLongBreak, in: 1...8, step: 1)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Total Rounds")
                            Spacer()
                            Text("\(Int(totalRounds))")
                                .fontWeight(.semibold)
                        }
                        Slider(value: $totalRounds, in: 1...12, step: 1)
                    }
                }

                Section {
                    routinePreview
                }
            }
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRoutine()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private var routinePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.caption)
                .foregroundColor(.secondary)

            let totalWorkTime = Int(workDuration) * Int(totalRounds)
            let shortBreaks = max(0, Int(totalRounds) - (Int(totalRounds) / Int(roundsBeforeLongBreak)))
            let longBreaks = Int(totalRounds) / Int(roundsBeforeLongBreak)
            let totalBreakTime = (shortBreaks * Int(shortBreakDuration)) + (longBreaks * Int(longBreakDuration))
            let totalTime = totalWorkTime + totalBreakTime

            Text("Total session: \(totalTime / 60)h \(totalTime % 60)m")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("\(Int(totalRounds)) work blocks • \(shortBreaks) short breaks • \(longBreaks) long breaks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func saveRoutine() {
        let newRoutine = Routine(
            name: name,
            workDuration: Int(workDuration),
            shortBreakDuration: Int(shortBreakDuration),
            longBreakDuration: Int(longBreakDuration),
            roundsBeforeLongBreak: Int(roundsBeforeLongBreak),
            totalRounds: Int(totalRounds)
        )
        onSave(newRoutine)
    }
}
