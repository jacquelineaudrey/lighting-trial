import RealityKit

/// Native RealityKit ECS component for AR objects that can react to
/// LiDAR-reconstructed real-world geometry.
///
/// The component contains only value-type state. Runtime behavior belongs in
/// `LidarPhysicsSystem` rather than in SwiftUI state or an Entity subclass.
struct LidarInteractableComponent: Component, Codable, Sendable {
    var isAnchoredToMesh: Bool
    var mass: Float
    var velocity: SIMD3<Float>
    var surfaceDistance: Float
    var usesGravity: Bool

    init(
        mass: Float = 1.0,
        usesGravity: Bool = false
    ) {
        self.isAnchoredToMesh = false
        self.mass = mass
        self.velocity = .zero
        self.surfaceDistance = .greatestFiniteMagnitude
        self.usesGravity = usesGravity
    }
}
