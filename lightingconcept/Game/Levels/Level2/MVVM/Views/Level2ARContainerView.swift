import Combine
import RealityKit
import SwiftUI

struct Level2ARContainerView: UIViewRepresentable {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    let telemetryDelegate: any ARSceneTelemetryDelegate

    func makeCoordinator() -> ARSceneCoordinator {
        ARSceneCoordinator(
            viewModel: sceneViewModel,
            gesturePolicy: .placementOnly,
            telemetryDelegate: telemetryDelegate
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.configure(arView: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        let coordinator = context.coordinator
        Task { @MainActor in
            coordinator.synchronizeScene()
        }
    }
}
