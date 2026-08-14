import SwiftUI

struct Level2SpreadGestureSurface: View {
    let viewModel: Level2ViewModel
    @State private var isPinching = false

    var body: some View {
        Color.clear
            .contentShape(.rect)
            .gesture(
                MagnifyGesture(minimumScaleDelta: 0.005)
                    .onChanged(handleMagnification)
                    .onEnded(handleMagnificationEnd)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pengatur lebar cahaya")
            .accessibilityValue("\(Int(viewModel.beamSpreadDegrees.rounded())) derajat")
            .accessibilityHint("Cubit untuk mengubah lebar cahaya. Geser ke atas atau bawah dengan VoiceOver untuk menyesuaikan.")
            .accessibilityAdjustableAction(adjustForAccessibility)
    }

    private func handleMagnification(_ value: MagnifyGesture.Value) {
        if !isPinching {
            isPinching = true
            viewModel.beginSpreadGesture()
        }
        viewModel.updateSpreadGesture(magnification: Float(value.magnification))
    }

    private func handleMagnificationEnd(_ value: MagnifyGesture.Value) {
        isPinching = false
        viewModel.endSpreadGesture()
    }

    private func adjustForAccessibility(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment:
            viewModel.adjustSpread(by: 8)
        case .decrement:
            viewModel.adjustSpread(by: -8)
        @unknown default:
            break
        }
    }
}
