import RealityKit

/// Keeps educational shadow state on entities. Actual shadow receivers remain
/// in ShadowReceiverManager/ProjectionLineRenderer; this system owns the ECS state.
final class LessonShadowSystem: System {
    private static let query = EntityQuery(where: .has(LessonShadowComponent.self))

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard let shadow = entity.components[LessonShadowComponent.self] else { continue }
            entity.isEnabled = shadow.enabled
        }
    }
}
