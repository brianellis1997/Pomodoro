import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var routineSyncService: RoutineSyncService
    @StateObject private var timerViewModel = TimerViewModel()
    @StateObject private var statsService = StatsService()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TimerTab(
                timerViewModel: timerViewModel,
                statsService: statsService
            )
            .tabItem {
                Label("Timer", systemImage: "timer")
            }
            .tag(0)

            StatsView(statsService: statsService)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(1)

            RoutineBuilderView { routine in
                timerViewModel.configure(routine: routine)
                selectedTab = 0
            }
            .tabItem {
                Label("Routines", systemImage: "list.bullet.rectangle")
            }
            .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.pomodoroRed)
        .onAppear {
            statsService.setModelContext(modelContext)
            routineSyncService.setModelContext(modelContext)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                timerViewModel.onAppBecameActive()
            } else if newPhase == .background {
                if !timerViewModel.isRunning {
                    LiveActivityManager.shared.endAllActivities()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionCompletionReceived)) { notification in
            if let session = notification.object as? SessionCompletion {
                handleWatchSessionCompletion(session)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .statsRequested)) { _ in
            sendStatsToWatch()
        }
    }

    private func handleWatchSessionCompletion(_ session: SessionCompletion) {
        statsService.recordSession(
            routineName: session.routineName,
            durationMinutes: session.durationMinutes,
            wasFullSession: session.wasFullSession
        )
        sendStatsToWatch()
    }

    private func sendStatsToWatch() {
        guard let stats = statsService.userStats else { return }
        let update = StatsUpdate(
            totalSessions: stats.totalSessionsCompleted,
            totalMinutes: stats.totalMinutesStudied,
            currentStreak: stats.currentStreak,
            todaySessions: statsService.todaySessions,
            totalPoints: stats.totalPoints,
            level: stats.level
        )
        WatchConnectivityManager.shared.sendStatsUpdate(update)
    }
}

struct TimerTab: View {
    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var statsService: StatsService
    @Query(sort: \Routine.createdAt, order: .reverse) private var customRoutines: [Routine]
    @Query private var settingsArray: [AppSettings]

    @State private var sessionStartTime: Date?
    @State private var showCompletionAlert = false
    @State private var earnedPoints = 0

    private var settings: AppSettings? {
        settingsArray.first
    }

    var body: some View {
        ZStack {
            TimerView(viewModel: timerViewModel)

            VStack {
                HStack {
                    Menu {
                        Section("Presets") {
                            ForEach(RoutineConfiguration.presets, id: \.name) { preset in
                                Button {
                                    timerViewModel.configure(with: preset)
                                } label: {
                                    if timerViewModel.currentRoutineName == preset.name {
                                        Label(preset.name, systemImage: "checkmark")
                                    } else {
                                        Text(preset.name)
                                    }
                                }
                            }
                        }
                        if !customRoutines.isEmpty {
                            Section("Your Routines") {
                                ForEach(customRoutines) { routine in
                                    Button {
                                        timerViewModel.configure(routine: routine)
                                    } label: {
                                        if timerViewModel.currentRoutineName == routine.name {
                                            Label(routine.name, systemImage: "checkmark")
                                        } else {
                                            Text(routine.name)
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(timerViewModel.currentRoutineName)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.backgroundSecondary))
                    }

                    Spacer()

                    if let stats = statsService.userStats {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.pomodoroOrange)
                            Text("\(stats.currentStreak)")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.backgroundSecondary))
                    }
                }
                .padding()

                Spacer()
            }
        }
        .onChange(of: timerViewModel.state) { oldState, newState in
            if oldState == .idle && newState == .running {
                sessionStartTime = Date()
            }
        }
        .onChange(of: timerViewModel.phase) { oldPhase, newPhase in
            if oldPhase == .work && (newPhase == .shortBreak || newPhase == .longBreak) {
                checkAndRecordSession()
            }
        }
        .alert("Session Complete!", isPresented: $showCompletionAlert) {
            Button("Continue") { }
        } message: {
            Text("You earned \(earnedPoints) points!")
        }
        .onAppear {
            syncSettings()
        }
        .onChange(of: settings?.autoStartBreaks) { _, _ in
            syncSettings()
        }
        .onChange(of: settings?.autoStartWork) { _, _ in
            syncSettings()
        }
    }

    private func syncSettings() {
        timerViewModel.updateSettings(
            autoStartBreaks: settings?.autoStartBreaks ?? false,
            autoStartWork: settings?.autoStartWork ?? false
        )
    }

    private func checkAndRecordSession() {
        let workDurationSeconds = timerViewModel.engine.workDuration
        let workDurationMinutes = Int(workDurationSeconds / 60)

        guard let startTime = sessionStartTime else {
            return
        }

        let elapsedTime = Date().timeIntervalSince(startTime)
        let completionPercentage = elapsedTime / workDurationSeconds

        let minimumThreshold = 0.80

        if completionPercentage >= minimumThreshold {
            statsService.recordSession(
                routineName: timerViewModel.currentRoutineName,
                durationMinutes: workDurationMinutes,
                wasFullSession: completionPercentage >= 0.95
            )

            earnedPoints = workDurationMinutes * 3
            showCompletionAlert = true
        }

        sessionStartTime = nil
    }
}

#Preview {
    MainTabView()
}
