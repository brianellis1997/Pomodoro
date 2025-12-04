import SwiftUI

struct TimerControlsView: View {
    @ObservedObject var viewModel: TimerViewModel

    var body: some View {
        HStack(spacing: 40) {
            Button(action: viewModel.reset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color(.systemGray6))
                    )
            }

            Button(action: viewModel.startPause) {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(viewModel.phaseColor)
                            .shadow(color: viewModel.phaseColor.opacity(0.4), radius: 10, y: 5)
                    )
            }

            Button(action: viewModel.skip) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }
}

struct TimerControlsView_Previews: PreviewProvider {
    static var previews: some View {
        TimerControlsView(viewModel: TimerViewModel())
            .padding()
    }
}
