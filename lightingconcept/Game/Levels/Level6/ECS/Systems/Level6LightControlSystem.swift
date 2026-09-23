import RealityKit

/// Applies Level 6 brightness and beam width on the render loop.
final class Level6LightControlSystem: System {
    private static let query = EntityQuery(
        where: .has(Level6LightControlComponent.self)
    )

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.entities(
            matching: Self.query,
            updatingSystemWhen: .rendering
        ) {
            guard let control = entity.components[Level6LightControlComponent.self],
                  let emitter = entity.children.first(where: { $0.name == "Light Emitter" }),
                  var spotlight = emitter.components[SpotLightComponent.self] else { continue }

            if entity.position != control.localPosition {
                entity.position = control.localPosition
            }
            if let angles = SceneLightSystem.aimingAngles(
                from: control.localPosition,
                to: control.aimTargetLocalPosition
            ) {
                let orientation = SceneLightSystem.orientation(
                    yawDegrees: angles.yawDegrees,
                    pitchDegrees: angles.pitchDegrees
                )
                if emitter.orientation != orientation {
                    emitter.orientation = orientation
                }
            }

            let innerAngle = min(
                control.outerAngleInDegrees * 0.55,
                max(0.1, control.outerAngleInDegrees - 2)
            )
            let needsUpdate = abs(spotlight.intensity - control.intensity) >= 24
                || abs(spotlight.outerAngleInDegrees - control.outerAngleInDegrees) >= 0.2
                || abs(spotlight.innerAngleInDegrees - innerAngle) >= 0.2
            guard needsUpdate else { continue }

            spotlight.intensity = control.intensity
            spotlight.outerAngleInDegrees = control.outerAngleInDegrees
            spotlight.innerAngleInDegrees = innerAngle
            emitter.components.set(spotlight)

            if let fillEntity = entity.children.first(where: { $0.name == "Light Fill" }),
               var fill = fillEntity.components[PointLightComponent.self] {
                fill.intensity = control.intensity * 0.08
                fillEntity.components.set(fill)
            }
        }
    }
}
