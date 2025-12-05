import SwiftUI
import SwiftData

@main
struct PomodoroApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Routine.self,
            StudySession.self,
            UserStats.self,
            AppSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
