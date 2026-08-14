import RealityKit

/// Applies lesson light component state to RealityKit spotlights.
final class LessonLightSystem: System {
    private static let query = EntityQuery(where: .has(LessonLightComponent.self))

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard let lesson = entity.components[LessonLightComponent.self],
                  var spotlight = entity.components[SpotLightComponent.self] else { continue }
            spotlight.intensity = lesson.enabled ? lesson.intensity : 0
            spotlight.outerAngleInDegrees = lesson.outerAngleDegrees
            entity.components.set(spotlight)
        }
    }
}
