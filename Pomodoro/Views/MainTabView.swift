import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var routineSyncService: RoutineSyncService
    @StateObject private var timerViewModel = TimerViewModel()
    @StateObject private var statsService = StatsService()
    @Query(sort: \Routine.createdAt, order: .reverse) private var customRoutines: [Routine]
    @State private var selectedTab = 0
    @State private var showAchievementAlert = false

    var body: some View {
        ZStack {
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

                AchievementsView(statsService: statsService)
                    .tabItem {
                        Label("Achievements", systemImage: "trophy.fill")
                    }
                    .tag(2)

                RoutineBuilderView { routine in
                    timerViewModel.configure(routine: routine)
                    selectedTab = 0
                }
                .tabItem {
                    Label("Routines", systemImage: "list.bullet.rectangle")
                }
                .tag(3)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .tint(.pomodoroRed)

            if showAchievementAlert && !statsService.newlyUnlockedAchievements.isEmpty {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                AchievementUnlockAlert(
                    achievements: statsService.newlyUnlockedAchievements,
                    onDismiss: {
                        showAchievementAlert = false
                        statsService.clearNewAchievements()
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(), value: showAchievementAlert)
        .onChange(of: statsService.newlyUnlockedAchievements) { _, newValue in
            if !newValue.isEmpty {
                showAchievementAlert = true
            }
        }
        .onAppear {
            statsService.setModelContext(modelContext)
            routineSyncService.setModelContext(modelContext)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                timerViewModel.onAppBecameActive()
            } else if newPhase == .background {
                timerViewModel.onAppWentToBackground()
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
        .onReceive(NotificationCenter.default.publisher(for: .startScheduledSession)) { notification in
            handleScheduledSessionStart(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .timerStateSyncReceived)) { notification in
            if let timerState = notification.object as? TimerStateTransfer {
                timerViewModel.applyTimerStateFromWatch(timerState)
            }
        }
    }

    private func handleScheduledSessionStart(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let routineName = userInfo["routineName"] as? String else { return }

        if let preset = RoutineConfiguration.presets.first(where: { $0.name == routineName }) {
            timerViewModel.configure(with: preset)
        } else if let customRoutine = customRoutines.first(where: { $0.name == routineName }) {
            timerViewModel.configure(routine: customRoutine)
        }

        selectedTab = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !timerViewModel.isRunning {
                timerViewModel.startPause()
            }
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
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var statsService: StatsService
    @Query(sort: \Routine.createdAt, order: .reverse) private var customRoutines: [Routine]
    @Query private var settingsArray: [AppSettings]
    @Query private var availableTags: [SessionTag]

    @State private var sessionStartTime: Date?
    @State private var showCompletionSheet = false
    @State private var showCompletionAlert = false
    @State private var earnedPoints = 0
    @State private var selectedTags: Set<String> = []
    @State private var pendingSessionData: PendingSession?

    struct PendingSession {
        let routineName: String
        let durationMinutes: Int
        let wasFullSession: Bool
        let hadFocusViolation: Bool
        let focusModeEnabled: Bool
        let points: Int
    }

    private var settings: AppSettings {
        if let existing = settingsArray.first {
            return existing
        }
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }

    var body: some View {
        ZStack {
            TimerView(viewModel: timerViewModel)

            VStack {
                if timerViewModel.sessionFailed && timerViewModel.focusModeEnabled && !timerViewModel.violationBannerDismissed {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("Focus Mode Violation!")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Text("Points reduced to 50% • No streak bonus")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Button("Dismiss") {
                            timerViewModel.dismissViolationBanner()
                        }
                        .font(.caption)
                        .foregroundColor(.pomodoroRed)
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.top, 8)
                }

                if timerViewModel.showCloseCallMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Close call! You made it back in time.")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.top, 8)
                    .transition(.scale.combined(with: .opacity))
                }

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
        .animation(.easeInOut(duration: 0.3), value: timerViewModel.showCloseCallMessage)
        .animation(.easeInOut(duration: 0.3), value: timerViewModel.sessionFailed)
        .animation(.easeInOut(duration: 0.3), value: timerViewModel.violationBannerDismissed)
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
        .sheet(isPresented: $showCompletionSheet) {
            SessionCompletionSheet(
                earnedPoints: earnedPoints,
                selectedTags: $selectedTags,
                availableTags: availableTags,
                onSave: {
                    recordSessionWithTags(Array(selectedTags))
                    showCompletionSheet = false
                },
                onSkip: {
                    recordSessionWithTags([])
                    showCompletionSheet = false
                }
            )
        }
        .onAppear {
            syncSettings()
        }
        .onChange(of: settings.autoStartBreaks) { _, _ in
            syncSettings()
        }
        .onChange(of: settings.autoStartWork) { _, _ in
            syncSettings()
        }
        .onChange(of: settings.focusModeEnabled) { _, _ in
            syncSettings()
        }
        .onChange(of: settings.spotifyEnabled) { _, _ in
            syncSettings()
        }
        .onChange(of: settings.spotifyStudyPlaylistUri) { _, _ in
            syncSettings()
        }
        .onChange(of: settings.spotifyBreakPlaylistUri) { _, _ in
            syncSettings()
        }
    }

    private func syncSettings() {
        timerViewModel.updateSettings(
            autoStartBreaks: settings.autoStartBreaks,
            autoStartWork: settings.autoStartWork,
            focusModeEnabled: settings.focusModeEnabled,
            spotifyEnabled: settings.spotifyEnabled,
            spotifyStudyPlaylistUri: settings.spotifyStudyPlaylistUri,
            spotifyBreakPlaylistUri: settings.spotifyBreakPlaylistUri
        )
        timerViewModel.sendSettingsToWatch()
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
        let hadViolation = timerViewModel.sessionFailed
        let wasFullSession = completionPercentage >= 0.95

        if completionPercentage >= minimumThreshold {
            let points = hadViolation ? workDurationMinutes : workDurationMinutes * 3
            earnedPoints = points

            pendingSessionData = PendingSession(
                routineName: timerViewModel.currentRoutineName,
                durationMinutes: workDurationMinutes,
                wasFullSession: wasFullSession,
                hadFocusViolation: hadViolation,
                focusModeEnabled: timerViewModel.focusModeEnabled,
                points: points
            )

            selectedTags = []

            if availableTags.isEmpty {
                recordSessionWithTags([])
            } else {
                showCompletionSheet = true
            }
        }

        timerViewModel.resetFocusModeViolation()
        sessionStartTime = nil
    }

    private func recordSessionWithTags(_ tags: [String]) {
        guard let session = pendingSessionData else { return }

        statsService.recordSession(
            routineName: session.routineName,
            durationMinutes: session.durationMinutes,
            wasFullSession: session.wasFullSession,
            hadFocusViolation: session.hadFocusViolation,
            focusModeEnabled: session.focusModeEnabled,
            tags: tags
        )

        pendingSessionData = nil
        showCompletionAlert = true
    }
}

struct SessionCompletionSheet: View {
    let earnedPoints: Int
    @Binding var selectedTags: Set<String>
    let availableTags: [SessionTag]
    let onSave: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Session Complete!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("You earned \(earnedPoints) points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Add tags to this session")
                        .font(.headline)

                    if availableTags.isEmpty {
                        Text("No tags available. Create tags in Settings.")
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        onSave()
                    } label: {
                        Text(selectedTags.isEmpty ? "Save Without Tags" : "Save with \(selectedTags.count) Tag\(selectedTags.count == 1 ? "" : "s")")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.pomodoroRed)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        onSkip()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    MainTabView()
}
