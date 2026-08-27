import RealityKit

/// Owns the frame-safe RealityKit application of Level 2's beam and brightness
/// state. It deliberately stores no SwiftUI or ViewModel references.
final class Level2LightControlSystem: System {
    private static let query = EntityQuery(where: .has(Level2LightControlComponent.self))

    required init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let control = entity.components[Level2LightControlComponent.self],
                  let emitter = entity.children.first(where: { $0.name == "Light Emitter" }),
                  var spotlight = emitter.components[SpotLightComponent.self] else { continue }

            let targetIntensity: Float = control.isEnabled ? control.intensity : 0
            let targetInnerAngle = min(control.outerAngleInDegrees * 0.55, max(0.1, control.outerAngleInDegrees - 2.0))

            let intensityDiff = abs(spotlight.intensity - targetIntensity)
            let outerAngleDiff = abs(spotlight.outerAngleInDegrees - control.outerAngleInDegrees)
            let innerAngleDiff = abs(spotlight.innerAngleInDegrees - targetInnerAngle)

            // Matches the coarser gate in Level2ViewModel.setIntensity — with
            // the old 1.0 threshold, almost every intensity tick forced a real
            // SpotLightComponent write here, and each write triggers RealityKit
            // to refresh the shadow map even though intensity alone never
            // changes shadow shape. 24 units is imperceptible but cuts how
            // often that real (expensive) write happens.
            let isUnchanged = intensityDiff < 24
                && outerAngleDiff < 0.2
                && innerAngleDiff < 0.2
            guard !isUnchanged else { continue }

            spotlight.intensity = targetIntensity
            spotlight.outerAngleInDegrees = control.outerAngleInDegrees
            spotlight.innerAngleInDegrees = targetInnerAngle
            emitter.components.set(spotlight)

            if let fillLight = entity.children.first(where: { $0.name == "Light Fill" }),
               var fill = fillLight.components[PointLightComponent.self] {
                let fillTarget = targetIntensity * 0.08
                if fill.intensity != fillTarget {
                    fill.intensity = fillTarget
                    fillLight.components.set(fill)
                }
            }
        }
    }
}
