import SwiftUI

struct AchievementsView: View {
    @ObservedObject var statsService: StatsService
    @State private var selectedCategory: Achievement.AchievementCategory?

    private var unlockedIds: Set<String> {
        Set(statsService.userStats?.unlockedAchievements ?? [])
    }

    private var filteredAchievements: [Achievement] {
        if let category = selectedCategory {
            return Achievement.allAchievements.filter { $0.category == category }
        }
        return Achievement.allAchievements
    }

    private var unlockedCount: Int {
        Achievement.allAchievements.filter { unlockedIds.contains($0.id) }.count
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    progressHeader

                    categoryPicker

                    achievementsList
                }
                .padding()
            }
            .navigationTitle("Achievements")
            .background(Color.backgroundPrimary)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text("\(unlockedCount) / \(Achievement.allAchievements.count)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.pomodoroRed)

            Text("Achievements Unlocked")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ProgressView(value: Double(unlockedCount), total: Double(Achievement.allAchievements.count))
                .tint(.pomodoroRed)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryButton(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                ForEach(Achievement.AchievementCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        title: category.rawValue,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
        }
    }

    private var achievementsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredAchievements) { achievement in
                AchievementRow(
                    achievement: achievement,
                    isUnlocked: unlockedIds.contains(achievement.id)
                )
            }
        }
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.pomodoroRed : Color.backgroundSecondary)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.pomodoroRed : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)

                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(isUnlocked ? .white : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)
                    .foregroundColor(isUnlocked ? .primary : .secondary)

                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Text("+\(achievement.pointsReward)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.pomodoroOrange)
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
        .opacity(isUnlocked ? 1.0 : 0.7)
    }
}

struct AchievementUnlockAlert: View {
    let achievements: [Achievement]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)

            Text(achievements.count == 1 ? "Achievement Unlocked!" : "Achievements Unlocked!")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                ForEach(achievements) { achievement in
                    HStack(spacing: 12) {
                        Image(systemName: achievement.icon)
                            .font(.title3)
                            .foregroundColor(.pomodoroRed)

                        VStack(alignment: .leading) {
                            Text(achievement.name)
                                .font(.headline)
                            Text("+\(achievement.pointsReward) points")
                                .font(.caption)
                                .foregroundColor(.pomodoroOrange)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color.backgroundSecondary)
                    .cornerRadius(8)
                }
            }

            Button("Awesome!") {
                onDismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .background(Color.pomodoroRed)
            .cornerRadius(25)
        }
        .padding(24)
        .background(Color.backgroundPrimary)
        .cornerRadius(20)
        .shadow(radius: 20)
        .padding(40)
    }
}

#Preview {
    AchievementsView(statsService: StatsService())
}
