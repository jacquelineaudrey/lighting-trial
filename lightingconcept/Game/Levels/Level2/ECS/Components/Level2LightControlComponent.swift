import RealityKit

/// ECS state for the Level 2 light experiment. SwiftUI writes this state through
/// `ARSceneCoordinator`; `Level2LightControlSystem` applies it to the spotlight.
struct Level2LightControlComponent: Component, Equatable {
    var intensity: Float
    var outerAngleInDegrees: Float
    var isEnabled: Bool
}
