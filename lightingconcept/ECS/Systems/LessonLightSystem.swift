import RealityKit

/// Applies lesson light component state to RealityKit spotlights.
final class LessonLightSystem: System {
    private static let query = EntityQuery(where: .has(LessonLightComponent.self))

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard let lesson = entity.components[LessonLightComponent.self],
                  var spotlight = entity.components[SpotLightComponent.self] else { continue }
            let targetIntensity: Float = lesson.enabled ? lesson.intensity : 0
            let targetOuterAngle = lesson.outerAngleDegrees
            if spotlight.intensity == targetIntensity && spotlight.outerAngleInDegrees == targetOuterAngle {
                continue
            }
            spotlight.intensity = targetIntensity
            spotlight.outerAngleInDegrees = targetOuterAngle
            entity.components.set(spotlight)
        }
    }
}
