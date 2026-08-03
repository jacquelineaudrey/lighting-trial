import Combine
import Foundation
import RealityKit
import SwiftUI

final class ARSceneViewModel: ObservableObject {
    @Published var selectedObjectType: LearningObjectType = .cube
    @Published var selectedTexture: MaterialTexture = .defaultGrid
    @Published var objectScale: Float = 1
    @Published var objectYawDegrees: Float = 0
    @Published var interactionMode: InteractionMode = .moveObject
    @Published var surfaceState: SurfaceDetectionState = .scanning
    @Published var isObjectPlaced = false
    @Published var isLiDARAvailable = false
    @Published var lidarScanProgress: Float = 0
    @Published var lidarScannedMeshCount = 0
    @Published var lidarScannedFaceCount = 0

    @Published var lights: [LightConfiguration]
    @Published var selectedLightID: UUID

    @Published var showLightDirection = true
    @Published var showLightRays = false
    @Published var showProjectionLines = false
    @Published var showGroundProjection = true
    @Published var showShadowLabels = false
    @Published var showShadowInformation = true

    @Published var selectedConcept: ShadowConcept?
    @Published var shadowInfo = ShadowInfo()
    @Published var collisionWarning: String?

    @Published var pendingResetScene = false
    @Published var pendingRescanSurface = false
    @Published var sceneRevision = 0

    init() {
        let initialLight = LightConfiguration.defaultLight()
        lights = [initialLight]
        selectedLightID = initialLight.id
    }

    var surfaceGuidanceText: String {
        switch surfaceState {
        case .scanning:
            if isLiDARAvailable {
                return "LiDAR scan \(Int(lidarScanProgress * 100))%: move around the table/object slowly."
            }
            return "Move your device to detect a surface."
        case .found:
            if isLiDARAvailable, lidarScanProgress < 0.85 {
                return "Keep scanning real objects before placing. LiDAR scan \(Int(lidarScanProgress * 100))%."
            }
            return "Tap the surface to place an object."
        case .placed:
            return "\(interactionMode.rawValue): adjust the scene and study the shadow."
        }
    }

    var isReadyForPlacement: Bool {
        !isLiDARAvailable || lidarScanProgress >= 0.85
    }

    var lidarPlacementProgress: Float {
        min(lidarScanProgress / 0.85, 1)
    }

    func updateLiDARScan(meshCount: Int, faceCount: Int) {
        isLiDARAvailable = true
        lidarScannedMeshCount = meshCount
        lidarScannedFaceCount = faceCount
        let meshProgress = min(Float(meshCount) / 6, 1)
        let faceProgress = min(Float(faceCount) / 1500, 1)
        lidarScanProgress = min(meshProgress * 0.45 + faceProgress * 0.55, 1)
    }

    func resetLiDARScan() {
        lidarScanProgress = 0
        lidarScannedMeshCount = 0
        lidarScannedFaceCount = 0
    }

    var selectedLight: LightConfiguration {
        get {
            lights.first(where: { $0.id == selectedLightID }) ?? lights[0]
        }
        set {
            guard let index = lights.firstIndex(where: { $0.id == newValue.id }) else { return }
            lights[index] = newValue
            sceneRevision += 1
        }
    }

    func updateSelectedLight(_ update: (inout LightConfiguration) -> Void) {
        guard let index = lights.firstIndex(where: { $0.id == selectedLightID }) else { return }
        update(&lights[index])
        sceneRevision += 1
    }

    func updateLightPosition(id: UUID, position: SIMD3<Float>) {
        guard let index = lights.firstIndex(where: { $0.id == id }),
              lights[index].position != position else { return }
        lights[index].position = position
        sceneRevision += 1
    }

    func selectTexture(_ texture: MaterialTexture) {
        selectedTexture = texture
        sceneRevision += 1
    }

    func addLight() {
        guard lights.count < 3 else {
            debugLog("Maximum of three lights reached")
            return
        }
        var next = LightConfiguration.defaultLight(index: lights.count + 1)
        let offset = Float(lights.count) * 0.18
        next.position.x = clamped(next.position.x + offset, -0.55, 0.55)
        next.position.z = clamped(next.position.z - offset, -0.55, 0.55)
        lights.append(next)
        selectedLightID = next.id
        interactionMode = .moveLight
        sceneRevision += 1
        debugLog("Additional light created: \(next.name)")
    }

    func removeSelectedLight() {
        guard lights.count > 1 else { return }
        lights.removeAll { $0.id == selectedLightID }
        selectedLightID = lights[0].id
        sceneRevision += 1
        debugLog("Selected additional light removed")
    }

    func resetScene() {
        pendingResetScene.toggle()
    }

    func rescanSurface() {
        pendingRescanSurface.toggle()
    }

    func debugLog(_ message: String) {
        print("[ARShadowLearning] \(message)")
    }
}
