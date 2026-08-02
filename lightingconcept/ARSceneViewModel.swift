import Combine
import Foundation
import RealityKit
import SwiftUI

final class ARSceneViewModel: ObservableObject {
    @Published var objects: [ObjectConfiguration]
    @Published var selectedObjectID: UUID
    @Published var selectedTexture: MaterialTexture = .defaultGrid
    @Published var interactionMode: InteractionMode = .moveObject
    @Published var surfaceState: SurfaceDetectionState = .scanning
    @Published var isObjectPlaced = false

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

    @Published var pendingResetObject = false
    @Published var pendingResetScene = false
    @Published var pendingRescanSurface = false
    @Published var sceneRevision = 0

    init() {
        let initialObject = ObjectConfiguration.defaultObject()
        let initialLight = LightConfiguration.defaultLight()
        objects = [initialObject]
        selectedObjectID = initialObject.id
        lights = [initialLight]
        selectedLightID = initialLight.id
    }

    var surfaceGuidanceText: String {
        switch surfaceState {
        case .scanning:
            "Move your device to detect a surface."
        case .found:
            "Tap the surface to place an object."
        case .placed:
            "\(interactionMode.rawValue): adjust the scene and study the shadow."
        }
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

    var selectedObject: ObjectConfiguration {
        objects.first(where: { $0.id == selectedObjectID }) ?? objects[0]
    }

    var selectedObjectType: LearningObjectType {
        get { selectedObject.type }
        set { updateSelectedObject { $0.type = newValue } }
    }

    var objectScale: Float {
        get { selectedObject.scale }
        set { updateSelectedObject { $0.scale = newValue } }
    }

    var objectYawDegrees: Float {
        get { selectedObject.yawDegrees }
        set { updateSelectedObject { $0.yawDegrees = newValue } }
    }

    func updateSelectedObject(_ update: (inout ObjectConfiguration) -> Void) {
        guard let index = objects.firstIndex(where: { $0.id == selectedObjectID }) else { return }
        var object = objects[index]
        update(&object)
        guard object != objects[index] else { return }
        objects[index] = object
        sceneRevision += 1
    }

    func updateObjectPosition(id: UUID, position: SIMD3<Float>) {
        guard let index = objects.firstIndex(where: { $0.id == id }),
              objects[index].position != position else { return }
        objects[index].position = position
        sceneRevision += 1
    }

    func addObject() {
        let index = objects.count
        let slot = index - 1
        let ring = Float(slot / 6)
        let angle = Float(slot % 6) * (.pi / 3)
        let radius: Float = 0.28 + ring * 0.25
        let position = SIMD3<Float>(cos(angle) * radius, 0, sin(angle) * radius)
        let object = ObjectConfiguration.defaultObject(
            index: index + 1,
            type: selectedObjectType,
            position: position
        )
        objects.append(object)
        selectedObjectID = object.id
        interactionMode = .moveObject
        sceneRevision += 1
        debugLog("Additional object created: \(object.name)")
    }

    func removeSelectedObject() {
        guard objects.count > 1 else { return }
        let removedID = selectedObjectID
        objects.removeAll { $0.id == removedID }
        selectedObjectID = objects[0].id
        sceneRevision += 1
        debugLog("Selected object removed")
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
        next.yawDegrees += Float(lights.count) * 18
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

    func resetObjectPosition() {
        pendingResetObject.toggle()
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
