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

            spotlight.intensity = control.isEnabled ? control.intensity : 0
            spotlight.outerAngleInDegrees = control.outerAngleInDegrees
            spotlight.innerAngleInDegrees = min(spotlight.innerAngleInDegrees, control.outerAngleInDegrees)
            emitter.components.set(spotlight)
        }
    }
}
