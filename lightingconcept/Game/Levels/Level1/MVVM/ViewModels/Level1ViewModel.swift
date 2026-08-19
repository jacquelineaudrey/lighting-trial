//
//  Level1ViewModel.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import ARKit
import Combine
import Foundation
import RealityKit
import Photos
import UIKit

enum Level1Phase: Equatable {
    case onboarding
    case scanningSurface
    case surfaceReady
    case lightShadowIntro
    case findingShapes
    case returningToFirstObject
    case textureTapPrompt
    case textureExploration
    case shapeChange
    case drawingPrompt
    case drawingReady
    case drawingActive
    case photoPrompt
    case photoComparison
    case completed
}

enum Level1ExperimentPanel: Equatable {
    case texture
    case shape
}

enum Level1DevFlow: String, CaseIterable, Identifiable {
    case onboarding = "Onboarding"
    case lightShadowIntro = "Cahaya & Bayangan"
    case findingShapes = "Cari Bentuk"
    case textureTapPrompt = "Tap Tekstur"
    case textureExploration = "Eksplor Tekstur"
    case shapeChange = "Ganti Bentuk"
    case drawingPrompt = "Mulai Gambar"
    case photoPrompt = "Foto Gambar"
    case completed = "Selesai"

    var id: String { rawValue }
}

enum Level1RadarTarget: String, CaseIterable, Equatable {
    case light
    case shadow
    case object
}

struct Level1Instruction: Equatable {
    let text: String
    let audioFileName: String?
    let radarTarget: Level1RadarTarget?
}

struct CheckpointCelebration: Identifiable, Equatable {
    let id = UUID()
    let checkpointNumber: Int
    let checkpointCount: Int
    let shapeName: String
}

@MainActor
final class Level1ViewModel: ObservableObject {

    let checkpoints = Level1Content.checkpoints
    let textureStops = Level1Content.kubus.textures
    let shapeOptions = Level1Content.checkpoints.map(\.shape)
    let onboardingDialog = Level1Content.onboardingDialog

    @Published private(set) var phase: Level1Phase = .scanningSurface
    @Published private(set) var onboardingIndex = 0
    @Published private(set) var lightShadowIndex = 0
    @Published private(set) var currentCheckpointIndex = 0
    @Published private(set) var currentTextureIndex = 0
    @Published private(set) var selectedShapeIndex = 0
    @Published private(set) var waypointDistanceMeters: Double = 0
    @Published private(set) var hasWaypointTarget = false
    @Published private(set) var checkpointCelebration: CheckpointCelebration?
    @Published private(set) var selectedRadarTarget: Level1RadarTarget?
    @Published private(set) var showsObjectModeBadge = false
    @Published private(set) var activeExperimentPanel: Level1ExperimentPanel?
    @Published private(set) var hasSelectedTexture = false
    @Published private(set) var hasSelectedShape = false
    @Published private(set) var hasOpenedTextureControls = false
    @Published private(set) var hasOpenedShapeControls = false
    @Published private(set) var hasContinuedToShapeSelection = false
    @Published private(set) var hasChangedShape = false
    @Published private(set) var hidesGuideForDrawing = false
    @Published private(set) var pendingDrawingPhotoCapture = false
    @Published private(set) var isSavingDrawingPhoto = false
    @Published private(set) var frozenSceneImage: UIImage?
    @Published private(set) var userDrawingImage: UIImage?
    @Published private(set) var showsPhotoComparisonPanel = false
    @Published var showsDrawingCamera = false
    @Published private(set) var photoSaveMessage: String?
    @Published var showsFreezeSceneConfirmation = false
    @Published private(set) var isPreparingFrozenScene = false
    @Published private(set) var isSceneFrozen = false
    @Published private(set) var successFeedbackTrigger = 0
    @Published private(set) var guideOverlayScreenPosition: CGPoint?
    @Published private(set) var textureTapObjectScreenPosition: CGPoint?

    private var visitedCheckpoints: Set<Int> = []
    private var visitedTextures: Set<Int> = [0]
    private let progressStore = GameProgressStore.shared
    let arSceneViewModel = ARSceneViewModel()

    private weak var rootAnchor: AnchorEntity?
    private var pathAnchor: AnchorEntity?
    private var checkpointLightEntities: [Entity] = []
    private var radarEntities: [Level1RadarTarget: Entity] = [:]
    private var radarWorldPositions: [Level1RadarTarget: SIMD3<Float>] = [:]
    private var radarLabelEntity: Entity?
    private var hasPlacedScene = false
    private var latestHorizontalPlaneAnchor: ARPlaneAnchor?
    private var latestCameraPositionXZ: SIMD2<Float>?
    private var latestCameraForwardXZ: SIMD2<Float>?
    private var scanStartTime: Date?

    private var checkpointEntities: [ModelEntity] = []
    private var checkpointLocalPositions: [SIMD3<Float>] = []
    private var markerWorldPositions: [SIMD3<Float>] = []
    private var checkpointHighlightEntities: [Entity] = []
    private var checkpointShadowEntities: [ModelEntity] = []
    private var directionIndicatorRoot: ModelEntity?
    private var directionIndicatorLabel: ModelEntity?
    private var lastIndicatorDistanceText: String?
    private var lastArrivedIndex: Int?
    private var recentlyExplainedCheckpointIndex: Int?
    private let shadowReceiverManager = ShadowReceiverManager()
    private var guideRoot: Entity?
    private var guideCharacter: Entity?
    private var guideCharacterAsset: CharacterGuideAsset?
    private var guideCloud: Entity?
    private var guideText: String?
    private var guideNeedsPlacement = true

    private let hapticGenerator = UINotificationFeedbackGenerator()
    private let checkpointSpacing: Float = 1.2
    private let firstCheckpointDistance: Float = 0.8
    private let checkpointHeight: Float = 0.34
    private let markerRadius: Float = 0.5

    private static var cachedRadarRingTexture: TextureResource?
    private static var cachedShadowTextures: [String: TextureResource] = [:]

    private let lightShadowInstructions: [Level1Instruction] = [
        Level1Instruction(
            text: "Coba jalan dan lihat keliling kotak! Ada yang terang dan ada yang gelap lho.",
            audioFileName: "level-1/5 coba jalan dan lihat keliling kotak.mp3",
            radarTarget: nil
        ),
        Level1Instruction(
            text: "Coba deh tekan lingkaran ini.",
            audioFileName: "level-1/marker/6 [marker] coba deh tekan lingkaran ini.mp3",
            radarTarget: .light
        ),
        Level1Instruction(
            text: "Yang bagian terang ini Cahaya!",
            audioFileName: "level-1/marker/7 [marker] yang bagian terang ini cahaya.mp3",
            radarTarget: nil
        ),
        Level1Instruction(
            text: "Sekarang tekan lingkaran ini.",
            audioFileName: "level-1/8 sekarang tekan lingkaran ini.mp3",
            radarTarget: .shadow
        ),
        Level1Instruction(
            text: "Bayangan muncul karena kotak menghalangi cahaya!",
            audioFileName: "level-1/marker/9 [marker] Bayangan muncul karena kotak menghalangi cahaya.mp3",
            radarTarget: nil
        ),
        Level1Instruction(
            text: "Yuk, coba tekan lingkaran ini!",
            audioFileName: "level-1/10 Yuk coba tekan lingkaran ini.mp3",
            radarTarget: .object
        ),
        Level1Instruction(
            text: "Ini Kubus! Semua sisinya sama besar, lho!",
            audioFileName: "level-1/marker/objek/[kubus] Ini Kubus Semua sisinya sama besar lho.mp3",
            radarTarget: nil
        )
    ]

    init() {
        hapticGenerator.prepare()
    }

    func setupLevel(in anchor: AnchorEntity) {
        rootAnchor = anchor
        scanStartTime = Date()
        setupDirectionIndicator()
        setupGuideCharacter()
    }

    func trackLatestHorizontalPlane(_ anchor: ARAnchor) {
        guard !hasPlacedScene, phase == .scanningSurface, let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .horizontal else { return }

        if let existing = latestHorizontalPlaneAnchor {
            if planeArea(planeAnchor) > planeArea(existing) {
                latestHorizontalPlaneAnchor = planeAnchor
            }
        } else {
            latestHorizontalPlaneAnchor = planeAnchor
        }

        if let bestPlane = latestHorizontalPlaneAnchor, planeArea(bestPlane) > 0.6,
           let start = scanStartTime, Date().timeIntervalSince(start) > 4.0 {
            placeSceneIfNeeded()
            // Urutan Level 1: scan dahulu, scene siap, baru Lumi membuka dialog.
            phase = .onboarding
            onboardingIndex = 0
            syncEntities()
        }
    }

    private func planeArea(_ planeAnchor: ARPlaneAnchor) -> Float {
        planeAnchor.planeExtent.width * planeAnchor.planeExtent.height
    }

    func updateCameraPose(position: SIMD3<Float>, forward: SIMD3<Float>) {
        guard !isSceneFrozen else { return }

        latestCameraPositionXZ = SIMD2<Float>(position.x, position.z)
        let horizontalForward = SIMD2<Float>(forward.x, forward.z)
        let length = simd_length(horizontalForward)
        guard length > 0.0001 else { return }
        latestCameraForwardXZ = horizontalForward / length
        updateGuidePosition(cameraPosition: position, horizontalForward: horizontalForward / length)
    }

    var guideOverlayWorldPosition: SIMD3<Float>? {
        guard showsGuideOverlay, !guideNeedsPlacement, let guide = guideRoot else { return nil }
        return guide.position(relativeTo: nil)
    }

    func updateGuideOverlayScreenPosition(_ position: CGPoint?) {
        guideOverlayScreenPosition = position
    }

    var textureTapObjectWorldPosition: SIMD3<Float>? {
        guard phase == .textureTapPrompt,
              let pathAnchor,
              let objectPosition = checkpointLocalPositions.first else { return nil }

        return pathAnchor.position(relativeTo: nil)
            + objectPosition
            + SIMD3<Float>(0, checkpointHeight * 0.65, 0)
    }

    func updateTextureTapObjectScreenPosition(_ position: CGPoint?) {
        textureTapObjectScreenPosition = position
    }

    func processSceneUpdate(cameraTransform: simd_float4x4) {
        let isFindingFirstObject = phase == .onboarding && onboardingIndex == 2
        guard phase == .findingShapes || phase == .returningToFirstObject || isFindingFirstObject else { return }
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        checkProximity(cameraPosition: cameraPosition)
        updateDirectionIndicator(cameraTransform: cameraTransform, cameraPosition: cameraPosition)
    }

    func handleTap(on entity: Entity?) {
        if let target = radarTarget(for: entity) {
            tapRadarTarget(target)
        } else if phase == .textureTapPrompt, entityBelongsToLearningObject(entity) {
            objectTappedForTexture()
        } else if (phase == .textureExploration || phase == .shapeChange), entityBelongsToLearningObject(entity) {
            objectTappedDuringExperiment()
        } else {
            closeExperimentPanel()
            advanceNarrativeFromWorldTap()
        }
    }

    /// Dialog Lumi maju dengan tap di ruang AR. Saat sebuah marker tugas
    /// aktif, tap kosong sengaja tidak melakukan apa-apa sampai marker itu
    /// sendiri disentuh.
    private func advanceNarrativeFromWorldTap() {
        switch phase {
        case .onboarding:
            advanceDialog()
        case .lightShadowIntro where currentLightShadowInstruction.radarTarget == nil:
            continueLightShadowIntro()
        case .findingShapes where recentlyExplainedCheckpointIndex != nil:
            recentlyExplainedCheckpointIndex = nil
            if hasFoundAllShapes {
                phase = .returningToFirstObject
                currentCheckpointIndex = 0
                hasWaypointTarget = true
            } else {
                hasWaypointTarget = true
            }
            syncEntities()
        case .drawingPrompt:
            phase = .drawingReady
            syncEntities()
            hideGuideAfterDrawingInstruction()
        default:
            break
        }
    }

    func advanceDialog() {
        guard phase == .onboarding else { return }
        // Dialog "Coba cari objek…" adalah tugas waypoint. Ia tidak boleh
        // dilewati dengan tap kosong sebelum pemain benar-benar sampai.
        guard onboardingIndex != 2 else { return }
        if onboardingIndex == onboardingDialog.count - 1 {
            phase = .lightShadowIntro
            lightShadowIndex = 0
            hasWaypointTarget = false
            syncEntities()
        } else {
            onboardingIndex += 1
            if onboardingIndex == 2 {
                hasWaypointTarget = true
                syncEntities()
            }
        }
    }

    func continueAfterSurfaceCheck() {
        guard phase == .surfaceReady else { return }
        phase = .lightShadowIntro
        lightShadowIndex = 0
        syncEntities()
    }

    func rescanSurface() {
        guard phase == .surfaceReady || phase == .scanningSurface else { return }
        pathAnchor?.removeFromParent()
        pathAnchor = nil
        checkpointLightEntities.removeAll()
        radarEntities.removeAll()
        radarWorldPositions.removeAll()
        radarLabelEntity = nil
        hasPlacedScene = false
        checkpointEntities.removeAll()
        checkpointLocalPositions.removeAll()
        markerWorldPositions.removeAll()
        checkpointHighlightEntities.removeAll()
        checkpointShadowEntities.removeAll()
        shadowReceiverManager.reset()
        latestHorizontalPlaneAnchor = nil
        guideNeedsPlacement = true
        guideRoot?.isEnabled = false
        hasWaypointTarget = false
        recentlyExplainedCheckpointIndex = nil
        hasContinuedToShapeSelection = false
        frozenSceneImage = nil
        userDrawingImage = nil
        showsPhotoComparisonPanel = false
        showsDrawingCamera = false
        showsFreezeSceneConfirmation = false
        isPreparingFrozenScene = false
        isSceneFrozen = false
        scanStartTime = Date()
        phase = .scanningSurface
    }

    func continueLightShadowIntro() {
        guard phase == .lightShadowIntro else { return }
        if lightShadowIndex == lightShadowInstructions.count - 1 {
            phase = .findingShapes
            selectedRadarTarget = nil
            hasWaypointTarget = true
        } else {
            lightShadowIndex += 1
            selectedRadarTarget = nil
        }
        syncEntities()
    }

    /// Dua pilihan Figma dapat dibuka kapan saja setelah anak menyentuh
    /// objek. Keduanya tetap memakai entity RealityKit yang sama.
    func showTextureControls() {
        guard phase == .textureExploration || phase == .shapeChange else { return }
        phase = .textureExploration
        activeExperimentPanel = .texture
        hasOpenedTextureControls = true
        showsObjectModeBadge = true
        syncEntities()
    }

    func showShapeControls() {
        guard phase == .textureExploration || phase == .shapeChange else { return }
        phase = .shapeChange
        activeExperimentPanel = .shape
        hasOpenedShapeControls = true
        showsObjectModeBadge = true
        syncEntities()
    }

    func closeExperimentPanel() {
        guard phase == .textureExploration || phase == .shapeChange else { return }
        activeExperimentPanel = nil
        showsObjectModeBadge = false
    }

    var canContinueToShapeSelection: Bool {
        phase == .textureExploration && hasSelectedTexture && !hasContinuedToShapeSelection
    }

    var canConfirmDrawingChoices: Bool {
        phase == .shapeChange && hasSelectedTexture && hasSelectedShape
    }

    func continueToShapeSelection() {
        guard canContinueToShapeSelection else { return }
        phase = .shapeChange
        activeExperimentPanel = nil
        hasContinuedToShapeSelection = true
        hasOpenedShapeControls = false
        showsObjectModeBadge = true
        syncEntities()
    }

    func tapRadarTarget(_ target: Level1RadarTarget) {
        guard phase == .lightShadowIntro, currentLightShadowInstruction.radarTarget == target else { return }
        triggerSuccessFeedback()
        selectedRadarTarget = target
        if lightShadowIndex < lightShadowInstructions.count - 1 {
            lightShadowIndex += 1
        }
        syncEntities()
    }

    func continueToTextureLesson() {
        guard (phase == .findingShapes || phase == .returningToFirstObject), hasFoundAllShapes else { return }
        phase = .textureTapPrompt
        currentCheckpointIndex = 0
        currentTextureIndex = 0
        visitedTextures = [0]
        activeExperimentPanel = nil
        hasSelectedTexture = false
        hasSelectedShape = false
        hasOpenedTextureControls = false
        hasOpenedShapeControls = false
        hasContinuedToShapeSelection = false
        showsObjectModeBadge = false
        hasWaypointTarget = false
        syncEntities()
    }

    func objectTappedDuringExperiment() {
        guard phase == .textureExploration || phase == .shapeChange else { return }
        showsObjectModeBadge = true
        syncEntities()
    }

    func objectTappedForTexture() {
        guard phase == .textureTapPrompt else { return }
        showsObjectModeBadge = true
        activeExperimentPanel = nil
        hasOpenedTextureControls = false
        phase = .textureExploration
        triggerSuccessFeedback()
        syncEntities()
    }

    func selectTexture(at index: Int) {
        guard phase == .textureExploration, textureStops.indices.contains(index) else { return }
        currentTextureIndex = index
        visitedTextures.insert(index)
        hasSelectedTexture = true
        triggerSuccessFeedback()
        applyCurrentTextureToPrimaryObject()
        syncEntities()
    }

    func startShapeChange() {
        guard phase == .textureExploration else { return }
        phase = .shapeChange
        activeExperimentPanel = .shape
        showsObjectModeBadge = true
        syncEntities()
    }

    func selectShape(at index: Int) {
        guard phase == .shapeChange, shapeOptions.indices.contains(index) else { return }
        selectedShapeIndex = index
        hasSelectedShape = true
        hasChangedShape = index != 0
        triggerSuccessFeedback()
        applyCurrentShapeToPrimaryObject()
        syncEntities()
    }

    func confirmDrawingChoices() {
        guard (phase == .textureExploration || phase == .shapeChange), canConfirmDrawingChoices else { return }
        showsFreezeSceneConfirmation = true
    }

    func cancelFreezeSceneConfirmation() {
        guard !isPreparingFrozenScene else { return }
        showsFreezeSceneConfirmation = false
    }

    func confirmFreezeSceneAndStartDrawing() {
        guard (phase == .textureExploration || phase == .shapeChange), canConfirmDrawingChoices else {
            showsFreezeSceneConfirmation = false
            isPreparingFrozenScene = false
            return
        }

        isPreparingFrozenScene = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            self?.freezeSceneAndStartDrawing()
        }
    }

    private func freezeSceneAndStartDrawing() {
        guard (phase == .textureExploration || phase == .shapeChange), canConfirmDrawingChoices else {
            showsFreezeSceneConfirmation = false
            isPreparingFrozenScene = false
            return
        }

        showsFreezeSceneConfirmation = false
        isPreparingFrozenScene = false
        activeExperimentPanel = nil
        showsObjectModeBadge = false
        hidesGuideForDrawing = true
        isSceneFrozen = true
        phase = .drawingPrompt
        triggerSuccessFeedback()
        syncEntities()
    }

    func finishDrawing() {
        guard phase == .drawingReady || phase == .drawingActive else { return }
        hidesGuideForDrawing = false
        phase = .photoPrompt
        triggerSuccessFeedback()
        syncEntities()
    }

    func captureDrawingPhoto() {
        guard phase == .photoPrompt, !isSavingDrawingPhoto else { return }
        isSavingDrawingPhoto = true
        pendingDrawingPhotoCapture.toggle()
    }

    func completeFrozenSceneSnapshot(success: Bool, image: UIImage?, message: String?) {
        isSavingDrawingPhoto = false
        guard success, let image else {
            photoSaveMessage = message
            syncEntities()
            return
        }

        frozenSceneImage = image
        showsDrawingCamera = true
        syncEntities()
    }

    func cancelDrawingCamera() {
        showsDrawingCamera = false
    }

    func completeUserDrawingPhoto(_ image: UIImage) {
        showsDrawingCamera = false
        isSavingDrawingPhoto = true
        saveImageToPhotoLibrary(image) { [weak self] success, message in
            guard let self else { return }
            self.isSavingDrawingPhoto = false
            guard success else {
                self.photoSaveMessage = message
                return
            }

            self.userDrawingImage = image
            self.hidesGuideForDrawing = false
            self.showsPhotoComparisonPanel = false
            self.phase = .photoComparison
            self.triggerSuccessFeedback()
            self.syncEntities()
        }
    }

    func showPhotoComparisonPanel() {
        guard phase == .photoComparison else { return }
        showsPhotoComparisonPanel = true
    }

    func completeLevelAfterPhotoComparison() {
        guard phase == .photoComparison else { return }
        showsPhotoComparisonPanel = false
        phase = .completed
        progressStore.markLevelCompleted(Level1Content.levelID)
        triggerSuccessFeedback()
        syncEntities()
    }

    func clearPhotoSaveMessage() {
        photoSaveMessage = nil
    }

    #if DEBUG
    func jumpToDevFlow(_ flow: Level1DevFlow) {
        if !hasPlacedScene {
            placeSceneIfNeeded()
        }

        selectedRadarTarget = nil
        activeExperimentPanel = nil
        showsObjectModeBadge = false
        hasWaypointTarget = false
        recentlyExplainedCheckpointIndex = nil
        isSceneFrozen = false
        showsFreezeSceneConfirmation = false
        isPreparingFrozenScene = false
        showsDrawingCamera = false
        showsPhotoComparisonPanel = false
        guideNeedsPlacement = true

        switch flow {
        case .onboarding:
            phase = .onboarding
            onboardingIndex = 0
            visitedCheckpoints.removeAll()
        case .lightShadowIntro:
            phase = .lightShadowIntro
            lightShadowIndex = 0
            visitedCheckpoints = [0]
        case .findingShapes:
            phase = .findingShapes
            visitedCheckpoints = [0]
            currentCheckpointIndex = 1
            hasWaypointTarget = true
        case .textureTapPrompt:
            phase = .textureTapPrompt
            currentCheckpointIndex = 0
            visitedCheckpoints = Set(checkpoints.indices)
        case .textureExploration:
            phase = .textureExploration
            currentCheckpointIndex = 0
            currentTextureIndex = 0
            visitedCheckpoints = Set(checkpoints.indices)
            hasSelectedTexture = false
            hasOpenedTextureControls = false
            showsObjectModeBadge = true
        case .shapeChange:
            phase = .shapeChange
            currentCheckpointIndex = 0
            currentTextureIndex = min(1, textureStops.count - 1)
            selectedShapeIndex = 0
            visitedCheckpoints = Set(checkpoints.indices)
            hasSelectedTexture = true
            hasSelectedShape = false
            hasOpenedShapeControls = false
            showsObjectModeBadge = true
            applyCurrentTextureToPrimaryObject()
        case .drawingPrompt:
            phase = .drawingPrompt
            visitedCheckpoints = Set(checkpoints.indices)
            hasSelectedTexture = true
            hasSelectedShape = true
        case .photoPrompt:
            phase = .photoPrompt
            visitedCheckpoints = Set(checkpoints.indices)
            hasSelectedTexture = true
            hasSelectedShape = true
        case .completed:
            phase = .completed
            visitedCheckpoints = Set(checkpoints.indices)
        }

        syncEntities()
    }
    #endif

    private func saveImageToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, error in
                    Task { @MainActor in
                        completion(success, success ? nil : "Foto belum tersimpan. \(error?.localizedDescription ?? "")")
                    }
                }
            default:
                Task { @MainActor in
                    completion(false, "Izinkan akses Photos untuk menyimpan foto.")
                }
            }
        }
    }

    var currentDialogLine: DialogLine { onboardingDialog[onboardingIndex] }
    var isLastDialogLine: Bool { onboardingIndex == onboardingDialog.count - 1 }
    var currentLightShadowInstruction: Level1Instruction { lightShadowInstructions[lightShadowIndex] }
    var currentCheckpoint: Checkpoint { checkpoints[currentCheckpointIndex] }
    var currentTexture: TextureStop { textureStops[currentTextureIndex] }
    var selectedShape: GameShape { shapeOptions[selectedShapeIndex] }
    var hasFoundAllShapes: Bool { checkpoints.indices.allSatisfy { visitedCheckpoints.contains($0) } }
    var hasExploredAllTextures: Bool { textureStops.indices.allSatisfy { visitedTextures.contains($0) } }
    var showsExperimentControls: Bool {
        (phase == .textureExploration || phase == .shapeChange)
            && (showsObjectModeBadge || activeExperimentPanel != nil)
    }
    var showsTextureControlGesture: Bool { phase == .textureExploration && !hasOpenedTextureControls }
    var showsShapeControlGesture: Bool { phase == .shapeChange && !hasOpenedShapeControls }

    var nextTargetCheckpointIndex: Int? {
        if phase == .onboarding, onboardingIndex == 2, !visitedCheckpoints.contains(0) {
            return 0
        }
        if phase == .returningToFirstObject {
            return 0
        }
        guard phase == .findingShapes else { return nil }
        if recentlyExplainedCheckpointIndex != nil { return nil }
        return checkpoints.indices.first { !visitedCheckpoints.contains($0) }
    }

    var narrationText: String {
        switch phase {
        case .onboarding:
            currentDialogLine.text
        case .scanningSurface:
            "Arahkan iPad pelan-pelan ke lantai atau meja."
        case .surfaceReady:
            "Permukaan sudah siap."
        case .lightShadowIntro:
            currentLightShadowInstruction.text
        case .findingShapes:
            findingShapeNarrationText
        case .returningToFirstObject:
            "Ayo kembali ke kubus pertama!"
        case .textureTapPrompt:
            "Coba tekan sekali kotaknya! Kita lihat tekstur yang lain ya!"
        case .textureExploration:
            hasSelectedTexture ? currentTexture.description : "Kamu bisa ganti tekstur yang kamu suka, lho."
        case .shapeChange:
            hasSelectedShape
                ? "Yuk, arahkan kameramu ke bendanya dulu sebelum mulai menggambar!"
                : "Kamu bisa ganti bentuk yang kamu suka, lho."
        case .drawingPrompt:
            "Simsalabim! Gambarnya kita bikin diam ya, biar gampang digambar!"
        case .drawingReady, .drawingActive:
            "Kalau sudah, tekan tombol ini ya!"
        case .photoPrompt:
            "Yeay, gambarmu sudah jadi! Sekarang, yuk foto gambarmu!"
        case .photoComparison:
            "Keren! Gambarmu sudah tersimpan."
        case .completed:
            "Level 1 selesai. Kamu hebat! Sekarang kamu bisa ke level berikutnya!"
        }
    }

    var narrationAudioFileName: String? {
        switch phase {
        case .onboarding:
            currentDialogLine.audioFileName
        case .scanningSurface:
            "level-1/3 coba cari objek berbentuk kotak di sekitarmu.mp3"
        case .surfaceReady:
            "level-1/4 yeay ketemu sekarang lumi hidupin lampu.mp3"
        case .lightShadowIntro:
            currentLightShadowInstruction.audioFileName
        case .findingShapes:
            findingShapeNarrationAudioFileName
        case .returningToFirstObject:
            "level-1/26 Sekarang, yuk kita balik lagi ke bentuk kubus! Masih ingat kan bentuknya?.mp3"
        case .textureTapPrompt:
            "level-1/14 Coba tekan sekali kotaknya Kita lihat tekstur yang lain yaa.mp3"
        case .textureExploration:
            hasSelectedTexture
                ? currentTexture.audioFileName
                : "level-1/19 Kamu bisa ganti bentuk dan tekstur yang kamu suka lho.mp3"
        case .shapeChange:
            hasSelectedShape
                ? "level-1/27 Yuk, arahkan kameramu ke bendanya dulu sebelum mulai menggambar!.mp3"
                : "level-1/15 Wah ada banyak bentuk Kamu bisa ganti bentuk yang lain lho.mp3"
        case .drawingPrompt:
            "level-1/28 Simsalabim! Gambarnya kita bikin diam ya, biar gampang digambar!.mp3"
        case .drawingReady, .drawingActive:
            "level-1/22 Kalau sudah tekan tombol ini ya.mp3"
        case .photoPrompt:
            "level-1/23 Yeay gambarmu sudah jadi Sekarang yuk foto gambarmu.mp3"
        case .photoComparison:
            "level-1/24 Keren Gambarmu sudah tersimpan.mp3"
        case .completed:
            "level-1/29 Level 1 selesai. Kamu hebat! Sekarang kamu bisa ke level berikutnya!.mp3"
        }
    }

    private var findingShapeNarrationText: String {
        if let foundIndex = recentlyExplainedCheckpointIndex, checkpoints.indices.contains(foundIndex) {
            return explanationText(for: checkpoints[foundIndex].shape)
        }

        if hasFoundAllShapes {
            return "Wah, semua bentuk sudah kamu temukan!"
        }

        guard let targetIndex = nextTargetCheckpointIndex else {
            return "Selain kotak, coba temukan bentuk yang lain di sekitarmu!"
        }
        return searchPromptText(for: checkpoints[targetIndex].shape)
    }

    private var findingShapeNarrationAudioFileName: String? {
        if let foundIndex = recentlyExplainedCheckpointIndex, checkpoints.indices.contains(foundIndex) {
            return explanationAudioFileName(for: checkpoints[foundIndex].shape)
        }

        if hasFoundAllShapes {
            return "level-1/25 Wah, semua bentuk sudah kamu temukan!.mp3"
        }

        guard let targetIndex = nextTargetCheckpointIndex else {
            return "level-1/12 Selain kotak coba temukan bentuk yang lain di sekitarmu.mp3"
        }
        return searchPromptAudioFileName(for: checkpoints[targetIndex].shape)
    }

    private func searchPromptText(for shape: GameShape) -> String {
        switch shape.id {
        case "balok":
            return "Yuk, cari bentuk balok di sekitarmu!"
        case "bola":
            return "Coba cari bentuk bola yang bulat sempurna di sekitarmu!"
        case "piramida":
            return "Coba cari bentuk piramida! Runcing ke atas seperti tenda, kan?"
        case "kerucut":
            return "Coba cari kerucut! Bawahnya bulat, tapi atasnya lancip!"
        case "tabung":
            return "Coba cari bentuk tabung! Seperti celengan yang memanjang ke atas!"
        default:
            return "Coba cari objek berbentuk kotak di sekitarmu!"
        }
    }

    private func searchPromptAudioFileName(for shape: GameShape) -> String? {
        switch shape.id {
        case "balok":
            return "level-1/bentuk/[balok] Yuk, cari bentuk balok di sekitarmu!.mp3"
        case "bola":
            return "level-1/bentuk/[bola] Coba cari bentuk bola yang bulat sempurna di sekitarmu!.mp3"
        case "piramida":
            return "level-1/bentuk/[piramida] Coba cari bentuk piramida! Runcing ke atas seperti tenda, kan_.mp3"
        case "kerucut":
            return "level-1/bentuk/[Kerucut] Coba cari kerucut! Bawahnya bulat, tapi atasnya lancip!.mp3"
        case "tabung":
            return "level-1/bentuk/[tabung] Coba cari bentuk tabung! Seperti celengan yang memanjang ke atas!.mp3"
        default:
            return "level-1/3 coba cari objek berbentuk kotak di sekitarmu.mp3"
        }
    }

    private func explanationText(for shape: GameShape) -> String {
        switch shape.id {
        case "kubus":
            return "Ini Kubus! Semua sisinya sama besar, lho!"
        case "balok":
            return "Ini Balok! Sisi yang berhadapan sama bentuk dan ukurannya."
        case "bola":
            return "Ini Bola! Bentuknya bulat sempurna tanpa titik sudut."
        case "piramida":
            return "Ini Piramida! Bawahnya datar dan puncaknya runcing."
        case "kerucut":
            return "Ini Kerucut! Alasnya lingkaran dan atasnya lancip."
        case "tabung":
            return "Ini Tabung! Alas dan tutupnya berbentuk lingkaran."
        default:
            return "Ini \(shape.displayName)!"
        }
    }

    private func explanationAudioFileName(for shape: GameShape) -> String? {
        switch shape.id {
        case "kubus":
            return "level-1/marker/objek/[kubus] Ini Kubus Semua sisinya sama besar lho.mp3"
        case "balok":
            return "level-1/marker/objek/[balok] Ini Balok! Sisi yang saling berhadapan, bentuk dan ukurannya sama persis, lho!.mp3"
        case "bola":
            return "level-1/marker/objek/[bola] Ini Bola! Bentuknya bulat sempurna dan tidak punya titik sudut sama sekali, lho!.mp3"
        case "piramida":
            return "level-1/marker/objek/[piramida] Ini Piramida! Bawahnya datar dan punya titik puncak yang runcing di atas, lho!.mp3"
        case "kerucut":
            return "level-1/marker/objek/[kerucut] Ini Kerucut! Alasnya berbentuk lingkaran dan atasnya lancip seperti topi ulang tahun, lho!.mp3"
        case "tabung":
            return "level-1/marker/objek/[tabung] Ini Tabung! Alas dan tutupnya berbentuk lingkaran yang ukurannya sama besar, lho!.mp3"
        default:
            return nil
        }
    }

    var narrationID: String {
        let phaseID: String
        switch phase {
        case .drawingActive:
            phaseID = "\(Level1Phase.drawingReady)"
        default:
            phaseID = "\(phase)"
        }

        let choiceID: String
        switch phase {
        case .textureExploration:
            choiceID = "texture-\(currentTextureIndex)"
        case .shapeChange:
            choiceID = "shape-\(selectedShapeIndex)"
        default:
            choiceID = "none"
        }

        let discoveryID = "found-\(visitedCheckpoints.count)-explaining-\(recentlyExplainedCheckpointIndex ?? -1)-target-\(nextTargetCheckpointIndex ?? -1)"
        return "\(phaseID)-\(onboardingIndex)-\(lightShadowIndex)-\(currentCheckpointIndex)-\(hasFoundAllShapes)-\(hasSelectedTexture)-\(hasSelectedShape)-\(choiceID)-\(discoveryID)"
    }

    private func placeSceneIfNeeded() {
        guard !hasPlacedScene, let root = rootAnchor else { return }
        hasPlacedScene = true

        let count = checkpoints.count
        let scanCameraXZ = latestCameraPositionXZ ?? .zero
        let scanForwardXZ = latestCameraForwardXZ ?? SIMD2<Float>(0, -1)
        let floorY = latestHorizontalPlaneAnchor?.transform.columns.3.y ?? -1.2
        let firstCheckpointXZ = firstCheckpointPlacementXZ(cameraXZ: scanCameraXZ, forwardXZ: scanForwardXZ)
        let firstCheckpointDirection = -scanForwardXZ
        let explorationRadius = explorationPathRadius(for: count)
        let pathCenterXZ = firstCheckpointXZ - firstCheckpointDirection * explorationRadius

        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(pathCenterXZ.x, floorY, pathCenterXZ.y, 1)
        let anchorGroup = AnchorEntity(world: matrix)
        root.addChild(anchorGroup)
        pathAnchor = anchorGroup
        shadowReceiverManager.setupReceiver(on: anchorGroup, usesFlatFallback: true, surfaceTexture: .defaultGrid)

        for (index, checkpoint) in checkpoints.enumerated() {
            let shapeXZ: SIMD2<Float>
            if count == 2 {
                // Dua target dibuat sebagai jalur lurus di depan pemain agar
                // waypoint mudah diikuti dan objek kedua tidak muncul terlalu jauh.
                shapeXZ = scanCameraXZ + scanForwardXZ * (firstCheckpointDistance + Float(index) * checkpointSpacing)
            } else {
                let angleStep = (2 * Float.pi) / Float(count)
                let baseAngle = atan2(firstCheckpointDirection.y, firstCheckpointDirection.x)
                let angle = baseAngle + angleStep * Float(index)
                shapeXZ = pathCenterXZ + SIMD2<Float>(cos(angle), sin(angle)) * explorationRadius
            }
            let worldPosition = SIMD3<Float>(shapeXZ.x, floorY + 0.005, shapeXZ.y)
            markerWorldPositions.append(worldPosition)

            let localPosition = SIMD3<Float>(shapeXZ.x - pathCenterXZ.x, 0, shapeXZ.y - pathCenterXZ.y)
            checkpointLocalPositions.append(localPosition)

            let shapeEntity = makeCheckpointEntity(for: checkpoint)
            shapeEntity.name = "level1-object-\(checkpoint.shape.id)"
            shapeEntity.position += localPosition
            checkpointEntities.append(shapeEntity)
            anchorGroup.addChild(shapeEntity)

            let lightPosition = localPosition + lightOffset(for: checkpoint.shape.objectType)
            let lightTarget = localPosition + SIMD3<Float>(0, checkpointHeight * 0.55, 0)
            let lightEntity = makeLightEntity(from: lightPosition, aimingAt: lightTarget)
            checkpointLightEntities.append(lightEntity)
            anchorGroup.addChild(lightEntity)

            let shadowEntity = makeShadowVisualEntity(
                objectType: checkpoint.shape.objectType,
                texture: checkpoint.shape.textures[0].material
            )
            updateShadowVisualEntity(
                shadowEntity,
                objectPosition: localPosition,
                lightPosition: lightPosition,
                objectType: checkpoint.shape.objectType,
                texture: checkpoint.shape.textures[0].material
            )
            checkpointShadowEntities.append(shadowEntity)
            anchorGroup.addChild(shadowEntity)

            // Checkpoint floor ring sengaja tidak dibuat: Level 1 sekarang
            // fokus pada cahaya, bayangan, dan objek uji yang sama.
        }

        let primaryObjectPosition = checkpointLocalPositions.first ?? .zero
        let primaryLightPosition = checkpointLightEntities.first?.position ?? primaryObjectPosition + lightOffset(for: .cube)
        let primaryShadowPosition = estimatedShadowPosition(
            objectPosition: primaryObjectPosition,
            lightPosition: primaryLightPosition,
            objectType: checkpoints.first?.shape.objectType ?? .cube
        )
        let objectTargetPosition = primaryObjectPosition + SIMD3<Float>(0, checkpointHeight * 0.62, 0)
        let radarPositions: [Level1RadarTarget: (target: SIMD3<Float>, marker: SIMD3<Float>)] = [
            .light: (
                primaryLightPosition,
                primaryLightPosition
            ),
            .shadow: (
                primaryShadowPosition + SIMD3<Float>(0, 0.025, 0),
                primaryShadowPosition + diagonalMarkerOffset(direction: SIMD3<Float>(-1, 1, 1), distance: 0.40)
            ),
            .object: (
                objectTargetPosition,
                objectTargetPosition + diagonalMarkerOffset(direction: SIMD3<Float>(1, 1, 1), distance: 0.40)
            )
        ]
        for (target, positions) in radarPositions {
            let radar = makeRadarEntity(target: target)
            radar.position = positions.marker
            if target == .object {
                radar.addChild(makeDashedLeader(toward: positions.target - positions.marker))
            }
            radarEntities[target] = radar
            radarWorldPositions[target] = SIMD3<Float>(
                pathCenterXZ.x + positions.marker.x,
                floorY + positions.marker.y,
                pathCenterXZ.y + positions.marker.z
            )
            anchorGroup.addChild(radar)
        }

        syncEntities()
    }

    private func explorationPathRadius(for checkpointCount: Int) -> Float {
        guard checkpointCount > 2 else { return checkpointSpacing }
        let halfAngle = Float.pi / Float(checkpointCount)
        return checkpointSpacing / (2 * sin(halfAngle))
    }

    private func firstCheckpointPlacementXZ(cameraXZ: SIMD2<Float>, forwardXZ: SIMD2<Float>) -> SIMD2<Float> {
        guard let planeAnchor = latestHorizontalPlaneAnchor else {
            return cameraXZ + forwardXZ * firstCheckpointDistance
        }

        let center = planeAnchor.center
        let localCenter = SIMD4<Float>(center.x, 0, center.z, 1)
        let worldCenter = planeAnchor.transform * localCenter
        return SIMD2<Float>(worldCenter.x, worldCenter.z)
    }

    private func checkProximity(cameraPosition: SIMD3<Float>) {
        guard let targetIndex = nextTargetCheckpointIndex,
              markerWorldPositions.indices.contains(targetIndex) else { return }

        let targetPosition = markerWorldPositions[targetIndex]
        let dx = cameraPosition.x - targetPosition.x
        let dz = cameraPosition.z - targetPosition.z
        let distance = sqrt(dx * dx + dz * dz)

        if distance < markerRadius {
            guard lastArrivedIndex != targetIndex else { return }
            lastArrivedIndex = targetIndex
            arrive(atCheckpointIndex: targetIndex)
        } else if lastArrivedIndex == targetIndex {
            lastArrivedIndex = nil
        }
    }

    private func arrive(atCheckpointIndex index: Int) {
        if phase == .returningToFirstObject, index == 0 {
            currentCheckpointIndex = 0
            hasWaypointTarget = false
            triggerSuccessFeedback()
            continueToTextureLesson()
            return
        }

        guard checkpoints.indices.contains(index), !visitedCheckpoints.contains(index) else { return }
        currentCheckpointIndex = index
        visitedCheckpoints.insert(index)
        triggerSuccessFeedback()
        if phase == .onboarding {
            // Setelah anak mencapai lokasi waypoint, kubus baru ditampilkan
            // bersama dialog "Yeay ketemu!". Lampu tetap belum menyala.
            onboardingIndex = min(onboardingDialog.count - 1, 3)
            hasWaypointTarget = false
            syncEntities()
            return
        }
        recentlyExplainedCheckpointIndex = index
        hasWaypointTarget = false
        syncEntities()
    }

    func syncEntities() {
        syncGuidePresentation()
        moveGuideIfNeeded()
        let showLightAndShadow = phase != .onboarding && phase != .scanningSurface

        for (index, entity) in checkpointEntities.enumerated() {
            switch phase {
            case .onboarding:
                entity.isEnabled = index == 0
            case .surfaceReady, .lightShadowIntro:
                entity.isEnabled = index == 0
            case .findingShapes:
                entity.isEnabled = visitedCheckpoints.contains(index) || index == nextTargetCheckpointIndex
            case .returningToFirstObject:
                entity.isEnabled = index == 0
            case .textureTapPrompt, .textureExploration, .shapeChange, .drawingPrompt, .drawingReady, .drawingActive, .photoPrompt, .photoComparison, .completed:
                entity.isEnabled = index == 0
            default:
                entity.isEnabled = false
            }
        }

        for (index, light) in checkpointLightEntities.enumerated() {
            light.isEnabled = showLightAndShadow && (checkpointEntities[safe: index]?.isEnabled == true)
        }

        for (index, shadow) in checkpointShadowEntities.enumerated() {
            shadow.isEnabled = showLightAndShadow && (checkpointEntities[safe: index]?.isEnabled == true)
        }

        for (index, highlight) in checkpointHighlightEntities.enumerated() {
            highlight.isEnabled = phase == .findingShapes && index == nextTargetCheckpointIndex
        }

        directionIndicatorRoot?.isEnabled = hasWaypointTarget && nextTargetCheckpointIndex != nil
        syncRadarEntities()
    }

    private func updateDirectionIndicator(cameraTransform: simd_float4x4, cameraPosition: SIMD3<Float>) {
        guard let root = directionIndicatorRoot,
              let targetIndex = nextTargetCheckpointIndex,
              markerWorldPositions.indices.contains(targetIndex) else { return }

        let targetPosition = markerWorldPositions[targetIndex]
        let forward3D = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        let horizontalForward3D = SIMD3<Float>(forward3D.x, 0, forward3D.z)
        let forwardLength = simd_length(horizontalForward3D)
        guard forwardLength > 0.0001 else { return }

        let normalizedForward = horizontalForward3D / forwardLength
        let dx = cameraPosition.x - targetPosition.x
        let dz = cameraPosition.z - targetPosition.z
        let distanceMeters = sqrt(dx * dx + dz * dz)
        let time = Float(CACurrentMediaTime())
        let position = cameraPosition
            + normalizedForward * (max(0.3, min(1.15, distanceMeters - 0.4)) + sin(time * 2.4) * 0.10)
            + SIMD3<Float>(0, -0.35 + sin(time * 2.0) * 0.015, 0)

        root.look(at: SIMD3<Float>(targetPosition.x, position.y, targetPosition.z), from: position, relativeTo: nil)
        updateIndicatorDistanceLabel(meters: Double(distanceMeters), parent: root)
    }

    private func triggerSuccessFeedback() {
        successFeedbackTrigger += 1
        hapticGenerator.notificationOccurred(.success)
        hapticGenerator.prepare()
    }

    private func showCelebration(for checkpointIndex: Int) {
        let celebration = CheckpointCelebration(
            checkpointNumber: max(checkpointIndex, 1),
            checkpointCount: checkpoints.count - 1,
            shapeName: checkpoints[checkpointIndex].shape.displayName
        )
        checkpointCelebration = celebration
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard self?.checkpointCelebration?.id == celebration.id else { return }
            self?.checkpointCelebration = nil
        }
    }

    private func applyCurrentTextureToPrimaryObject() {
        guard let entity = checkpointEntities.first else { return }
        var material = SceneObjectSystem.makeMaterial(for: currentTexture.material)
        material.faceCulling = .none
        entity.model?.materials = [material]
        refreshPrimaryShadowVisual()
    }

    private func applyCurrentShapeToPrimaryObject() {
        guard let entity = checkpointEntities.first else { return }
        let replacement = SceneObjectSystem.makeObject(type: selectedShape.objectType, texture: currentTexture.material)
        entity.model = replacement.model
        entity.collision = replacement.collision
        let finalScale = checkpointHeight / SceneObjectSystem.baseDimensions(for: selectedShape.objectType).y
        entity.components.set(DynamicLightShadowComponent(castsShadow: true))
        entity.components.set(GroundingShadowComponent(castsShadow: true, receivesShadow: false))
        entity.scale = SIMD3<Float>(repeating: finalScale)
        refreshPrimaryShadowVisual()
    }

    private func hideGuideAfterDrawingInstruction() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4.0))
            guard self?.phase == .drawingReady else { return }
            self?.phase = .drawingActive
            self?.syncEntities()
        }
    }

    private func entityBelongsToLearningObject(_ entity: Entity?) -> Bool {
        var candidate = entity
        while let current = candidate {
            if current.name.hasPrefix("level1-object") {
                return true
            }
            candidate = current.parent
        }
        return false
    }

    private func radarTarget(for entity: Entity?) -> Level1RadarTarget? {
        var candidate = entity
        while let current = candidate {
            for target in Level1RadarTarget.allCases where current.name.contains("level1-radar-\(target.rawValue)") {
                return target
            }
            candidate = current.parent
        }
        return nil
    }

    private func syncRadarEntities() {
        let activeTarget = phase == .lightShadowIntro ? currentLightShadowInstruction.radarTarget : nil
        let explainedTarget = phase == .lightShadowIntro && currentLightShadowInstruction.radarTarget == nil ? selectedRadarTarget : nil
        for (target, entity) in radarEntities {
            let isVisible = activeTarget == target || explainedTarget == target
            entity.isEnabled = isVisible
            updateRadarAppearance(entity, isSelected: explainedTarget == target)
        }

        radarLabelEntity?.removeFromParent()
        radarLabelEntity = nil

        // Penjelasan setelah white mark ditekan ditampilkan lewat bubble Lumi.
        // Label marker terpisah sengaja tidak dibuat agar dialog tidak duplikat.
    }

    private func updateRadarAppearance(_ entity: Entity, isSelected: Bool) {
        guard let center = entity.children.first(where: { $0.name.contains("-center") }) as? ModelEntity else { return }

        if isSelected {
            center.model?.materials = [UnlitMaterial(color: .systemRed)]
            center.components.set(PulseAnimationComponent(baseScale: 1, speed: 5.0, amplitude: 0.35, isActiveTarget: true))
        } else {
            center.model?.materials = [UnlitMaterial(color: .white)]
            center.components.remove(PulseAnimationComponent.self)
            center.scale = SIMD3<Float>(repeating: 1)
        }
    }

    private func setupDirectionIndicator() {
        guard let root = rootAnchor else { return }
        let rootEntity = ModelEntity()
        rootEntity.isEnabled = false

        let mesh = MeshResource.generateText("➔", extrusionDepth: 0.04, font: .systemFont(ofSize: 0.35, weight: .black))
        let arrowEntity = ModelEntity(
            mesh: mesh,
            materials: [SimpleMaterial(color: UIColor(red: 0.44, green: 0.06, blue: 0.74, alpha: 1), roughness: 0.2, isMetallic: false)]
        )
        arrowEntity.position = SIMD3<Float>(-mesh.bounds.center.x, -mesh.bounds.center.y, -mesh.bounds.center.z)

        let pivot = Entity()
        pivot.addChild(arrowEntity)
        pivot.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        rootEntity.addChild(pivot)
        root.addChild(rootEntity)
        directionIndicatorRoot = rootEntity
    }

    private func updateIndicatorDistanceLabel(meters: Double, parent: ModelEntity) {
        let text = String(format: "%.1f Meter ke kiri", max(meters, 0.1))
        guard text != lastIndicatorDistanceText else { return }
        lastIndicatorDistanceText = text

        directionIndicatorLabel?.removeFromParent()
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.002, font: .boldSystemFont(ofSize: 0.05), containerFrame: .zero, alignment: .center, lineBreakMode: .byTruncatingTail)
        let label = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
        label.components.set(BillboardComponent())
        label.position = SIMD3<Float>(-mesh.bounds.center.x - mesh.bounds.extents.x / 2, 0.18, 0)
        parent.addChild(label)
        directionIndicatorLabel = label
    }

    private func makeCheckpointEntity(for checkpoint: Checkpoint) -> ModelEntity {
        let entity = SceneObjectSystem.makeObject(type: checkpoint.shape.objectType, texture: checkpoint.shape.textures[0].material)
        let scale = checkpointHeight / SceneObjectSystem.baseDimensions(for: checkpoint.shape.objectType).y
        entity.scale = SIMD3<Float>(repeating: scale)
        entity.position.y = checkpointHeight / 2
        var material = SceneObjectSystem.makeMaterial(for: checkpoint.shape.textures[0].material)
        material.faceCulling = .none
        entity.model?.materials = [material]
        entity.components.set(DynamicLightShadowComponent(castsShadow: true))
        entity.components.set(GroundingShadowComponent(castsShadow: true, receivesShadow: false))
        return entity
    }

    private func makeShadowVisualEntity(objectType: LearningObjectType, texture: MaterialTexture) -> ModelEntity {
        let entity = ModelEntity(
            mesh: .generatePlane(width: 0.1, height: 0.1),
            materials: [shadowVisualMaterial(objectType: objectType, texture: texture)]
        )
        entity.name = "Level 1 floor shadow decal"
        entity.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(0.28, 0.006, 0.42))]))
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        entity.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: false))
        return entity
    }

    private func refreshPrimaryShadowVisual() {
        guard let shadow = checkpointShadowEntities.first,
              let objectPosition = checkpointLocalPositions.first,
              let lightPosition = checkpointLightEntities.first?.position else { return }

        updateShadowVisualEntity(
            shadow,
            objectPosition: objectPosition,
            lightPosition: lightPosition,
            objectType: selectedShape.objectType,
            texture: currentTexture.material
        )
    }

    private func updateShadowVisualEntity(
        _ entity: ModelEntity,
        objectPosition: SIMD3<Float>,
        lightPosition: SIMD3<Float>,
        objectType: LearningObjectType,
        texture: MaterialTexture
    ) {
        let dimensions = scaledObjectDimensions(for: objectType)
        let groundDirection = ShadowGeometryCalculator.groundShadowDirection(
            lightPosition: lightPosition,
            objectPosition: objectPosition
        ) ?? SIMD3<Float>(0, 0, 1)
        let lightDirection = simd_normalize(objectPosition - lightPosition)
        let estimatedLength = ShadowGeometryCalculator.approximateShadowLength(
            lightDirection: lightDirection,
            objectHeight: dimensions.y
        ) ?? 0.34

        let footprintDepth = projectedShadowFootprintDepth(for: objectType, dimensions: dimensions)
        let projectedLength = estimatedLength * predefinedShadowLengthMultiplier(for: objectType)
        let shadowLength = clamped(
            max(projectedLength, dimensions.y * 1.05) + footprintDepth * 1.25,
            0.58,
            1.55
        )
        let shadowWidth = clamped(
            max(dimensions.x, dimensions.z) * shadowWidthMultiplier(for: objectType) + shadowLength * 0.16,
            0.34,
            0.86
        )
        let centerOffset = max(0.04, shadowLength * 0.5 - footprintDepth * 0.52)

        entity.model = ModelComponent(
            mesh: .generatePlane(width: shadowWidth, height: shadowLength),
            materials: [shadowVisualMaterial(objectType: objectType, texture: texture)]
        )
        entity.scale = .one
        entity.position = objectPosition + groundDirection * centerOffset + SIMD3<Float>(0, 0.018, 0)
        let yaw = atan2(groundDirection.x, groundDirection.z)
        entity.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            * simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        entity.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(shadowWidth, 0.006, shadowLength))]))
    }

    private func predefinedShadowLengthMultiplier(for objectType: LearningObjectType) -> Float {
        switch objectType {
        case .sphere:
            return 1.18
        case .cylinder, .cone:
            return 1.24
        case .cube:
            return 1.36
        case .cuboid:
            return 1.42
        case .squarePyramid, .triangularPyramid:
            return 1.22
        default:
            return 1.24
        }
    }

    private func shadowWidthMultiplier(for objectType: LearningObjectType) -> Float {
        switch objectType {
        case .sphere:
            return 1.45
        case .cylinder, .cone:
            return 1.35
        case .cube:
            return 1.55
        case .cuboid:
            return 1.34
        default:
            return 1.25
        }
    }

    private func projectedShadowFootprintDepth(for objectType: LearningObjectType, dimensions: SIMD3<Float>) -> Float {
        switch objectType {
        case .cube:
            return max(dimensions.x, dimensions.z) * 1.0
        case .cuboid:
            return max(dimensions.x, dimensions.z) * 1.08
        case .sphere, .cylinder:
            return max(dimensions.x, dimensions.z) * 0.92
        case .cone, .squarePyramid, .triangularPyramid:
            return max(dimensions.x, dimensions.z) * 0.82
        case .hemisphere:
            return max(dimensions.x, dimensions.z) * 0.78
        }
    }

    private func shadowVisualMaterial(objectType: LearningObjectType, texture: MaterialTexture) -> UnlitMaterial {
        var material = UnlitMaterial()
        let alpha = shadowAlpha(for: objectType, texture: texture)
        let key = "v3-\(objectType.rawValue)-\(texture.id)"
        if let shadowTexture = Self.cachedShadowTextures[key] ?? Self.generateShadowTexture(objectType: objectType, texture: texture) {
            Self.cachedShadowTextures[key] = shadowTexture
            material.color = .init(tint: .white, texture: .init(shadowTexture))
            material.blending = .transparent(opacity: .init(floatLiteral: 1.0))
        } else {
            material.color = .init(tint: UIColor.black.withAlphaComponent(alpha))
            material.blending = .transparent(opacity: .init(floatLiteral: Float(alpha)))
        }
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private func shadowAlpha(for objectType: LearningObjectType, texture: MaterialTexture) -> CGFloat {
        let baseAlpha: CGFloat
        switch texture.shadowBehavior {
        case .cutout:
            baseAlpha = 0.34
        case .opaque:
            baseAlpha = texture.isMetallic ? 0.42 : 0.46
        }

        switch objectType {
        case .sphere:
            return baseAlpha - 0.04
        case .cube, .cuboid:
            return baseAlpha + 0.02
        default:
            return baseAlpha
        }
    }

    private static func generateShadowTexture(
        objectType: LearningObjectType,
        texture: MaterialTexture,
        size: CGFloat = 256
    ) -> TextureResource? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let cgContext = context.cgContext
            cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))

            drawSoftShadowSilhouette(
                in: cgContext,
                objectType: objectType,
                texture: texture,
                size: size
            )

            if texture.shadowBehavior == .cutout {
                drawProjectedCutoutOpenings(
                    in: cgContext,
                    objectType: objectType,
                    size: size
                )
            }
        }

        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource(image: cgImage, withName: nil, options: .init(semantic: .color))
    }

    private static func drawSoftShadowSilhouette(
        in cgContext: CGContext,
        objectType: LearningObjectType,
        texture: MaterialTexture,
        size: CGFloat
    ) {
        let baseRect = CGRect(
            x: size * 0.12,
            y: size * 0.16,
            width: size * 0.76,
            height: size * 0.68
        )
        let centerAlpha = shadowCenterAlpha(for: texture)
        let edgeAlpha = CGFloat(0.045)

        for layer in 0..<9 {
            let progress = CGFloat(layer) / 8
            let inset = size * 0.045 * progress
            let alpha = edgeAlpha + pow(progress, 1.55) * (centerAlpha - edgeAlpha)
            let rect = baseRect.insetBy(dx: inset, dy: inset * 0.82)
            cgContext.setFillColor(UIColor.black.withAlphaComponent(alpha).cgColor)
            cgContext.addPath(shadowSilhouettePath(for: objectType, in: rect))
            cgContext.fillPath()
        }
    }

    private static func drawProjectedCutoutOpenings(
        in cgContext: CGContext,
        objectType: LearningObjectType,
        size: CGFloat
    ) {
        let baseRect = CGRect(
            x: size * 0.12,
            y: size * 0.16,
            width: size * 0.76,
            height: size * 0.68
        )
        let silhouette = shadowSilhouettePath(for: objectType, in: baseRect)

        cgContext.saveGState()
        cgContext.addPath(silhouette)
        cgContext.clip()

        // Cutout shadow is not fully transparent in AR because floor texture,
        // ambient light, and penumbra still soften the projected openings.
        cgContext.setBlendMode(.destinationOut)
        for row in 0..<4 {
            let progress = CGFloat(row) / 3
            let y = baseRect.minY + baseRect.height * (0.26 + progress * 0.48)
            let rowWidth = baseRect.width * (0.58 + progress * 0.16)
            let startX = baseRect.midX - rowWidth / 2
            let columnCount = row % 2 == 0 ? 4 : 3

            for column in 0..<columnCount {
                let fraction = CGFloat(column) / CGFloat(max(columnCount - 1, 1))
                let drift = (progress - 0.5) * baseRect.width * 0.10
                let x = startX + rowWidth * fraction + drift
                let openingWidth = size * (0.068 + progress * 0.018)
                let openingHeight = size * (0.090 + progress * 0.030)
                let rect = CGRect(
                    x: x - openingWidth / 2,
                    y: y - openingHeight / 2,
                    width: openingWidth,
                    height: openingHeight
                )

                for layer in stride(from: 3, through: 0, by: -1) {
                    let layerProgress = CGFloat(layer) / 3
                    let inset = size * 0.010 * layerProgress
                    let alpha = 0.10 + (1 - layerProgress) * 0.42
                    cgContext.setFillColor(UIColor.black.withAlphaComponent(alpha).cgColor)
                    cgContext.fillEllipse(in: rect.insetBy(dx: -inset, dy: -inset * 0.72))
                }
            }
        }

        cgContext.setBlendMode(.normal)
        cgContext.restoreGState()
    }

    private static func shadowSilhouettePath(for objectType: LearningObjectType, in rect: CGRect) -> CGPath {
        switch objectType {
        case .cube:
            return UIBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.02, dy: rect.height * 0.04), cornerRadius: 4).cgPath
        case .cuboid:
            return UIBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.07, dy: rect.height * 0.02), cornerRadius: 4).cgPath
        case .sphere, .cylinder:
            return UIBezierPath(ovalIn: rect).cgPath
        case .cone:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.08))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.maxY - rect.height * 0.10),
                controlPoint: CGPoint(x: rect.maxX + rect.width * 0.04, y: rect.midY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY - rect.height * 0.10),
                controlPoint: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.08)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.08),
                controlPoint: CGPoint(x: rect.minX - rect.width * 0.04, y: rect.midY)
            )
            path.close()
            return path.cgPath
        case .squarePyramid, .triangularPyramid:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.04))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.midY + rect.height * 0.10))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.04))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY + rect.height * 0.10))
            path.close()
            return path.cgPath
        default:
            return UIBezierPath(ovalIn: rect).cgPath
        }
    }

    private static func shadowCenterAlpha(for texture: MaterialTexture) -> CGFloat {
        switch texture.shadowBehavior {
        case .cutout:
            return 0.42
        case .opaque:
            return texture.isMetallic ? 0.44 : 0.48
        }
    }

    private static func shadowMidAlpha(for texture: MaterialTexture) -> CGFloat {
        switch texture.shadowBehavior {
        case .cutout:
            return 0.26
        case .opaque:
            return texture.isMetallic ? 0.28 : 0.30
        }
    }

    // MARK: - Lumi AR Guide

    private func setupGuideCharacter() {
        guard guideRoot == nil, let root = rootAnchor else { return }
        let guide = Entity()
        guide.name = "Level 1 Guide — Lumi"
        guide.isEnabled = false
        let asset = currentGuideAsset
        if let character = CharacterGuideFactory.makeCharacter(asset: asset, width: 0.10, height: 0.14) {
            guide.addChild(character)
            guideCharacter = character
            guideCharacterAsset = asset
        }
        root.addChild(guide)
        guideRoot = guide
    }

    private func updateGuidePosition(cameraPosition: SIMD3<Float>, horizontalForward: SIMD2<Float>) {
        guard hasPlacedScene, let guide = guideRoot else { return }
        let forward = SIMD3<Float>(horizontalForward.x, 0, horizontalForward.y)
        let right = SIMD3<Float>(-horizontalForward.y, 0, horizontalForward.x)
        let destination: SIMD3<Float>

        if let activeTarget = activeGuideRadarTarget,
           let radarPosition = radarWorldPositions[activeTarget] {
            let side: Float = radarAppearsOnRight(radarPosition: radarPosition, cameraPosition: cameraPosition, cameraRight: right) ? -1 : 1
            destination = radarPosition + right * (0.14 * side) + SIMD3<Float>(0, 0.02, 0)
        } else {
            destination = cameraPosition + forward * 0.66 + right * 0.30 + SIMD3<Float>(0, -0.54, 0)
        }

        if guideNeedsPlacement {
            guide.position = destination
            guideNeedsPlacement = false
            guide.isEnabled = shouldShowGuide
            syncGuidePresentation()
        } else {
            guide.position += (destination - guide.position) * 0.24
        }
        guide.look(at: cameraPosition, from: guide.position, relativeTo: nil)
        guideCloud?.position = guideCloudPosition(cameraPosition: cameraPosition, cameraRight: right)
    }

    private func syncGuidePresentation() {
        guard let guide = guideRoot else { return }
        guide.isEnabled = shouldShowGuide && !guideNeedsPlacement
        syncGuideCharacterAsset()
        let text = narrationText
        guard guideText != text else { return }
        guideText = text
        guideCloud?.removeFromParent()
        let speechLayout = guideSpeechLayout(for: text)
        let cloud = CharacterGuideFactory.makeSpeechCloud(
            text: speechLayout.text,
            width: speechLayout.width,
            height: speechLayout.height,
            fontSize: 0.013,
            textHorizontalInset: 0.025,
            textVerticalInset: 0.030
        )
        cloud.name = "Lumi Speech Cloud"
        cloud.position = defaultGuideCloudPosition
        guide.addChild(cloud)
        guideCloud = cloud
    }

    private func moveGuideIfNeeded() {
        guideCloud?.position = defaultGuideCloudPosition
    }

    private var shouldShowGuide: Bool {
        false
    }

    var showsGuideOverlay: Bool {
        guard !hidesGuideForDrawing else { return false }
        return phase != .scanningSurface && phase != .drawingActive && phase != .completed
    }

    var guideOverlayAssetName: String {
        currentGuideAsset.rawValue
    }

    private var activeGuideRadarTarget: Level1RadarTarget? {
        guard phase == .lightShadowIntro else { return nil }
        return currentLightShadowInstruction.radarTarget ?? selectedRadarTarget
    }

    private var currentGuideAsset: CharacterGuideAsset {
        switch phase {
        case .onboarding:
            switch onboardingIndex {
            case 0:
                return .lumiIdle
            case 1:
                return .lumiPoint
            case 2:
                return .lumiQuestion
            default:
                return .lumiPointWink
            }
        case .surfaceReady:
            return .lumiPoint
        case .lightShadowIntro:
            return currentLightShadowInstruction.radarTarget == nil ? .lumiPointWink : .lumiPoint
        case .findingShapes:
            return recentlyExplainedCheckpointIndex == nil ? .lumiQuestion : .lumiPointWink
        case .returningToFirstObject:
            return .lumiQuestion
        case .textureTapPrompt:
            return .lumiPoint
        case .textureExploration:
            return hasSelectedTexture ? .lumiPointWink : .lumiQuestion
        case .shapeChange:
            return hasSelectedShape ? .lumiPointWink : .lumiPoint
        case .drawingPrompt:
            return .lumiIdle
        case .drawingReady, .photoPrompt:
            return .lumiPointWink
        case .drawingActive, .scanningSurface, .photoComparison, .completed:
            return .lumiIdle
        }
    }

    private func syncGuideCharacterAsset() {
        guard let guide = guideRoot else { return }
        let asset = currentGuideAsset
        guard guideCharacterAsset != asset else { return }

        guard let character = CharacterGuideFactory.makeCharacter(asset: asset, width: 0.10, height: 0.14) else {
            return
        }
        guideCharacter?.removeFromParent()
        guide.addChild(character)
        guideCharacter = character
        guideCharacterAsset = asset
    }

    private var defaultGuideCloudPosition: SIMD3<Float> {
        return SIMD3<Float>(0.22, 0.14, 0)
    }

    private func guideSpeechLayout(for text: String) -> (text: String, width: Float, height: Float) {
        let wrappedText = wrappedGuideText(text, maximumWordsPerLine: 8)
        let lines = wrappedText.split(separator: "\n", omittingEmptySubsequences: false)
        let longestLineCount = lines.map(\.count).max() ?? text.count
        let width = clamped(Float(longestLineCount) * 0.0064 + 0.10, 0.24, 0.56)
        let height = clamped(Float(lines.count) * 0.022 + 0.060, 0.082, 0.24)
        return (wrappedText, width, height)
    }

    private func wrappedGuideText(_ text: String, maximumWordsPerLine: Int) -> String {
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var currentWords: [String] = []

        for word in words {
            if currentWords.count == maximumWordsPerLine {
                lines.append(currentWords.joined(separator: " "))
                currentWords = [word]
            } else {
                currentWords.append(word)
            }
        }

        if !currentWords.isEmpty {
            lines.append(currentWords.joined(separator: " "))
        }

        return lines.joined(separator: "\n")
    }

    private func guideCloudPosition(cameraPosition: SIMD3<Float>, cameraRight: SIMD3<Float>) -> SIMD3<Float> {
        defaultGuideCloudPosition
    }

    private func radarAppearsOnRight(
        radarPosition: SIMD3<Float>,
        cameraPosition: SIMD3<Float>,
        cameraRight: SIMD3<Float>
    ) -> Bool {
        simd_dot(radarPosition - cameraPosition, cameraRight) > 0
    }

    private func diagonalMarkerOffset(direction: SIMD3<Float>, distance: Float) -> SIMD3<Float> {
        let length = simd_length(direction)
        guard length > 0.0001 else { return SIMD3<Float>(0, distance, 0) }
        return direction / length * distance
    }

    private func estimatedShadowPosition(
        objectPosition: SIMD3<Float>,
        lightPosition: SIMD3<Float>,
        objectType: LearningObjectType
    ) -> SIMD3<Float> {
        let groundDirection = ShadowGeometryCalculator.groundShadowDirection(
            lightPosition: lightPosition,
            objectPosition: objectPosition
        ) ?? SIMD3<Float>(-1, 0, 0)
        let objectHeight = scaledObjectDimensions(for: objectType).y
        let lightDirection = simd_normalize(objectPosition - lightPosition)
        let estimatedLength = ShadowGeometryCalculator.approximateShadowLength(
            lightDirection: lightDirection,
            objectHeight: objectHeight
        ) ?? 0.38
        let dimensions = scaledObjectDimensions(for: objectType)
        let footprintDepth = projectedShadowFootprintDepth(for: objectType, dimensions: dimensions)
        let projectedLength = estimatedLength * predefinedShadowLengthMultiplier(for: objectType)
        let shadowLength = clamped(
            max(projectedLength, dimensions.y * 1.05) + footprintDepth * 1.25,
            0.58,
            1.55
        )
        let length = max(0.04, shadowLength * 0.5 - footprintDepth * 0.52)
        return objectPosition + groundDirection * length + SIMD3<Float>(0, 0.025, 0)
    }

    private func makeCheckpointHighlightEntity() -> Entity {
        let root = Entity()
        var material = UnlitMaterial(color: UIColor.systemBlue.withAlphaComponent(0.55))
        material.blending = .transparent(opacity: 0.55)
        let circle = ModelEntity(mesh: .generateSphere(radius: 0.55), materials: [material])
        circle.scale = SIMD3<Float>(1, 0.035, 1)
        root.addChild(circle)
        return root
    }

    private func makeRadarEntity(target: Level1RadarTarget) -> Entity {
        let root = makeWhiteMarkEntity(name: "level1-radar-\(target.rawValue)", receivesInput: true)
        root.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.04)]))
        root.components.set(InputTargetComponent())
        return root
    }

    private func makeWhiteMarkEntity(name: String, receivesInput: Bool) -> Entity {
        let root = Entity()
        root.name = name

        let dot = ModelEntity(
            mesh: .generateSphere(radius: 0.007),
            materials: [UnlitMaterial(color: .white)]
        )
        dot.name = "\(name)-center"
        dot.components.set(DynamicLightShadowComponent(castsShadow: false))
        if receivesInput {
            dot.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.018)]))
            dot.components.set(InputTargetComponent())
        }
        root.addChild(dot)

        let ring = ModelEntity(
            mesh: .generatePlane(width: 0.022, height: 0.022),
            materials: [Self.radarRingMaterial(alpha: 1.0)]
        )
        ring.name = "\(name)-ring"
        ring.components.set(BillboardComponent())
        ring.components.set(DynamicLightShadowComponent(castsShadow: false))
        ring.components.set(PulseAnimationComponent(baseScale: 1, speed: 3.8, amplitude: 0.45, isActiveTarget: true))
        if receivesInput {
            ring.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.04)]))
            ring.components.set(InputTargetComponent())
        }
        root.addChild(ring)

        return root
    }

    private static func radarRingMaterial(alpha: Float) -> UnlitMaterial {
        var material = UnlitMaterial()
        if let texture = cachedRadarRingTexture ?? generateRadarRingTexture() {
            cachedRadarRingTexture = texture
            material.color = .init(
                tint: UIColor.white.withAlphaComponent(CGFloat(alpha)),
                texture: .init(texture)
            )
        } else {
            material.color = .init(tint: UIColor.white.withAlphaComponent(CGFloat(alpha)))
        }
        material.blending = .transparent(opacity: .init(floatLiteral: alpha))
        return material
    }

    private static func generateRadarRingTexture(
        size: CGFloat = 256,
        strokeWidthFraction: CGFloat = 0.1
    ) -> TextureResource? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            context.cgContext.clear(rect)
            let lineWidth = size * strokeWidthFraction
            let ringRect = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(lineWidth)
            context.cgContext.strokeEllipse(in: ringRect)
        }
        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource(image: cgImage, withName: nil, options: .init(semantic: .color))
    }

    /// Dibuat sebagai anak dari marker, sehingga ikut berpindah bersamanya.
    /// Titik-titik kecil memberi visual garis putus-putus tanpa update per
    /// frame atau overlay SwiftUI tambahan.
    private func makeDashedLeader(toward targetOffset: SIMD3<Float>) -> Entity {
        let leader = Entity()
        let length = simd_length(targetOffset)
        guard length > 0.001 else { return leader }

        let material = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.9))
        let fractions: [Float] = [0.14, 0.26, 0.38, 0.50, 0.62, 0.74, 0.86]

        for fraction in fractions {
            let dash = ModelEntity(mesh: .generateSphere(radius: 0.0032), materials: [material])
            dash.position = targetOffset * fraction
            dash.components.set(DynamicLightShadowComponent(castsShadow: false))
            leader.addChild(dash)
        }
        return leader
    }


    private func makeLightEntity(from position: SIMD3<Float>, aimingAt target: SIMD3<Float>) -> Entity {
        let root = Entity()
        root.position = position

        let light = Entity()
        var component = SpotLightComponent()
        component.color = .yellow
        component.intensity = 4_200
        component.attenuationRadius = 5.5
        component.innerAngleInDegrees = 16
        component.outerAngleInDegrees = 46
        light.components.set(component)
        var shadow = SpotLightComponent.Shadow()
        shadow.zNear = .fixed(0.01)
        shadow.zFar = .fixed(8)
        shadow.depthBias = 0.004
        light.components.set(shadow)
        if let angles = SceneLightSystem.aimingAngles(from: position, to: target) {
            light.orientation = SceneLightSystem.orientation(
                yawDegrees: angles.yawDegrees,
                pitchDegrees: angles.pitchDegrees
            )
        }
        root.addChild(light)

        let marker = ModelEntity(mesh: .generateSphere(radius: 0.08), materials: [UnlitMaterial(color: .yellow)])
        marker.components.set(DynamicLightShadowComponent(castsShadow: false))
        root.addChild(marker)
        return root
    }

    private func lightOffset(for objectType: LearningObjectType) -> SIMD3<Float> {
        let heightAdjustment: Float = objectType == .sphere ? 0.04 : 0
        return SIMD3<Float>(0.48, 0.46 + heightAdjustment, -0.42)
    }


    private func scaledObjectDimensions(for objectType: LearningObjectType) -> SIMD3<Float> {
        let base = SceneObjectSystem.baseDimensions(for: objectType)
        let scale = checkpointHeight / base.y
        return base * scale
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
