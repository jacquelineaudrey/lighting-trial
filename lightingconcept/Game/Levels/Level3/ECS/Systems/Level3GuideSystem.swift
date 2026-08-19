import QuartzCore
import RealityKit

final class Level3GuideSystem: System {
    private static let query = EntityQuery(where: .has(Level3GuideComponent.self))

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let time = Float(CACurrentMediaTime())
        for entity in context.scene.performQuery(Self.query) {
            guard let guide = entity.components[Level3GuideComponent.self] else { continue }
            let floatOffset = SIMD3<Float>(
                sin(time * 1.15) * 0.006,
                sin(time * 1.6) * 0.018,
                0
            )
            entity.position = guide.basePosition + floatOffset
        }
    }
}
