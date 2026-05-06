import SwiftUI
import SwiftData

struct RoutineBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var routineSyncService: RoutineSyncService
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
                routineSyncService.sendRoutinesToWatch()
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
                routine.sessionsData = updatedRoutine.sessionsData
                try? modelContext.save()
                routineSyncService.sendRoutinesToWatch()
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
                        routine.setSteps(preset.steps)
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
                        routineSyncService.sendRoutinesToWatch()
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

private func formatTotalTime(minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60
    if hours > 0 {
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }
    return "\(mins)m"
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

                    Text("\(config.steps.count) steps • \(formatTotalTime(minutes: config.steps.totalMinutes))")
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
        let steps = routine.resolvedSteps()
        HStack {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(steps.count) steps • \(formatTotalTime(minutes: steps.totalMinutes))")
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
    @State private var steps: [SessionStep] = []
    @FocusState private var focusedField: FocusedField?

    enum FocusedField: Hashable {
        case name
        case label(UUID)
        case duration(UUID)
    }

    init(routine: Routine?, onSave: @escaping (Routine) -> Void) {
        self.routine = routine
        self.onSave = onSave

        if let r = routine {
            _name = State(initialValue: r.name)
            _steps = State(initialValue: r.resolvedSteps())
        } else {
            _name = State(initialValue: "")
            _steps = State(initialValue: [SessionStep](RoutineConfiguration.classicPomodoro.steps))
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section("Routine Name") {
                    TextField("e.g., Morning Work Block", text: $name)
                        .focused($focusedField, equals: .name)
                }

                Section {
                    ForEach($steps) { $step in
                        StepRow(
                            step: $step,
                            position: stepPosition(step),
                            focusedField: $focusedField
                        )
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                duplicateStep(id: step.id)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove { from, to in
                        steps.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { indexSet in
                        steps.remove(atOffsets: indexSet)
                    }

                    addStepMenu
                } header: {
                    HStack {
                        Text("Sessions")
                        Spacer()
                        EditButton()
                            .font(.caption)
                    }
                } footer: {
                    Text("Swipe right to duplicate, left to delete. Tap Edit to reorder.")
                        .font(.caption2)
                }

                Section("Quick Templates") {
                    ForEach(RoutineConfiguration.presets, id: \.name) { preset in
                        Button {
                            steps = preset.steps
                            if name.isEmpty { name = preset.name }
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(preset.steps.count) steps")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Preview") {
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
                    .disabled(name.isEmpty || steps.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }

    private func duplicateStep(id: UUID) {
        guard let idx = steps.firstIndex(where: { $0.id == id }) else { return }
        let source = steps[idx]
        let copy = SessionStep(kind: source.kind, durationMinutes: source.durationMinutes, label: source.label)
        steps.insert(copy, at: idx + 1)
    }

    private var addStepMenu: some View {
        Menu {
            Button {
                steps.append(SessionStep(kind: .focus, durationMinutes: 25))
            } label: {
                Label("Add Focus", systemImage: "brain.head.profile")
            }
            Button {
                steps.append(SessionStep(kind: .shortBreak, durationMinutes: 5))
            } label: {
                Label("Add Break", systemImage: "cup.and.saucer.fill")
            }
            Button {
                steps.append(SessionStep(kind: .longBreak, durationMinutes: 20))
            } label: {
                Label("Add Long Break", systemImage: "figure.walk")
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.pomodoroRed)
                Text("Add Step")
                    .foregroundColor(.pomodoroRed)
                Spacer()
            }
        }
    }

    private var routinePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatTotalTime(minutes: steps.totalMinutes))
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 4) {
                ForEach(Array(steps.prefix(20).enumerated()), id: \.offset) { _, step in
                    Text(step.kind.defaultEmoji)
                        .font(.caption)
                }
                if steps.count > 20 {
                    Text("…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            let focusCount = steps.filter { $0.kind == .focus }.count
            let shortCount = steps.filter { $0.kind == .shortBreak }.count
            let longCount = steps.filter { $0.kind == .longBreak }.count
            Text("\(focusCount) focus • \(shortCount) break\(shortCount == 1 ? "" : "s") • \(longCount) long break\(longCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func stepPosition(_ step: SessionStep) -> Int {
        let sameKind = steps.filter { $0.kind == step.kind }
        return (sameKind.firstIndex(where: { $0.id == step.id }) ?? 0) + 1
    }

    private func saveRoutine() {
        let summary = legacySummary(from: steps)
        let newRoutine = Routine(
            name: name,
            workDuration: summary.work,
            shortBreakDuration: summary.shortBreak,
            longBreakDuration: summary.longBreak,
            roundsBeforeLongBreak: summary.longBreakEvery,
            totalRounds: summary.rounds
        )
        newRoutine.setSteps(steps)
        onSave(newRoutine)
    }

    private func legacySummary(from steps: [SessionStep]) -> (work: Int, shortBreak: Int, longBreak: Int, longBreakEvery: Int, rounds: Int) {
        let focus = steps.first(where: { $0.kind == .focus })?.durationMinutes ?? 25
        let short = steps.first(where: { $0.kind == .shortBreak })?.durationMinutes ?? 5
        let long = steps.first(where: { $0.kind == .longBreak })?.durationMinutes ?? 20
        let rounds = max(1, steps.filter { $0.kind == .focus }.count)
        return (focus, short, long, 4, rounds)
    }
}

private struct StepRow: View {
    @Binding var step: SessionStep
    let position: Int
    var focusedField: FocusBinding

    typealias FocusBinding = FocusState<RoutineEditorView.FocusedField?>.Binding

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(tint)
                .frame(width: 24)

            TextField(defaultPlaceholder, text: Binding(
                get: { step.label ?? "" },
                set: { step.label = $0.isEmpty ? nil : $0 }
            ))
            .font(.body)
            .focused(focusedField, equals: .label(step.id))

            Spacer(minLength: 4)

            HStack(spacing: 0) {
                Button {
                    step.durationMinutes = max(1, step.durationMinutes - 5)
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderless)

                TextField("0", value: $step.durationMinutes, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .focused(focusedField, equals: .duration(step.id))
                    .onChange(of: step.durationMinutes) { _, newValue in
                        if newValue < 1 { step.durationMinutes = 1 }
                        if newValue > 240 { step.durationMinutes = 240 }
                    }

                Text("min")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)

                Button {
                    step.durationMinutes = min(240, step.durationMinutes + 5)
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderless)
            }
            .background(Color.gray.opacity(0.12))
            .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch step.kind {
        case .focus: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "figure.walk"
        }
    }

    private var tint: Color {
        switch step.kind {
        case .focus: return .pomodoroRed
        case .shortBreak: return .pomodoroGreen
        case .longBreak: return .pomodoroBlue
        }
    }

    private var defaultPlaceholder: String {
        "\(step.kind.defaultName) \(position)"
    }
}
