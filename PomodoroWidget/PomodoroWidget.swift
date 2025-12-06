import WidgetKit
import SwiftUI
import AppIntents

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
        let entry = loadCurrentEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")
        let isRunning = defaults?.bool(forKey: "isRunning") ?? false
        let endTimeInterval = defaults?.double(forKey: "endTime") ?? 0

        if isRunning && endTimeInterval > 0 {
            let endTime = Date(timeIntervalSince1970: endTimeInterval)
            let now = Date()

            if endTime > now {
                var entries: [PomodoroEntry] = []
                var currentDate = now

                while currentDate < endTime && entries.count < 120 {
                    let entry = loadCurrentEntry(for: currentDate, endTime: endTime)
                    entries.append(entry)
                    currentDate = currentDate.addingTimeInterval(15)
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

    private func loadCurrentEntry(for date: Date, endTime: Date? = nil) -> PomodoroEntry {
        let defaults = UserDefaults(suiteName: "group.com.bdogellis.pomodoro")

        let storedTotalTime = defaults?.double(forKey: "totalTime") ?? 0
        let phaseRaw = defaults?.string(forKey: "phase") ?? "work"
        let storedCurrentRound = defaults?.integer(forKey: "currentRound")
        let storedTotalRounds = defaults?.integer(forKey: "totalRounds")
        let isRunning = defaults?.bool(forKey: "isRunning") ?? false
        let routineName = defaults?.string(forKey: "routineName") ?? "Classic Pomodoro"

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

        return PomodoroEntry(
            date: date,
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
        guard totalTime > 0 else { return 1 }
        return remainingTime / totalTime
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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(entry.phaseColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(entry.timeString)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 90, height: 90)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.routineName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(entry.phaseLabel)
                    .font(.caption)
                    .foregroundColor(entry.phaseColor)

                Text("Round \(entry.currentRound)/\(entry.totalRounds)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()
            }

            Spacer()

            VStack(spacing: 8) {
                Button(intent: ToggleTimerIntent()) {
                    Image(systemName: entry.isRunning ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(entry.phaseColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(intent: ResetTimerIntent()) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.backgroundPrimary
        }
    }

    private var largeWidget: some View {
        VStack(spacing: 12) {
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
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(entry.phaseLabel)
                        .font(.title3)
                        .foregroundColor(entry.phaseColor)
                }
            }
            .frame(width: 160, height: 160)

            HStack(spacing: 8) {
                ForEach(0..<entry.totalRounds, id: \.self) { index in
                    Circle()
                        .fill(index < entry.currentRound ? entry.phaseColor : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }

            HStack(spacing: 24) {
                Button(intent: ResetTimerIntent()) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(intent: ToggleTimerIntent()) {
                    Image(systemName: entry.isRunning ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(entry.phaseColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(intent: SkipPhaseIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
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
