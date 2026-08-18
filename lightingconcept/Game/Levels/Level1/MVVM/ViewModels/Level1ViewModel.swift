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
    @Published var showsDrawingCamera = false
    @Published private(set) var photoSaveMessage: String?
    @Published var showsFreezeSceneConfirmation = false
    @Published private(set) var isSceneFrozen = false
    @Published private(set) var successFeedbackTrigger = 0

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
    private var checkpointShadowEntities: [Entity] = []
    private var checkpointLocalPositions: [SIMD3<Float>] = []
    private var markerWorldPositions: [SIMD3<Float>] = []
    private var checkpointHighlightEntities: [Entity] = []
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
    private let pathRadius: Float = 3.2
    private let checkpointHeight: Float = 0.34
    private let markerRadius: Float = 1.0

    private static var cachedRadarRingTexture: TextureResource?

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
        checkpointShadowEntities.removeAll()
        checkpointLocalPositions.removeAll()
        markerWorldPositions.removeAll()
        checkpointHighlightEntities.removeAll()
        shadowReceiverManager.reset()
        latestHorizontalPlaneAnchor = nil
        guideNeedsPlacement = true
        guideRoot?.isEnabled = false
        hasWaypointTarget = false
        recentlyExplainedCheckpointIndex = nil
        hasContinuedToShapeSelection = false
        frozenSceneImage = nil
        userDrawingImage = nil
        showsDrawingCamera = false
        showsFreezeSceneConfirmation = false
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
        showsFreezeSceneConfirmation = false
    }

    func confirmFreezeSceneAndStartDrawing() {
        guard (phase == .textureExploration || phase == .shapeChange), canConfirmDrawingChoices else {
            showsFreezeSceneConfirmation = false
            return
        }

        showsFreezeSceneConfirmation = false
        activeExperimentPanel = nil
        showsObjectModeBadge = false
        hidesGuideForDrawing = false
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
            self.phase = .photoComparison
            self.triggerSuccessFeedback()
            self.syncEntities()
        }
    }

    func completeLevelAfterPhotoComparison() {
        guard phase == .photoComparison else { return }
        phase = .completed
        progressStore.markLevelCompleted(Level1Content.levelID)
        triggerSuccessFeedback()
        syncEntities()
    }

    func clearPhotoSaveMessage() {
        photoSaveMessage = nil
    }

    #if DEBUG
    func debugAdvanceCurrentPhase() {
        switch phase {
        case .scanningSurface, .surfaceReady:
            debugJumpToLightShadowIntro()
        case .onboarding:
            onboardingIndex = max(0, onboardingDialog.count - 1)
            phase = .lightShadowIntro
            lightShadowIndex = 0
        case .lightShadowIntro:
            debugJumpToShapeAdventure()
        case .findingShapes:
            debugCompleteShapeAdventure()
        case .returningToFirstObject:
            debugJumpToTexturePrompt()
        case .textureTapPrompt:
            objectTappedForTexture()
        case .textureExploration:
            debugJumpToShapeSelectionReady()
        case .shapeChange:
            debugJumpToDrawingReady()
        case .drawingPrompt:
            phase = .drawingReady
            syncEntities()
        case .drawingReady, .drawingActive:
            finishDrawing()
        case .photoPrompt:
            debugJumpToPhotoComparison()
        case .photoComparison:
            completeLevelAfterPhotoComparison()
        case .completed:
            break
        }
        successFeedbackTrigger += 1
    }

    func debugJumpToLightShadowIntro() {
        debugEnsureScenePlaced()
        onboardingIndex = max(0, onboardingDialog.count - 1)
        lightShadowIndex = 0
        selectedRadarTarget = nil
        phase = .lightShadowIntro
        hasWaypointTarget = false
        syncEntities()
    }

    func debugJumpToShapeAdventure() {
        debugEnsureScenePlaced()
        phase = .findingShapes
        currentCheckpointIndex = nextTargetCheckpointIndex ?? 0
        recentlyExplainedCheckpointIndex = nil
        hasWaypointTarget = true
        syncEntities()
    }

    func debugCompleteShapeAdventure() {
        debugEnsureScenePlaced()
        visitedCheckpoints = Set(checkpoints.indices)
        recentlyExplainedCheckpointIndex = nil
        currentCheckpointIndex = 0
        phase = .returningToFirstObject
        hasWaypointTarget = true
        syncEntities()
    }

    func debugJumpToTexturePrompt() {
        debugEnsureScenePlaced()
        visitedCheckpoints = Set(checkpoints.indices)
        recentlyExplainedCheckpointIndex = nil
        phase = .textureTapPrompt
        currentCheckpointIndex = 0
        hasWaypointTarget = false
        showsObjectModeBadge = false
        activeExperimentPanel = nil
        syncEntities()
    }

    func debugJumpToTextureSelection() {
        debugJumpToTexturePrompt()
        objectTappedForTexture()
    }

    func debugJumpToShapeSelectionReady() {
        debugEnsureScenePlaced()
        visitedCheckpoints = Set(checkpoints.indices)
        phase = .shapeChange
        currentCheckpointIndex = 0
        currentTextureIndex = min(1, max(0, textureStops.count - 1))
        hasSelectedTexture = true
        hasSelectedShape = false
        hasOpenedTextureControls = true
        hasOpenedShapeControls = false
        hasContinuedToShapeSelection = true
        showsObjectModeBadge = true
        activeExperimentPanel = nil
        applyCurrentTextureToPrimaryObject()
        syncEntities()
    }

    func debugJumpToDrawingReady() {
        debugEnsureScenePlaced()
        visitedCheckpoints = Set(checkpoints.indices)
        phase = .shapeChange
        currentCheckpointIndex = 0
        currentTextureIndex = min(1, max(0, textureStops.count - 1))
        selectedShapeIndex = min(1, max(0, shapeOptions.count - 1))
        hasSelectedTexture = true
        hasSelectedShape = true
        hasOpenedTextureControls = true
        hasOpenedShapeControls = true
        hasContinuedToShapeSelection = true
        showsObjectModeBadge = true
        activeExperimentPanel = nil
        applyCurrentTextureToPrimaryObject()
        applyCurrentShapeToPrimaryObject()
        syncEntities()
    }

    func debugJumpToPhotoPrompt() {
        debugEnsureScenePlaced()
        isSceneFrozen = true
        hidesGuideForDrawing = false
        showsObjectModeBadge = false
        activeExperimentPanel = nil
        phase = .photoPrompt
        syncEntities()
    }

    func debugJumpToPhotoComparison() {
        debugEnsureScenePlaced()
        isSceneFrozen = true
        frozenSceneImage = frozenSceneImage ?? debugPlaceholderImage(title: "Contoh")
        userDrawingImage = userDrawingImage ?? debugPlaceholderImage(title: "Hasil")
        showsDrawingCamera = false
        phase = .photoComparison
        syncEntities()
    }

    private func debugEnsureScenePlaced() {
        placeSceneIfNeeded()
        if checkpointEntities.isEmpty {
            phase = .scanningSurface
        }
    }

    private func debugPlaceholderImage(title: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 360, height: 260))
        return renderer.image { context in
            UIColor(white: 0.92, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 360, height: 260))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.darkGray
            ]
            title.draw(at: CGPoint(x: 28, y: 108), withAttributes: attributes)
        }
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
        let firstCheckpointDistance: Float = 1.25
        let pathCenterXZ = scanCameraXZ + scanForwardXZ * (pathRadius + firstCheckpointDistance)
        let firstCheckpointDirection = -scanForwardXZ

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
                shapeXZ = scanCameraXZ + scanForwardXZ * (firstCheckpointDistance + Float(index) * 1.40)
            } else {
                let angleStep = (2 * Float.pi) / Float(count)
                let baseAngle = atan2(firstCheckpointDirection.y, firstCheckpointDirection.x)
                let angle = baseAngle + angleStep * Float(index)
                shapeXZ = pathCenterXZ + SIMD2<Float>(cos(angle), sin(angle)) * pathRadius
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

            let shadowEntity = makeShadowEntity(
                for: checkpoint.shape.objectType,
                objectPosition: localPosition,
                lightPosition: lightPosition
            )
            checkpointShadowEntities.append(shadowEntity)
            anchorGroup.addChild(shadowEntity)

            // Checkpoint floor ring sengaja tidak dibuat: Level 1 sekarang
            // fokus pada cahaya, bayangan, dan objek uji yang sama.
        }

        let primaryObjectPosition = checkpointLocalPositions.first ?? .zero
        let primaryLightPosition = checkpointLightEntities.first?.position ?? primaryObjectPosition + lightOffset(for: .cube)
        // Semua checkpoint selalu membuat entity bayangan. Fallback di sini
        // hanya untuk menjaga posisi marker tetap aman bila scene dibersihkan.
        let primaryShadowPosition = checkpointShadowEntities.first?.position ?? primaryObjectPosition
        // White mark diberi jarak dari target dan terhubung garis putus-putus,
        // supaya tidak tenggelam ke dalam objek atau bayangan.
        let objectTargetPosition = primaryObjectPosition + SIMD3<Float>(0, checkpointHeight * 0.62, 0)
        let radarPositions: [Level1RadarTarget: (target: SIMD3<Float>, marker: SIMD3<Float>)] = [
            .light: (
                primaryLightPosition,
                primaryLightPosition + diagonalMarkerOffset(direction: SIMD3<Float>(1, 1, 1), distance: 0.30)
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
            radar.addChild(makeDashedLeader(toward: positions.target - positions.marker))
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

        for (index, shadow) in checkpointShadowEntities.enumerated() {
            shadow.isEnabled = showLightAndShadow && (checkpointEntities[safe: index]?.isEnabled == true)
        }

        for (index, light) in checkpointLightEntities.enumerated() {
            light.isEnabled = showLightAndShadow && (checkpointEntities[safe: index]?.isEnabled == true)
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
    }

    private func applyCurrentShapeToPrimaryObject() {
        guard let entity = checkpointEntities.first else { return }
        let replacement = SceneObjectSystem.makeObject(type: selectedShape.objectType, texture: currentTexture.material)
        entity.model = replacement.model
        entity.collision = replacement.collision
        let finalScale = checkpointHeight / SceneObjectSystem.baseDimensions(for: selectedShape.objectType).y
        if let primaryShadow = checkpointShadowEntities.first {
            configureShadowEntity(
                primaryShadow,
                for: selectedShape.objectType,
                objectPosition: checkpointLocalPositions.first ?? .zero,
                lightPosition: checkpointLightEntities.first?.position ?? lightOffset(for: selectedShape.objectType)
            )
        }
        entity.scale = SIMD3<Float>(repeating: finalScale)
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
        return entity
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
        phase != .scanningSurface && phase != .drawingActive && phase != .completed
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
            return .lumiQuestion
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
        component.intensity = 3_800
        component.attenuationRadius = 3.8
        component.innerAngleInDegrees = 16
        component.outerAngleInDegrees = 38
        light.components.set(component)
        var shadow = SpotLightComponent.Shadow()
        shadow.zNear = .fixed(0.01)
        shadow.zFar = .fixed(4)
        shadow.depthBias = 0.03
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


    private func makeShadowEntity(
        for objectType: LearningObjectType,
        objectPosition: SIMD3<Float>,
        lightPosition: SIMD3<Float>
    ) -> Entity {
        let root = Entity()
        configureShadowEntity(root, for: objectType, objectPosition: objectPosition, lightPosition: lightPosition)
        return root
    }

    /// Memakai kalkulator bayangan shared agar arah dan panjangnya konsisten
    /// dengan level lain.
    private func configureShadowEntity(
        _ root: Entity,
        for objectType: LearningObjectType,
        objectPosition: SIMD3<Float>,
        lightPosition: SIMD3<Float>
    ) {
        root.children.removeAll()
        let lightDirection = simd_normalize(objectPosition - lightPosition)
        let groundDirection = ShadowGeometryCalculator.groundShadowDirection(
            lightPosition: lightPosition,
            objectPosition: objectPosition
        ) ?? SIMD3<Float>(-1, 0, 0)
        let objectHeight = scaledObjectDimensions(for: objectType).y
        let topCenter = objectPosition + SIMD3<Float>(0, objectHeight, 0)
        let projectedTop = ShadowGeometryCalculator.projectPointAlongLightDirection(
            vertexPosition: topCenter,
            lightDirection: lightDirection,
            planeY: objectPosition.y
        )
        let projectedLength = projectedTop.map {
            simd_length(SIMD3<Float>($0.x - objectPosition.x, 0, $0.z - objectPosition.z))
        }
        let estimatedLength = ShadowGeometryCalculator.approximateShadowLength(
            lightDirection: lightDirection,
            objectHeight: objectHeight
        )
        let rawLength = projectedLength ?? estimatedLength ?? 0.38
        let length = clamped(rawLength * 1.05, 0.40, 1.35)
        root.position = objectPosition + groundDirection * (length * 0.52) + SIMD3<Float>(0, 0.018, 0)
        root.orientation = simd_quatf(angle: atan2(groundDirection.z, groundDirection.x), axis: [0, 1, 0])

        let shadowWidth = shadowBaseWidth(for: objectType)
        let layers: [(lengthMultiplier: Float, widthMultiplier: Float, alpha: Float)] = [
            (1.00, 1.04, 0.62),
            (1.16, 1.24, 0.34),
            (1.36, 1.46, 0.16)
        ]

        for (index, layer) in layers.enumerated() {
            var material = UnlitMaterial(color: UIColor.black.withAlphaComponent(CGFloat(layer.alpha)))
            material.blending = .transparent(opacity: .init(floatLiteral: layer.alpha))
            let shadow = makeShadowLayer(
                for: objectType,
                length: length * layer.lengthMultiplier,
                width: shadowWidth * layer.widthMultiplier,
                material: material
            )
            shadow.name = "level1-soft-shadow-\(index)"
            shadow.position.y = Float(index) * 0.002
            shadow.components.set(DynamicLightShadowComponent(castsShadow: false))
            root.addChild(shadow)
        }
    }

    private func makeShadowLayer(
        for objectType: LearningObjectType,
        length: Float,
        width: Float,
        material: UnlitMaterial
    ) -> ModelEntity {
        switch objectType {
        case .cube, .cuboid, .squarePyramid, .triangularPyramid:
            return ModelEntity(
                mesh: .generateBox(width: max(length, 0.12), height: 0.005, depth: max(width, 0.09)),
                materials: [material]
            )
        case .sphere, .cylinder, .cone, .hemisphere:
            let radius = max(width * 0.5, 0.04)
            let entity = ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
            entity.scale = SIMD3<Float>(max(length / max(width, 0.001), 0.8), 0.012, 1.0)
            return entity
        }
    }

    private func shadowBaseWidth(for objectType: LearningObjectType) -> Float {
        let dimensions = scaledObjectDimensions(for: objectType)
        let footprint = max(dimensions.x, dimensions.z)
        switch objectType {
        case .cuboid:
            return footprint * 1.08
        case .squarePyramid, .triangularPyramid:
            return footprint * 0.92
        case .cone:
            return footprint * 0.84
        case .cube, .sphere, .cylinder, .hemisphere:
            return footprint
        }
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
