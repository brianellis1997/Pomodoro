import ActivityKit
import WidgetKit
import SwiftUI

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.state.phaseLabel)
                            .font(.caption)
                            .foregroundColor(phaseColor(context.state.phase))
                        Text("Round \(context.state.currentRound)/\(context.state.totalRounds)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.timeString)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(phaseColor(context.state.phase))
                }

                DynamicIslandExpandedRegion(.center) {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.linear)
                        .tint(phaseColor(context.state.phase))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.routineName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Text(context.state.phaseEmoji)
            } compactTrailing: {
                Text(context.state.timeString)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(phaseColor(context.state.phase))
            } minimal: {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(phaseColor(context.state.phase), lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
    }

    private func phaseColor(_ phase: TimerPhase) -> Color {
        switch phase {
        case .work: return .pomodoroRed
        case .shortBreak: return .pomodoroGreen
        case .longBreak: return .pomodoroBlue
        }
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 6)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: context.state.progress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 60, height: 60)

                Text(context.state.phaseEmoji)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.timeString)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)

                HStack {
                    Text(context.state.phaseLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(phaseColor)

                    Text("•")
                        .foregroundColor(.white.opacity(0.6))

                    Text("Round \(context.state.currentRound)/\(context.state.totalRounds)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            VStack(spacing: 4) {
                if context.state.isRunning {
                    Image(systemName: "pause.circle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(phaseColor)
                }
            }
        }
        .padding()
        .activityBackgroundTint(phaseColor.opacity(0.85))
        .activitySystemActionForegroundColor(.white)
    }

    private var phaseColor: Color {
        switch context.state.phase {
        case .work: return .pomodoroRed
        case .shortBreak: return .pomodoroGreen
        case .longBreak: return .pomodoroBlue
        }
    }
}

#Preview("Lock Screen", as: .content, using: PomodoroActivityAttributes(routineName: "Deep Work")) {
    PomodoroLiveActivity()
} contentStates: {
    PomodoroActivityAttributes.ContentState(
        remainingTime: 15 * 60,
        totalTime: 25 * 60,
        phase: .work,
        currentRound: 2,
        totalRounds: 4,
        isRunning: true
    )
}
