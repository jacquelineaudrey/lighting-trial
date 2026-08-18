import Foundation

/// Telemetry ringan untuk level belajar yang perlu mengetahui posisi scene dan
/// kamera tanpa menjadi delegate kedua dari `ARSession`.
@MainActor
protocol ARSceneTelemetryDelegate: AnyObject {
    func sceneDidPlace(at worldPosition: SIMD3<Float>)
    func sceneDidReset()
    func cameraDidUpdate(position: SIMD3<Float>)
    func lightDidSelect()
}
