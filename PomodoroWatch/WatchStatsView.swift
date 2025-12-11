import SwiftUI

struct WatchStatsView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @State private var totalSessions = 0
    @State private var totalMinutes = 0
    @State private var currentStreak = 0
    @State private var todaySessions = 0
    @State private var totalPoints = 0
    @State private var level = 1

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

                HStack(spacing: 8) {
                    StatCard(
                        title: "Points",
                        value: formatPoints(totalPoints),
                        subtitle: "earned",
                        color: .yellow
                    )

                    StatCard(
                        title: "Level",
                        value: "\(level)",
                        subtitle: levelTitle(level),
                        color: .purple
                    )
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Stats")
        .onAppear {
            loadStats()
            connectivityManager.requestStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: .statsReceived)) { notification in
            if let stats = notification.object as? [String: Any] {
                updateStats(from: stats)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .statsUpdateReceived)) { notification in
            if let stats = notification.object as? StatsUpdate {
                updateFromStatsUpdate(stats)
            }
        }
    }

    private func loadStats() {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")
        totalSessions = defaults?.integer(forKey: "stats_totalSessions") ?? 0
        totalMinutes = defaults?.integer(forKey: "stats_totalMinutes") ?? 0
        currentStreak = defaults?.integer(forKey: "stats_currentStreak") ?? 0
        todaySessions = defaults?.integer(forKey: "stats_todaySessions") ?? 0
        totalPoints = defaults?.integer(forKey: "stats_totalPoints") ?? 0
        level = defaults?.integer(forKey: "stats_level") ?? 1
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

    private func updateFromStatsUpdate(_ stats: StatsUpdate) {
        totalSessions = stats.totalSessions
        totalMinutes = stats.totalMinutes
        currentStreak = stats.currentStreak
        todaySessions = stats.todaySessions
        totalPoints = stats.totalPoints
        level = stats.level

        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")
        defaults?.set(stats.totalSessions, forKey: "stats_totalSessions")
        defaults?.set(stats.totalMinutes, forKey: "stats_totalMinutes")
        defaults?.set(stats.currentStreak, forKey: "stats_currentStreak")
        defaults?.set(stats.todaySessions, forKey: "stats_todaySessions")
        defaults?.set(stats.totalPoints, forKey: "stats_totalPoints")
        defaults?.set(stats.level, forKey: "stats_level")
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

    private func formatPoints(_ points: Int) -> String {
        if points >= 1000 {
            let k = Double(points) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(points)"
    }

    private func levelTitle(_ level: Int) -> String {
        switch level {
        case 1: return "beginner"
        case 2: return "novice"
        case 3: return "student"
        case 4: return "scholar"
        case 5: return "expert"
        case 6: return "master"
        case 7: return "sage"
        case 8: return "guru"
        case 9: return "legend"
        case 10: return "grandmaster"
        default: return "level \(level)"
        }
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
