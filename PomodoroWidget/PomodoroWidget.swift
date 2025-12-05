import WidgetKit
import SwiftUI

struct PomodoroProvider: TimelineProvider {
    func placeholder(in context: Context) -> PomodoroEntry {
        PomodoroEntry(
            date: Date(),
            remainingTime: 25 * 60,
            totalTime: 25 * 60,
            phase: .work,
            currentRound: 1,
            totalRounds: 4,
            isRunning: false,
            routineName: "Classic Pomodoro"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PomodoroEntry) -> Void) {
        let entry = loadCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroEntry>) -> Void) {
        let entry = loadCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadCurrentEntry() -> PomodoroEntry {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")

        let remainingTime = defaults?.double(forKey: "remainingTime") ?? 25 * 60
        let totalTime = defaults?.double(forKey: "totalTime") ?? 25 * 60
        let phaseRaw = defaults?.string(forKey: "phase") ?? "work"
        let currentRound = defaults?.integer(forKey: "currentRound") ?? 1
        let totalRounds = defaults?.integer(forKey: "totalRounds") ?? 4
        let isRunning = defaults?.bool(forKey: "isRunning") ?? false
        let routineName = defaults?.string(forKey: "routineName") ?? "Classic Pomodoro"

        let phase: TimerPhase
        switch phaseRaw {
        case "shortBreak": phase = .shortBreak
        case "longBreak": phase = .longBreak
        default: phase = .work
        }

        return PomodoroEntry(
            date: Date(),
            remainingTime: remainingTime,
            totalTime: totalTime,
            phase: phase,
            currentRound: currentRound,
            totalRounds: totalRounds,
            isRunning: isRunning,
            routineName: routineName
        )
    }
}

struct PomodoroEntry: TimelineEntry {
    let date: Date
    let remainingTime: TimeInterval
    let totalTime: TimeInterval
    let phase: TimerPhase
    let currentRound: Int
    let totalRounds: Int
    let isRunning: Bool
    let routineName: String

    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1.0 - (remainingTime / totalTime)
    }

    var timeString: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var phaseColor: Color {
        switch phase {
        case .work: return .pomodoroRed
        case .shortBreak: return .pomodoroGreen
        case .longBreak: return .pomodoroBlue
        }
    }

    var phaseLabel: String {
        switch phase {
        case .work: return "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long Break"
        }
    }
}

struct PomodoroWidgetEntryView: View {
    var entry: PomodoroProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(entry.phaseColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(entry.timeString)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(entry.phaseLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            HStack(spacing: 4) {
                ForEach(0..<entry.totalRounds, id: \.self) { index in
                    Circle()
                        .fill(index < entry.currentRound ? entry.phaseColor : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.backgroundPrimary
        }
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(entry.phaseColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(entry.timeString)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.routineName)
                    .font(.headline)
                    .lineLimit(1)

                Text(entry.phaseLabel)
                    .font(.subheadline)
                    .foregroundColor(entry.phaseColor)

                HStack(spacing: 4) {
                    Text("Round \(entry.currentRound)/\(entry.totalRounds)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if entry.isRunning {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Running")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                        Text("Paused")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.backgroundPrimary
        }
    }

    private var largeWidget: some View {
        VStack(spacing: 16) {
            Text(entry.routineName)
                .font(.headline)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(entry.phaseColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(entry.timeString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(entry.phaseLabel)
                        .font(.title3)
                        .foregroundColor(entry.phaseColor)
                }
            }
            .frame(width: 180, height: 180)

            HStack(spacing: 8) {
                ForEach(0..<entry.totalRounds, id: \.self) { index in
                    Circle()
                        .fill(index < entry.currentRound ? entry.phaseColor : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }

            if entry.isRunning {
                Label("Timer Running", systemImage: "timer")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Label("Timer Paused", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .containerBackground(for: .widget) {
            Color.backgroundPrimary
        }
    }
}

struct PomodoroWidget: Widget {
    let kind: String = "PomodoroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomodoroProvider()) { entry in
            PomodoroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pomodoro Timer")
        .description("Track your focus sessions at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    PomodoroWidget()
} timeline: {
    PomodoroEntry(
        date: Date(),
        remainingTime: 15 * 60,
        totalTime: 25 * 60,
        phase: .work,
        currentRound: 2,
        totalRounds: 4,
        isRunning: true,
        routineName: "Classic Pomodoro"
    )
}

#Preview(as: .systemMedium) {
    PomodoroWidget()
} timeline: {
    PomodoroEntry(
        date: Date(),
        remainingTime: 5 * 60,
        totalTime: 5 * 60,
        phase: .shortBreak,
        currentRound: 2,
        totalRounds: 4,
        isRunning: true,
        routineName: "Deep Work Session"
    )
}
