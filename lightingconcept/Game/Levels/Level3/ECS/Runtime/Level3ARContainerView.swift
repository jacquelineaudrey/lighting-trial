import ARKit
import Combine
import RealityKit
import SwiftUI

struct Level3ARContainerView: UIViewRepresentable {
    let viewModel: Level3ViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.configure(arView: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.requestSceneSynchronization()
    }

    @MainActor
    final class Coordinator {
        private let viewModel: Level3ViewModel
        private let arCoordinator: ARSceneCoordinator
        private weak var arView: ARView?
        private var guideAnchor: AnchorEntity?
        private var sceneUpdateSubscription: (any Cancellable)?

        init(viewModel: Level3ViewModel) {
            self.viewModel = viewModel
            self.arCoordinator = ARSceneCoordinator(
                viewModel: viewModel.arSceneViewModel,
                gesturePolicy: .full,
                lessonECSMode: .level3ShadowPresentation,
                telemetryDelegate: viewModel
            )
        }

        func configure(arView: ARView) {
            self.arView = arView
            arCoordinator.configure(arView: arView)

            let guideAnchor = AnchorEntity(world: .zero)
            guideAnchor.name = "Level 3 Guide Root Anchor"
            arView.scene.addAnchor(guideAnchor)
            self.guideAnchor = guideAnchor
            viewModel.attachGuideIfNeeded(to: guideAnchor)

            sceneUpdateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak arView] _ in
                guard let self, let arView else { return }
                self.syncGuide(in: arView)
            }
        }

        func requestSceneSynchronization() {
            arCoordinator.requestSceneSynchronization()
            if let arView {
                syncGuide(in: arView)
            } else if let guideAnchor {
                viewModel.attachGuideIfNeeded(to: guideAnchor)
            }
        }

        private func syncGuide(in arView: ARView) {
            guard let guideAnchor else { return }
            viewModel.attachGuideIfNeeded(to: guideAnchor)

            guard let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
            let cameraPosition = SIMD3<Float>(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )
            let forward = -SIMD3<Float>(
                cameraTransform.columns.2.x,
                cameraTransform.columns.2.y,
                cameraTransform.columns.2.z
            )
            viewModel.cameraDidUpdate(position: cameraPosition, forward: forward)
        }
    }
}
