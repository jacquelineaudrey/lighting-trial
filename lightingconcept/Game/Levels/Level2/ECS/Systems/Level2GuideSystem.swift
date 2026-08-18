import QuartzCore
import RealityKit

final class Level2GuideSystem: System {
    private static let query = EntityQuery(where: .has(Level2GuideComponent.self))

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let time = Float(CACurrentMediaTime())
        for entity in context.scene.performQuery(Self.query) {
            guard let guide = entity.components[Level2GuideComponent.self] else { continue }
            entity.position = guide.basePosition + SIMD3<Float>(0, sin(time * 1.6) * 0.018, 0)
        }
    }
}
