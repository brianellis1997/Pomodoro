import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
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
        }
    }
}

struct TimerTab: View {
    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var statsService: StatsService
    @Query(sort: \Routine.createdAt, order: .reverse) private var customRoutines: [Routine]

    @State private var sessionStartTime: Date?
    @State private var showCompletionAlert = false
    @State private var earnedPoints = 0

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
                recordCompletedSession()
            }
        }
        .alert("Session Complete!", isPresented: $showCompletionAlert) {
            Button("Continue") { }
        } message: {
            Text("You earned \(earnedPoints) points!")
        }
    }

    private func recordCompletedSession() {
        let workDuration = Int(timerViewModel.engine.workDuration / 60)
        statsService.recordSession(
            routineName: timerViewModel.currentRoutineName,
            durationMinutes: workDuration,
            wasFullSession: true
        )

        earnedPoints = workDuration * 3
        showCompletionAlert = true
    }
}

#Preview {
    MainTabView()
}
