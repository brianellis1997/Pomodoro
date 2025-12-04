import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) * 0.75

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    Text(viewModel.phaseDisplayName)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(viewModel.phaseColor)
                        .textCase(.uppercase)
                        .tracking(2)

                    Text(viewModel.roundsDisplay)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)

                ZStack {
                    CircularProgressView(
                        progress: viewModel.progress,
                        lineWidth: size * 0.06,
                        color: viewModel.phaseColor
                    )
                    .frame(width: size, height: size)

                    VStack(spacing: 4) {
                        Text(viewModel.formattedTime)
                            .font(.system(size: size * 0.22, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.primary)

                        Text(viewModel.isRunning ? "Tap to pause" : viewModel.isPaused ? "Tap to resume" : "Ready")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Circle())
                .onTapGesture {
                    viewModel.startPause()
                }

                Spacer()

                TimerControlsView(viewModel: viewModel)
                    .padding(.bottom, 60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView(viewModel: TimerViewModel())
    }
}
