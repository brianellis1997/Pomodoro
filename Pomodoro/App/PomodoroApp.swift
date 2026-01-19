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
        }
        .modelContainer(sharedModelContainer)
    }
}
