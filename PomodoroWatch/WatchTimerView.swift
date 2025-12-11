import SwiftUI
import Combine
import WidgetKit

struct WatchTimerView: View {
    @StateObject private var engine = TimerEngine()
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @State private var currentRoutineName = "Classic Pomodoro"
    @State private var showRoutinePicker = false
    @State private var syncedRoutines: [RoutineTransfer] = []
    @State private var previousPhase: TimerPhase = .work
    @State private var lastWorkDuration: Int = 25
    @State private var justSkipped: Bool = false
    @State private var sessionStartTime: Date?

    private let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                Button {
                    showRoutinePicker = true
                } label: {
                    HStack(spacing: 2) {
                        Text(currentRoutineName)
                            .font(.caption2)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Text(engine.phaseDisplayName)
                    .font(.caption2)
                    .foregroundColor(phaseColor)
                    .textCase(.uppercase)

                VStack(spacing: 4) {
                    Text(engine.formattedTime)
                        .font(.system(size: 48, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(phaseColor)

                    Text("Round \(engine.currentRound)/\(engine.totalRounds)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)

                HStack(spacing: 20) {
                    Button(action: {
                        engine.reset()
                        sendTimerStateToPhone()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if engine.state == .running {
                            engine.pause()
                        } else {
                            if engine.phase == .work && sessionStartTime == nil {
                                sessionStartTime = Date()
                            }
                            engine.start()
                        }
                        sendTimerStateToPhone()
                    }) {
                        Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(phaseColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if engine.phase == .work {
                            justSkipped = true
                            checkAndRecordSession()
                        }
                        engine.skip()
                        sendTimerStateToPhone()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .sheet(isPresented: $showRoutinePicker) {
                WatchRoutinePickerView(
                    selectedRoutineName: $currentRoutineName,
                    engine: engine,
                    syncedRoutines: syncedRoutines
                )
            }
            .onAppear {
                connectivityManager.requestRoutines()
                syncWidgetData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinesReceived)) { notification in
                if let routines = notification.object as? [RoutineTransfer] {
                    syncedRoutines = routines
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .timerStateSyncReceived)) { notification in
                if let timerState = notification.object as? TimerStateTransfer {
                    applyTimerState(timerState)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsSyncReceived)) { notification in
                if let settings = notification.object as? SettingsTransfer {
                    engine.autoStartBreaks = settings.autoStartBreaks
                    engine.autoStartWork = settings.autoStartWork
                }
            }
            .onReceive(engine.objectWillChange) { _ in
                syncWidgetData()
            }
            .onChange(of: engine.phase) { oldPhase, newPhase in
                if oldPhase == .work && (newPhase == .shortBreak || newPhase == .longBreak) {
                    if !justSkipped {
                        checkAndRecordSession()
                    }
                    justSkipped = false
                }
                previousPhase = newPhase
                sendTimerStateToPhone()
            }
            .onAppear {
                lastWorkDuration = Int(engine.workDuration / 60)
            }
        }
    }

    private func checkAndRecordSession() {
        let workDurationSeconds = engine.workDuration
        let workDurationMinutes = Int(workDurationSeconds / 60)

        guard let startTime = sessionStartTime else {
            return
        }

        let elapsedTime = Date().timeIntervalSince(startTime)
        let completionPercentage = elapsedTime / workDurationSeconds

        let minimumThreshold = 0.80

        if completionPercentage >= minimumThreshold {
            let session = SessionCompletion(
                routineName: currentRoutineName,
                durationMinutes: workDurationMinutes,
                wasFullSession: completionPercentage >= 0.95,
                completedAt: Date()
            )
            connectivityManager.sendSessionCompletion(session)
        }

        sessionStartTime = nil
    }

    private func syncWidgetData() {
        defaults?.set(engine.timeRemaining, forKey: "remainingTime")
        defaults?.set(engine.totalTime, forKey: "totalTime")
        defaults?.set(engine.phase.rawValue, forKey: "phase")
        defaults?.set(engine.currentRound, forKey: "currentRound")
        defaults?.set(engine.totalRounds, forKey: "totalRounds")
        defaults?.set(engine.state == .running, forKey: "isRunning")
        defaults?.set(currentRoutineName, forKey: "routineName")

        if engine.state == .running {
            let endTime = Date().addingTimeInterval(engine.timeRemaining)
            defaults?.set(endTime.timeIntervalSince1970, forKey: "endTime")
        } else {
            defaults?.removeObject(forKey: "endTime")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    private var phaseColor: Color {
        switch engine.phase {
        case .work:
            return .pomodoroRed
        case .shortBreak:
            return .pomodoroGreen
        case .longBreak:
            return .pomodoroBlue
        }
    }

    private func sendTimerStateToPhone() {
        connectivityManager.sendTimerState(
            timeRemaining: engine.timeRemaining,
            totalTime: engine.totalTime,
            phase: engine.phase,
            currentRound: engine.currentRound,
            totalRounds: engine.totalRounds,
            isRunning: engine.state == .running,
            routineName: currentRoutineName,
            workDuration: engine.workDuration,
            shortBreakDuration: engine.shortBreakDuration,
            longBreakDuration: engine.longBreakDuration
        )
    }

    private func applyTimerState(_ state: TimerStateTransfer) {
        guard let phase = TimerPhase(rawValue: state.phase) else { return }

        if engine.state == .running {
            engine.pause()
        }

        engine.phase = phase
        engine.timeRemaining = state.timeRemaining
        engine.totalTime = state.totalTime
        engine.currentRound = state.currentRound
        engine.totalRounds = state.totalRounds
        engine.workDuration = state.workDuration
        engine.shortBreakDuration = state.shortBreakDuration
        engine.longBreakDuration = state.longBreakDuration
        currentRoutineName = state.routineName

        if state.isRunning {
            if engine.phase == .work && sessionStartTime == nil {
                sessionStartTime = Date()
            }
            engine.start()
        }

        syncWidgetData()
    }
}

struct WatchRoutinePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRoutineName: String
    let engine: TimerEngine
    let syncedRoutines: [RoutineTransfer]

    var body: some View {
        List {
            Section("Presets") {
                ForEach(RoutineConfiguration.presets, id: \.name) { preset in
                    Button {
                        selectedRoutineName = preset.name
                        engine.configure(routine: preset)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.caption)
                                Text("\(preset.workDuration)m / \(preset.shortBreakDuration)m")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedRoutineName == preset.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.pomodoroRed)
                            }
                        }
                    }
                }
            }

            if !syncedRoutines.isEmpty {
                Section("Your Routines") {
                    ForEach(syncedRoutines, id: \.id) { routine in
                        Button {
                            selectedRoutineName = routine.name
                            let config = RoutineConfiguration(
                                name: routine.name,
                                workDuration: routine.workDuration,
                                shortBreakDuration: routine.shortBreakDuration,
                                longBreakDuration: routine.longBreakDuration,
                                roundsBeforeLongBreak: routine.roundsBeforeLongBreak,
                                totalRounds: routine.totalRounds
                            )
                            engine.configure(routine: config)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routine.name)
                                        .font(.caption)
                                    Text("\(routine.workDuration)m / \(routine.shortBreakDuration)m")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedRoutineName == routine.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.pomodoroRed)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Routines")
    }
}

#Preview {
    WatchTimerView()
}
