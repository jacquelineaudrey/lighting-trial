import Foundation
import Observation
import simd
import RealityKit
import QuartzCore
import UIKit
import Photos

enum Level3Phase: String, Codable, Equatable {
    case onboarding
    case placingScene
    case surfaceReady
    case shadowExploration
    case shadowTrivia
    case shadowTypesInteraction
    case shapeComparison
    case closing
    case review
    case drawingPrompt
    case drawingReady
    case photoPrompt
    case photoComparison
    case completed
}

enum Level3DevFlow: String, CaseIterable, Identifiable {
    case onboarding = "Onboarding"
    case shadowExplorationCube = "Marker Kubus"
    case shadowExplorationSphere = "Marker Bola"
    case review = "Tombol Info"
    case drawingPrompt = "Mulai Gambar"
    case completed = "Selesai"

    var id: String { rawValue }
}

@MainActor
@Observable
final class Level3ViewModel: ARSceneTelemetryDelegate {
    enum ShadowMarkerRound {
        case cube
        case sphere
    }

    private static let fixedBeamSpreadDegrees: Float = 54
    private static let fixedLightIntensity: Float = 3_200
    private static let cubeRequiredShadowConcepts: Set<ShadowConcept> = [.lightSide, .shadowSide, .castShadow]
    private static let sphereRequiredShadowConcepts: Set<ShadowConcept> = [.lightSide, .shadowSide, .castShadow, .reflectedLight]

    let arSceneViewModel = ARSceneViewModel()
    var lastMarkerTapTime: Date = Date.distantPast
    private(set) var phase: Level3Phase = .onboarding
    private(set) var onboardingIndex = 0
    private(set) var shadowTriviaIndex = 0
    private(set) var shadowTypesIndex = 0
    private(set) var closingIndex = 0
    private(set) var reviewIndex = 0
    private(set) var drawingIndex = 0

    private(set) var visitedShadowConcepts: Set<ShadowConcept> = []
    private(set) var hasCompletedShadowTask = false
    private(set) var markerRound: ShadowMarkerRound = .cube
    private(set) var shadowVisible = true
    private(set) var selectedComparison: ComparisonShape = .cube
    private(set) var hasComparedShapes = false
    private(set) var isNarrationComplete = false
    private(set) var markerNarrationTrigger = 0
    private(set) var narrationRevision = 0
    @ObservationIgnored private var comparedShapes: Set<ComparisonShape> = []
    private(set) var successFeedbackTrigger = 0
    private(set) var progressCelebration: LessonProgressCelebration?
    
    private(set) var isShadowInfoOpen = false
    private(set) var hasSelectedShadowTypesMenu = false
    private(set) var frozenSceneImage: UIImage?
    private(set) var userDrawingImage: UIImage?
    private(set) var photoSaveMessage: String?
    var showsDrawingCamera = false
    var showsFreezeSceneConfirmation = false
    var isSavingDrawingPhoto = false

    var shouldShowInfoGesture: Bool {
        phase == .review && reviewIndex <= 1 && !hasSelectedShadowTypesMenu
    }

    @ObservationIgnored private let progressStore: GameProgressStore
    @ObservationIgnored private var previousCameraForward = SIMD3<Float>(0, 0, -1)
    @ObservationIgnored private var resumePhaseAfterPlacement: Level3Phase?
    @ObservationIgnored private var markerCompletionTask: Task<Void, Never>?
    @ObservationIgnored private var lastExplainedShadowConcept: ShadowConcept?
    @ObservationIgnored private var lastExplainedConceptWorldPosition: SIMD3<Float>?
    @ObservationIgnored private var pendingHiddenShadowConcept: ShadowConcept?
    
    // MARK: - AR Guide (Bayo) State
    @ObservationIgnored private weak var guideParent: Entity?
    @ObservationIgnored private var guideRoot: Entity?
    @ObservationIgnored private var guideCharacter: Entity?
    @ObservationIgnored private var guideCharacterAsset: CharacterGuideAsset?
    @ObservationIgnored private var guideCloud: Entity?
    @ObservationIgnored private var guideText: String?
    @ObservationIgnored private var guideNeedsPlacement = true
    @ObservationIgnored private let guideForwardDistance: Float = 0.66
    @ObservationIgnored private let guideRightDistance: Float = 0.30
    @ObservationIgnored private let guideVerticalOffset: Float = -0.54
    @ObservationIgnored private let guideFollowLerp: Float = 0.24

    enum ComparisonShape: String, CaseIterable, Identifiable, Hashable {
        case cube = "Kubus"
        case sphere = "Bola"
        var id: String { rawValue }
        var objectType: LearningObjectType { self == .cube ? .cube : .sphere }
    }

    init(progressStore: GameProgressStore? = nil) {
        self.progressStore = progressStore ?? .shared
        configureLearningScene()
    }

    var currentOnboardingLine: DialogLine { Level3Content.onboardingDialog[onboardingIndex] }
    var currentShadowTriviaLine: DialogLine { Level3Content.shadowTrivia[shadowTriviaIndex] }
    var currentShadowTypesLine: DialogLine { Level3Content.shadowTypesTrivia[shadowTypesIndex] }
    var currentClosingLine: DialogLine { Level3Content.closingDialog[closingIndex] }
    var currentReviewLine: DialogLine { Level3Content.reviewDialog[reviewIndex] }
    var currentDrawingLine: DialogLine { Level3Content.drawingDialog[drawingIndex] }

    // MARK: - Narration & Marker Audio
    
    var narrationText: String {
        if let concept = arSceneViewModel.selectedConcept {
            return text(for: concept)
        }
        
        switch phase {
        case .onboarding: return currentOnboardingLine.text
        case .placingScene: return "Arahkan titik tengah layar ke meja atau lantai, lalu tekan tombol Taruh Benda di Tengah."
        case .surfaceReady: return "Permukaan dan posisi benda sudah siap. Pilih Lanjut untuk mulai belajar, atau Scan Ulang untuk mengatur ulang permukaan."
        case .shadowExploration:
            if let lastExplainedShadowConcept {
                return text(for: lastExplainedShadowConcept)
            }
            if hasCompletedShadowTask {
                return currentShadowTriviaLine.text
            }
            return markerRound == .cube ? currentOnboardingLine.text : currentShadowTriviaLine.text
        case .shadowTrivia: return currentShadowTriviaLine.text
        case .shadowTypesInteraction: return currentShadowTypesLine.text
        case .shapeComparison: return "Pilih kubus dan bola. Bandingkan bentuk bayangan yang dihasilkan keduanya."
        case .closing: return currentClosingLine.text
        case .review:
            if let lastExplainedShadowConcept {
                return text(for: lastExplainedShadowConcept)
            }
            return currentReviewLine.text
        case .drawingPrompt, .drawingReady, .photoPrompt, .photoComparison: return currentDrawingLine.text
        case .completed: return "Level tiga selesai. Kamu hebat, Detektif Bayangan!"
        }
    }
    
    var narrationAudioFileName: String? {
        if let concept = arSceneViewModel.selectedConcept {
            return audioFileName(for: concept)
        }
        
        switch phase {
        case .onboarding: return currentOnboardingLine.audioFileName
        case .shadowTrivia: return currentShadowTriviaLine.audioFileName
        case .shadowTypesInteraction: return currentShadowTypesLine.audioFileName
        case .closing: return currentClosingLine.audioFileName
        case .review: return currentReviewLine.audioFileName
        case .drawingPrompt, .drawingReady, .photoPrompt, .photoComparison: return currentDrawingLine.audioFileName
        default: return nil
        }
    }
    
    private var currentGuideAsset: CharacterGuideAsset {
        if arSceneViewModel.selectedConcept != nil || lastExplainedShadowConcept != nil {
            return .bayoPoint
        }
        
        switch phase {
        case .onboarding:
            switch onboardingIndex {
            case 0:
                return .bayoIdle
            default:
                return .bayoPoint
            }
        case .surfaceReady, .shadowExploration:
            return .bayoPoint
        case .shadowTrivia:
            return shadowTriviaIndex == 0 ? .bayoPointWink : .bayoPoint
        case .shadowTypesInteraction:
            return shadowTypesIndex == 1 ? .bayoQuestion : .bayoPoint
        case .shapeComparison:
            return hasComparedShapes ? .bayoPointWink : .bayoQuestion
        case .closing:
            return closingIndex == 0 ? .bayoPointWink : .bayoIdle
        case .review:
            return reviewIndex == Level3Content.reviewDialog.count - 1 ? .bayoPointWink : .bayoPoint
        case .drawingPrompt:
            return .bayoPointWink
        case .drawingReady, .photoPrompt, .photoComparison, .placingScene, .completed:
            return .bayoIdle
        }
    }
    
    var narrationID: String {
        let revisionID = "revision-\(narrationRevision)"
        if phase == .shadowExploration,
           arSceneViewModel.selectedConcept == nil,
           visitedShadowConcepts.isEmpty,
           !hasCompletedShadowTask {
            switch markerRound {
            case .cube:
                return "onboarding-\(Level3Content.onboardingDialog.count - 1)-\(shadowTriviaIndex)-\(shadowTypesIndex)-\(closingIndex)-\(reviewIndex)-\(drawingIndex)-\(revisionID)"
            case .sphere:
                return "shadowTrivia-\(onboardingIndex)-\(Level3Content.shadowTrivia.count - 1)-\(shadowTypesIndex)-\(closingIndex)-\(reviewIndex)-\(drawingIndex)-\(revisionID)"
            }
        }
        return "\(phase)-\(onboardingIndex)-\(shadowTriviaIndex)-\(shadowTypesIndex)-\(closingIndex)-\(reviewIndex)-\(drawingIndex)-\(revisionID)"
    }
    
    func forceSyncGuideForConcept() {
        syncGuidePresentation()
    }
    
    // MARK: - Marker Content
            
    private func text(for concept: ShadowConcept) -> String {
        switch concept {
        case .castShadow:
            return "Bayangan gelap yang muncul di lantai karena cahaya terhalang."
        case .reflectedLight:
            return "Cahaya pantulan dari lantai yang memantul kembali ke bola."
        case .shadowSide, .coreShadow, .terminator, .contactShadow:
            return "Sisi gelap karena cahayanya tidak sampai ke sini."
        case .lightSide, .highlight:
            return "Sisi terang karena langsung menghadap ke lampu."
        }
    }
    
    private func audioFileName(for concept: ShadowConcept) -> String? {
        switch concept {
        case .castShadow:
            return "level-3/marker/[marker] Bayangan gelap yang muncul di lantai karena cahaya terhalang.mp3"
        case .reflectedLight:
            return "level-3/marker/[marker] Cahaya pantulan dari lantai yang memantul kembali ke bola.mp3"
        case .shadowSide, .coreShadow, .terminator, .contactShadow:
            return "level-3/marker/[marker] Sisi gelap karena cahayanya tidak sampai ke sini.mp3"
        case .lightSide, .highlight:
            return "level-3/marker/[marker] Sisi terang karena langsung menghadap ke lampu.mp3"
        }
    }

    var shadowProgress: Int { min(visitedShadowConcepts.count, requiredShadowConcepts.count) }
    var shadowConceptTargetCount: Int { requiredShadowConcepts.count }
    var canAdvanceCurrentDialog: Bool {
        (isNarrationComplete || canSkipCompletedLevelDialog) && arSceneViewModel.selectedConcept == nil
    }

    var narrationAudioFileNames: [String] {
        guard let narrationAudioFileName else { return [] }
        return [narrationAudioFileName].deduplicatedKeepingOrder()
    }

    var shouldSpeakNarration: Bool {
        !(phase == .shadowExploration && arSceneViewModel.selectedConcept == nil && !hasCompletedShadowTask)
    }

    var areReviewMarkersVisible: Bool {
        requiredShadowConcepts.isDisjoint(with: arSceneViewModel.hiddenShadowConcepts)
    }

    private var requiredShadowConcepts: Set<ShadowConcept> {
        switch markerRound {
        case .cube:
            Self.cubeRequiredShadowConcepts
        case .sphere:
            Self.sphereRequiredShadowConcepts
        }
    }

    private var canSkipCompletedLevelDialog: Bool {
        progressStore.isLevelCompleted(Level3Content.levelID)
    }

    private func registerDialogSkipIfNeeded() {
        guard canSkipCompletedLevelDialog, !isNarrationComplete else { return }
        narrationRevision += 1
    }

    func narrationWillStart() {
        isNarrationComplete = false
        syncShadowConceptSelectionAvailability()
    }

    func narrationDidFinish() {
        isNarrationComplete = true
        if arSceneViewModel.selectedConcept != nil {
            completeSelectedShadowConcept()
        } else if phase == .onboarding,
                  onboardingIndex == Level3Content.onboardingDialog.count - 1,
                  arSceneViewModel.isObjectPlaced {
            phase = .shadowExploration
            syncShadowConceptSelectionAvailability()
            syncGuidePresentation()
        } else if phase == .shadowTrivia,
                  shadowTriviaIndex == Level3Content.shadowTrivia.count - 1,
                  markerRound == .cube,
                  arSceneViewModel.selectedObjectType == .sphere {
            startSphereShadowTask()
        } else {
            syncShadowConceptSelectionAvailability()
        }
    }

    func advanceOnboarding() {
        guard phase == .onboarding, canAdvanceCurrentDialog else { return }
        registerDialogSkipIfNeeded()
        if onboardingIndex == 0, !arSceneViewModel.isObjectPlaced {
            phase = .placingScene
        } else if onboardingIndex == 1, !arSceneViewModel.isObjectPlaced {
            arSceneViewModel.placeSceneAtScreenCenter()
        } else if onboardingIndex == Level3Content.onboardingDialog.count - 1 {
            phase = .shadowExploration
        } else {
            onboardingIndex += 1
        }
        isNarrationComplete = phase == .shadowExploration && canSkipCompletedLevelDialog
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    func sceneDidPlace(at worldPosition: SIMD3<Float>) {
        let shouldContinueOnboardingAfterPlacement = phase == .placingScene
            || phase == .surfaceReady
            || (phase == .onboarding && onboardingIndex == 1)

        if shouldContinueOnboardingAfterPlacement {
            phase = .onboarding
            onboardingIndex = min(2, Level3Content.onboardingDialog.count - 1)
            isNarrationComplete = false
            syncShadowConceptSelectionAvailability()
        }
        syncGuidePresentation()
    }

    func continueAfterSurfaceCheck() {
        guard phase == .surfaceReady else { return }
        if arSceneViewModel.isObjectPlaced {
            phase = resumePhaseAfterPlacement ?? .shadowExploration
            resumePhaseAfterPlacement = nil
        } else {
            arSceneViewModel.placeSceneAtScreenCenter()
        }
        syncGuidePresentation()
    }

    func rescanSurface() {
        guard phase == .surfaceReady else { return }
        arSceneViewModel.rescanSurface()
        guideNeedsPlacement = true
        guideRoot?.isEnabled = false
    }

    func surfaceDidBecomeReady() {
        guard phase == .placingScene, arSceneViewModel.surfaceState == .found else { return }
        phase = .onboarding
        onboardingIndex = min(1, Level3Content.onboardingDialog.count - 1)
        isNarrationComplete = false
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    func sceneDidReset() {
        markerCompletionTask?.cancel()
        markerCompletionTask = nil
        clearLastExplainedMarker()
        visitedShadowConcepts.removeAll()
        hasCompletedShadowTask = false
        markerRound = .cube
        shadowVisible = false
        isShadowInfoOpen = false
        hasSelectedShadowTypesMenu = false
        drawingIndex = 0
        frozenSceneImage = nil
        userDrawingImage = nil
        photoSaveMessage = nil
        showsDrawingCamera = false
        showsFreezeSceneConfirmation = false
        isSavingDrawingPhoto = false
        resetHiddenShadowConceptsForCurrentRound()
        arSceneViewModel.isShadowConceptSelectionEnabled = false
        guideNeedsPlacement = true
        guideRoot?.isEnabled = false
        guard phase != .onboarding && phase != .completed else { return }
        resumePhaseAfterPlacement = (phase == .placingScene || phase == .surfaceReady) ? nil : phase
        phase = .placingScene
    }

    func lightDidSelect() {}

    func advancePhaseOnTap() {
        guard canAdvanceCurrentDialog else { return }

        switch phase {
        case .surfaceReady:
            arSceneViewModel.placeSceneAtScreenCenter()
        case .onboarding: advanceOnboarding()
        case .shadowExploration:
            if hasCompletedShadowTask { continueFromShadowTask() }
        case .shadowTrivia: advanceShadowTrivia()
        case .shadowTypesInteraction: advanceShadowTypes()
        case .shapeComparison:
            if hasComparedShapes { finishShapeComparison() }
        case .closing: advanceClosing()
        case .review: advanceReview()
        case .drawingPrompt: requestFreezeSceneForDrawing()
        case .drawingReady: finishDrawing()
        default: break
        }
    }
    
    func cameraDidUpdate(position: SIMD3<Float>) {
        updateGuidePosition(cameraPosition: position, cameraForward: previousCameraForward)
    }

    func cameraDidUpdate(position: SIMD3<Float>, forward: SIMD3<Float>) {
        previousCameraForward = forward
        updateGuidePosition(cameraPosition: position, cameraForward: forward)
    }

    func cameraDidUpdate(
        position: SIMD3<Float>,
        forward: SIMD3<Float>,
        right: SIMD3<Float>,
        up: SIMD3<Float>
    ) {
        previousCameraForward = forward
        updateGuidePosition(
            cameraPosition: position,
            cameraForward: forward,
            cameraRight: right,
            cameraUp: up
        )
    }

    func sceneDidReceiveWorldTap() {
        advancePhaseOnTap()
    }

    func shadowConceptDidSelect(_ concept: ShadowConcept) {
        didSelectShadowConcept(concept)
        if arSceneViewModel.selectedConcept == concept {
            markerNarrationTrigger += 1
        }
    }

    func didSelectShadowConcept(_ concept: ShadowConcept) {
        if phase == .review, requiredShadowConcepts.contains(concept) {
            lastExplainedShadowConcept = concept
            lastExplainedConceptWorldPosition = arSceneViewModel.selectedConceptWorldPosition
            arSceneViewModel.isShadowConceptSelectionEnabled = false
            scheduleMarkerCompletionFallback(for: concept)
            syncGuidePresentation()
            return
        }

        guard phase == .shadowExploration,
              !hasCompletedShadowTask,
              requiredShadowConcepts.contains(concept),
              !visitedShadowConcepts.contains(concept) else {
            arSceneViewModel.selectedConcept = nil
            arSceneViewModel.selectedConceptWorldPosition = nil
            syncGuidePresentation()
            return
        }
        hidePendingCompletedMarker()
        visitedShadowConcepts.insert(concept)
        lastExplainedShadowConcept = concept
        lastExplainedConceptWorldPosition = arSceneViewModel.selectedConceptWorldPosition
        arSceneViewModel.isShadowConceptSelectionEnabled = false
        scheduleMarkerCompletionFallback(for: concept)
        syncGuidePresentation()
    }

    private func completeSelectedShadowConcept(cancelsFallback: Bool = true) {
        guard let concept = arSceneViewModel.selectedConcept else {
            syncShadowConceptSelectionAvailability()
            return
        }

        if phase == .review {
            if cancelsFallback {
                markerCompletionTask?.cancel()
                markerCompletionTask = nil
            }
            arSceneViewModel.selectedConcept = nil
            arSceneViewModel.selectedConceptWorldPosition = nil
            syncShadowConceptSelectionAvailability()
            syncGuidePresentation()
            return
        }

        guard phase == .shadowExploration else {
            syncShadowConceptSelectionAvailability()
            return
        }

        if cancelsFallback {
            markerCompletionTask?.cancel()
            markerCompletionTask = nil
        }
        pendingHiddenShadowConcept = concept
        arSceneViewModel.selectedConcept = nil
        arSceneViewModel.selectedConceptWorldPosition = nil

        if requiredShadowConcepts.isSubset(of: visitedShadowConcepts) {
            hasCompletedShadowTask = true
            successFeedbackTrigger += 1
            hidePendingCompletedMarker()
            switch markerRound {
            case .cube:
                continueFromShadowTask()
            case .sphere:
                continueToInfoButtonGuide()
            }
        } else {
            syncShadowConceptSelectionAvailability()
            syncGuidePresentation()
        }
    }

    private func scheduleMarkerCompletionFallback(for concept: ShadowConcept) {
        markerCompletionTask?.cancel()
        let delay = markerFallbackDelay(for: concept)
        markerCompletionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self,
                  self.phase == .shadowExploration,
                  self.arSceneViewModel.selectedConcept == concept else { return }
            self.markerCompletionTask = nil
            self.isNarrationComplete = true
            self.completeSelectedShadowConcept(cancelsFallback: false)
        }
    }

    private func markerFallbackDelay(for concept: ShadowConcept) -> Double {
        let wordCount = Double(text(for: concept).split(separator: " ").count)
        return max(wordCount * 0.40 + 0.8, 3.0)
    }

    private func syncShadowConceptSelectionAvailability() {
        arSceneViewModel.isShadowConceptSelectionEnabled =
            (
                phase == .shadowExploration
                && isNarrationComplete
                && arSceneViewModel.selectedConcept == nil
                && !hasCompletedShadowTask
            )
            || (
                phase == .review
                && arSceneViewModel.selectedConcept == nil
                && areReviewMarkersVisible
            )
    }

    func continueFromShadowTask() {
        guard hasCompletedShadowTask else { return }
        markerCompletionTask?.cancel()
        markerCompletionTask = nil
        clearLastExplainedMarker()
        arSceneViewModel.selectedConcept = nil
        arSceneViewModel.selectedConceptWorldPosition = nil
        phase = .shadowTrivia
        shadowTriviaIndex = 0
        isNarrationComplete = false
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    private func startSphereShadowTask() {
        markerCompletionTask?.cancel()
        markerCompletionTask = nil
        clearLastExplainedMarker()
        markerRound = .sphere
        visitedShadowConcepts.removeAll()
        hasCompletedShadowTask = false
        resetHiddenShadowConceptsForCurrentRound()
        arSceneViewModel.selectedConcept = nil
        arSceneViewModel.selectedConceptWorldPosition = nil
        chooseObjectTypeForShadowTypes(.sphere)
        phase = .shadowExploration
        isNarrationComplete = true
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    private func continueToInfoButtonGuide() {
        markerCompletionTask?.cancel()
        markerCompletionTask = nil
        clearLastExplainedMarker()
        arSceneViewModel.selectedConcept = nil
        arSceneViewModel.selectedConceptWorldPosition = nil
        arSceneViewModel.hiddenShadowConcepts.removeAll()
        arSceneViewModel.showShadowLabels = true
        isShadowInfoOpen = false
        arSceneViewModel.showShadowInformation = false
        phase = .review
        reviewIndex = Level3Content.reviewDialog.count - 1
        isNarrationComplete = false
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }
    
    func advanceShadowTrivia() {
        guard phase == .shadowTrivia, canAdvanceCurrentDialog else { return }
        registerDialogSkipIfNeeded()
        if shadowTriviaIndex == Level3Content.shadowTrivia.count - 1 {
            startSphereShadowTask()
            return
        }

        shadowTriviaIndex += 1
        if shadowTriviaIndex == Level3Content.shadowTrivia.count - 1 {
            chooseObjectTypeForShadowTypes(.sphere)
        }
        isNarrationComplete = false
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    func toggleShadow() {
        shadowVisible.toggle()
        arSceneViewModel.showGroundProjection = shadowVisible
        arSceneViewModel.showProjectionLines = shadowVisible
        arSceneViewModel.showLightDirection = shadowVisible
    }

    func toggleShadowInfo() {
        isShadowInfoOpen.toggle()
        arSceneViewModel.showShadowInformation = isShadowInfoOpen
    }

    func handleInfoButtonTap() {
        guard phase == .review else { return }
        if reviewIndex == 0, canAdvanceCurrentDialog {
            isShadowInfoOpen = true
            arSceneViewModel.showShadowInformation = true
            advanceReview()
        } else {
            toggleShadowInfo()
        }
    }

    func handleShadowTypesMenuTap() {
        guard phase == .review else { return }
        toggleReviewMarkers()
        hasSelectedShadowTypesMenu = true
        if reviewIndex == 1, canAdvanceCurrentDialog {
            advanceReview()
        }
    }

    private func toggleReviewMarkers() {
        if areReviewMarkersVisible {
            arSceneViewModel.hiddenShadowConcepts.formUnion(requiredShadowConcepts)
            arSceneViewModel.selectedConcept = nil
            arSceneViewModel.selectedConceptWorldPosition = nil
            clearLastExplainedMarker()
        } else {
            arSceneViewModel.hiddenShadowConcepts.subtract(requiredShadowConcepts)
        }
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    func closeShadowInfo() {
        if isShadowInfoOpen {
            isShadowInfoOpen = false
            arSceneViewModel.showShadowInformation = false
        }
    }
    
    func advanceShadowTypes() {
        guard phase == .shadowTypesInteraction, canAdvanceCurrentDialog else { return }
        registerDialogSkipIfNeeded()
        if shadowTypesIndex == Level3Content.shadowTypesTrivia.count - 1 { phase = .shapeComparison } else { shadowTypesIndex += 1 }
        isNarrationComplete = false
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    private func chooseObjectTypeForShadowTypes(_ objectType: LearningObjectType) {
        arSceneViewModel.updateSelectedObject { object in
            object.type = objectType
            object.importedModel = nil
        }
    }

    func chooseComparison(_ shape: ComparisonShape) {
        selectedComparison = shape
        comparedShapes.insert(shape)
        hasComparedShapes = comparedShapes.count == ComparisonShape.allCases.count
        let target = shape.objectType
        arSceneViewModel.updateSelectedObject { object in
            object.type = target
            object.importedModel = nil
        }
        successFeedbackTrigger += 1
        if hasComparedShapes {
            celebrate(title: "Bentuk Berhasil Dibandingkan!", detail: "Kubus dan bola menghasilkan bayangan yang berbeda.")
        }
    }

    func finishShapeComparison() {
        guard phase == .shapeComparison, hasComparedShapes, canAdvanceCurrentDialog else { return }
        registerDialogSkipIfNeeded()
        phase = .closing
        closingIndex = 0
        isNarrationComplete = false
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    private func celebrate(title: String, detail: String) {
        let celebration = LessonProgressCelebration(title: title, detail: detail)
        progressCelebration = celebration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard self?.progressCelebration?.id == celebration.id else { return }
            self?.progressCelebration = nil
        }
    }

    func advanceClosing() {
        guard phase == .closing, canAdvanceCurrentDialog else { return }
        registerDialogSkipIfNeeded()
        if closingIndex == Level3Content.closingDialog.count - 1 {
            phase = .review
            reviewIndex = 0
        } else {
            closingIndex += 1
        }
        isNarrationComplete = false
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    func advanceReview() {
        guard phase == .review, canAdvanceCurrentDialog else { return }
        registerDialogSkipIfNeeded()
        if reviewIndex == Level3Content.reviewDialog.count - 1 {
            startDrawingPrompt()
        } else {
            reviewIndex += 1
            isNarrationComplete = false
            syncShadowConceptSelectionAvailability()
            syncGuidePresentation()
        }
    }

    private func startDrawingPrompt() {
        arSceneViewModel.hiddenShadowConcepts.formUnion(requiredShadowConcepts)
        arSceneViewModel.selectedConcept = nil
        arSceneViewModel.selectedConceptWorldPosition = nil
        clearLastExplainedMarker()
        phase = .drawingPrompt
        drawingIndex = 0
        isNarrationComplete = false
        closeShadowInfo()
        arSceneViewModel.showShadowLabels = true
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    func requestFreezeSceneForDrawing() {
        guard phase == .drawingPrompt, canAdvanceCurrentDialog else { return }
        registerDialogSkipIfNeeded()
        showsFreezeSceneConfirmation = true
    }

    func cancelFreezeSceneConfirmation() {
        showsFreezeSceneConfirmation = false
    }

    func confirmFreezeSceneAndStartDrawing() {
        guard phase == .drawingPrompt, canAdvanceCurrentDialog else {
            showsFreezeSceneConfirmation = false
            return
        }

        showsFreezeSceneConfirmation = false
        frozenSceneImage = nil
        arSceneViewModel.isViewFrozen = true
        arSceneViewModel.captureSnapshot()
        phase = .drawingReady
        drawingIndex = 3
        isNarrationComplete = false
        successFeedbackTrigger += 1
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    func completeFrozenSceneSnapshot(_ image: UIImage?) {
        guard let image, frozenSceneImage == nil else { return }
        frozenSceneImage = image
        if phase == .drawingPrompt {
            phase = .drawingReady
            drawingIndex = 3
            isNarrationComplete = false
            syncShadowConceptSelectionAvailability()
            syncGuidePresentation()
        }
    }

    func finishDrawing() {
        guard phase == .drawingReady, canAdvanceCurrentDialog else { return }
        phase = .photoPrompt
        drawingIndex = 6
        isNarrationComplete = false
        successFeedbackTrigger += 1
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
    }

    func captureDrawingPhoto() {
        guard phase == .photoPrompt, !isSavingDrawingPhoto else { return }
        showsDrawingCamera = true
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
            self.photoSaveMessage = "Foto gambarmu sudah tersimpan."
            self.phase = .photoComparison
            self.drawingIndex = 7
            self.isNarrationComplete = false
            self.successFeedbackTrigger += 1
            self.syncShadowConceptSelectionAvailability()
            self.syncGuidePresentation()
        }
    }

    func clearPhotoSaveMessage() {
        photoSaveMessage = nil
    }

    func completeLevelAfterPhotoComparison() {
        guard phase == .photoComparison else { return }
        phase = .completed
        progressStore.markLevelCompleted(Level3Content.levelID)
        successFeedbackTrigger += 1
        syncGuidePresentation()
    }

    #if DEBUG
    func jumpToDevFlow(_ flow: Level3DevFlow) {
        arSceneViewModel.selectedConcept = nil
        arSceneViewModel.selectedConceptWorldPosition = nil
        isShadowInfoOpen = false
        arSceneViewModel.showShadowInformation = false
        showsFreezeSceneConfirmation = false
        showsDrawingCamera = false
        isSavingDrawingPhoto = false
        progressCelebration = nil

        switch flow {
        case .onboarding:
            phase = .onboarding
            onboardingIndex = 0
            markerRound = .cube
            visitedShadowConcepts.removeAll()
            hasCompletedShadowTask = false
            isNarrationComplete = true
            chooseObjectTypeForShadowTypes(.cube)
        case .shadowExplorationCube:
            phase = .shadowExploration
            markerRound = .cube
            visitedShadowConcepts.removeAll()
            hasCompletedShadowTask = false
            isNarrationComplete = true
            chooseObjectTypeForShadowTypes(.cube)
        case .shadowExplorationSphere:
            phase = .shadowExploration
            markerRound = .sphere
            visitedShadowConcepts.removeAll()
            hasCompletedShadowTask = false
            isNarrationComplete = true
            chooseObjectTypeForShadowTypes(.sphere)
        case .review:
            phase = .review
            reviewIndex = 0
            markerRound = .sphere
            visitedShadowConcepts = Self.sphereRequiredShadowConcepts
            hasCompletedShadowTask = true
            isNarrationComplete = true
            chooseObjectTypeForShadowTypes(.sphere)
        case .drawingPrompt:
            phase = .drawingPrompt
            drawingIndex = 0
            markerRound = .sphere
            isNarrationComplete = true
            chooseObjectTypeForShadowTypes(.sphere)
        case .completed:
            phase = .completed
            markerRound = .sphere
            isNarrationComplete = true
        }

        resetHiddenShadowConceptsForCurrentRound()
        syncShadowConceptSelectionAvailability()
        syncGuidePresentation()
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

    private func configureLearningScene() {
        arSceneViewModel.selectedObjectType = .cube
        arSceneViewModel.objectScale = 0.85
        arSceneViewModel.requiresLiDARScanBeforePlacement = false
        arSceneViewModel.usesLiDARSceneReconstruction = false
        arSceneViewModel.usesRealisticEnvironmentLighting = false
        
        arSceneViewModel.showLightDirection = true
        arSceneViewModel.showLightRays = false
        arSceneViewModel.showProjectionLines = true
        arSceneViewModel.showGroundProjection = true
        arSceneViewModel.showShadowLabels = true
        arSceneViewModel.showShadowInformation = false
        resetHiddenShadowConceptsForCurrentRound()
        arSceneViewModel.isShadowConceptSelectionEnabled = false

        arSceneViewModel.objectDirectManipulationLocked = true
        arSceneViewModel.directManipulationRotatesOnly = true
        arSceneViewModel.interactionMode = .moveLight
        arSceneViewModel.lightDirectionFollowsGesture = true
        arSceneViewModel.autoPlaceOnSurfaceFound = false
        arSceneViewModel.objectDirectManipulationLocked = true
        
        let objectCenter = SIMD3<Float>(0, SceneObjectSystem.cubeSize * 0.85 / 2, 0)
        let lightPosition = SIMD3<Float>(-0.24, 0.34, 0.28)
        let aimingAngles = SceneLightSystem.aimingAngles(from: lightPosition, to: objectCenter)

        arSceneViewModel.updateSelectedLight { light in
            light.type = .spot
            light.position = lightPosition
            light.intensity = Self.fixedLightIntensity
            light.beamSpread = .medium
            light.beamOuterAngleDegrees = Self.fixedBeamSpreadDegrees
            light.markerScale = 0.7
            if let aimingAngles {
                light.yawDegrees = aimingAngles.yawDegrees
                light.pitchDegrees = aimingAngles.pitchDegrees
            }
        }

        arSceneViewModel.updateSelectedObject { object in
            object.type = .cube
            object.position = SIMD3<Float>(0, 0, 0)
            object.scale = 0.85
        }
    }

    private func resetHiddenShadowConceptsForCurrentRound() {
        arSceneViewModel.hiddenShadowConcepts = markerRound == .cube ? [.reflectedLight] : []
    }

    private func clearLastExplainedMarker() {
        lastExplainedShadowConcept = nil
        lastExplainedConceptWorldPosition = nil
        pendingHiddenShadowConcept = nil
    }

    private func hidePendingCompletedMarker() {
        guard let pendingHiddenShadowConcept else { return }
        arSceneViewModel.hiddenShadowConcepts.insert(pendingHiddenShadowConcept)
        self.pendingHiddenShadowConcept = nil
    }
    
    // MARK: - AR Guide Character Logic (Bayo)
    
    func attachGuideIfNeeded(to parent: Entity) {
        if guideParent !== parent {
            guideRoot?.removeFromParent()
            guideRoot = nil
            guideParent = parent
            guideCharacter = nil
            guideCharacterAsset = nil
            guideCloud = nil
            guideText = nil
            guideNeedsPlacement = true
        }

        guard guideRoot == nil else { return }
        let guide = Entity()
        guide.name = "Level 3 Guide - Bayo"
        guide.isEnabled = false
        let asset = currentGuideAsset
        if let character = CharacterGuideFactory.makeCharacter(asset: asset, width: 0.10, height: 0.14) {
            guide.addChild(character)
            guideCharacter = character
            guideCharacterAsset = asset
        }
        parent.addChild(guide)
        guideRoot = guide
    }
    
    private func updateGuidePosition(cameraPosition: SIMD3<Float>, cameraForward: SIMD3<Float>) {
        guard let guide = guideRoot else { return }
        let horizontalForward = SIMD2<Float>(cameraForward.x, cameraForward.z)
        let forwardLength = simd_length(horizontalForward)
        guard forwardLength > 0.0001 else { return }

        let normalizedForward = horizontalForward / forwardLength
        let forward3D = SIMD3<Float>(normalizedForward.x, 0, normalizedForward.y)
        let right = SIMD3<Float>(-normalizedForward.y, 0, normalizedForward.x)
        let defaultDestination = cameraPosition
            + forward3D * guideForwardDistance
            + right * guideRightDistance
            + SIMD3<Float>(0, guideVerticalOffset, 0)
        let destination: SIMD3<Float>
        if let markerPosition = arSceneViewModel.selectedConceptWorldPosition ?? lastExplainedConceptWorldPosition {
            destination = markerPosition + SIMD3<Float>(0.18, 0.08, 0.12)
        } else {
            destination = defaultDestination
        }

        if guideNeedsPlacement {
            guide.position = destination
            guideNeedsPlacement = false
        } else {
            guide.position += (destination - guide.position) * guideFollowLerp
        }

        guide.look(at: cameraPosition, from: guide.position, relativeTo: nil)
        guideCloud?.position = defaultGuideCloudPosition
        syncGuidePresentation()
    }

    private func updateGuidePosition(
        cameraPosition: SIMD3<Float>,
        cameraForward: SIMD3<Float>,
        cameraRight: SIMD3<Float>,
        cameraUp: SIMD3<Float>
    ) {
        updateGuidePosition(cameraPosition: cameraPosition, cameraForward: cameraForward)
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
        cloud.name = "Bayo Speech Cloud"
        cloud.position = defaultGuideCloudPosition
        guide.addChild(cloud)
        guideCloud = cloud
    }
    
    private var shouldShowGuide: Bool {
        switch phase {
        case .placingScene, .drawingReady, .photoPrompt, .photoComparison, .completed:
            return false
        default:
            return true
        }
    }
    
    private func syncGuideCharacterAsset() {
        guard let guide = guideRoot else { return }
        let asset = currentGuideAsset
        guard guideCharacterAsset != asset else { return }

        guard let character = CharacterGuideFactory.makeCharacter(asset: asset, width: 0.10, height: 0.14) else { return }
        guideCharacter?.removeFromParent()
        guide.addChild(character)
        guideCharacter = character
        guideCharacterAsset = asset
    }

    private var defaultGuideCloudPosition: SIMD3<Float> {
        SIMD3<Float>(0.22, 0.14, 0)
    }

    private func guideCloudPosition(cameraPosition: SIMD3<Float>, cameraRight: SIMD3<Float>) -> SIMD3<Float> {
        defaultGuideCloudPosition
    }
    
    private func guideSpeechLayout(for text: String) -> (text: String, width: Float, height: Float) {
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var currentWords: [String] = []
        for word in words {
            if currentWords.count == 8 {
                lines.append(currentWords.joined(separator: " "))
                currentWords = [word]
            } else {
                currentWords.append(word)
            }
        }
        if !currentWords.isEmpty { lines.append(currentWords.joined(separator: " ")) }
        let wrappedText = lines.joined(separator: "\n")
        let longestLineCount = lines.map(\.count).max() ?? text.count
        let width = min(max(Float(longestLineCount) * 0.0064 + 0.10, 0.24), 0.56)
        let height = min(max(Float(lines.count) * 0.022 + 0.060, 0.082), 0.24)
        return (wrappedText, width, height)
    }
}

private extension Array where Element: Hashable {
    func deduplicatedKeepingOrder() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
