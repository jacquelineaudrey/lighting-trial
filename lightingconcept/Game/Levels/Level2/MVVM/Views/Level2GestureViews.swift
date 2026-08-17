import SwiftUI

/// Gesture SwiftUI hanya menerjemahkan input user ke ViewModel. Perubahan
/// entity/lampu tetap disinkronkan oleh ARSceneCoordinator + ECS RealityKit.
struct Level2GestureLayer: View {
    let viewModel: Level2ViewModel

    var body: some View {
        switch viewModel.phase {
        case .spreadExploration:
            Level2SpreadGestureSurface(viewModel: viewModel)
        case .intensityExploration:
            Level2BrightnessGestureSurface(viewModel: viewModel)
        default:
            EmptyView()
        }
    }
}

private struct Level2BrightnessGestureSurface: View {
    let viewModel: Level2ViewModel

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Level2BrightnessEdgeGestureView(viewModel: viewModel, isLeadingEdge: true).frame(width: proxy.size.width * 0.42)
                Color.clear.allowsHitTesting(false).frame(width: proxy.size.width * 0.16)
                Level2BrightnessEdgeGestureView(viewModel: viewModel, isLeadingEdge: false).frame(width: proxy.size.width * 0.42)
            }
        }
    }
}

private struct Level2BrightnessEdgeGestureView: View {
    let viewModel: Level2ViewModel
    let isLeadingEdge: Bool
    @State private var hasBegunDrag = false

    var body: some View {
        Color.clear.contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged(handleDrag).onEnded(handleDragEnd))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isLeadingEdge ? "Pengatur cahaya sisi kiri" : "Pengatur cahaya sisi kanan")
            .accessibilityValue("\(viewModel.intensityPercentage) persen")
            .accessibilityHint("Usap ke atas agar terang dan ke bawah agar redup.")
            .accessibilityAdjustableAction(adjustForAccessibility)
    }

    private func handleDrag(_ value: DragGesture.Value) {
        if !hasBegunDrag { hasBegunDrag = true; viewModel.beginIntensityGesture() }
        viewModel.updateIntensityGesture(verticalTranslation: Float(value.translation.height))
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        hasBegunDrag = false
        viewModel.endIntensityGesture()
    }

    private func adjustForAccessibility(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: viewModel.adjustIntensity(by: 800)
        case .decrement: viewModel.adjustIntensity(by: -800)
        @unknown default: break
        }
    }
}

private struct Level2SpreadGestureSurface: View {
    let viewModel: Level2ViewModel
    @State private var isPinching = false

    var body: some View {
        Color.clear.contentShape(.rect)
            .gesture(MagnifyGesture(minimumScaleDelta: 0.005).onChanged(handleMagnification).onEnded(handleMagnificationEnd))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pengatur lebar cahaya")
            .accessibilityValue("\(Int(viewModel.beamSpreadDegrees.rounded())) derajat")
            .accessibilityHint("Cubit untuk mengubah lebar cahaya. Geser ke atas atau bawah dengan VoiceOver untuk menyesuaikan.")
            .accessibilityAdjustableAction(adjustForAccessibility)
    }

    private func handleMagnification(_ value: MagnifyGesture.Value) {
        if !isPinching { isPinching = true; viewModel.beginSpreadGesture() }
        viewModel.updateSpreadGesture(magnification: Float(value.magnification))
    }

    private func handleMagnificationEnd(_ value: MagnifyGesture.Value) {
        isPinching = false
        viewModel.endSpreadGesture()
    }

    private func adjustForAccessibility(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: viewModel.adjustSpread(by: 8)
        case .decrement: viewModel.adjustSpread(by: -8)
        @unknown default: break
        }
    }
}
