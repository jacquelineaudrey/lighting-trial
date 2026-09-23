import RealityKit

/// Render-facing light values for Level 6. Data only; RealityKit mutation lives
/// in `Level6LightControlSystem`.
struct Level6LightControlComponent: Component, Equatable {
    var intensity: Float
    var outerAngleInDegrees: Float
    var localPosition: SIMD3<Float>
    var aimTargetLocalPosition: SIMD3<Float>
}
