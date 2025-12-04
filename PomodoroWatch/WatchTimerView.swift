import SwiftUI

struct WatchTimerView: View {
    @StateObject private var engine = TimerEngine()

    var body: some View {
        VStack(spacing: 8) {
            Text(engine.phaseDisplayName)
                .font(.caption2)
                .foregroundColor(phaseColor)
                .textCase(.uppercase)

            ZStack {
                Circle()
                    .stroke(phaseColor.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: engine.progress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(engine.formattedTime)
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.medium)
                        .monospacedDigit()

                    Text("Round \(engine.currentRound)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)

            HStack(spacing: 20) {
                Button(action: engine.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if engine.state == .running {
                        engine.pause()
                    } else {
                        engine.start()
                    }
                }) {
                    Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(phaseColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: engine.skip) {
                    Image(systemName: "forward.fill")
                        .font(.body)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var phaseColor: Color {
        switch engine.phase {
        case .work:
            return .pomodoroRed
        case .shortBreak:
            return .pomodoroGreen
        case .longBreak:
            return .pomodoroBlue
        }
    }
}

#Preview {
    WatchTimerView()
}
