import SwiftUI
import UIKit

struct Level2TouchPoint: Identifiable, Equatable {
    let id: Int
    let location: CGPoint
}

/// Gesture SwiftUI hanya menerjemahkan input user ke ViewModel. Perubahan
/// entity/lampu tetap disinkronkan oleh ARSceneCoordinator + ECS RealityKit.
struct Level2GestureLayer: View {
    let viewModel: Level2ViewModel
    @State private var touchPoints: [Level2TouchPoint] = []

    var body: some View {
        if viewModel.gestureMode != .none {
            ZStack {
                Level2TouchCaptureView(
                    mode: viewModel.gestureMode,
                    viewModel: viewModel,
                    touchPoints: $touchPoints
                )

                ForEach(touchPoints) { point in
                    Level2FingerPulse()
                        .position(point.location)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(accessibilityHint)
            .accessibilityAdjustableAction(adjustForAccessibility)
        }
    }

    private var accessibilityLabel: String {
        switch viewModel.gestureMode {
        case .spread:
            "Pengatur lebar cahaya"
        case .intensity:
            "Pengatur terang cahaya"
        case .spreadAndIntensity:
            "Pengatur lebar dan terang cahaya"
        case .none:
            ""
        }
    }

    private var accessibilityValue: String {
        "Lebar \(Int(viewModel.beamSpreadDegrees.rounded())) derajat, terang \(viewModel.intensityPercentage) persen"
    }

    private var accessibilityHint: String {
        switch viewModel.gestureMode {
        case .spread:
            "Gunakan dua jari untuk mengubah lebar cahaya."
        case .intensity:
            "Geser satu jari naik agar terang dan turun agar redup."
        case .spreadAndIntensity:
            "Gunakan dua jari untuk lebar cahaya, atau satu jari naik turun untuk terang dan redup."
        case .none:
            ""
        }
    }

    private func adjustForAccessibility(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment:
            if viewModel.canAdjustSpread { viewModel.adjustSpread(by: 8) }
            if viewModel.canAdjustIntensity { viewModel.adjustIntensity(by: 800) }
        case .decrement:
            if viewModel.canAdjustSpread { viewModel.adjustSpread(by: -8) }
            if viewModel.canAdjustIntensity { viewModel.adjustIntensity(by: -800) }
        @unknown default:
            break
        }
    }
}

private struct Level2FingerPulse: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.45), lineWidth: 1)
                .frame(width: 56, height: 56)
                .scaleEffect(isPulsing ? 1.25 : 0.82)
                .opacity(isPulsing ? 0.15 : 0.85)

            Circle()
                .stroke(.white.opacity(0.7), lineWidth: 1)
                .frame(width: 42, height: 42)

            Circle()
                .fill(Color.red)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(.white, lineWidth: 2))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

private struct Level2TouchCaptureView: UIViewRepresentable {
    let mode: Level2GestureMode
    let viewModel: Level2ViewModel
    @Binding var touchPoints: [Level2TouchPoint]

    func makeUIView(context: Context) -> Level2TouchCaptureUIView {
        let view = Level2TouchCaptureUIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: Level2TouchCaptureUIView, context: Context) {
        context.coordinator.mode = mode
        context.coordinator.viewModel = viewModel
        context.coordinator.touchPoints = $touchPoints
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode, viewModel: viewModel, touchPoints: $touchPoints)
    }

    final class Coordinator: NSObject {
        var mode: Level2GestureMode
        var viewModel: Level2ViewModel
        var touchPoints: Binding<[Level2TouchPoint]>

        private var activeTouches: [UITouch: CGPoint] = [:]
        private var touchIDs: [UITouch: Int] = [:]
        private var nextTouchID = 0
        private var spreadStartDistance: CGFloat?
        private var intensityStartY: CGFloat?
        private var movedDuringCurrentTouch = false
        private var lastSpreadHapticStep: Int?
        private var lastIntensityHapticStep: Int?
        private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
        private let gestureStartHapticGenerator = UIImpactFeedbackGenerator(style: .medium)

        init(mode: Level2GestureMode, viewModel: Level2ViewModel, touchPoints: Binding<[Level2TouchPoint]>) {
            self.mode = mode
            self.viewModel = viewModel
            self.touchPoints = touchPoints
        }

        func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
            guard mode != .none else { return }
            hapticGenerator.prepare()
            gestureStartHapticGenerator.prepare()
            for touch in touches {
                activeTouches[touch] = touch.location(in: view)
                touchIDs[touch] = nextTouchID
                nextTouchID += 1
                hapticGenerator.impactOccurred(intensity: 0.75)
            }
            if activeTouches.count == touches.count {
                movedDuringCurrentTouch = false
            }
            syncTouchPoints(in: view)
            viewModel.fingerTouchDidChange(count: activeTouches.count)
            beginGestureIfNeeded(in: view)
        }

        func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {
            guard mode != .none else { return }
            for touch in touches {
                activeTouches[touch] = touch.location(in: view)
            }
            movedDuringCurrentTouch = true
            syncTouchPoints(in: view)
            beginGestureIfNeeded(in: view)
            updateGesture()
        }

        func touchesEnded(_ touches: Set<UITouch>, in view: UIView) {
            let shouldEnterLookAround = activeTouches.count == 1
                && touches.count == 1
                && spreadStartDistance == nil
                && intensityStartY == nil
                && !movedDuringCurrentTouch
            remove(touches)
            syncTouchPoints(in: view)
            viewModel.fingerTouchDidChange(count: activeTouches.count)
            endGestureIfNeeded()
            if shouldEnterLookAround {
                viewModel.sceneDidTapEmpty()
            }
            beginGestureIfNeeded(in: view)
        }

        func touchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
            remove(touches)
            syncTouchPoints(in: view)
            viewModel.fingerTouchDidChange(count: activeTouches.count)
            endGestureIfNeeded()
        }

        private func beginGestureIfNeeded(in view: UIView) {
            if canUseSpread, activeTouches.count >= 2, spreadStartDistance == nil {
                spreadStartDistance = currentTouchDistance()
                lastSpreadHapticStep = Int(viewModel.beamSpreadDegrees / 8)
                gestureStartHapticGenerator.impactOccurred(intensity: 0.9)
                gestureStartHapticGenerator.prepare()
                viewModel.beginSpreadGesture()
            }

            if canUseIntensity,
               activeTouches.count == 1,
               intensityStartY == nil,
               let touchLocation = activeTouches.values.first,
               touchLocation.x <= view.bounds.width * 0.24 {
                intensityStartY = touchLocation.y
                lastIntensityHapticStep = viewModel.intensityPercentage / 10
                gestureStartHapticGenerator.impactOccurred(intensity: 0.9)
                gestureStartHapticGenerator.prepare()
                viewModel.beginIntensityGesture()
            }
        }

        private func updateGesture() {
            if canUseSpread,
               activeTouches.count >= 2,
               let spreadStartDistance,
               spreadStartDistance > 0,
               let distance = currentTouchDistance() {
                viewModel.updateSpreadGesture(magnification: Float(distance / spreadStartDistance))
                playSteppedHapticIfNeeded(forSpreadDegrees: viewModel.beamSpreadDegrees)
            }

            if canUseIntensity,
               activeTouches.count == 1,
               let intensityStartY,
               let currentY = activeTouches.values.first?.y {
                viewModel.updateIntensityGesture(verticalTranslation: Float(currentY - intensityStartY))
                playSteppedHapticIfNeeded(forIntensityPercentage: viewModel.intensityPercentage)
            }
        }

        private func endGestureIfNeeded() {
            if activeTouches.count < 2, spreadStartDistance != nil {
                spreadStartDistance = nil
                lastSpreadHapticStep = nil
                viewModel.endSpreadGesture()
            }

            if activeTouches.count != 1, intensityStartY != nil {
                intensityStartY = nil
                lastIntensityHapticStep = nil
                viewModel.endIntensityGesture()
            }
        }

        private func playSteppedHapticIfNeeded(forSpreadDegrees degrees: Float) {
            let step = Int(degrees / 8)
            guard step != lastSpreadHapticStep else { return }
            lastSpreadHapticStep = step
            hapticGenerator.impactOccurred(intensity: 0.45)
            hapticGenerator.prepare()
        }

        private func playSteppedHapticIfNeeded(forIntensityPercentage percentage: Int) {
            let step = percentage / 10
            guard step != lastIntensityHapticStep else { return }
            lastIntensityHapticStep = step
            hapticGenerator.impactOccurred(intensity: 0.45)
            hapticGenerator.prepare()
        }

        private func remove(_ touches: Set<UITouch>) {
            for touch in touches {
                activeTouches[touch] = nil
                touchIDs[touch] = nil
            }
            if activeTouches.isEmpty {
                nextTouchID = 0
                movedDuringCurrentTouch = false
            }
        }

        private func syncTouchPoints(in view: UIView) {
            touchPoints.wrappedValue = activeTouches.map { touch, location in
                Level2TouchPoint(id: touchIDs[touch] ?? touch.hash, location: location)
            }
        }

        private func currentTouchDistance() -> CGFloat? {
            let points = Array(activeTouches.values.prefix(2))
            guard points.count == 2 else { return nil }
            return hypot(points[0].x - points[1].x, points[0].y - points[1].y)
        }

        private var canUseSpread: Bool {
            mode == .spread || mode == .spreadAndIntensity
        }

        private var canUseIntensity: Bool {
            mode == .intensity || mode == .spreadAndIntensity
        }
    }
}

private final class Level2TouchCaptureUIView: UIView {
    weak var coordinator: Level2TouchCaptureView.Coordinator?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        coordinator?.touchesBegan(touches, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        coordinator?.touchesMoved(touches, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        coordinator?.touchesEnded(touches, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        coordinator?.touchesCancelled(touches, in: self)
    }
}
