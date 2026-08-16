import RealityKit

/// ECS state used by the learning levels for spotlight controls.
struct LessonLightComponent: Component {
    var intensity: Float
    var outerAngleDegrees: Float
    var enabled: Bool = true
}
