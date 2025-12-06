import SwiftUI

struct WatchStatsView: View {
    @State private var totalSessions = 0
    @State private var totalMinutes = 0
    @State private var currentStreak = 0
    @State private var todaySessions = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    StatCard(
                        title: "Today",
                        value: "\(todaySessions)",
                        subtitle: "sessions",
                        color: .pomodoroRed
                    )

                    StatCard(
                        title: "Streak",
                        value: "\(currentStreak)",
                        subtitle: "days",
                        color: .pomodoroOrange
                    )
                }

                HStack(spacing: 8) {
                    StatCard(
                        title: "Total",
                        value: "\(totalSessions)",
                        subtitle: "sessions",
                        color: .pomodoroGreen
                    )

                    StatCard(
                        title: "Focus",
                        value: formatTime(totalMinutes),
                        subtitle: "total",
                        color: .pomodoroBlue
                    )
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Stats")
        .onAppear {
            loadStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: .statsReceived)) { notification in
            if let stats = notification.object as? [String: Any] {
                updateStats(from: stats)
            }
        }
    }

    private func loadStats() {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")
        totalSessions = defaults?.integer(forKey: "stats_totalSessions") ?? 0
        totalMinutes = defaults?.integer(forKey: "stats_totalMinutes") ?? 0
        currentStreak = defaults?.integer(forKey: "stats_currentStreak") ?? 0
        todaySessions = defaults?.integer(forKey: "stats_todaySessions") ?? 0
    }

    private func updateStats(from stats: [String: Any]) {
        if let sessions = stats["totalSessions"] as? Int {
            totalSessions = sessions
        }
        if let minutes = stats["totalMinutes"] as? Int {
            totalMinutes = minutes
        }
        if let streak = stats["currentStreak"] as? Int {
            currentStreak = streak
        }
        if let today = stats["todaySessions"] as? Int {
            todaySessions = today
        }
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.backgroundSecondary)
        .cornerRadius(8)
    }
}

extension Notification.Name {
    static let statsReceived = Notification.Name("statsReceived")
}

#Preview {
    WatchStatsView()
}
