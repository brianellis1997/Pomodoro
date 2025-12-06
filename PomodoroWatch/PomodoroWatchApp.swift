import SwiftUI

@main
struct PomodoroWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchMainView()
        }
    }
}

struct WatchMainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WatchTimerView()
                .tag(0)

            WatchStatsView()
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}
