import RealityKit

final class ShadowReceiverManager {
    private var shadowReceiver: ModelEntity?

    func setupReceiver(on anchor: AnchorEntity, usesFlatFallback: Bool) {
        guard shadowReceiver == nil else {
            return
        }

        let plane = ModelEntity(
            mesh: .generatePlane(width: 2.4, depth: 2.4),
            materials: [OcclusionMaterial(receivesDynamicLighting: true)]
        )
        plane.name = usesFlatFallback ? "Flat shadow receiver fallback" : "AR shadow receiver"
        plane.position.y = -0.002
        plane.components.set(DynamicLightShadowComponent(castsShadow: false))
        anchor.addChild(plane)
        shadowReceiver = plane
        print("[ARShadowLearning] Shadow receiver setup: occlusion shadow catcher")
    }

    func reset() {
        shadowReceiver?.removeFromParent()
        shadowReceiver = nil
    }
}
