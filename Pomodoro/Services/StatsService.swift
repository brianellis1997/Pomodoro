import Foundation
import SwiftData

@MainActor
class StatsService: ObservableObject {
    private var modelContext: ModelContext?

    @Published var todayMinutes: Int = 0
    @Published var weekMinutes: Int = 0
    @Published var monthMinutes: Int = 0
    @Published var yearMinutes: Int = 0
    @Published var allTimeMinutes: Int = 0

    @Published var todaySessions: Int = 0
    @Published var weekSessions: Int = 0

    @Published var userStats: UserStats?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadStats()
    }

    func loadStats() {
        guard let context = modelContext else { return }

        loadUserStats(context: context)
        calculateTimeStats(context: context)
    }

    private func loadUserStats(context: ModelContext) {
        let descriptor = FetchDescriptor<UserStats>()
        do {
            let stats = try context.fetch(descriptor)
            if let existingStats = stats.first {
                userStats = existingStats
                updateStreak()
            } else {
                let newStats = UserStats()
                context.insert(newStats)
                try? context.save()
                userStats = newStats
            }
        } catch {
            print("Failed to fetch user stats: \(error)")
        }
    }

    private func calculateTimeStats(context: ModelContext) {
        let now = Date()
        let calendar = Calendar.current

        let startOfDay = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now

        todayMinutes = fetchMinutes(since: startOfDay, context: context)
        weekMinutes = fetchMinutes(since: startOfWeek, context: context)
        monthMinutes = fetchMinutes(since: startOfMonth, context: context)
        yearMinutes = fetchMinutes(since: startOfYear, context: context)
        allTimeMinutes = fetchMinutes(since: .distantPast, context: context)

        todaySessions = fetchSessionCount(since: startOfDay, context: context)
        weekSessions = fetchSessionCount(since: startOfWeek, context: context)
    }

    private func fetchMinutes(since date: Date, context: ModelContext) -> Int {
        let predicate = #Predicate<StudySession> { session in
            session.completedAt >= date
        }
        let descriptor = FetchDescriptor<StudySession>(predicate: predicate)

        do {
            let sessions = try context.fetch(descriptor)
            return sessions.reduce(0) { $0 + $1.durationMinutes }
        } catch {
            return 0
        }
    }

    private func fetchSessionCount(since date: Date, context: ModelContext) -> Int {
        let predicate = #Predicate<StudySession> { session in
            session.completedAt >= date
        }
        let descriptor = FetchDescriptor<StudySession>(predicate: predicate)

        do {
            return try context.fetch(descriptor).count
        } catch {
            return 0
        }
    }

    func recordSession(routineName: String, durationMinutes: Int, wasFullSession: Bool = true) {
        guard let context = modelContext else { return }

        let basePoints = durationMinutes * 2
        let bonusMultiplier = wasFullSession ? 1.5 : 1.0
        let streakBonus = min((userStats?.currentStreak ?? 0) * 5, 50)
        let pointsEarned = Int(Double(basePoints) * bonusMultiplier) + streakBonus

        let session = StudySession(
            routineName: routineName,
            durationMinutes: durationMinutes,
            pointsEarned: pointsEarned,
            wasFullSession: wasFullSession
        )

        context.insert(session)

        if var stats = userStats {
            stats.totalPoints += pointsEarned
            stats.totalSessionsCompleted += 1
            stats.totalMinutesStudied += durationMinutes
            stats.lastStudyDate = Date()

            updateStreak()

            while stats.totalPoints >= stats.level * 500 {
                stats.level += 1
            }
        }

        try? context.save()
        loadStats()
    }

    private func updateStreak() {
        guard var stats = userStats else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastStudy = stats.lastStudyDate {
            let lastStudyDay = calendar.startOfDay(for: lastStudy)
            let daysDiff = calendar.dateComponents([.day], from: lastStudyDay, to: today).day ?? 0

            if daysDiff == 0 {
                // Same day, streak continues
            } else if daysDiff == 1 {
                stats.currentStreak += 1
                if stats.currentStreak > stats.longestStreak {
                    stats.longestStreak = stats.currentStreak
                }
            } else {
                stats.currentStreak = 1
            }
        } else {
            stats.currentStreak = 1
        }
    }

    var formattedTodayTime: String {
        formatTime(minutes: todayMinutes)
    }

    var formattedWeekTime: String {
        formatTime(minutes: weekMinutes)
    }

    var formattedMonthTime: String {
        formatTime(minutes: monthMinutes)
    }

    var formattedYearTime: String {
        formatTime(minutes: yearMinutes)
    }

    var formattedAllTime: String {
        formatTime(minutes: allTimeMinutes)
    }

    private func formatTime(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }
}
