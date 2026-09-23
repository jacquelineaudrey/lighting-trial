import RealityKit

/// Per-entity state consumed by `Level6DeviceFollowSystem`.
/// This component intentionally contains data only.
struct Level6DeviceFollowComponent: Component {
    var isActive: Bool
    var startCameraWorldPosition: SIMD3<Float>
    var currentCameraWorldPosition: SIMD3<Float>
    var startLightLocalPosition: SIMD3<Float>
    var minimumLocalPosition: SIMD3<Float>
    var maximumLocalPosition: SIMD3<Float>
    var aimTargetLocalPosition: SIMD3<Float>
}
