import Combine
import RealityKit
import SwiftUI

/// Runtime bridge untuk ARView Level 2. Sistem ECS menangani entity lampu;
/// SwiftUI hanya mengirim intent melalui ViewModel.
struct Level2ARContainerView: UIViewRepresentable {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    let telemetryDelegate: any ARSceneTelemetryDelegate

    func makeCoordinator() -> ARSceneCoordinator {
        ARSceneCoordinator(
            viewModel: sceneViewModel,
            gesturePolicy: .full,
            lessonECSMode: .level2LightControl,
            telemetryDelegate: telemetryDelegate
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.configure(arView: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.requestSceneSynchronization()
    }
}
