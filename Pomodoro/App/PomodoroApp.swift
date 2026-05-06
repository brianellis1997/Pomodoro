import SwiftUI
import SwiftData
import WatchConnectivity
import UserNotifications

@main
struct PomodoroApp: App {
    @StateObject private var routineSyncService = RoutineSyncService()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Routine.self,
            StudySession.self,
            UserStats.self,
            AppSettings.self,
            SessionTag.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(routineSyncService)
                .task {
                    RoutineMigration.migrateLegacyRoutinesIfNeeded(context: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

enum RoutineMigration {
    @MainActor
    static func migrateLegacyRoutinesIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Routine>()
        guard let routines = try? context.fetch(descriptor) else { return }

        var changed = false
        for routine in routines where routine.sessionsData == nil {
            let steps = [SessionStep].expandLegacy(
                work: routine.workDuration,
                shortBreak: routine.shortBreakDuration,
                longBreak: routine.longBreakDuration,
                longBreakEvery: routine.roundsBeforeLongBreak,
                rounds: routine.totalRounds
            )
            routine.setSteps(steps)
            changed = true
        }
        if changed {
            try? context.save()
        }
    }
}
