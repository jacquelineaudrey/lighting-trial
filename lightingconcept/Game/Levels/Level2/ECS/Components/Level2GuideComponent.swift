import RealityKit

/// State ECS untuk Lumi di Level 2. Posisi dasar disimpan sekali setelah
/// kamera siap, lalu sistem hanya memberi gerak mengambang yang ringan.
struct Level2GuideComponent: Component {
    var basePosition: SIMD3<Float>
}
