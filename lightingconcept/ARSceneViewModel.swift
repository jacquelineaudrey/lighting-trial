import Foundation
import SwiftUI
import RealityKit
import Combine

/// Drives ARSceneCoordinator. Owns every piece of UI-editable state:
/// selected object/texture, lights (add/delete/select/move), interaction
/// mode, learn-tab toggles, and transient collision warnings.
@MainActor
final class ARSceneViewModel: ObservableObject {
    static let maximumLights = 3

    @Published var lights: [LightConfiguration]
    @Published var selectedLightID: UUID

    @Published var selectedObjectType: LearningObjectType = .cube
    @Published var selectedTexture: MaterialTexture = .defaultGrid
    @Published var objectYawDegrees: Float = 0

    @Published var interactionMode: InteractionMode = .moveObject
    @Published var surfaceState: SurfaceDetectionState = .scanning
    @Published var isObjectPlaced: Bool = false

    @Published var shadowInfo = ShadowInfo()
    @Published var selectedConcept: ShadowConcept?

    @Published var showLightDirection = true
    @Published var showLightRays = true
    @Published var showProjectionLines = true
    @Published var showGroundProjection = true
    @Published var showShadowLabels = true

    @Published var pendingResetObject = false
    @Published var pendingResetScene = false
    @Published var pendingRescanSurface = false

    /// NEW: set briefly by ARSceneCoordinator whenever a drag was blocked
    /// because it would have pushed an object/light through another one.
    @Published var collisionWarning: String?

    @Published private(set) var debugMessages: [String] = []

    /// Bumped on any change that requires the coordinator to touch the
    /// scene graph; the coordinator compares it each frame in
    /// synchronizeScene().
    private(set) var sceneRevision: Int = 0

    init() {
        let first = LightConfiguration.defaultLight(index: 1)
        lights = [first]
        selectedLightID = first.id
    }

    var selectedLight: LightConfiguration {
        lights.first(where: { $0.id == selectedLightID }) ?? lights[0]
    }

    func updateSelectedLight(_ mutate: (inout LightConfiguration) -> Void) {
        guard let index = lights.firstIndex(where: { $0.id == selectedLightID }) else { return }
        mutate(&lights[index])
        bumpRevision()
    }

    // MARK: - Light source addition and deletion (requested feature)

    func addLight() {
        guard lights.count < Self.maximumLights else {
            debugLog("Add light rejected: maximum of \(Self.maximumLights) lights reached")
            return
        }
        let newLight = LightConfiguration.defaultLight(index: lights.count + 1)
        lights.append(newLight)
        selectedLightID = newLight.id
        bumpRevision()
        debugLog("Light added: \(newLight.name)")
    }

    func deleteLight(id: UUID) {
        guard lights.count > 1 else {
            debugLog("Delete light rejected: at least one light must remain")
            return
        }
        guard let index = lights.firstIndex(where: { $0.id == id }) else { return }
        let removed = lights.remove(at: index)
        if selectedLightID == id {
            selectedLightID = lights.first?.id ?? removed.id
        }
        bumpRevision()
        debugLog("Light deleted: \(removed.name)")
    }

    func deleteSelectedLight() {
        deleteLight(id: selectedLightID)
    }

    func selectLight(id: UUID) {
        guard lights.contains(where: { $0.id == id }) else { return }
        selectedLightID = id
    }

    // MARK: - Texture (requested feature)

    func selectTexture(_ texture: MaterialTexture) {
        selectedTexture = texture
        bumpRevision()
        debugLog("Texture changed: \(texture.name)")
    }

    // MARK: - Misc

    func bumpRevision() {
        sceneRevision += 1
    }

    func debugLog(_ message: String) {
        debugMessages.append(message)
        if debugMessages.count > 200 {
            debugMessages.removeFirst(debugMessages.count - 200)
        }
        #if DEBUG
        print("[ARShadowLearning] \(message)")
        #endif
    }
}
