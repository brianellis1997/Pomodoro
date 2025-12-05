import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @ObservedObject var statsService: StatsService
    @State private var selectedPeriod: StatsPeriod = .week
    @State private var selectedChartType: ChartType = .bar

    enum StatsPeriod: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case allTime = "All Time"
    }

    enum ChartType: String, CaseIterable {
        case bar = "Bar"
        case line = "Line"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                userLevelCard

                weeklyChartCard

                periodSelector

                timeStatsCard

                routineUsageCard

                streakCard

                achievementsPreview
            }
            .padding()
        }
        .background(Color.backgroundPrimary)
    }

    private var userLevelCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statsService.userStats?.rankTitle ?? "Novice")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Level \(statsService.userStats?.level ?? 1)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(statsService.userStats?.totalPoints ?? 0)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.pomodoroOrange)

                    Text("points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress to Level \((statsService.userStats?.level ?? 1) + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(statsService.userStats?.pointsToNextLevel ?? 500) pts to go")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.pomodoroOrange.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.pomodoroOrange)
                            .frame(width: geometry.size.width * (statsService.userStats?.levelProgress ?? 0), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This Week")
                    .font(.headline)

                Spacer()

                Picker("Chart Type", selection: $selectedChartType) {
                    ForEach(ChartType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            if statsService.weeklyData.isEmpty || statsService.weeklyData.allSatisfy({ $0.minutes == 0 }) {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No data yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Complete focus sessions to see your progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            } else {
                Chart(statsService.weeklyData) { day in
                    if selectedChartType == .bar {
                        BarMark(
                            x: .value("Day", day.dayLabel),
                            y: .value("Minutes", day.minutes)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pomodoroRed, .pomodoroOrange],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(4)
                    } else {
                        LineMark(
                            x: .value("Day", day.dayLabel),
                            y: .value("Minutes", day.minutes)
                        )
                        .foregroundStyle(Color.pomodoroRed)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                        AreaMark(
                            x: .value("Day", day.dayLabel),
                            y: .value("Minutes", day.minutes)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pomodoroRed.opacity(0.3), .pomodoroRed.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        PointMark(
                            x: .value("Day", day.dayLabel),
                            y: .value("Minutes", day.minutes)
                        )
                        .foregroundStyle(Color.pomodoroRed)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let minutes = value.as(Int.self) {
                                Text("\(minutes)m")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }

            HStack {
                Label("\(statsService.weeklyData.reduce(0) { $0 + $1.minutes }) min total", systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Label("\(statsService.weeklyData.reduce(0) { $0 + $1.sessions }) sessions", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StatsPeriod.allCases, id: \.self) { period in
                    Button(action: { selectedPeriod = period }) {
                        Text(period.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedPeriod == period ? .semibold : .regular)
                            .foregroundColor(selectedPeriod == period ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedPeriod == period ? Color.pomodoroRed : Color.backgroundSecondary)
                            )
                    }
                }
            }
        }
    }

    private var timeStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Study Time")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text(timeForPeriod)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.pomodoroRed)

                    Text(selectedPeriod.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 60)

                VStack(spacing: 8) {
                    Text("\(sessionsForPeriod)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.pomodoroGreen)

                    Text("Sessions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }

    private var routineUsageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Routine Usage")
                    .font(.headline)
                Spacer()
            }

            if statsService.routineUsage.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No routines used yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(statsService.routineUsage.prefix(5)) { usage in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(usage.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("\(usage.totalMinutes) min total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("\(usage.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.pomodoroBlue)

                            Text("times")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)

                        if usage.id != statsService.routineUsage.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }

                if !statsService.routineUsage.isEmpty {
                    let total = statsService.routineUsage.reduce(0) { $0 + $1.count }
                    Chart(statsService.routineUsage.prefix(5)) { usage in
                        SectorMark(
                            angle: .value("Count", usage.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Routine", usage.name))
                        .cornerRadius(4)
                    }
                    .chartLegend(position: .bottom, spacing: 10)
                    .frame(height: 200)
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }

    private var timeForPeriod: String {
        switch selectedPeriod {
        case .today:
            return statsService.formattedTodayTime
        case .week:
            return statsService.formattedWeekTime
        case .month:
            return statsService.formattedMonthTime
        case .year:
            return statsService.formattedYearTime
        case .allTime:
            return statsService.formattedAllTime
        }
    }

    private var sessionsForPeriod: Int {
        switch selectedPeriod {
        case .today:
            return statsService.todaySessions
        case .week:
            return statsService.weekSessions
        default:
            return statsService.userStats?.totalSessionsCompleted ?? 0
        }
    }

    private var streakCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundColor(.pomodoroOrange)

                Text("\(statsService.userStats?.currentStreak ?? 0)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Current Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 60)

            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundColor(.yellow)

                Text("\(statsService.userStats?.longestStreak ?? 0)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Best Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }

    private var achievementsPreview: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                achievementBadge(icon: "star.fill", title: "First Focus", unlocked: (statsService.userStats?.totalSessionsCompleted ?? 0) >= 1)
                achievementBadge(icon: "bolt.fill", title: "Power Hour", unlocked: (statsService.userStats?.totalMinutesStudied ?? 0) >= 60)
                achievementBadge(icon: "flame.fill", title: "Week Warrior", unlocked: (statsService.userStats?.currentStreak ?? 0) >= 7)
                achievementBadge(icon: "crown.fill", title: "Century", unlocked: (statsService.userStats?.totalSessionsCompleted ?? 0) >= 100)
                achievementBadge(icon: "moon.stars.fill", title: "Night Owl", unlocked: false)
                achievementBadge(icon: "sunrise.fill", title: "Early Bird", unlocked: false)
                achievementBadge(icon: "medal.fill", title: "Marathon", unlocked: (statsService.userStats?.totalMinutesStudied ?? 0) >= 600)
                achievementBadge(icon: "sparkles", title: "Legend", unlocked: (statsService.userStats?.level ?? 0) >= 50)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }

    private func achievementBadge(icon: String, title: String, unlocked: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(unlocked ? Color.pomodoroOrange : Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(unlocked ? .white : .gray)
            }

            Text(title)
                .font(.caption2)
                .foregroundColor(unlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
}
