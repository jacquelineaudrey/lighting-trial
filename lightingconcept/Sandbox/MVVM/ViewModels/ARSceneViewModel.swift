import Combine
import Foundation
import SwiftUI
import RealityKit

final class ARSceneViewModel: ObservableObject {
    @Published var objects: [ObjectConfiguration]
    @Published var selectedObjectID: UUID
    @Published var selectedTexture: MaterialTexture = .defaultGrid
    @Published var interactionMode: InteractionMode = .moveObject
    @Published var surfaceState: SurfaceDetectionState = .scanning
    @Published var isObjectPlaced = false
    @Published var isLiDARAvailable = false
    /// Sandbox can use real-world mesh occlusion and collision. Learning levels
    /// that only need a horizontal placement plane disable it to avoid the
    /// continuous LiDAR depth and mesh reconstruction workload.
    @Published var usesLiDARSceneReconstruction = true
    @Published var lidarScanProgress: Float = 0
    @Published var lidarScannedMeshCount = 0
    @Published var lidarScannedFaceCount = 0
    @Published var objectDirectManipulationLocked: Bool = false
    @Published var lights: [LightConfiguration]
    @Published var selectedLightID: UUID

    @Published var showLightDirection = true
    @Published var showLightRays = false
    @Published var showProjectionLines = false
    @Published var showGroundProjection = true
    @Published var showShadowLabels = false
    @Published var showShadowInformation = true

    @Published var selectedConcept: ShadowConcept?
    @Published var selectedConceptTapLocation: CGPoint = .zero
    /// Posisi WORLD dari marker edukasi yang sedang dipilih. Dipakai
    /// Level 3 supaya Bayo bisa terbang mendekat ke titik yang dipencet, mirip
    /// cara Lumi menghampiri marker di Level 1. `nil` saat tidak ada yang dipilih.
    @Published var selectedConceptWorldPosition: SIMD3<Float>?
    @Published var hiddenShadowConcepts: Set<ShadowConcept> = []
    @Published var isShadowConceptSelectionEnabled = true
    @Published var shadowInfo = ShadowInfo()
    @Published var collisionWarning: String?
    @Published var isImportingModel = false
    @Published var modelImportFailure: ModelImportFailure?

    @Published var pendingResetScene = false
    @Published var pendingRescanSurface = false
    @Published var pendingPlaceSceneAtCenter = false
    @Published var placementFeedback: String?
    @Published var sceneRevision = 0

    @Published var isViewFrozen = false
    @Published var pendingCaptureSnapshot = false
    @Published var isSavingSnapshot = false
    @Published var capturedSnapshotImage: UIImage?
    @Published var snapshotFeedback: SnapshotFeedback?
    /// Kalau `true`, `ARSceneCoordinator` menaruh scene (object + light) secara
    /// OTOMATIS begitu permukaan datar ketemu — anak tidak perlu tap layar.
    /// Dipakai oleh Level 4 (lihat `Level4ViewModel.init`) supaya perilakunya
    /// sama seperti auto-placement di Level 1, karena flow Level 4 tidak
    /// pernah menampilkan instruksi "tap untuk menaruh". Mode sandbox biasa
    /// (`ContentView`) membiarkan ini `false` supaya tap-to-place manual yang
    /// sudah ada tetap berjalan seperti biasa.
    @Published var autoPlaceOnSurfaceFound = false

    /// Mengunci geser langsung pada scene menjadi kontrol arah saja. Dipakai
    /// Level 4: posisi benda/lampu hanya boleh berubah lewat tombol tahan,
    /// sedangkan sapuan jari di area AR cukup memutar objek atau mengarahkan
    /// sorot lampu. Sandbox tetap memakai nilai default `false` agar kontrol
    /// drag-posisi yang lama tidak berubah.
    @Published var directManipulationRotatesOnly = false

    /// Level tertentu dapat meminta arah sorot mengikuti sapuan jari layar.
    /// Ini hanya mengubah yaw/pitch, bukan posisi lampu.
    @Published var lightDirectionFollowsGesture = false

    /// Kalau `true` (default), ARKit environment texturing + light estimation
    /// dinyalakan supaya PBR material object menyerap pantulan & warna cahaya
    /// ruangan asli — bagus untuk mode sandbox yang memang soal belajar
    /// cahaya realistis. Level 4 mematikan ini (lihat `Level4ViewModel.init`)
    /// supaya cube-nya tetap kelihatan seperti benda AR yang jelas/flat
    /// (mirip Level 1), bukan menyatu jadi kelihatan seperti "benda sungguhan".
    @Published var usesRealisticEnvironmentLighting = true

    /// Sandbox bisa mewajibkan coverage LiDAR sebelum placement. Level lesson
    /// memakai scan sebagai feedback UX saja supaya anak tidak terkunci menunggu
    /// mesh reconstruction yang lambat di iPhone.
    @Published var requiresLiDARScanBeforePlacement = true
    @Published var additionalEntities: [Entity] = []
    
    init() {
        let initialObject = ObjectConfiguration.defaultObject()
        let initialLight = LightConfiguration.defaultLight()
        objects = [initialObject]
        selectedObjectID = initialObject.id
        lights = [initialLight]
        selectedLightID = initialLight.id
    }

    func addEntityToScene(_ entity: Entity) {
        additionalEntities.append(entity)
    }
    
    var surfaceGuidanceText: String {
        switch surfaceState {
        case .scanning:
            if isLiDARAvailable {
                return "LiDAR scan \(Int(lidarScanProgress * 100))%: move around the table/object slowly."
            }
            return "Move your device to detect a surface."
        case .found:
            if isLiDARAvailable, requiresLiDARScanBeforePlacement, lidarScanProgress < 0.85 {
                return "Keep scanning real objects before placing. LiDAR scan \(Int(lidarScanProgress * 100))%."
            }
            return "Tap the surface to place an object."
        case .placed:
            return "\(interactionMode.rawValue): adjust the scene and study the shadow."
        }
    }

    var isReadyForPlacement: Bool {
        !isLiDARAvailable || !requiresLiDARScanBeforePlacement || lidarScanProgress >= 0.85
    }

    var lidarPlacementProgress: Float {
        min(lidarScanProgress / 0.85, 1)
    }

    func updateLiDARScan(meshCount: Int, faceCount: Int) {
        let meshProgress = min(Float(meshCount) / 6, 1)
        let faceProgress = min(Float(faceCount) / 1500, 1)
        let newProgress = min(meshProgress * 0.45 + faceProgress * 0.55, 1)

        if !isLiDARAvailable {
            isLiDARAvailable = true
        }
        if lidarScannedMeshCount != meshCount {
            lidarScannedMeshCount = meshCount
        }
        if lidarScannedFaceCount != faceCount {
            lidarScannedFaceCount = faceCount
        }
        if abs(lidarScanProgress - newProgress) >= 0.005 {
            lidarScanProgress = newProgress
        }
    }

    func resetLiDARScan() {
        if lidarScanProgress != 0 {
            lidarScanProgress = 0
        }
        if lidarScannedMeshCount != 0 {
            lidarScannedMeshCount = 0
        }
        if lidarScannedFaceCount != 0 {
            lidarScannedFaceCount = 0
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
        set {
            guard let index = objects.firstIndex(where: { $0.id == selectedObjectID }) else { return }
            var object = objects[index]
            object.type = newValue
            if object.importedModel != nil {
                object.importedModel = nil
                object.name = "Object \(index + 1)"
            }
            guard object != objects[index] else { return }
            objects[index] = object
            sceneRevision += 1
        }
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
        let object = ObjectConfiguration.defaultObject(
            index: index + 1,
            type: selectedObjectType,
            position: nextObjectPosition()
        )
        objects.append(object)
        selectedObjectID = object.id
        interactionMode = .moveObject
        sceneRevision += 1
        debugLog("Additional object created: \(object.name)")
    }

    func importModels(from sourceURLs: [URL]) {
        guard !sourceURLs.isEmpty, !isImportingModel else { return }
        isImportingModel = true

        Task {
            defer { isImportingModel = false }
            var failedModelNames: [String] = []

            for sourceURL in sourceURLs {
                let displayName = sourceURL.deletingPathExtension().lastPathComponent
                do {
                    let storedURL = try await Task.detached(priority: .userInitiated) {
                        try ImportedModelStore.copyIntoTemporaryStorage(from: sourceURL)
                    }.value
                    addImportedModel(fileURL: storedURL, displayName: displayName)
                } catch {
                    failedModelNames.append(displayName)
                    debugLog("Model import failed: \(error.localizedDescription)")
                }
            }

            if !failedModelNames.isEmpty {
                modelImportFailure = ModelImportFailure(
                    message: "Could not import: \(failedModelNames.joined(separator: ", "))."
                )
            }
        }
    }

    func updateImportedModelDimensions(id: UUID, dimensions: SIMD3<Float>) {
        guard let index = objects.firstIndex(where: { $0.id == id }),
              objects[index].importedModel != nil,
              objects[index].importedModel?.dimensions != dimensions else { return }
        objects[index].importedModel?.dimensions = dimensions
        sceneRevision += 1
    }

    func reportModelLoadFailure(named name: String, error: any Error) {
        modelImportFailure = ModelImportFailure(
            message: "\(name) could not be loaded. \(error.localizedDescription)"
        )
        debugLog("Imported model load failed: \(error.localizedDescription)")
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

    func placeSceneAtScreenCenter() {
        placementFeedback = nil
        pendingPlaceSceneAtCenter.toggle()
    }

    func toggleFreeze() {
        isViewFrozen.toggle()
        debugLog(isViewFrozen ? "AR view frozen" : "AR view resumed")
    }

    func captureSnapshot() {
        guard isViewFrozen, !isSavingSnapshot else { return }
        isSavingSnapshot = true
        capturedSnapshotImage = nil
        pendingCaptureSnapshot.toggle()
    }

    func debugLog(_ message: String) {
        print("[ARShadowLearning] \(message)")
    }

    private func addImportedModel(fileURL: URL, displayName: String) {
        let index = objects.count
        var object = ObjectConfiguration.defaultObject(
            index: index + 1,
            type: .cuboid,
            position: nextObjectPosition()
        )
        object.name = displayName.isEmpty ? "Imported Model" : displayName
        object.importedModel = ImportedModelConfiguration(
            fileURL: fileURL,
            displayName: object.name
        )
        objects.append(object)
        selectedObjectID = object.id
        interactionMode = .moveObject
        sceneRevision += 1
        debugLog("Imported model added: \(object.name)")
    }

    private func nextObjectPosition() -> SIMD3<Float> {
        let slot = max(objects.count - 1, 0)
        let ring = Float(slot / 6)
        let angle = Float(slot % 6) * (.pi / 3)
        let radius: Float = 0.28 + ring * 0.25
        return SIMD3<Float>(cos(angle) * radius, 0, sin(angle) * radius)
    }
}
