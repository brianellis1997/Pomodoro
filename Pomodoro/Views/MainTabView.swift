import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var timerViewModel = TimerViewModel()
    @StateObject private var statsService = StatsService()
    @State private var selectedTab = 0
    @State private var currentRoutineName = "Classic Pomodoro"

    var body: some View {
        TabView(selection: $selectedTab) {
            TimerTab(
                timerViewModel: timerViewModel,
                statsService: statsService,
                currentRoutineName: $currentRoutineName
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
                currentRoutineName = routine.name
                selectedTab = 0
            }
            .tabItem {
                Label("Routines", systemImage: "list.bullet.rectangle")
            }
            .tag(2)
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
    @Binding var currentRoutineName: String

    @State private var sessionStartTime: Date?
    @State private var showCompletionAlert = false
    @State private var earnedPoints = 0

    var body: some View {
        ZStack {
            TimerView(viewModel: timerViewModel)

            VStack {
                HStack {
                    Text(currentRoutineName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.backgroundSecondary))

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
            routineName: currentRoutineName,
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
