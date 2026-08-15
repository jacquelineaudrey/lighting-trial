import Foundation
import Observation
import RealityKit

@MainActor
@Observable
final class Level3ViewModel: ARSceneTelemetryDelegate {
    // Nilai tetap (tidak lagi bisa diubah pemain) untuk sebaran & intensitas
    // cahaya di Level 3 — pembelajaran dispersity & intensity dihapus dari
    // level ini per request, jadi cahaya cukup dikonfigurasi statis supaya
    // bayangan tetap terlihat jelas.
    private static let fixedBeamSpreadDegrees: Float = 54
    private static let fixedLightIntensity: Float = 3_200

    let arSceneViewModel = ARSceneViewModel()

    private(set) var phase: Level3Phase = .onboarding
    private(set) var onboardingIndex = 0
    private(set) var shadowTriviaIndex = 0
    private(set) var shadowTypesIndex = 0
    private(set) var closingIndex = 0

    private(set) var visitedShadowSectors: Set<Int> = []
    private(set) var hasCompletedShadowTask = false
    private(set) var shadowVisible = true
    private(set) var selectedComparison: ComparisonShape = .cube
    private(set) var hasComparedShapes = false
    @ObservationIgnored private var comparedShapes: Set<ComparisonShape> = []
    private(set) var successFeedbackTrigger = 0
    
    // --- TAMBAHAN BARU: State untuk mengontrol pop-up marker ---
    private(set) var isShadowInfoOpen = false
    // -----------------------------------------------------------

    @ObservationIgnored private let progressStore: GameProgressStore
    @ObservationIgnored private var sceneWorldPosition: SIMD3<Float>?
    @ObservationIgnored private var previousCameraPosition: SIMD3<Float>?
    @ObservationIgnored private var resumePhaseAfterPlacement: Level3Phase?

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

    var narrationText: String {
        switch phase {
        case .onboarding: currentOnboardingLine.text
        case .placingScene: "Arahkan titik tengah layar ke meja atau lantai, lalu tekan Taruh Benda di Tengah."
        case .shadowExploration: hasCompletedShadowTask ? "Bagus! Kamu sudah melihat bayangan dari beberapa sisi." : "Jalan pelan mengelilingi benda dan cari bayangannya dari tiga sisi."
        case .shadowTrivia: currentShadowTriviaLine.text
        case .shadowTypesInteraction: "Tekan Lihat Shadow untuk menampilkan bayangan, lalu perhatikan bagian yang paling gelap dan bagian yang lebih samar."
        case .shapeComparison: "Pilih kubus dan bola. Bandingkan bentuk bayangan yang dihasilkan keduanya."
        case .closing: currentClosingLine.text
        case .review: "Bayangan dipengaruhi oleh bentuk benda yang menghalangi cahaya."
        case .completed: "Level tiga selesai. Kamu hebat, Detektif Bayangan!"
        }
    }

    var shadowProgress: Int { min(visitedShadowSectors.count, 3) }

    func advanceOnboarding() {
        guard phase == .onboarding else { return }
        if onboardingIndex == Level3Content.onboardingDialog.count - 1 { phase = .placingScene } else { onboardingIndex += 1 }
    }

    func sceneDidPlace(at worldPosition: SIMD3<Float>) {
        sceneWorldPosition = worldPosition
        previousCameraPosition = nil
        if phase == .placingScene {
            phase = resumePhaseAfterPlacement ?? .shadowExploration
            resumePhaseAfterPlacement = nil
        }
    }

    func sceneDidReset() {
        sceneWorldPosition = nil
        previousCameraPosition = nil
        visitedShadowSectors.removeAll()
        hasCompletedShadowTask = false
        shadowVisible = false
        isShadowInfoOpen = false // Reset popup state
        guard phase != .onboarding && phase != .completed else { return }
        resumePhaseAfterPlacement = phase == .placingScene ? nil : phase
        phase = .placingScene
    }

    func cameraDidUpdate(position: SIMD3<Float>) {
        guard phase == .shadowExploration, !hasCompletedShadowTask, let center = sceneWorldPosition else { return }
        defer { previousCameraPosition = position }
        if let previous = previousCameraPosition {
            let step = simd_length(SIMD2<Float>(position.x - previous.x, position.z - previous.z))
            if step >= 0.005 && step <= 0.35 { }
        }
        let offset = SIMD2<Float>(position.x - center.x, position.z - center.z)
        let radius = simd_length(offset)
        guard radius >= 0.3 && radius <= 3 else { return }
        let angle = atan2(offset.y, offset.x) + .pi
        let sector = Int(floor(angle / (2 * .pi) * 8)) % 8
        visitedShadowSectors.insert(sector)
        if visitedShadowSectors.count >= 3 {
            hasCompletedShadowTask = true
            successFeedbackTrigger += 1
        }
    }

    func continueFromShadowTask() { guard hasCompletedShadowTask else { return }; phase = .shadowTrivia; shadowTriviaIndex = 0 }
    
    func advanceShadowTrivia() {
        guard phase == .shadowTrivia else { return }
        if shadowTriviaIndex == Level3Content.shadowTrivia.count - 1 { phase = .shadowTypesInteraction; shadowTypesIndex = 0 } else { shadowTriviaIndex += 1 }
    }

    func toggleShadow() {
        shadowVisible.toggle()
        arSceneViewModel.showGroundProjection = shadowVisible
        arSceneViewModel.showProjectionLines = shadowVisible
        arSceneViewModel.showLightDirection = shadowVisible
        // Label shadow tetap on, dan ini tidak mengganggu state pop-up informasi
    }

    // --- TAMBAHAN BARU: Fungsi untuk Buka/Tutup Marker ---
    
    func toggleShadowInfo() {
        isShadowInfoOpen.toggle()
        arSceneViewModel.showShadowInformation = isShadowInfoOpen
    }

    func closeShadowInfo() {
        if isShadowInfoOpen {
            isShadowInfoOpen = false
            arSceneViewModel.showShadowInformation = false
        }
    }
    
    // -----------------------------------------------------

    func advanceShadowTypes() {
        guard phase == .shadowTypesInteraction else { return }
        if shadowTypesIndex == Level3Content.shadowTypesTrivia.count - 1 { phase = .shapeComparison } else { shadowTypesIndex += 1 }
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
    }

    func finishShapeComparison() {
        guard phase == .shapeComparison, hasComparedShapes else { return }
        phase = .closing
        closingIndex = 0
    }

    func advanceClosing() {
        guard phase == .closing else { return }
        if closingIndex == Level3Content.closingDialog.count - 1 { phase = .review } else { closingIndex += 1 }
    }

    func finishReview() {
        guard phase == .review else { return }
        phase = .completed
        progressStore.markLevelCompleted(Level3Content.levelID)
    }

    #if DEBUG
    func debugAdvanceCurrentPhase() {
        switch phase {
        case .onboarding:
            onboardingIndex = max(0, Level3Content.onboardingDialog.count - 1)
            phase = .placingScene
        case .placingScene:
            sceneDidPlace(at: sceneWorldPosition ?? .zero)
        case .shadowExploration:
            visitedShadowSectors = [0, 2, 4]
            hasCompletedShadowTask = true
            phase = .shadowTrivia
            shadowTriviaIndex = 0
        case .shadowTrivia:
            shadowTriviaIndex = max(0, Level3Content.shadowTrivia.count - 1)
            phase = .shadowTypesInteraction
            shadowTypesIndex = 0
        case .shadowTypesInteraction:
            shadowTypesIndex = max(0, Level3Content.shadowTypesTrivia.count - 1)
            phase = .shapeComparison
        case .shapeComparison:
            comparedShapes = Set(ComparisonShape.allCases)
            hasComparedShapes = true
            phase = .closing
            closingIndex = 0
        case .closing:
            closingIndex = max(0, Level3Content.closingDialog.count - 1)
            phase = .review
        case .review:
            finishReview()
        case .completed:
            break
        }
        successFeedbackTrigger += 1
    }

    func completeCurrentTaskForDebugging() {
        switch phase {
        case .shadowExploration:
            visitedShadowSectors = [0, 2, 4]
            hasCompletedShadowTask = true
        case .shapeComparison:
            comparedShapes = Set(ComparisonShape.allCases)
            hasComparedShapes = true
        default:
            break
        }
        successFeedbackTrigger += 1
    }
    #endif

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
        
        // Initial state popup marker tertutup
        arSceneViewModel.showShadowInformation = isShadowInfoOpen

        arSceneViewModel.objectDirectManipulationLocked = true
        arSceneViewModel.directManipulationRotatesOnly = true
        arSceneViewModel.interactionMode = .moveLight

        let objectCenter = SIMD3<Float>(0, SceneObjectSystem.cubeSize * 0.85 / 2, 0)
        let lightPosition = SIMD3<Float>(-0.24, 0.34, 0.28)
        let aimingAngles = SceneLightSystem.aimingAngles(
            from: lightPosition,
            to: objectCenter
        )

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
}
