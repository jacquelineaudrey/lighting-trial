import RealityKit

/// ECS state describing whether educational shadow visualization is enabled.
struct LessonShadowComponent: Component {
    var enabled: Bool
    var softness: Float = 0.5
    var typeIndex: Int = 0
}
