import RealityKit
import SwiftUI

struct Level3ARContainerView: UIViewRepresentable {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    let telemetryDelegate: any ARSceneTelemetryDelegate

    func makeCoordinator() -> ARSceneCoordinator {
        ARSceneCoordinator(
            viewModel: sceneViewModel,
            gesturePolicy: .full,
            lessonECSMode: .level3ShadowPresentation,
            telemetryDelegate: telemetryDelegate
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.configure(arView: arView)

        // Bayo dipasang di anchor DUNIA (bukan kamera). Dengan begitu posisi
        // world-nya bisa di-update tiap frame oleh Level3ViewModel untuk
        // "terbang" mengejar pemain dengan gerak halus, sama seperti Lumi di
        // Level 1. Kalau dulu memakai AnchorEntity(.camera), Bayo akan menempel
        // kaku di layar tanpa efek melayang.
        let guideAnchor = AnchorEntity(world: .zero)
        guideAnchor.name = "Level3WorldGuideAnchor"
        arView.scene.addAnchor(guideAnchor)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.requestSceneSynchronization()

        guard let guideAnchor = uiView.scene.findEntity(named: "Level3WorldGuideAnchor") as? AnchorEntity else { return }

        for entity in sceneViewModel.additionalEntities {
            if entity.parent == nil {
                guideAnchor.addChild(entity)
            }
        }
    }
}
