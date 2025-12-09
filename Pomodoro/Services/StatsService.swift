import Foundation
import SwiftData

struct DailyStats: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
    let sessions: Int

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

struct RoutineUsage: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let totalMinutes: Int
}

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

    @Published var weeklyData: [DailyStats] = []
    @Published var monthlyData: [DailyStats] = []
    @Published var routineUsage: [RoutineUsage] = []

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadStats()
    }

    func loadStats() {
        guard let context = modelContext else { return }

        loadUserStats(context: context)
        calculateTimeStats(context: context)
        calculateChartData(context: context)
        calculateRoutineUsage(context: context)
        syncStatsToWatch()
    }

    private func syncStatsToWatch() {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")
        defaults?.set(userStats?.totalSessionsCompleted ?? 0, forKey: "stats_totalSessions")
        defaults?.set(userStats?.totalMinutesStudied ?? 0, forKey: "stats_totalMinutes")
        defaults?.set(userStats?.currentStreak ?? 0, forKey: "stats_currentStreak")
        defaults?.set(todaySessions, forKey: "stats_todaySessions")
        defaults?.set(userStats?.totalPoints ?? 0, forKey: "stats_totalPoints")
        defaults?.set(userStats?.level ?? 1, forKey: "stats_level")
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

    func recordSession(routineName: String, durationMinutes: Int, wasFullSession: Bool = true, hadFocusViolation: Bool = false) {
        guard let context = modelContext else { return }

        let basePoints = durationMinutes * 2
        var bonusMultiplier = wasFullSession ? 1.5 : 1.0

        if hadFocusViolation {
            bonusMultiplier = 0.5
        }

        let streakBonus = hadFocusViolation ? 0 : min((userStats?.currentStreak ?? 0) * 5, 50)
        let pointsEarned = Int(Double(basePoints) * bonusMultiplier) + streakBonus

        let session = StudySession(
            routineName: routineName,
            durationMinutes: durationMinutes,
            pointsEarned: pointsEarned,
            wasFullSession: wasFullSession && !hadFocusViolation
        )

        context.insert(session)

        if var stats = userStats {
            stats.totalPoints += pointsEarned
            stats.totalSessionsCompleted += 1
            stats.totalMinutesStudied += durationMinutes
            stats.lastStudyDate = Date()
            updateStreak()
            stats.level = UserStats.levelForPoints(stats.totalPoints)
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

    private func calculateChartData(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var weekly: [DailyStats] = []
        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date

            let stats = fetchDayStats(from: date, to: nextDay, context: context)
            weekly.append(stats)
        }
        weeklyData = weekly

        var monthly: [DailyStats] = []
        for dayOffset in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date

            let stats = fetchDayStats(from: date, to: nextDay, context: context)
            monthly.append(stats)
        }
        monthlyData = monthly
    }

    private func fetchDayStats(from startDate: Date, to endDate: Date, context: ModelContext) -> DailyStats {
        let predicate = #Predicate<StudySession> { session in
            session.completedAt >= startDate && session.completedAt < endDate
        }
        let descriptor = FetchDescriptor<StudySession>(predicate: predicate)

        do {
            let sessions = try context.fetch(descriptor)
            let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
            return DailyStats(date: startDate, minutes: totalMinutes, sessions: sessions.count)
        } catch {
            return DailyStats(date: startDate, minutes: 0, sessions: 0)
        }
    }

    private func calculateRoutineUsage(context: ModelContext) {
        let descriptor = FetchDescriptor<StudySession>()

        do {
            let sessions = try context.fetch(descriptor)

            var usageDict: [String: (count: Int, minutes: Int)] = [:]
            for session in sessions {
                let current = usageDict[session.routineName] ?? (0, 0)
                usageDict[session.routineName] = (current.count + 1, current.minutes + session.durationMinutes)
            }

            routineUsage = usageDict.map { name, data in
                RoutineUsage(name: name, count: data.count, totalMinutes: data.minutes)
            }.sorted { $0.count > $1.count }
        } catch {
            routineUsage = []
        }
    }
}
