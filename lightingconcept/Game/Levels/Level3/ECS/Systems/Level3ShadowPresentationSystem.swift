import RealityKit

/// Applies Level 3 presentation state to RealityKit's dynamic shadow component.
final class Level3ShadowPresentationSystem: System {
    private static let query = EntityQuery(where: .has(Level3ShadowPresentationComponent.self))

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let presentation = entity.components[Level3ShadowPresentationComponent.self] else { continue }
            entity.components.set(DynamicLightShadowComponent(castsShadow: presentation.castsShadow))
        }
    }
}
