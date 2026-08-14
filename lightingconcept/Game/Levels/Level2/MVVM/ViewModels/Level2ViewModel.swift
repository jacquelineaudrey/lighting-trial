import Foundation
import Observation
import RealityKit

@MainActor
@Observable
final class Level2ViewModel: ARSceneTelemetryDelegate {
    static let minimumBeamAngle: Float = 24
    static let maximumBeamAngle: Float = 88
    static let minimumIntensity: Float = 450
    static let maximumIntensity: Float = 6_500

    let arSceneViewModel = ARSceneViewModel()

    private(set) var phase: Level2Phase = .onboarding
    private(set) var onboardingIndex = 0
    private(set) var shadowTriviaIndex = 0
    private(set) var spreadTransitionIndex = 0
    private(set) var spreadTriviaIndex = 0
    private(set) var intensityTriviaIndex = 0
    private(set) var closingIndex = 0

    private(set) var visitedShadowSectors: Set<Int> = []
    private(set) var hasCompletedShadowTask = false
    private(set) var hasReachedNarrowSpread = false
    private(set) var hasReachedWideSpread = false
    private(set) var hasCompletedSpreadTask = false
    private(set) var hasReachedDimIntensity = false
    private(set) var hasReachedBrightIntensity = false
    private(set) var hasCompletedIntensityTask = false
    private(set) var successFeedbackTrigger = 0

    private(set) var beamSpreadDegrees: Float = 54
    private(set) var lightIntensity: Float = 3_200

    @ObservationIgnored private let progressStore: GameProgressStore
    @ObservationIgnored private var sceneWorldPosition: SIMD3<Float>?
    @ObservationIgnored private var previousCameraPosition: SIMD3<Float>?
    @ObservationIgnored private var shadowTravelDistance: Float = 0
    @ObservationIgnored private var spreadGestureStart: Float?
    @ObservationIgnored private var intensityGestureStart: Float?

    init(progressStore: GameProgressStore? = nil) {
        self.progressStore = progressStore ?? .shared
        configureLearningScene()
    }

    var currentOnboardingLine: DialogLine { Level2Content.onboardingDialog[onboardingIndex] }
    var currentShadowTriviaLine: DialogLine { Level2Content.shadowTrivia[shadowTriviaIndex] }
    var currentSpreadTransitionLine: DialogLine { Level2Content.spreadTransition[spreadTransitionIndex] }
    var currentSpreadTriviaLine: DialogLine { Level2Content.spreadTrivia[spreadTriviaIndex] }
    var currentIntensityTriviaLine: DialogLine { Level2Content.intensityTrivia[intensityTriviaIndex] }
    var currentClosingLine: DialogLine { Level2Content.closingDialog[closingIndex] }

    var shadowProgress: Int { min(visitedShadowSectors.count, 3) }

    var spreadProgress: Int {
        (hasReachedNarrowSpread ? 1 : 0) + (hasReachedWideSpread ? 1 : 0)
    }

    var intensityProgress: Int {
        (hasReachedDimIntensity ? 1 : 0) + (hasReachedBrightIntensity ? 1 : 0)
    }

    var intensityPercentage: Int {
        let range = Self.maximumIntensity - Self.minimumIntensity
        return Int(((lightIntensity - Self.minimumIntensity) / range * 100).rounded())
    }

    var narrationText: String {
        switch phase {
        case .onboarding:
            currentOnboardingLine.text
        case .placingScene:
            "Arahkan titik tengah layar ke meja atau lantai, lalu tekan tombol Taruh Benda di Tengah."
        case .shadowExploration:
            hasCompletedShadowTask
                ? "Hebat! Kamu sudah melihat bayangan dari beberapa sisi. Yuk, cari tahu bagaimana bayangan terbentuk."
                : "Jalan pelan mengelilingi benda. Cari bayangannya dari tiga sisi yang berbeda."
        case .shadowTrivia:
            currentShadowTriviaLine.text
        case .spreadTransition:
            currentSpreadTransitionLine.text
        case .spreadExploration:
            hasCompletedSpreadTask
                ? "Keren! Kamu sudah mencoba cahaya sempit dan cahaya lebar."
                : "Rapatkan dua ibu jari untuk menyempitkan cahaya. Jauhkan dua ibu jari untuk melebarkannya."
        case .spreadTrivia:
            currentSpreadTriviaLine.text
        case .intensityExploration:
            hasCompletedIntensityTask
                ? "Bagus! Kamu sudah membuat cahaya redup dan terang."
                : "Usap ke atas di sisi kiri atau kanan layar agar cahaya lebih terang. Usap ke bawah agar lebih redup."
        case .intensityTrivia:
            currentIntensityTriviaLine.text
        case .closing:
            currentClosingLine.text
        case .review:
            "Bayangan muncul saat cahaya terhalang. Cahaya bisa dibuat sempit atau lebar, juga terang atau redup."
        case .completed:
            "Level dua selesai. Kamu hebat, Detektif Cahaya!"
        }
    }

    func advanceOnboarding() {
        guard phase == .onboarding else { return }
        if onboardingIndex == Level2Content.onboardingDialog.count - 1 {
            phase = .placingScene
        } else {
            onboardingIndex += 1
        }
    }

    func continueFromShadowTask() {
        guard phase == .shadowExploration, hasCompletedShadowTask else { return }
        phase = .shadowTrivia
        shadowTriviaIndex = 0
    }

    func advanceShadowTrivia() {
        guard phase == .shadowTrivia else { return }
        if shadowTriviaIndex == Level2Content.shadowTrivia.count - 1 {
            phase = .spreadTransition
            spreadTransitionIndex = 0
        } else {
            shadowTriviaIndex += 1
        }
    }

    func advanceSpreadTransition() {
        guard phase == .spreadTransition else { return }
        if spreadTransitionIndex == Level2Content.spreadTransition.count - 1 {
            phase = .spreadExploration
            arSceneViewModel.showLightRays = true
        } else {
            spreadTransitionIndex += 1
        }
    }

    func beginSpreadGesture() {
        guard phase == .spreadExploration else { return }
        spreadGestureStart = beamSpreadDegrees
    }

    func updateSpreadGesture(magnification: Float) {
        guard phase == .spreadExploration, let spreadGestureStart else { return }
        // Rentang dibuat cukup responsif untuk dua ibu jari anak: perubahan
        // skala sekitar 40-60% sudah bisa menunjukkan dua kondisi ekstrem.
        setBeamSpread(spreadGestureStart + (magnification - 1) * 90)
    }

    func endSpreadGesture() {
        spreadGestureStart = nil
    }

    func adjustSpread(by delta: Float) {
        guard phase == .spreadExploration else { return }
        setBeamSpread(beamSpreadDegrees + delta)
    }

    func continueFromSpreadTask() {
        guard phase == .spreadExploration, hasCompletedSpreadTask else { return }
        phase = .spreadTrivia
        spreadTriviaIndex = 0
    }

    func advanceSpreadTrivia() {
        guard phase == .spreadTrivia else { return }
        if spreadTriviaIndex == Level2Content.spreadTrivia.count - 1 {
            phase = .intensityExploration
            arSceneViewModel.showLightRays = true
        } else {
            spreadTriviaIndex += 1
        }
    }

    func beginIntensityGesture() {
        guard phase == .intensityExploration else { return }
        intensityGestureStart = lightIntensity
    }

    func updateIntensityGesture(verticalTranslation: Float) {
        guard phase == .intensityExploration, let intensityGestureStart else { return }
        setIntensity(intensityGestureStart - verticalTranslation * 18)
    }

    func endIntensityGesture() {
        intensityGestureStart = nil
    }

    func adjustIntensity(by delta: Float) {
        guard phase == .intensityExploration else { return }
        setIntensity(lightIntensity + delta)
    }

    func continueFromIntensityTask() {
        guard phase == .intensityExploration, hasCompletedIntensityTask else { return }
        phase = .intensityTrivia
        intensityTriviaIndex = 0
    }

    func advanceIntensityTrivia() {
        guard phase == .intensityTrivia else { return }
        if intensityTriviaIndex == Level2Content.intensityTrivia.count - 1 {
            phase = .closing
            closingIndex = 0
        } else {
            intensityTriviaIndex += 1
        }
    }

    func advanceClosing() {
        guard phase == .closing else { return }
        if closingIndex == Level2Content.closingDialog.count - 1 {
            phase = .review
        } else {
            closingIndex += 1
        }
    }

    func finishReview() {
        guard phase == .review else { return }
        phase = .completed
        progressStore.markLevelCompleted(Level2Content.levelID)
    }

    func sceneDidPlace(at worldPosition: SIMD3<Float>) {
        sceneWorldPosition = worldPosition
        previousCameraPosition = nil
        guard phase == .placingScene else { return }
        phase = .shadowExploration
    }

    func sceneDidReset() {
        sceneWorldPosition = nil
        previousCameraPosition = nil
        visitedShadowSectors = []
        shadowTravelDistance = 0
        hasCompletedShadowTask = false

        guard phase != .onboarding, phase != .completed else { return }
        phase = .placingScene
    }

    func cameraDidUpdate(position: SIMD3<Float>) {
        guard phase == .shadowExploration,
              !hasCompletedShadowTask,
              let sceneWorldPosition else { return }

        recordTravel(to: position)

        let offset = SIMD2<Float>(
            position.x - sceneWorldPosition.x,
            position.z - sceneWorldPosition.z
        )
        let radius = simd_length(offset)
        guard radius >= 0.3, radius <= 3 else { return }

        let normalizedAngle = atan2(offset.y, offset.x) + .pi
        let sectorWidth = (2 * Float.pi) / 8
        let sector = min(Int(normalizedAngle / sectorWidth), 7)
        visitedShadowSectors.insert(sector)

        if visitedShadowSectors.count >= 3, shadowTravelDistance >= 0.45 {
            hasCompletedShadowTask = true
            successFeedbackTrigger += 1
        }
    }

    #if DEBUG
    func completeShadowTaskForDebugging() {
        guard phase == .shadowExploration else { return }
        hasCompletedShadowTask = true
        visitedShadowSectors = [0, 2, 4]
        successFeedbackTrigger += 1
    }
    #endif

    private func configureLearningScene() {
        arSceneViewModel.selectedObjectType = .cube
        arSceneViewModel.objectScale = 0.85
        arSceneViewModel.requiresLiDARScanBeforePlacement = false
        // Matches Level3/Level4: skip environment texturing + light estimation.
        // Level2's cube doesn't need photoreal blending, and this is one of the
        // more thermally expensive ARKit features — Level2 was paying for it
        // with no visible benefit since this flag was never set here before.
        arSceneViewModel.usesRealisticEnvironmentLighting = false
        arSceneViewModel.showLightDirection = true
        arSceneViewModel.showLightRays = false
        arSceneViewModel.showProjectionLines = false
        arSceneViewModel.showGroundProjection = true
        arSceneViewModel.showShadowLabels = false
        arSceneViewModel.showShadowInformation = false

        let selectedObject = arSceneViewModel.selectedObject
        let objectCenter = selectedObject.position + SIMD3<Float>(
            0,
            SceneObjectEntityFactory.objectHeight(for: selectedObject) * selectedObject.scale / 2,
            0
        )
        let lightPosition = SIMD3<Float>(-0.24, 0.34, 0.28)
        let aimingAngles = SceneLightEntityFactory.aimingAngles(
            from: lightPosition,
            to: objectCenter
        )

        arSceneViewModel.updateSelectedLight { light in
            light.type = .spot
            light.position = lightPosition
            light.intensity = lightIntensity
            light.beamSpread = .medium
            light.beamOuterAngleDegrees = beamSpreadDegrees
            light.markerScale = 0.7
            if let aimingAngles {
                light.yawDegrees = aimingAngles.yawDegrees
                light.pitchDegrees = aimingAngles.pitchDegrees
            }
        }

        #if DEBUG
        if let aimingAngles {
            let actualDirection = SceneLightEntityFactory.forwardVector(
                yawDegrees: aimingAngles.yawDegrees,
                pitchDegrees: aimingAngles.pitchDegrees
            )
            let expectedDirection = simd_normalize(objectCenter - lightPosition)
            assert(
                simd_dot(actualDirection, expectedDirection) > 0.9999,
                "Spotlight Level 2 harus tepat mengarah ke pusat objek."
            )
        }
        #endif
    }

    private func recordTravel(to position: SIMD3<Float>) {
        defer { previousCameraPosition = position }
        guard let previousCameraPosition else { return }

        let step = simd_length(SIMD2<Float>(
            position.x - previousCameraPosition.x,
            position.z - previousCameraPosition.z
        ))
        guard step >= 0.005, step <= 0.35 else { return }
        shadowTravelDistance += step
    }

    private func setBeamSpread(_ requestedValue: Float) {
        let nextValue = clamped(
            requestedValue,
            Self.minimumBeamAngle,
            Self.maximumBeamAngle
        )
        guard nextValue != beamSpreadDegrees else { return }
        beamSpreadDegrees = nextValue
        arSceneViewModel.updateSelectedLight { $0.beamOuterAngleDegrees = nextValue }

        if nextValue <= 34 { hasReachedNarrowSpread = true }
        if nextValue >= 78 { hasReachedWideSpread = true }
        completeSpreadTaskIfNeeded()
    }

    private func completeSpreadTaskIfNeeded() {
        guard hasReachedNarrowSpread, hasReachedWideSpread, !hasCompletedSpreadTask else { return }
        hasCompletedSpreadTask = true
        successFeedbackTrigger += 1
    }

    private func setIntensity(_ requestedValue: Float) {
        let nextValue = clamped(
            requestedValue,
            Self.minimumIntensity,
            Self.maximumIntensity
        )
        guard nextValue != lightIntensity else { return }
        lightIntensity = nextValue
        arSceneViewModel.updateSelectedLight { $0.intensity = nextValue }

        if nextValue <= 1_200 { hasReachedDimIntensity = true }
        if nextValue >= 5_400 { hasReachedBrightIntensity = true }
        completeIntensityTaskIfNeeded()
    }

    private func completeIntensityTaskIfNeeded() {
        guard hasReachedDimIntensity, hasReachedBrightIntensity, !hasCompletedIntensityTask else { return }
        hasCompletedIntensityTask = true
        successFeedbackTrigger += 1
    }
}
