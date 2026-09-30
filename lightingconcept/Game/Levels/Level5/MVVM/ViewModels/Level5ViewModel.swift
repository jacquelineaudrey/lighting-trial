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

    private(set) var successFeedbackTrigger = 0
    private(set) var isNarrationComplete = false
    private(set) var isTransitioning = false

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

    init(progressStore: GameProgressStore? = nil) {
        self.progressStore = progressStore ?? .shared

        let firstLightID = arSceneViewModel.selectedLightID

        selectedLightIDForUI = firstLightID

        arSceneViewModel.selectedObjectType = .cube

        arSceneViewModel.objectScale = 0.82

        arSceneViewModel.objectDirectManipulationLocked = true

        arSceneViewModel.interactionMode = .moveLight

        arSceneViewModel.autoPlaceOnSurfaceFound = true

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
        phase == .exploration && arSceneViewModel.lights.count >= 2 && hasMovedLeft && hasMovedRight
    }

    var explorationInstruction: String {
        if !hasMovedLeft {
            return "Jalan sedikit ke kiri untuk melihat bayangannya."
        }

        if !hasMovedRight {
            return "Sekarang jalan ke kanan dan bandingkan bayangannya."
        }

        return "Kamu sudah melihat dari dua arah. Pilih Lampu 1 atau Lampu 2, lalu atur susunannya."
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

    func narrationWillStart() {
        isNarrationComplete = false
    }

    func narrationDidFinish() {
        isNarrationComplete = true
    }

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
        arSceneViewModel.interactionMode = .moveLight
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

    func addSecondLight() {

        guard phase == .singleLightIntro, arSceneViewModel.isObjectPlaced else {
            return
        }

        arSceneViewModel.addLight()

        let secondLightID = arSceneViewModel.selectedLightID

        arSceneViewModel.updateSelectedLight {
            light in

            light.name = "Lampu 2"
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
