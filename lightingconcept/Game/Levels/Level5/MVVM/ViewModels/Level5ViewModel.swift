//
//  Level5ViewModel.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 28/09/26.
//

import ARKit
import Combine
import Foundation
import Observation
import Photos
import RealityKit
import SwiftUI
import UIKit
import simd

@MainActor
@Observable
final class Level5ViewModel: ARSceneTelemetryDelegate {

    let arSceneViewModel = ARSceneViewModel()

    private(set) var phase: Level5Phase = .placingScene
    private(set) var selectedLightIDForUI: UUID

    private(set) var hasMovedLeft = false
    private(set) var hasMovedRight = false
    private(set) var isLookAroundMode = false

    private(set) var successFeedbackTrigger = 0
    private(set) var isNarrationComplete = false
    private(set) var isTransitioning = false

    private(set) var guideOverlayScreenPosition: CGPoint?

    var showsDrawingCamera = false

    private(set) var photoSaveMessage: String?
    private(set) var frozenSceneImage: UIImage?
    private(set) var userDrawingImage: UIImage?

    @ObservationIgnored private let progressStore: GameProgressStore

    @ObservationIgnored private var referenceCameraPosition: SIMD3<Float>?

    @ObservationIgnored private var referenceCameraRight = SIMD3<Float>(1, 0, 0)

    @ObservationIgnored private var minimumLateralDisplacement: Float = 0

    @ObservationIgnored private var maximumLateralDisplacement: Float = 0

    @ObservationIgnored private var activeNarrationID: String?

    @ObservationIgnored private var isWaitingForARSnapshot = false

    // AR owns a lightweight anchor only. SwiftUI owns the visible guide,
    // matching Levels 1–4 and keeping character state in this ViewModel.
    @ObservationIgnored private weak var guideParent: Entity?
    @ObservationIgnored private var guideRoot: Entity?
    @ObservationIgnored private var guideNeedsPlacement = true
    @ObservationIgnored private let guideForwardDistance: Float = 0.66
    @ObservationIgnored private let guideRightDistance: Float = 0.30
    @ObservationIgnored private let guideVerticalOffset: Float = -0.54
    @ObservationIgnored private let guideFollowLerp: Float = 0.24

    init(progressStore: GameProgressStore? = nil) {
        self.progressStore = progressStore ?? .shared

        let firstLightID = arSceneViewModel.selectedLightID

        selectedLightIDForUI = firstLightID

        arSceneViewModel.selectedObjectType = .cube

        arSceneViewModel.objectScale = 0.82

        arSceneViewModel.objectDirectManipulationLocked = true

        arSceneViewModel.interactionMode = .moveLight

        arSceneViewModel.autoPlaceOnSurfaceFound = false

        arSceneViewModel.requiresLiDARScanBeforePlacement = false

        arSceneViewModel.usesLiDARSceneReconstruction = false

        arSceneViewModel.usesLiDARPhysicsInteraction = false

        arSceneViewModel.usesRealisticEnvironmentLighting = false

        arSceneViewModel.showLightDirection = true

        arSceneViewModel.showLightRays = true

        arSceneViewModel.showGroundProjection = true

        arSceneViewModel.showProjectionLines = false

        arSceneViewModel.showShadowLabels = false

        arSceneViewModel.showShadowInformation = false

        configureFirstLight()
    }

    var isObjectPlaced: Bool {
        arSceneViewModel.isObjectPlaced
    }

    var selectedLightName: String {
        arSceneViewModel.selectedLight.name
    }

    var canLockArrangement: Bool {
        phase == .exploration
    }

    var explorationInstruction: String {
        "Pilih Lampu 1 atau Lampu 2, lalu atur susunannya. Tekan tombol jika sudah memilih."
    }

    var narrationText: String {
        switch phase {
        case .placingScene: Level5Content.placementText

        case .singleLightIntro: Level5Content.singleLightIntroText

        case .twoLightIntro: Level5Content.twoLightIntroText

        case .exploration: explorationInstruction

        case .drawingActive: Level5Content.drawingText

        case .photoPrompt: Level5Content.photoPromptText

        case .photoComparison: Level5Content.comparisonText

        case .completed: Level5Content.completionText
        }
    }

    var shouldSpeakNarration: Bool {
        switch phase {
        case .placingScene,
             .singleLightIntro,
             .twoLightIntro,
             .drawingActive,
             .photoPrompt,
             .completed:
            true

        case .exploration,
             .photoComparison:
            false
        }
    }

    var narrationID: String {
        "\(phase.rawValue)-\(hasMovedLeft)-\(hasMovedRight)-\(selectedLightIDForUI.uuidString)"
    }

    var guideText: String {
        narrationText
    }

    /// Setiap frame desain hanya menampilkan satu pemandu. Karakter diganti
    /// sesuai giliran dialog/instruksi, bukan digambar berdampingan.
    var guideCharacterAsset: CharacterGuideAsset {
        switch phase {
        case .singleLightIntro:
            return .lumiPointWink

        case .twoLightIntro:
            return .bayoQuestion

        case .exploration:
            if hasMovedLeft && hasMovedRight {
                return .lumiPoint
            }
            if hasMovedLeft {
                return .bayoPoint
            }
            return .lumiPointWink

        case .placingScene,
             .drawingActive,
             .photoPrompt,
             .photoComparison,
             .completed:
            return .lumiIdle
        }
    }

    var showsGuide: Bool {
        switch phase {

        case .placingScene,
             .drawingActive,
             .photoPrompt,
             .photoComparison,
             .completed:
            false

        case .singleLightIntro,
             .twoLightIntro,
             .exploration:
            true
        }
    }

    // MARK: - Shared ECS guide position / SwiftUI guide presentation

    func attachGuideIfNeeded(to parent: Entity) {
        if guideParent !== parent {
            guideRoot?.removeFromParent()
            guideParent = parent
            guideRoot = nil
            guideNeedsPlacement = true
        }

        guard guideRoot == nil else { return }
        let guide = Entity()
        guide.name = "Level 5 Guide Anchor"
        guide.isEnabled = false
        parent.addChild(guide)
        guideRoot = guide
    }

    func updateGuide(cameraPosition: SIMD3<Float>, forward cameraForward: SIMD3<Float>) {
        guard let guideRoot else { return }
        let horizontalForward = SIMD2<Float>(cameraForward.x, cameraForward.z)
        let length = simd_length(horizontalForward)
        guard length > 0.0001 else { return }

        let normalizedForward = horizontalForward / length
        let forward = SIMD3<Float>(normalizedForward.x, 0, normalizedForward.y)
        let right = SIMD3<Float>(-normalizedForward.y, 0, normalizedForward.x)
        let destination = cameraPosition
            + forward * guideForwardDistance
            + right * guideRightDistance
            + SIMD3<Float>(0, guideVerticalOffset, 0)

        if guideNeedsPlacement {
            guideRoot.position = destination
            guideNeedsPlacement = false
        } else {
            guideRoot.position += (destination - guideRoot.position) * guideFollowLerp
        }
        guideRoot.look(at: cameraPosition, from: guideRoot.position, relativeTo: nil)
    }

    var guideOverlayWorldPosition: SIMD3<Float>? {
        guard showsGuide, !guideNeedsPlacement, let guideRoot else { return nil }
        return guideRoot.position(relativeTo: nil)
    }

    func updateGuideOverlayScreenPosition(_ position: CGPoint?) {
        guard showsGuide else {
            guideOverlayScreenPosition = nil
            return
        }
        switch (guideOverlayScreenPosition, position) {
        case let (current?, next?) where hypot(current.x - next.x, current.y - next.y) < 4:
            return
        case (nil, nil):
            return
        default:
            guideOverlayScreenPosition = position
        }
    }

    func narrationWillStart() {
        isNarrationComplete = false
    }

    func narrationDidFinish() {
        isNarrationComplete = true
    }

#if DEBUG
    func jumpToDevFlow(_ flow: Level5DevFlow) {
        isWaitingForARSnapshot = false
        isTransitioning = false
        isNarrationComplete = true

        if flow != .placingScene {
            configureFirstLight()
            phase = .singleLightIntro
            if flow != .singleLightIntro {
                addSecondLight()
            }
        }

        switch flow {
        case .placingScene: phase = .placingScene
        case .singleLightIntro: phase = .singleLightIntro
        case .twoLightIntro: phase = .twoLightIntro
        case .exploration:
            phase = .exploration
            resetExplorationTracking()
        case .drawingActive:
            phase = .drawingActive
            arSceneViewModel.isViewFrozen = true
        case .photoPrompt:
            phase = .photoPrompt
            arSceneViewModel.isViewFrozen = true
        case .photoComparison: phase = .photoComparison
        case .completed: phase = .completed
        }
    }
#endif

    func sceneDidPlace(at worldPosition: SIMD3<Float>) {
        guard phase == .placingScene else {
            return
        }

        configureFirstLight()

        phase = .singleLightIntro

        successFeedbackTrigger += 1
    }

    func sceneDidReset() {
        phase = .placingScene

        resetExplorationTracking()
        isLookAroundMode = false
    }

    func cameraDidUpdate(position: SIMD3<Float>) {
        
    }

    func cameraDidUpdate(
        position: SIMD3<Float>,
        forward: SIMD3<Float>,
        right: SIMD3<Float>,
        up: SIMD3<Float>
    ) {
        guard phase == .exploration else {
            return
        }

        if referenceCameraPosition == nil {
            referenceCameraPosition = position

            referenceCameraRight = simd_normalize(SIMD3<Float>(right.x, 0, right.z))

            return
        }

        guard let referenceCameraPosition else {
            return
        }

        let displacement = position - referenceCameraPosition

        let lateralDisplacement = simd_dot(displacement, referenceCameraRight)

        minimumLateralDisplacement = min(minimumLateralDisplacement, lateralDisplacement)

        maximumLateralDisplacement = max(maximumLateralDisplacement, lateralDisplacement)

        hasMovedLeft = minimumLateralDisplacement <= -0.25

        hasMovedRight = maximumLateralDisplacement >= 0.25
    }

    func lightDidSelect() {
        isLookAroundMode = false
        arSceneViewModel.interactionMode = .moveLight
    }

    func sceneDidReceiveWorldTap() {
        guard phase == .exploration else { return }
        isLookAroundMode = true
        resetExplorationTracking()
    }

    func shadowConceptDidSelect(_ concept: ShadowConcept) {
        
    }

    func markerSurfaceToneDidChange(_ tone: EducationalMarkerStyle.SurfaceTone) {
        
    }

    func safetyWarningDidChange(_ warning: SafetyProximityWarning?) {
        arSceneViewModel.updateSafetyWarning(warning)
    }

    func dismissSafetyWarning() {
        arSceneViewModel.dismissSafetyWarning()
    }

    func startCompletedLevelReplayAtTask() {
        guard phase == .singleLightIntro else { return }
        addSecondLight()
        beginExploration()
    }

    func addSecondLight() {

        guard phase == .singleLightIntro else {
            return
        }

        arSceneViewModel.addLight()

        let secondLightID = arSceneViewModel.selectedLightID

        arSceneViewModel.updateSelectedLight {
            light in

            light.name = "Lampu 2"
            light.color = Color(red: 1.0, green: 0.76, blue: 0.10)
            light.position = SIMD3<Float>(0.42, 0.44, -0.16)
            light.intensity = 3_600
            light.beamSpread = .spread

            light.beamOuterAngleDegrees = nil

            if let aiming = SceneLightSystem.aimingAngles(from: light.position, to: SIMD3<Float>(0, 0.10, 0)) {
                light.yawDegrees = aiming.yawDegrees
                light.pitchDegrees = aiming.pitchDegrees
            }
        }

        selectedLightIDForUI = secondLightID
        arSceneViewModel.interactionMode = .moveLight
        phase = .twoLightIntro
        successFeedbackTrigger += 1
    }

    func beginExploration() {
        guard phase == .twoLightIntro else {
            return
        }

        phase = .exploration
        arSceneViewModel.interactionMode = .moveLight
        resetExplorationTracking()
        isLookAroundMode = false
        successFeedbackTrigger += 1
    }

    func selectLight(_ id: UUID) {
        guard phase == .exploration else {
            return
        }

        guard arSceneViewModel.lights.contains(where: { $0.id == id }) else {
            return
        }

        arSceneViewModel.selectedLightID = id
        arSceneViewModel.interactionMode = .moveLight
        selectedLightIDForUI = id
        isLookAroundMode = false
    }

    func confirmArrangement() {
        guard canLockArrangement else {
            return
        }

        arSceneViewModel.isViewFrozen = true
        phase = .drawingActive
        isNarrationComplete = false
        successFeedbackTrigger += 1
    }

    func finishDrawing() {
        guard phase == .drawingActive, !isTransitioning else {
            return
        }

        phase = .photoPrompt
        isNarrationComplete = false
        successFeedbackTrigger += 1
    }

    func captureDrawingPhoto() {
        guard phase == .photoPrompt, !isTransitioning, !isWaitingForARSnapshot else {
            return
        }

        isWaitingForARSnapshot = true
        arSceneViewModel.captureSnapshot()
    }

    func handleCapturedARSnapshot(_ image: UIImage?) {
        guard isWaitingForARSnapshot else {
            return
        }

        guard let image else {
            return
        }

        isWaitingForARSnapshot = false

        frozenSceneImage = image

        showsDrawingCamera = true
    }

    func cancelDrawingCamera() {
        showsDrawingCamera = false

        isWaitingForARSnapshot = false
    }

    func completeUserDrawingPhoto(_ image: UIImage) {
        showsDrawingCamera = false

        saveImageToPhotoLibrary(image) { [weak self] success, message in
            guard let self else { return }

            guard success else {
                self.photoSaveMessage = message
                return
            }

            self.userDrawingImage = image
            self.phase = .photoComparison
            self.successFeedbackTrigger += 1
        }
    }

    func clearPhotoSaveMessage() {
        photoSaveMessage = nil
    }

    func completePhotoComparison() {
        guard phase == .photoComparison else { return }

        phase = .completed
        progressStore.markLevelCompleted(Level5Content.levelID)
        successFeedbackTrigger += 1
    }

    func returnFromCompletedLevel() {
        // The actual unlock chain for Level 5 is completed here once the
        // project's GameProgressStore includes Level 5 in playable IDs.
    }

    private func configureFirstLight() {

        guard let firstLightID = arSceneViewModel.lights.first?.id else { return }

        arSceneViewModel.selectedLightID = firstLightID
        selectedLightIDForUI = firstLightID
        arSceneViewModel.updateSelectedLight {
            light in

            light.name = "Lampu 1"
            light.type = .spot
            light.color = Color(red: 1.0, green: 0.76, blue: 0.10)
            light.position = SIMD3<Float>(-0.42, 0.44, 0.18)
            light.intensity = 3_600
            light.beamSpread = .spread
            light.beamOuterAngleDegrees = nil

            if let aiming = SceneLightSystem.aimingAngles(from: light.position, to: SIMD3<Float>(0, 0.10, 0)) {
                light.yawDegrees = aiming.yawDegrees
                light.pitchDegrees = aiming.pitchDegrees
            }
        }
    }

    private func resetExplorationTracking() {
        referenceCameraPosition = nil
        referenceCameraRight = SIMD3<Float>(1, 0, 0)
        minimumLateralDisplacement = 0
        maximumLateralDisplacement = 0
        hasMovedLeft = false
        hasMovedRight = false
    }

    private func saveImageToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in

            guard status == .authorized || status == .limited
            else {
                Task {
                    @MainActor in completion(false, "Izinkan akses Photos untuk menyimpan foto.")
                }
                return
            }

            PHPhotoLibrary.shared()
                .performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)

                }) { success, error in
                    Task {
                        @MainActor in completion(success, success ? nil : "Foto belum tersimpan. \(error?.localizedDescription ?? "")")
                    }
                }
        }
    }
}
