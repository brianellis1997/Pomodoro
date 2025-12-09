import Foundation
import SwiftData

@Model
final class UserStats {
    var id: UUID
    var totalPoints: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastStudyDate: Date?
    var totalSessionsCompleted: Int
    var totalMinutesStudied: Int
    var level: Int
    var createdAt: Date
    var focusModeSessionsCompleted: Int
    var focusModeSessionsFailed: Int
    var currentFocusStreak: Int
    var longestFocusStreak: Int
    var unlockedAchievementsData: String

    var unlockedAchievements: [String] {
        get {
            guard !unlockedAchievementsData.isEmpty else { return [] }
            return unlockedAchievementsData.components(separatedBy: ",")
        }
        set {
            unlockedAchievementsData = newValue.joined(separator: ",")
        }
    }

    init(
        id: UUID = UUID(),
        totalPoints: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastStudyDate: Date? = nil,
        totalSessionsCompleted: Int = 0,
        totalMinutesStudied: Int = 0,
        level: Int = 1,
        createdAt: Date = Date(),
        focusModeSessionsCompleted: Int = 0,
        focusModeSessionsFailed: Int = 0,
        currentFocusStreak: Int = 0,
        longestFocusStreak: Int = 0,
        unlockedAchievements: [String] = []
    ) {
        self.id = id
        self.totalPoints = totalPoints
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastStudyDate = lastStudyDate
        self.totalSessionsCompleted = totalSessionsCompleted
        self.totalMinutesStudied = totalMinutesStudied
        self.level = level
        self.createdAt = createdAt
        self.focusModeSessionsCompleted = focusModeSessionsCompleted
        self.focusModeSessionsFailed = focusModeSessionsFailed
        self.currentFocusStreak = currentFocusStreak
        self.longestFocusStreak = longestFocusStreak
        self.unlockedAchievementsData = unlockedAchievements.joined(separator: ",")
    }

    static func pointsRequiredForLevel(_ level: Int) -> Int {
        if level <= 1 { return 0 }

        var total = 0
        for lvl in 1..<level {
            total += pointsForSingleLevel(lvl)
        }
        return total
    }

    static func pointsForSingleLevel(_ level: Int) -> Int {
        switch level {
        case 1...10:
            return 500
        case 11...25:
            return 1_000
        case 26...50:
            return 2_500
        case 51...75:
            return 5_000
        case 76...100:
            return 10_000
        default:
            return 25_000
        }
    }

    var pointsToNextLevel: Int {
        let nextLevelThreshold = UserStats.pointsRequiredForLevel(level + 1)
        return max(0, nextLevelThreshold - totalPoints)
    }

    var levelProgress: Double {
        let currentLevelThreshold = UserStats.pointsRequiredForLevel(level)
        let nextLevelThreshold = UserStats.pointsRequiredForLevel(level + 1)
        let pointsInCurrentLevel = totalPoints - currentLevelThreshold
        let pointsNeededForLevel = nextLevelThreshold - currentLevelThreshold
        guard pointsNeededForLevel > 0 else { return 1.0 }
        return Double(pointsInCurrentLevel) / Double(pointsNeededForLevel)
    }

    static func levelForPoints(_ points: Int) -> Int {
        var level = 1
        while pointsRequiredForLevel(level + 1) <= points {
            level += 1
        }
        return level
    }

    var rankTitle: String {
        switch level {
        case 1...5:
            return "Novice"
        case 6...10:
            return "Apprentice"
        case 11...15:
            return "Student"
        case 16...20:
            return "Scholar"
        case 21...25:
            return "Adept"
        case 26...30:
            return "Expert"
        case 31...40:
            return "Veteran"
        case 41...50:
            return "Master"
        case 51...60:
            return "Grandmaster"
        case 61...75:
            return "Sage"
        case 76...90:
            return "Legend"
        case 91...100:
            return "Mythic"
        default:
            return "Transcendent"
        }
    }
}
