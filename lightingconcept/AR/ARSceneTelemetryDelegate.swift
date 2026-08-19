import Foundation

/// Telemetry ringan untuk level belajar yang perlu mengetahui posisi scene dan
/// kamera tanpa menjadi delegate kedua dari `ARSession`.
@MainActor
protocol ARSceneTelemetryDelegate: AnyObject {
    func sceneDidPlace(at worldPosition: SIMD3<Float>)
    func sceneDidReset()
    func cameraDidUpdate(position: SIMD3<Float>)
    func lightDidSelect()
    func shadowConceptDidSelect(_ concept: ShadowConcept)
    func markerSurfaceToneDidChange(_ tone: EducationalMarkerStyle.SurfaceTone)
}

extension ARSceneTelemetryDelegate {
    func cameraDidUpdate(position: SIMD3<Float>, forward: SIMD3<Float>) {
        cameraDidUpdate(position: position)
    }

    func cameraDidUpdate(
        position: SIMD3<Float>,
        forward: SIMD3<Float>,
        right: SIMD3<Float>,
        up: SIMD3<Float>
    ) {
        cameraDidUpdate(position: position, forward: forward)
    }

    func sceneDidReceiveWorldTap() {}
    func shadowConceptDidSelect(_ concept: ShadowConcept) {}
    func markerSurfaceToneDidChange(_ tone: EducationalMarkerStyle.SurfaceTone) {}
}
