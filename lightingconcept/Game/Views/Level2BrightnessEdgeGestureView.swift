import SwiftUI

struct Level2BrightnessEdgeGestureView: View {
    let viewModel: Level2ViewModel
    let isLeadingEdge: Bool
    @State private var hasBegunDrag = false

    var body: some View {
        Color.clear
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(handleDrag)
                    .onEnded(handleDragEnd)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isLeadingEdge ? "Pengatur cahaya sisi kiri" : "Pengatur cahaya sisi kanan")
            .accessibilityValue("\(viewModel.intensityPercentage) persen")
            .accessibilityHint("Usap ke atas agar terang dan ke bawah agar redup.")
            .accessibilityAdjustableAction(adjustForAccessibility)
    }

    private func handleDrag(_ value: DragGesture.Value) {
        if !hasBegunDrag {
            hasBegunDrag = true
            viewModel.beginIntensityGesture()
        }
        viewModel.updateIntensityGesture(verticalTranslation: Float(value.translation.height))
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        hasBegunDrag = false
        viewModel.endIntensityGesture()
    }

    private func adjustForAccessibility(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment:
            viewModel.adjustIntensity(by: 800)
        case .decrement:
            viewModel.adjustIntensity(by: -800)
        @unknown default:
            break
        }
    }
}
