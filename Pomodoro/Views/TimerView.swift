import SwiftUI
import SwiftData
import UIKit

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Query private var appSettings: [AppSettings]

    @State private var dragStartAngle: Double?
    @State private var dragLastRawAngle: Double?
    @State private var dragCumulativeDelta: Double = 0
    @State private var dragStartRemaining: TimeInterval = 0
    @State private var dragStartTotal: TimeInterval = 0
    @State private var dragLastHapticMinute: Int?

    private var vibrationEnabled: Bool {
        appSettings.first?.vibrationEnabled ?? true
    }

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
                        color: viewModel.phaseColor,
                        animated: dragStartAngle == nil
                    )
                    .frame(width: size, height: size)

                    VStack(spacing: 4) {
                        Text(viewModel.formattedTime)
                            .font(.system(size: size * 0.22, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.primary)

                        Text(dragHintText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: size, height: size)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            handleDragChanged(value, ringSize: size)
                        }
                        .onEnded { _ in
                            handleDragEnded()
                        }
                )
                .onTapGesture {
                    guard dragStartAngle == nil else { return }
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

    private var dragHintText: String {
        if dragStartAngle != nil {
            return "Release to set"
        }
        if viewModel.isRunning {
            return "Tap to pause · drag ↻ to shorten"
        }
        if viewModel.isPaused {
            return "Tap to resume"
        }
        return "Ready"
    }

    private func handleDragChanged(_ value: DragGesture.Value, ringSize: CGFloat) {
        let center = CGPoint(x: ringSize / 2, y: ringSize / 2)
        let rawAngle = angle(from: center, to: value.location)

        if dragStartAngle == nil {
            dragStartAngle = rawAngle
            dragLastRawAngle = rawAngle
            dragCumulativeDelta = 0
            dragStartRemaining = viewModel.timeRemaining
            dragStartTotal = viewModel.totalTime
            dragLastHapticMinute = Int(viewModel.timeRemaining / 60)
            viewModel.beginTimeAdjustment()
            triggerHaptic(style: .soft)
            return
        }

        let last = dragLastRawAngle ?? rawAngle
        var step = rawAngle - last
        while step > .pi { step -= 2 * .pi }
        while step < -.pi { step += 2 * .pi }
        dragCumulativeDelta += step
        dragLastRawAngle = rawAngle

        guard dragStartTotal > 0 else { return }
        let timeDeltaSec = (dragCumulativeDelta / (2 * .pi)) * dragStartTotal
        var candidate = dragStartRemaining - timeDeltaSec
        candidate = max(60, min(candidate, dragStartRemaining))

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            viewModel.previewTimeAdjustment(newRemaining: candidate)
        }

        let nowMinute = Int(candidate / 60)
        if let prev = dragLastHapticMinute, prev != nowMinute {
            triggerHaptic(style: .light)
        }
        dragLastHapticMinute = nowMinute
    }

    private func handleDragEnded() {
        guard dragStartAngle != nil else { return }
        viewModel.commitTimeAdjustment()
        triggerHaptic(style: .medium)
        dragStartAngle = nil
        dragLastRawAngle = nil
        dragCumulativeDelta = 0
        dragStartRemaining = 0
        dragStartTotal = 0
        dragLastHapticMinute = nil
    }

    private func angle(from center: CGPoint, to point: CGPoint) -> Double {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        return atan2(dx, -dy)
    }

    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard vibrationEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView(viewModel: TimerViewModel())
    }
}
