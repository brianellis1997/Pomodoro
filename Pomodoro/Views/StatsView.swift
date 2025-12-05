import SwiftUI
import SwiftData

struct StatsView: View {
    @ObservedObject var statsService: StatsService
    @State private var selectedPeriod: StatsPeriod = .today

    enum StatsPeriod: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case allTime = "All Time"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                userLevelCard

                periodSelector

                timeStatsCard

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
                        .font(.system(size: 44, weight: .bold, design: .rounded))
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
                        .font(.system(size: 44, weight: .bold, design: .rounded))
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
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                achievementBadge(icon: "star.fill", title: "First Focus", unlocked: (statsService.userStats?.totalSessionsCompleted ?? 0) >= 1)
                achievementBadge(icon: "bolt.fill", title: "Power Hour", unlocked: (statsService.userStats?.totalMinutesStudied ?? 0) >= 60)
                achievementBadge(icon: "flame.fill", title: "Week Warrior", unlocked: (statsService.userStats?.currentStreak ?? 0) >= 7)
                achievementBadge(icon: "crown.fill", title: "Century", unlocked: (statsService.userStats?.totalSessionsCompleted ?? 0) >= 100)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }

    private func achievementBadge(icon: String, title: String, unlocked: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(unlocked ? Color.pomodoroOrange : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(unlocked ? .white : .gray)
            }

            Text(title)
                .font(.caption2)
                .foregroundColor(unlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
