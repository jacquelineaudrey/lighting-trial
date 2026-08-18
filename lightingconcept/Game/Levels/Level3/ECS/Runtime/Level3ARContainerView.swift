import Combine
import RealityKit
import SwiftUI
import ARKit

struct Level3ARContainerView: UIViewRepresentable {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    let telemetryDelegate: any ARSceneTelemetryDelegate

    func makeCoordinator() -> ARSceneCoordinator {
        // ⭐️ Gunakan ARSceneCoordinator bawaan project-mu yang asli
        ARSceneCoordinator(
            viewModel: sceneViewModel,
            gesturePolicy: .full,
            lessonECSMode: .level3ShadowPresentation,
            telemetryDelegate: telemetryDelegate
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // ⭐️ Panggil fungsi configure asli dari ARSceneCoordinator bawaan
        context.coordinator.configure(arView: arView)
        
        // Buat penampung anchor entitas tambahan (Bayo dkk)
        let additionalAnchor = AnchorEntity(world: .zero)
        additionalAnchor.name = "AdditionalEntitiesAnchor"
        arView.scene.addAnchor(additionalAnchor)
        
        // Konfigurasi session AR untuk mendeteksi lantai (seperti Level 1)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // Pasang Tap Gesture standar untuk mendeteksi klik marker atau layar kosong
        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapRecognizer)
        
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        guard let additionalAnchor = uiView.scene.findEntity(named: "AdditionalEntitiesAnchor") as? AnchorEntity else { return }

        for entity in sceneViewModel.additionalEntities {
            if entity.parent == nil {
                additionalAnchor.addChild(entity)
            }
        }
    }
}

// Ekstensi helper untuk menangkap tap di Coordinator bawaan
private class CoordinatorExtension {
    @objc static func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = recognizer.view as? ARView else { return }
        let location = recognizer.location(in: arView)
        _ = arView.entity(at: location)
    }
}
