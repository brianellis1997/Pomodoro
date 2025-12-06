import WidgetKit
import SwiftUI

struct WatchPomodoroProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchPomodoroEntry {
        WatchPomodoroEntry(
            date: Date(),
            remainingTime: 25 * 60,
            totalTime: 25 * 60,
            phase: .work,
            currentRound: 1,
            totalRounds: 4,
            isRunning: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchPomodoroEntry) -> Void) {
        let entry = loadCurrentEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchPomodoroEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")
        let isRunning = defaults?.bool(forKey: "isRunning") ?? false
        let endTimeInterval = defaults?.double(forKey: "endTime") ?? 0

        if isRunning && endTimeInterval > 0 {
            let endTime = Date(timeIntervalSince1970: endTimeInterval)
            let now = Date()

            if endTime > now {
                var entries: [WatchPomodoroEntry] = []
                var currentDate = now

                while currentDate < endTime && entries.count < 60 {
                    let entry = loadCurrentEntry(for: currentDate, endTime: endTime)
                    entries.append(entry)
                    currentDate = currentDate.addingTimeInterval(30)
                }

                let finalEntry = loadCurrentEntry(for: endTime, endTime: endTime)
                entries.append(finalEntry)

                let timeline = Timeline(entries: entries, policy: .after(endTime))
                completion(timeline)
                return
            }
        }

        let entry = loadCurrentEntry(for: Date())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadCurrentEntry(for date: Date, endTime: Date? = nil) -> WatchPomodoroEntry {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")

        let storedTotalTime = defaults?.double(forKey: "totalTime") ?? 0
        let phaseRaw = defaults?.string(forKey: "phase") ?? "work"
        let storedCurrentRound = defaults?.integer(forKey: "currentRound")
        let storedTotalRounds = defaults?.integer(forKey: "totalRounds")
        let isRunning = defaults?.bool(forKey: "isRunning") ?? false

        let totalTime = storedTotalTime > 0 ? storedTotalTime : 25 * 60
        let currentRound = (storedCurrentRound ?? 0) > 0 ? storedCurrentRound! : 1
        let totalRounds = (storedTotalRounds ?? 0) > 0 ? storedTotalRounds! : 4

        let remainingTime: TimeInterval
        if let endTime = endTime, isRunning {
            remainingTime = max(0, endTime.timeIntervalSince(date))
        } else {
            let storedRemainingTime = defaults?.double(forKey: "remainingTime") ?? 0
            remainingTime = storedRemainingTime > 0 ? storedRemainingTime : 25 * 60
        }

        let phase: TimerPhase
        switch phaseRaw {
        case "shortBreak": phase = .shortBreak
        case "longBreak": phase = .longBreak
        default: phase = .work
        }

        return WatchPomodoroEntry(
            date: date,
            remainingTime: remainingTime,
            totalTime: totalTime,
            phase: phase,
            currentRound: currentRound,
            totalRounds: totalRounds,
            isRunning: isRunning
        )
    }
}

struct WatchPomodoroEntry: TimelineEntry {
    let date: Date
    let remainingTime: TimeInterval
    let totalTime: TimeInterval
    let phase: TimerPhase
    let currentRound: Int
    let totalRounds: Int
    let isRunning: Bool

    var progress: Double {
        guard totalTime > 0 else { return 1 }
        return remainingTime / totalTime
    }

    var timeString: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var shortTimeString: String {
        let minutes = Int(remainingTime) / 60
        return "\(minutes)m"
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

    var shortPhaseLabel: String {
        switch phase {
        case .work: return "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long"
        }
    }
}

struct PomodoroWatchWidgetEntryView: View {
    var entry: WatchPomodoroProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryCorner:
            accessoryCorner
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            accessoryInline
        default:
            accessoryCircular
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)

            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(entry.phaseColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: -1, y: 1)

            Text(entry.shortTimeString)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .padding(2)
    }

    private var accessoryCorner: some View {
        Text(entry.shortTimeString)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .widgetCurvesContent()
            .widgetLabel {
                ProgressView(value: entry.progress)
                    .tint(entry.phaseColor)
            }
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(entry.phaseColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x: -1, y: 1)

                Image("TomatoIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.timeString)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(entry.phaseLabel)
                    .font(.caption2)
                    .foregroundColor(entry.phaseColor)

                Text("Round \(entry.currentRound)/\(entry.totalRounds)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var accessoryInline: some View {
        Text(entry.timeString)
            .monospacedDigit()
    }
}

@main
struct PomodoroWatchWidget: Widget {
    let kind: String = "PomodoroWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchPomodoroProvider()) { entry in
            PomodoroWatchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pomodoro")
        .description("Track your focus timer")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

#Preview(as: .accessoryCircular) {
    PomodoroWatchWidget()
} timeline: {
    WatchPomodoroEntry(
        date: Date(),
        remainingTime: 15 * 60,
        totalTime: 25 * 60,
        phase: .work,
        currentRound: 2,
        totalRounds: 4,
        isRunning: true
    )
}

#Preview(as: .accessoryRectangular) {
    PomodoroWatchWidget()
} timeline: {
    WatchPomodoroEntry(
        date: Date(),
        remainingTime: 5 * 60,
        totalTime: 5 * 60,
        phase: .shortBreak,
        currentRound: 2,
        totalRounds: 4,
        isRunning: true
    )
}
