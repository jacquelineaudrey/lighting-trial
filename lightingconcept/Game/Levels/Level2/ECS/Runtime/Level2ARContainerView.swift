import ARKit
import Combine
import RealityKit
import SwiftUI

/// Runtime bridge untuk ARView Level 2. Sistem ECS menangani entity lampu;
/// SwiftUI hanya mengirim intent melalui ViewModel.
struct Level2ARContainerView: UIViewRepresentable {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    let viewModel: Level2ViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneViewModel: sceneViewModel, viewModel: viewModel)
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
        private let sceneViewModel: ARSceneViewModel
        private let viewModel: Level2ViewModel
        private let arCoordinator: ARSceneCoordinator
        private weak var arView: ARView?
        private var guideAnchor: AnchorEntity?
        private var sceneUpdateSubscription: (any Cancellable)?

        init(sceneViewModel: ARSceneViewModel, viewModel: Level2ViewModel) {
            self.sceneViewModel = sceneViewModel
            self.viewModel = viewModel
            self.arCoordinator = ARSceneCoordinator(
                viewModel: sceneViewModel,
                gesturePolicy: .full,
                lessonECSMode: .level2LightControl,
                telemetryDelegate: viewModel
            )
        }

        func configure(arView: ARView) {
            self.arView = arView
            PulseAnimationSystem.registerSystem()
            arCoordinator.configure(arView: arView)
            let guideAnchor = AnchorEntity(world: .zero)
            guideAnchor.name = "Level 2 Guide Root Anchor"
            arView.scene.addAnchor(guideAnchor)
            self.guideAnchor = guideAnchor
            viewModel.attachGuideIfNeeded(to: guideAnchor)

            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tapRecognizer)

            sceneUpdateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak arView] _ in
                guard let self, let arView else { return }
                self.syncGuide(in: arView)
                self.syncLightPrompt(in: arView)
            }
        }

        func requestSceneSynchronization() {
            arCoordinator.requestSceneSynchronization()
            if let arView {
                syncGuide(in: arView)
                syncLightPrompt(in: arView)
            }
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = recognizer.location(in: arView)
            var candidate = arView.entity(at: location)
            while let current = candidate {
                if current.name.contains("level2-light-tap-prompt")
                    || SceneLightSystem.selectLight(containing: current) != nil {
                    viewModel.lightDidSelect()
                    return
                }
                candidate = current.parent
            }
            viewModel.sceneDidTapEmpty()
        }

        private func syncLightPrompt(in arView: ARView) {
            guard let sceneAnchor = arView.scene.findEntity(named: ARSceneCoordinator.sceneAnchorName) else { return }
            viewModel.syncLightTapPrompt(in: sceneAnchor)
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
            viewModel.updateGuide(cameraPosition: cameraPosition, forward: forward)

            let guidePosition = viewModel.guideOverlayWorldPosition.flatMap(arView.project)
            viewModel.updateGuideOverlayScreenPosition(guidePosition)
        }
    }
}
