import RealityKit
import UIKit

final class ShadowReceiverManager {
    private var flatFallbackReceiver: ModelEntity?

    func setupReceiver(on anchor: AnchorEntity, usesFlatFallback: Bool) {
        guard usesFlatFallback, flatFallbackReceiver == nil else {
            if !usesFlatFallback {
                print("[ARShadowLearning] Shadow receiver setup: LiDAR scene-understanding mesh mode")
            }
            return
        }

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: 0.55, alpha: 0.04))
        material.roughness = .init(floatLiteral: 1)
        material.blending = .transparent(opacity: 0.04)

        let plane = ModelEntity(mesh: .generatePlane(width: 1.6, depth: 1.6), materials: [material])
        plane.name = "Flat fallback shadow receiver"
        plane.position.y = 0.001
        plane.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: true))
        anchor.addChild(plane)
        flatFallbackReceiver = plane
        print("[ARShadowLearning] Shadow receiver setup: flat fallback receiver")
    }

    func reset() {
        flatFallbackReceiver?.removeFromParent()
        flatFallbackReceiver = nil
    }
}
