import Combine
import RealityKit
import SwiftUI

struct Level3ARContainerView: UIViewRepresentable {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    let telemetryDelegate: any ARSceneTelemetryDelegate

    func makeCoordinator() -> ARSceneCoordinator {
        ARSceneCoordinator(
            viewModel: sceneViewModel,
            gesturePolicy: .placementOnly,
            lessonECSMode: .level3ShadowPresentation,
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
