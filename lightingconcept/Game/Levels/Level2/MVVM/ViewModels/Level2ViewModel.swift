import Foundation
import Observation
import RealityKit
import UIKit
import simd

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
    private(set) var spreadTutorialIndex = 0
    private(set) var intensityTutorialIndex = 0
    private(set) var missionIndex = 0
    private(set) var closingIndex = 0

    private(set) var hasReachedNarrowSpread = false
    private(set) var hasReachedWideSpread = false
    private(set) var hasReachedDimIntensity = false
    private(set) var hasReachedBrightIntensity = false
    private(set) var successFeedbackTrigger = 0
    private(set) var progressCelebration: LessonProgressCelebration?
    private(set) var activeTouchCount = 0
    private(set) var isAdjustingIntensity = false
    private(set) var waitsForLightTap = false
    private(set) var isLookAroundMode = false

    private(set) var beamSpreadDegrees: Float = 54
    private(set) var lightIntensity: Float = 3_200

    @ObservationIgnored private let progressStore: GameProgressStore
    @ObservationIgnored private var spreadGestureStart: Float?
    @ObservationIgnored private var intensityGestureStart: Float?
    @ObservationIgnored private weak var guideParent: Entity?
    @ObservationIgnored private var guideRoot: Entity?
    @ObservationIgnored private var guideCharacter: Entity?
    @ObservationIgnored private var guideCharacterAsset: CharacterGuideAsset?
    @ObservationIgnored private var guideCloud: Entity?
    @ObservationIgnored private var guideText: String?
    @ObservationIgnored private var guideNeedsPlacement = true
    @ObservationIgnored private weak var lightTapPromptParent: Entity?
    @ObservationIgnored private var lightTapPromptEntity: Entity?

    private static var cachedLightTapRingTexture: TextureResource?
    private static var cachedLightTapDotTexture: TextureResource?

    init(progressStore: GameProgressStore? = nil) {
        self.progressStore = progressStore ?? .shared
        configureLearningScene()
    }

    var currentOnboardingLine: Level2OverlayLine { Level2Content.onboardingDialog[onboardingIndex] }
    var currentSpreadTutorialStep: Level2TutorialStep { Level2Content.spreadTutorial[spreadTutorialIndex] }
    var currentIntensityTutorialStep: Level2TutorialStep { Level2Content.intensityTutorial[intensityTutorialIndex] }
    var currentMissionLine: Level2OverlayLine { Level2Content.mission[missionIndex] }
    var currentClosingLine: DialogLine { Level2Content.closingDialog[closingIndex] }

    var intensityPercentage: Int {
        let range = Self.maximumIntensity - Self.minimumIntensity
        return Int(((lightIntensity - Self.minimumIntensity) / range * 100).rounded())
    }

    var topModeTitle: String? {
        switch phase {
        case .spreadTutorial, .spreadFreeIntro, .spreadFreeInstructions, .intensityTransition, .intensityTutorial, .mission:
            isLookAroundMode ? "Mode lihat-lihat" : "Kamu jadi cahaya!"
        case .spreadFreeExploration:
            isLookAroundMode ? "Mode lihat-lihat" : "Kamu jadi cahaya!"
        default:
            nil
        }
    }

    var narrationAudioFileName: String? {
        narrationAudioFileNames.first
    }

    var narrationAudioFileNames: [String] {
        switch phase {
        case .onboarding:
            currentOnboardingLine.audioFileName.map { [$0] } ?? []
        case .placingScene:
            [Level2Content.placementAudioFileName]
        case .spreadTutorial:
            currentSpreadTutorialStep.audioFileName.map { [$0] }
                ?? [Level2Content.genericGestureAudioFileName]
        case .spreadFreeIntro:
            Level2Content.spreadFreeIntro.audioFileName.map { [$0] } ?? []
        case .spreadFreeInstructions:
            Level2Content.spreadReminderAudioFileNames
        case .spreadFreeExploration:
            [Level2Content.spreadFreeExplorationAudioFileName]
        case .intensityTransition:
            Level2Content.intensityTransition.audioFileName.map { [$0] } ?? []
        case .intensityTutorial:
            currentIntensityTutorialStep.audioFileName.map { [$0] }
                ?? [Level2Content.verticalSlideAudioFileName]
        case .mission:
            currentMissionLine.audioFileName.map { [$0] } ?? []
        case .completed:
            [Level2Content.completedAudioFileName]
        default:
            []
        }
    }

    var narrationID: String {
        "\(phase.rawValue)-\(onboardingIndex)-\(spreadTutorialIndex)-\(intensityTutorialIndex)-\(missionIndex)-\(closingIndex)-\(narrationAudioFileNames.joined(separator: "|"))"
    }

    var narrationText: String {
        switch phase {
        case .onboarding:
            currentOnboardingLine.text
        case .placingScene:
            "Arahkan titik tengah layar ke meja atau lantai, lalu tekan tombol Taruh Benda di Tengah."
        case .surfaceReady:
            "Permukaan dan posisi benda sudah siap. Pilih Lanjut untuk mulai belajar, atau Scan Ulang untuk mengatur ulang permukaan."
        case .spreadTutorial:
            currentSpreadTutorialStep.text ?? "Ikuti gerakan jari di layar."
        case .spreadFreeIntro:
            Level2Content.spreadFreeIntro.text
        case .spreadFreeInstructions:
            "Rapatkan dua jari untuk mengecilkan cahaya. Lebarkan dua jari untuk melebarkan cahaya."
        case .spreadFreeExploration:
            "Tekan sekali di tempat kosong untuk lihat-lihat. Kalau sudah, tekan Selanjutnya."
        case .intensityTransition:
            Level2Content.intensityTransition.text
        case .intensityTutorial:
            currentIntensityTutorialStep.text ?? "Geser jarimu naik dan turun di sebelah kiri layar."
        case .mission:
            currentMissionLine.text
        case .closing:
            currentClosingLine.text
        case .review:
            "Cahaya bisa dibuat sempit atau lebar, juga terang atau redup. Perubahan itu mengubah bayangan."
        case .completed:
            "Level dua selesai. Kamu hebat, Detektif Cahaya!"
        }
    }

    var canAdjustSpread: Bool {
        switch phase {
        case .spreadTutorial, .spreadFreeExploration:
            !isLookAroundMode
        case .mission:
            !isLookAroundMode && (missionIndex == 1 || missionIndex == 3)
        default:
            false
        }
    }

    var canAdjustIntensity: Bool {
        switch phase {
        case .intensityTutorial:
            !isLookAroundMode
        case .mission:
            !isLookAroundMode && (missionIndex == 1 || missionIndex == 3)
        default:
            false
        }
    }

    var gestureMode: Level2GestureMode {
        if isLookAroundMode { return .none }
        if phase == .mission, canAdjustSpread || canAdjustIntensity { return .spreadAndIntensity }
        if canAdjustSpread { return .spread }
        if canAdjustIntensity { return .intensity }
        return .none
    }


    func advanceOnboarding() {
        guard phase == .onboarding else { return }
        if onboardingIndex == 0, !arSceneViewModel.isObjectPlaced {
            phase = .placingScene
        } else if onboardingIndex == 1 {
            onboardingIndex = 2
            waitsForLightTap = true
        } else if onboardingIndex == Level2Content.onboardingDialog.count - 1, !waitsForLightTap {
            startSpreadTutorial()
        }
    }

    func continueAfterSurfaceCheck() {
        guard phase == .surfaceReady else { return }
        if arSceneViewModel.isObjectPlaced {
            startSpreadTutorial()
        } else {
            arSceneViewModel.placeSceneAtScreenCenter()
        }
    }

    func rescanSurface() {
        guard phase == .surfaceReady else { return }
        arSceneViewModel.rescanSurface()
    }

    func advanceSpreadTutorial() {
        guard phase == .spreadTutorial else { return }
        if spreadTutorialIndex == Level2Content.spreadTutorial.count - 1 {
            phase = .spreadFreeIntro
        } else {
            spreadTutorialIndex += 1
        }
    }

    func advanceSpreadFreeIntro() {
        guard phase == .spreadFreeIntro else { return }
        phase = .spreadFreeInstructions
    }

    func dismissSpreadFreeInstructions() {
        guard phase == .spreadFreeInstructions else { return }
        phase = .spreadFreeExploration
        isLookAroundMode = false
    }

    func finishSpreadFreeExploration() {
        guard phase == .spreadFreeExploration else { return }
        phase = .intensityTransition
    }

    func advanceIntensityTransition() {
        guard phase == .intensityTransition else { return }
        phase = .intensityTutorial
        intensityTutorialIndex = 0
    }

    func advanceIntensityTutorial() {
        guard phase == .intensityTutorial else { return }
        if intensityTutorialIndex == Level2Content.intensityTutorial.count - 1 {
            phase = .mission
            missionIndex = 0
        } else {
            intensityTutorialIndex += 1
        }
    }

    func advanceMission() {
        guard phase == .mission else { return }
        switch missionIndex {
        case 0, 2, 4:
            missionIndex += 1
        case 5:
            phase = .completed
            progressStore.markLevelCompleted(Level2Content.levelID)
        default:
            break
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
        switch phase {
        case .placingScene, .surfaceReady:
            phase = .onboarding
            onboardingIndex = 1
            waitsForLightTap = false
        default:
            break
        }
    }


    func sceneDidReset() {
        resetInteractionProgress()
        guideRoot?.removeFromParent()
        guideRoot = nil
        guideParent = nil
        guideCharacter = nil
        guideCharacterAsset = nil
        guideCloud = nil
        guideText = nil
        guideNeedsPlacement = true
        lightTapPromptEntity?.removeFromParent()
        lightTapPromptParent = nil
        lightTapPromptEntity = nil
        guard phase != .onboarding, phase != .completed else { return }
        phase = .placingScene
    }

    func cameraDidUpdate(position: SIMD3<Float>) {}

    func lightDidSelect() {
        if phase == .onboarding, onboardingIndex == 2, waitsForLightTap {
            waitsForLightTap = false
            isLookAroundMode = false
            successFeedbackTrigger += 1
            startSpreadTutorial()
            return
        }

        if phase == .intensityTutorial, intensityTutorialIndex == 0 {
            isLookAroundMode = false
            successFeedbackTrigger += 1
            advanceIntensityTutorial()
            return
        }

        guard canSelectLightForControl else { return }
        isLookAroundMode = false
        successFeedbackTrigger += 1
    }

    func syncLightTapPrompt(in parent: Entity) {
        guard shouldShowLightTapPrompt else {
            lightTapPromptEntity?.isEnabled = false
            return
        }

        if lightTapPromptParent !== parent {
            lightTapPromptEntity?.removeFromParent()
            lightTapPromptParent = parent
            lightTapPromptEntity = nil
        }

        let prompt = lightTapPromptEntity ?? makeLightTapPromptEntity()
        if lightTapPromptEntity == nil {
            parent.addChild(prompt)
            lightTapPromptEntity = prompt
        }
        prompt.isEnabled = true
        prompt.position = arSceneViewModel.selectedLight.position + SIMD3<Float>(0, 0.015, 0)
    }

    func sceneDidTapEmpty() {
        guard canEnterLookAroundMode else { return }
        isLookAroundMode = true
        isAdjustingIntensity = false
        intensityGestureStart = nil
        spreadGestureStart = nil
    }

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
        guide.name = "Level 2 Guide - Lumi"
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

    func updateGuide(cameraPosition: SIMD3<Float>, forward: SIMD3<Float>) {
        guard let guide = guideRoot else { return }
        let horizontalForward = SIMD2<Float>(forward.x, forward.z)
        let forwardLength = simd_length(horizontalForward)
        guard forwardLength > 0.0001 else { return }

        let normalizedForward = horizontalForward / forwardLength
        let forward3D = SIMD3<Float>(normalizedForward.x, 0, normalizedForward.y)
        let right = SIMD3<Float>(-normalizedForward.y, 0, normalizedForward.x)
        let destination = cameraPosition + forward3D * 0.66 + right * 0.30 + SIMD3<Float>(0, -0.54, 0)

        if guideNeedsPlacement {
            guide.position = destination
            guideNeedsPlacement = false
        } else {
            guide.position += (destination - guide.position) * 0.24
        }

        guide.look(at: cameraPosition, from: guide.position, relativeTo: nil)
        syncGuidePresentation()
    }


    func fingerTouchDidChange(count: Int) {
        activeTouchCount = count
        guard phase == .spreadTutorial else { return }

        if spreadTutorialIndex == 0, count >= 2 {
            successFeedbackTrigger += 1
            advanceSpreadTutorialAfterDelay(from: spreadTutorialIndex, delay: 0.45)
        } else if spreadTutorialIndex == 1, count < 2, !hasReachedWideSpread {
            spreadTutorialIndex = 0
        }
    }

    func beginSpreadGesture() {
        guard canAdjustSpread else { return }
        spreadGestureStart = beamSpreadDegrees
    }

    func updateSpreadGesture(magnification: Float) {
        guard canAdjustSpread, let spreadGestureStart else { return }
        setBeamSpread(spreadGestureStart + (magnification - 1) * 90)
    }

    func endSpreadGesture() {
        spreadGestureStart = nil
        if phase == .spreadTutorial, spreadTutorialIndex == 1, !hasReachedWideSpread {
            spreadTutorialIndex = 0
        }
    }

    func adjustSpread(by delta: Float) {
        guard canAdjustSpread else { return }
        setBeamSpread(beamSpreadDegrees + delta)
    }

    func beginIntensityGesture() {
        guard canAdjustIntensity else { return }
        isAdjustingIntensity = true
        intensityGestureStart = lightIntensity
        if phase == .intensityTutorial, intensityTutorialIndex == 1 {
            advanceIntensityTutorialAfterDelay(from: intensityTutorialIndex, delay: 0.35)
        }
    }

    func updateIntensityGesture(verticalTranslation: Float) {
        guard canAdjustIntensity, let intensityGestureStart else { return }
        setIntensity(intensityGestureStart - verticalTranslation * 18)
    }

    func endIntensityGesture() {
        isAdjustingIntensity = false
        intensityGestureStart = nil
    }

    func adjustIntensity(by delta: Float) {
        guard canAdjustIntensity else { return }
        setIntensity(lightIntensity + delta)
    }

    private func startSpreadTutorial() {
        phase = .spreadTutorial
        spreadTutorialIndex = 0
        arSceneViewModel.showLightRays = true
    }

    private var currentGuideLine: Level2OverlayLine? {
        switch phase {
        case .onboarding:
            currentOnboardingLine
        case .spreadTutorial:
            guideLine(for: currentSpreadTutorialStep)
        case .spreadFreeIntro:
            Level2Content.spreadFreeIntro
        case .spreadFreeExploration:
            Level2OverlayLine(
                text: "Tekan sekali di tempat kosong untuk lihat-lihat!",
                mascot: .pointWink,
                audioFileName: Level2Content.spreadFreeExplorationAudioFileName
            )
        case .intensityTransition:
            Level2Content.intensityTransition
        case .intensityTutorial:
            guideLine(for: currentIntensityTutorialStep)
        case .mission:
            currentMissionLine
        case .closing:
            Level2OverlayLine(text: currentClosingLine.text, mascot: .idle)
        default:
            nil
        }
    }

    private var currentGuideAsset: CharacterGuideAsset {
        switch currentGuideLine?.mascot ?? .idle {
        case .idle:
            .lumiIdle
        case .point:
            .lumiPoint
        case .pointWink:
            .lumiPointWink
        case .question:
            .lumiQuestion
        }
    }

    private func guideLine(for step: Level2TutorialStep) -> Level2OverlayLine? {
        guard let text = step.text, let mascot = step.mascot else { return nil }
        return Level2OverlayLine(
            text: text,
            mascot: mascot,
            bubble: step.bubble,
            highlightedWords: step.highlightedWords,
            audioFileName: step.audioFileName
        )
    }

    private func syncGuidePresentation() {
        guard let guide = guideRoot else { return }
        guard let line = currentGuideLine, !guideNeedsPlacement else {
            guide.isEnabled = false
            return
        }

        guide.isEnabled = true
        syncGuideCharacterAsset()
        guard guideText != line.text else { return }
        guideText = line.text
        guideCloud?.removeFromParent()
        let speechLayout = guideSpeechLayout(for: line.text)
        let cloud = CharacterGuideFactory.makeSpeechCloud(
            text: speechLayout.text,
            width: speechLayout.width,
            height: speechLayout.height,
            fontSize: 0.013,
            textHorizontalInset: 0.025,
            textVerticalInset: 0.030
        )
        cloud.name = "Lumi Level 2 Speech Cloud"
        cloud.position = SIMD3<Float>(0.22, 0.14, 0)
        guide.addChild(cloud)
        guideCloud = cloud
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
        let wrappedText = wrappedGuideText(text, maximumWordsPerLine: 8)
        let lines = wrappedText.split(separator: "\n", omittingEmptySubsequences: false)
        let longestLineCount = lines.map(\.count).max() ?? text.count
        let width = clamped(Float(longestLineCount) * 0.0064 + 0.10, 0.24, 0.56)
        let height = clamped(Float(lines.count) * 0.022 + 0.060, 0.082, 0.24)
        return (wrappedText, width, height)
    }

    private func wrappedGuideText(_ text: String, maximumWordsPerLine: Int) -> String {
        let words = text.replacingOccurrences(of: "\n", with: " ").split(separator: " ").map(String.init)
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

    private func makeLightTapPromptEntity() -> Entity {
        let root = Entity()
        root.name = "level2-light-tap-prompt"

        let dot = ModelEntity(
            mesh: .generatePlane(width: 0.034, height: 0.034),
            materials: [Self.lightTapDotMaterial(alpha: 1.0)]
        )
        dot.name = "level2-light-tap-prompt-center"
        dot.components.set(BillboardComponent())
        dot.components.set(DynamicLightShadowComponent(castsShadow: false))
        dot.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.04)]))
        dot.components.set(InputTargetComponent())
        dot.components.set(PulseAnimationComponent(baseScale: 1, speed: 5.0, amplitude: 0.35, isActiveTarget: true))
        root.addChild(dot)

        let ring = ModelEntity(
            mesh: .generatePlane(width: 0.07, height: 0.07),
            materials: [Self.lightTapRingMaterial(alpha: 1.0)]
        )
        ring.name = "level2-light-tap-prompt-ring"
        ring.components.set(BillboardComponent())
        ring.components.set(DynamicLightShadowComponent(castsShadow: false))
        ring.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.07)]))
        ring.components.set(InputTargetComponent())
        ring.components.set(PulseAnimationComponent(baseScale: 1, speed: 3.8, amplitude: 0.45, isActiveTarget: true))
        root.addChild(ring)

        root.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.08)]))
        root.components.set(InputTargetComponent())
        return root
    }

    private static func lightTapRingMaterial(alpha: Float) -> UnlitMaterial {
        var material = UnlitMaterial()
        if let texture = cachedLightTapRingTexture ?? generateLightTapRingTexture() {
            cachedLightTapRingTexture = texture
            material.color = .init(tint: UIColor.white.withAlphaComponent(CGFloat(alpha)), texture: .init(texture))
        } else {
            material.color = .init(tint: UIColor.white.withAlphaComponent(CGFloat(alpha)))
        }
        material.blending = .transparent(opacity: .init(floatLiteral: alpha))
        return material
    }

    private static func lightTapDotMaterial(alpha: Float) -> UnlitMaterial {
        var material = UnlitMaterial()
        if let texture = cachedLightTapDotTexture ?? generateLightTapDotTexture() {
            cachedLightTapDotTexture = texture
            material.color = .init(tint: UIColor.white.withAlphaComponent(CGFloat(alpha)), texture: .init(texture))
        } else {
            material.color = .init(tint: UIColor.systemRed.withAlphaComponent(CGFloat(alpha)))
        }
        material.blending = .transparent(opacity: .init(floatLiteral: alpha))
        return material
    }

    private static func generateLightTapRingTexture(
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

    private static func generateLightTapDotTexture(size: CGFloat = 256) -> TextureResource? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            context.cgContext.clear(rect)
            let dotRect = rect.insetBy(dx: size * 0.12, dy: size * 0.12)
            context.cgContext.setFillColor(UIColor.systemRed.cgColor)
            context.cgContext.fillEllipse(in: dotRect)
            context.cgContext.setStrokeColor(UIColor.white.cgColor)
            context.cgContext.setLineWidth(size * 0.08)
            context.cgContext.strokeEllipse(in: dotRect.insetBy(dx: size * 0.04, dy: size * 0.04))
        }
        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource(image: cgImage, withName: nil, options: .init(semantic: .color))
    }

    private func resetInteractionProgress() {
        hasReachedNarrowSpread = false
        hasReachedWideSpread = false
        hasReachedDimIntensity = false
        hasReachedBrightIntensity = false
        activeTouchCount = 0
        isAdjustingIntensity = false
        isLookAroundMode = false
        spreadGestureStart = nil
        intensityGestureStart = nil
    }

    private var shouldShowLightTapPrompt: Bool {
        if phase == .onboarding, onboardingIndex == 2, waitsForLightTap {
            return true
        }
        if phase == .intensityTutorial, intensityTutorialIndex == 0 {
            return true
        }
        return isLookAroundMode && canSelectLightForControl
    }

    private var canEnterLookAroundMode: Bool {
        switch phase {
        case .spreadFreeExploration, .intensityTransition, .intensityTutorial, .mission:
            true
        default:
            false
        }
    }

    private var canSelectLightForControl: Bool {
        switch phase {
        case .spreadFreeExploration, .intensityTransition, .intensityTutorial, .mission:
            true
        default:
            false
        }
    }

    private func configureLearningScene() {
        arSceneViewModel.selectedObjectType = .cube
        arSceneViewModel.objectScale = 0.85
        arSceneViewModel.requiresLiDARScanBeforePlacement = false
        arSceneViewModel.usesLiDARSceneReconstruction = true
        arSceneViewModel.usesRealisticEnvironmentLighting = true
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
        let aimingAngles = SceneLightSystem.aimingAngles(
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
        handleSpreadMilestone(nextValue)
        evaluateMissionProgress()
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
        handleIntensityMilestone(nextValue)
        evaluateMissionProgress()
    }

    private func handleSpreadMilestone(_ value: Float) {
        guard phase == .spreadTutorial else { return }
        switch spreadTutorialIndex {
        case 1, 3:
            if value >= 78 {
                advanceSpreadTutorialAfterDelay(from: spreadTutorialIndex, delay: 0.35)
            }
        case 2, 6:
            if value <= 34 {
                advanceSpreadTutorialAfterDelay(from: spreadTutorialIndex, delay: 0.35)
            }
        default:
            break
        }
    }

    private func handleIntensityMilestone(_ value: Float) {
        guard phase == .intensityTutorial, intensityTutorialIndex == 2 else { return }
        if value >= 5_400 || value <= 1_200 {
            advanceIntensityTutorialAfterDelay(from: intensityTutorialIndex, delay: 0.35)
        }
    }

    private func evaluateMissionProgress() {
        guard phase == .mission else { return }
        switch missionIndex {
        case 1 where beamSpreadDegrees >= 78 && lightIntensity >= 5_400:
            successFeedbackTrigger += 1
            missionIndex = 2
        case 3 where beamSpreadDegrees <= 34 && lightIntensity <= 1_200:
            successFeedbackTrigger += 1
            missionIndex = 4
        default:
            break
        }
    }

    private func advanceSpreadTutorialAfterDelay(from index: Int, delay: TimeInterval) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.phase == .spreadTutorial, self.spreadTutorialIndex == index else { return }
            if index == 0, self.activeTouchCount < 2 { return }
            self.advanceSpreadTutorial()
        }
    }

    private func advanceIntensityTutorialAfterDelay(from index: Int, delay: TimeInterval) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard self?.phase == .intensityTutorial, self?.intensityTutorialIndex == index else { return }
            self?.advanceIntensityTutorial()
        }
    }
}

enum Level2GestureMode: Equatable {
    case none
    case spread
    case intensity
    case spreadAndIntensity
}
