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

    init(
        id: UUID = UUID(),
        totalPoints: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastStudyDate: Date? = nil,
        totalSessionsCompleted: Int = 0,
        totalMinutesStudied: Int = 0,
        level: Int = 1,
        createdAt: Date = Date()
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
    }

    var pointsToNextLevel: Int {
        let nextLevelThreshold = level * 500
        return max(0, nextLevelThreshold - totalPoints)
    }

    var levelProgress: Double {
        let previousLevelThreshold = (level - 1) * 500
        let nextLevelThreshold = level * 500
        let pointsInCurrentLevel = totalPoints - previousLevelThreshold
        let pointsNeededForLevel = nextLevelThreshold - previousLevelThreshold
        return Double(pointsInCurrentLevel) / Double(pointsNeededForLevel)
    }

    var rankTitle: String {
        switch level {
        case 1...5:
            return "Novice"
        case 6...10:
            return "Apprentice"
        case 11...20:
            return "Scholar"
        case 21...35:
            return "Expert"
        case 36...50:
            return "Master"
        case 51...75:
            return "Grandmaster"
        default:
            return "Legend"
        }
    }
}
