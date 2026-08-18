import Foundation
import Observation
import simd
import RealityKit

enum Level2Phase: String, Equatable {
    case onboarding
    case placingScene
    case surfaceReady
    case shadowExploration
    case shadowTrivia
    case spreadTransition
    case spreadExploration
    case spreadTrivia
    case intensityExploration
    case intensityTrivia
    case closing
    case review
    case completed
}

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
    private(set) var progressCelebration: LessonProgressCelebration?

    private(set) var beamSpreadDegrees: Float = 54
    private(set) var lightIntensity: Float = 3_200

    @ObservationIgnored private let progressStore: GameProgressStore
    @ObservationIgnored private var sceneWorldPosition: SIMD3<Float>?
    @ObservationIgnored private var previousCameraPosition: SIMD3<Float>?
    @ObservationIgnored private var shadowTravelDistance: Float = 0
    @ObservationIgnored private var spreadGestureStart: Float?
    @ObservationIgnored private var intensityGestureStart: Float?
    
    // MARK: - AR Guide (Lumi) State
    @ObservationIgnored private var guideRoot: Entity?
    @ObservationIgnored private var guideCharacter: Entity?
    @ObservationIgnored private var guideCharacterAsset: CharacterGuideAsset?
    @ObservationIgnored private var guideCloud: Entity?
    @ObservationIgnored private var guideText: String?
    @ObservationIgnored private var guideNeedsPlacement = true

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
        case .onboarding: return currentOnboardingLine.text
        case .placingScene: return "Arahkan titik tengah layar ke meja atau lantai, lalu tekan tombol Taruh Benda di Tengah."
        case .surfaceReady: return "Permukaan dan posisi benda sudah siap."
        case .shadowExploration: return hasCompletedShadowTask ? "Hebat! Kamu sudah melihat bayangan dari beberapa sisi." : "Jalan pelan mengelilingi benda. Cari bayangannya dari tiga sisi yang berbeda."
        case .shadowTrivia: return currentShadowTriviaLine.text
        case .spreadTransition: return currentSpreadTransitionLine.text
        case .spreadExploration: return hasCompletedSpreadTask ? "Keren! Kamu sudah mencoba cahaya sempit dan cahaya lebar." : "Rapatkan dua ibu jari untuk mengecilkan cahaya. Lebarkan jari untuk melebarkan cahaya."
        case .spreadTrivia: return currentSpreadTriviaLine.text
        case .intensityExploration: return hasCompletedIntensityTask ? "Bagus! Kamu sudah membuat cahaya redup dan terang." : Level2Content.intensityExplorationDialog.text
        case .intensityTrivia: return currentIntensityTriviaLine.text
        case .closing: return currentClosingLine.text
        case .review: return "Lebar dan terang cahaya bisa mengubah bayangan!"
        case .completed: return "Level dua selesai!"
        }
    }
    
    var narrationAudioFileName: String? {
        switch phase {
        case .onboarding: return currentOnboardingLine.audioFileName
        case .shadowTrivia: return currentShadowTriviaLine.audioFileName
        case .spreadTransition: return currentSpreadTransitionLine.audioFileName
        case .spreadExploration: return hasCompletedSpreadTask ? nil : "level-2/6 Bagus! Rapatkan dua jari untuk mengecilkan cahaya.mp3"
        case .spreadTrivia: return currentSpreadTriviaLine.audioFileName
        case .intensityExploration: return hasCompletedIntensityTask ? nil : Level2Content.intensityExplorationDialog.audioFileName
        case .intensityTrivia: return currentIntensityTriviaLine.audioFileName
        case .closing: return currentClosingLine.audioFileName
        default: return nil
        }
    }
    
    var narrationID: String {
        "\(phase)-\(onboardingIndex)-\(shadowTriviaIndex)-\(spreadTransitionIndex)-\(spreadTriviaIndex)-\(intensityTriviaIndex)-\(closingIndex)-\(hasCompletedSpreadTask)-\(hasCompletedIntensityTask)"
    }

    func advanceOnboarding() {
        guard phase == .onboarding else { return }
        if onboardingIndex == Level2Content.onboardingDialog.count - 1 { phase = .placingScene } else { onboardingIndex += 1 }
        syncGuidePresentation()
    }

    func continueFromShadowTask() {
        guard phase == .shadowExploration, hasCompletedShadowTask else { return }
        phase = .shadowTrivia
        shadowTriviaIndex = 0
        syncGuidePresentation()
    }

    func advanceShadowTrivia() {
        guard phase == .shadowTrivia else { return }
        if shadowTriviaIndex == Level2Content.shadowTrivia.count - 1 {
            phase = .spreadTransition
            spreadTransitionIndex = 0
        } else {
            shadowTriviaIndex += 1
        }
        syncGuidePresentation()
    }

    func advanceSpreadTransition() {
        guard phase == .spreadTransition else { return }
        if spreadTransitionIndex == Level2Content.spreadTransition.count - 1 {
            phase = .spreadExploration
            arSceneViewModel.showLightRays = true
        } else {
            spreadTransitionIndex += 1
        }
        syncGuidePresentation()
    }

    func beginSpreadGesture() {
        guard phase == .spreadExploration else { return }
        spreadGestureStart = beamSpreadDegrees
    }

    func updateSpreadGesture(magnification: Float) {
        guard phase == .spreadExploration, let spreadGestureStart else { return }
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
        syncGuidePresentation()
    }

    func advanceSpreadTrivia() {
        guard phase == .spreadTrivia else { return }
        if spreadTriviaIndex == Level2Content.spreadTrivia.count - 1 {
            phase = .intensityExploration
            arSceneViewModel.showLightRays = true
        } else {
            spreadTriviaIndex += 1
        }
        syncGuidePresentation()
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
        syncGuidePresentation()
    }

    func advanceIntensityTrivia() {
        guard phase == .intensityTrivia else { return }
        if intensityTriviaIndex == Level2Content.intensityTrivia.count - 1 {
            phase = .closing
            closingIndex = 0
        } else {
            intensityTriviaIndex += 1
        }
        syncGuidePresentation()
    }

    func advanceClosing() {
        guard phase == .closing else { return }
        if closingIndex == Level2Content.closingDialog.count - 1 {
            phase = .review
        } else {
            closingIndex += 1
        }
        syncGuidePresentation()
    }

    func finishReview() {
        guard phase == .review else { return }
        phase = .completed
        progressStore.markLevelCompleted(Level2Content.levelID)
    }

    func sceneDidPlace(at worldPosition: SIMD3<Float>) {
        sceneWorldPosition = worldPosition
        previousCameraPosition = nil
        switch phase {
        case .placingScene:
            phase = .surfaceReady
        case .surfaceReady:
            phase = .shadowExploration
        default:
            break
        }
        setupGuideCharacterIfNeeded()
    }

    func continueAfterSurfaceCheck() {
        guard phase == .surfaceReady else { return }
        if arSceneViewModel.isObjectPlaced {
            phase = .shadowExploration
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
        phase = .surfaceReady
    }

    func sceneDidReset() {
        sceneWorldPosition = nil
        previousCameraPosition = nil
        visitedShadowSectors = []
        shadowTravelDistance = 0
        hasCompletedShadowTask = false
        guideNeedsPlacement = true
        guideRoot?.isEnabled = false

        guard phase != .onboarding, phase != .completed else { return }
        phase = .placingScene
    }

    func cameraDidUpdate(position: SIMD3<Float>) {
        updateGuidePosition(cameraPosition: position)
        
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
            celebrate(title: "Misi Bayangan Selesai!", detail: "Kamu menemukan bayangan dari tiga sisi.")
            syncGuidePresentation()
        }
    }

    #if DEBUG
    func completeShadowTaskForDebugging() {
        guard phase == .shadowExploration else { return }
        hasCompletedShadowTask = true
        visitedShadowSectors = [0, 2, 4]
        successFeedbackTrigger += 1
        syncGuidePresentation()
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
        arSceneViewModel.showProjectionLines = false
        arSceneViewModel.showGroundProjection = true
        arSceneViewModel.showShadowLabels = false
        arSceneViewModel.showShadowInformation = false
        arSceneViewModel.objectDirectManipulationLocked = true
        arSceneViewModel.directManipulationRotatesOnly = true
        arSceneViewModel.interactionMode = .moveLight
        arSceneViewModel.lightDirectionFollowsGesture = true

        let selectedObject = arSceneViewModel.selectedObject
        let objectCenter = selectedObject.position + SIMD3<Float>(
            0,
            SceneObjectSystem.objectHeight(for: selectedObject) * selectedObject.scale / 2,
            0
        )
        let lightPosition = SIMD3<Float>(-0.24, 0.34, 0.28)
        let aimingAngles = SceneLightSystem.aimingAngles(from: lightPosition, to: objectCenter)

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
        let nextValue = clamped(requestedValue, Self.minimumBeamAngle, Self.maximumBeamAngle)
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
        celebrate(title: "Cahaya Berhasil Diatur!", detail: "Kamu sudah mencoba cahaya sempit dan lebar.")
        syncGuidePresentation()
    }

    private func setIntensity(_ requestedValue: Float) {
        let nextValue = clamped(requestedValue, Self.minimumIntensity, Self.maximumIntensity)
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
        celebrate(title: "Terang dan Redup Selesai!", detail: "Kamu sudah mencoba dua intensitas cahaya.")
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
    
    // MARK: - AR Guide Character Logic (Lumi)
    
    private func setupGuideCharacterIfNeeded() {
        guard guideRoot == nil else { return }
        let guide = Entity()
        guide.name = "Level 2 Guide — Lumi"
        guide.isEnabled = false
        let asset = currentGuideAsset
        if let character = CharacterGuideFactory.makeCharacter(asset: asset, width: 0.10, height: 0.14) {
            guide.addChild(character)
            guideCharacter = character
            guideCharacterAsset = asset
        }
        
        arSceneViewModel.addEntityToScene(guide)
        guideRoot = guide
    }
    
    private func updateGuidePosition(cameraPosition: SIMD3<Float>) {
        guard let guide = guideRoot, let center = sceneWorldPosition else { return }
        
        let forward = simd_normalize(center - cameraPosition)
        let right = SIMD3<Float>(-forward.z, 0, forward.x)
        let destination = cameraPosition + forward * 0.66 + right * 0.30 + SIMD3<Float>(0, -0.54, 0)

        if guideNeedsPlacement {
            guide.position = destination
            guideNeedsPlacement = false
            guide.isEnabled = shouldShowGuide
            syncGuidePresentation()
        } else {
            guide.position += (destination - guide.position) * 0.24
        }
        
        guide.look(at: cameraPosition, from: guide.position, relativeTo: nil)
        guideCloud?.position = SIMD3<Float>(0.22, 0.14, 0)
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
        cloud.position = SIMD3<Float>(0.22, 0.14, 0)
        guide.addChild(cloud)
        guideCloud = cloud
    }
    
    private var shouldShowGuide: Bool {
        phase != .placingScene && phase != .completed
    }
    
    private var currentGuideAsset: CharacterGuideAsset {
        switch phase {
        case .onboarding: return .lumiIdle
        case .shadowExploration: return hasCompletedShadowTask ? .lumiPointWink : .lumiPoint
        case .shadowTrivia: return .lumiPoint
        case .spreadTransition: return .lumiPoint
        case .spreadExploration: return hasCompletedSpreadTask ? .lumiPointWink : .lumiPoint
        case .spreadTrivia: return .lumiQuestion
        case .intensityExploration: return hasCompletedIntensityTask ? .lumiPointWink : .lumiPoint
        case .intensityTrivia: return .lumiQuestion
        case .closing, .review: return .lumiIdle
        default: return .lumiIdle
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
