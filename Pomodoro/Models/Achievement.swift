import Foundation

struct Achievement: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let pointsReward: Int
    let requirement: AchievementRequirement

    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id
    }

    enum AchievementCategory: String, CaseIterable {
        case focus = "Focus Mode"
        case sessions = "Sessions"
        case streaks = "Streaks"
        case time = "Time"
        case milestones = "Milestones"
    }

    enum AchievementRequirement {
        case focusSessionsCompleted(Int)
        case focusStreakReached(Int)
        case totalSessionsCompleted(Int)
        case totalMinutesStudied(Int)
        case dailyStreakReached(Int)
        case levelReached(Int)
        case totalPointsEarned(Int)
    }

    func isUnlocked(by stats: UserStats) -> Bool {
        switch requirement {
        case .focusSessionsCompleted(let count):
            return stats.focusModeSessionsCompleted >= count
        case .focusStreakReached(let count):
            return stats.longestFocusStreak >= count
        case .totalSessionsCompleted(let count):
            return stats.totalSessionsCompleted >= count
        case .totalMinutesStudied(let minutes):
            return stats.totalMinutesStudied >= minutes
        case .dailyStreakReached(let count):
            return stats.longestStreak >= count
        case .levelReached(let level):
            return stats.level >= level
        case .totalPointsEarned(let points):
            return stats.totalPoints >= points
        }
    }

    static let allAchievements: [Achievement] = focusAchievements + sessionAchievements + streakAchievements + timeAchievements + milestoneAchievements

    static let focusAchievements: [Achievement] = [
        Achievement(
            id: "focus_first",
            name: "Laser Focus",
            description: "Complete your first focus mode session",
            icon: "eye.fill",
            category: .focus,
            pointsReward: 100,
            requirement: .focusSessionsCompleted(1)
        ),
        Achievement(
            id: "focus_10",
            name: "Concentrated Mind",
            description: "Complete 10 focus mode sessions",
            icon: "brain.head.profile",
            category: .focus,
            pointsReward: 250,
            requirement: .focusSessionsCompleted(10)
        ),
        Achievement(
            id: "focus_50",
            name: "Unwavering",
            description: "Complete 50 focus mode sessions",
            icon: "scope",
            category: .focus,
            pointsReward: 500,
            requirement: .focusSessionsCompleted(50)
        ),
        Achievement(
            id: "focus_100",
            name: "Zen Master",
            description: "Complete 100 focus mode sessions",
            icon: "figure.mind.and.body",
            category: .focus,
            pointsReward: 1000,
            requirement: .focusSessionsCompleted(100)
        ),
        Achievement(
            id: "focus_500",
            name: "Unbreakable Will",
            description: "Complete 500 focus mode sessions",
            icon: "diamond.fill",
            category: .focus,
            pointsReward: 2500,
            requirement: .focusSessionsCompleted(500)
        ),
        Achievement(
            id: "focus_streak_5",
            name: "Getting in the Zone",
            description: "Complete 5 focus sessions in a row without violations",
            icon: "flame",
            category: .focus,
            pointsReward: 200,
            requirement: .focusStreakReached(5)
        ),
        Achievement(
            id: "focus_streak_10",
            name: "Deep Focus",
            description: "Complete 10 focus sessions in a row without violations",
            icon: "flame.fill",
            category: .focus,
            pointsReward: 500,
            requirement: .focusStreakReached(10)
        ),
        Achievement(
            id: "focus_streak_25",
            name: "Hyperfocus",
            description: "Complete 25 focus sessions in a row without violations",
            icon: "bolt.fill",
            category: .focus,
            pointsReward: 1000,
            requirement: .focusStreakReached(25)
        ),
        Achievement(
            id: "focus_streak_50",
            name: "Flow State Master",
            description: "Complete 50 focus sessions in a row without violations",
            icon: "sparkles",
            category: .focus,
            pointsReward: 2500,
            requirement: .focusStreakReached(50)
        ),
        Achievement(
            id: "focus_streak_100",
            name: "Legendary Focus",
            description: "Complete 100 focus sessions in a row without violations",
            icon: "crown.fill",
            category: .focus,
            pointsReward: 5000,
            requirement: .focusStreakReached(100)
        )
    ]

    static let sessionAchievements: [Achievement] = [
        Achievement(
            id: "sessions_first",
            name: "First Step",
            description: "Complete your first session",
            icon: "play.circle.fill",
            category: .sessions,
            pointsReward: 50,
            requirement: .totalSessionsCompleted(1)
        ),
        Achievement(
            id: "sessions_10",
            name: "Getting Started",
            description: "Complete 10 sessions",
            icon: "checkmark.circle",
            category: .sessions,
            pointsReward: 100,
            requirement: .totalSessionsCompleted(10)
        ),
        Achievement(
            id: "sessions_50",
            name: "Building Habits",
            description: "Complete 50 sessions",
            icon: "checkmark.circle.fill",
            category: .sessions,
            pointsReward: 250,
            requirement: .totalSessionsCompleted(50)
        ),
        Achievement(
            id: "sessions_100",
            name: "Century Club",
            description: "Complete 100 sessions",
            icon: "100.circle.fill",
            category: .sessions,
            pointsReward: 500,
            requirement: .totalSessionsCompleted(100)
        ),
        Achievement(
            id: "sessions_500",
            name: "Dedicated",
            description: "Complete 500 sessions",
            icon: "star.circle.fill",
            category: .sessions,
            pointsReward: 1500,
            requirement: .totalSessionsCompleted(500)
        ),
        Achievement(
            id: "sessions_1000",
            name: "Pomodoro Legend",
            description: "Complete 1000 sessions",
            icon: "medal.fill",
            category: .sessions,
            pointsReward: 3000,
            requirement: .totalSessionsCompleted(1000)
        )
    ]

    static let streakAchievements: [Achievement] = [
        Achievement(
            id: "streak_3",
            name: "Consistency",
            description: "Study for 3 days in a row",
            icon: "calendar",
            category: .streaks,
            pointsReward: 100,
            requirement: .dailyStreakReached(3)
        ),
        Achievement(
            id: "streak_7",
            name: "Week Warrior",
            description: "Study for 7 days in a row",
            icon: "calendar.badge.checkmark",
            category: .streaks,
            pointsReward: 250,
            requirement: .dailyStreakReached(7)
        ),
        Achievement(
            id: "streak_14",
            name: "Fortnight Focus",
            description: "Study for 14 days in a row",
            icon: "calendar.circle",
            category: .streaks,
            pointsReward: 500,
            requirement: .dailyStreakReached(14)
        ),
        Achievement(
            id: "streak_30",
            name: "Monthly Master",
            description: "Study for 30 days in a row",
            icon: "calendar.circle.fill",
            category: .streaks,
            pointsReward: 1000,
            requirement: .dailyStreakReached(30)
        ),
        Achievement(
            id: "streak_100",
            name: "Unstoppable",
            description: "Study for 100 days in a row",
            icon: "flame.circle.fill",
            category: .streaks,
            pointsReward: 5000,
            requirement: .dailyStreakReached(100)
        ),
        Achievement(
            id: "streak_365",
            name: "Year of Growth",
            description: "Study for 365 days in a row",
            icon: "trophy.fill",
            category: .streaks,
            pointsReward: 25000,
            requirement: .dailyStreakReached(365)
        )
    ]

    static let timeAchievements: [Achievement] = [
        Achievement(
            id: "time_60",
            name: "First Hour",
            description: "Study for a total of 1 hour",
            icon: "clock",
            category: .time,
            pointsReward: 50,
            requirement: .totalMinutesStudied(60)
        ),
        Achievement(
            id: "time_600",
            name: "Ten Hours",
            description: "Study for a total of 10 hours",
            icon: "clock.fill",
            category: .time,
            pointsReward: 200,
            requirement: .totalMinutesStudied(600)
        ),
        Achievement(
            id: "time_3000",
            name: "Fifty Hours",
            description: "Study for a total of 50 hours",
            icon: "hourglass",
            category: .time,
            pointsReward: 500,
            requirement: .totalMinutesStudied(3000)
        ),
        Achievement(
            id: "time_6000",
            name: "Century of Hours",
            description: "Study for a total of 100 hours",
            icon: "hourglass.bottomhalf.filled",
            category: .time,
            pointsReward: 1000,
            requirement: .totalMinutesStudied(6000)
        ),
        Achievement(
            id: "time_30000",
            name: "500 Hour Club",
            description: "Study for a total of 500 hours",
            icon: "hourglass.tophalf.filled",
            category: .time,
            pointsReward: 5000,
            requirement: .totalMinutesStudied(30000)
        ),
        Achievement(
            id: "time_60000",
            name: "Thousand Hour Master",
            description: "Study for a total of 1000 hours",
            icon: "timer.circle.fill",
            category: .time,
            pointsReward: 10000,
            requirement: .totalMinutesStudied(60000)
        )
    ]

    static let milestoneAchievements: [Achievement] = [
        Achievement(
            id: "level_10",
            name: "Apprentice",
            description: "Reach level 10",
            icon: "star",
            category: .milestones,
            pointsReward: 500,
            requirement: .levelReached(10)
        ),
        Achievement(
            id: "level_25",
            name: "Adept",
            description: "Reach level 25",
            icon: "star.fill",
            category: .milestones,
            pointsReward: 1000,
            requirement: .levelReached(25)
        ),
        Achievement(
            id: "level_50",
            name: "Master",
            description: "Reach level 50",
            icon: "star.circle",
            category: .milestones,
            pointsReward: 2500,
            requirement: .levelReached(50)
        ),
        Achievement(
            id: "level_75",
            name: "Sage",
            description: "Reach level 75",
            icon: "star.circle.fill",
            category: .milestones,
            pointsReward: 5000,
            requirement: .levelReached(75)
        ),
        Achievement(
            id: "level_100",
            name: "Legend",
            description: "Reach level 100",
            icon: "crown",
            category: .milestones,
            pointsReward: 10000,
            requirement: .levelReached(100)
        ),
        Achievement(
            id: "points_10000",
            name: "Point Collector",
            description: "Earn 10,000 total points",
            icon: "dollarsign.circle",
            category: .milestones,
            pointsReward: 500,
            requirement: .totalPointsEarned(10000)
        ),
        Achievement(
            id: "points_100000",
            name: "Point Hoarder",
            description: "Earn 100,000 total points",
            icon: "dollarsign.circle.fill",
            category: .milestones,
            pointsReward: 2500,
            requirement: .totalPointsEarned(100000)
        ),
        Achievement(
            id: "points_500000",
            name: "Point Mogul",
            description: "Earn 500,000 total points",
            icon: "banknote.fill",
            category: .milestones,
            pointsReward: 10000,
            requirement: .totalPointsEarned(500000)
        )
    ]
}
