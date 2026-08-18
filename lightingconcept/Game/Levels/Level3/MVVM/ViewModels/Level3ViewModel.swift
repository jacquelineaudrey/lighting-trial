import Foundation
import Observation
import simd
import RealityKit

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
    case completed
}

@MainActor
@Observable
final class Level3ViewModel: ARSceneTelemetryDelegate {
    private static let fixedBeamSpreadDegrees: Float = 54
    private static let fixedLightIntensity: Float = 3_200

    let arSceneViewModel = ARSceneViewModel()
    var lastMarkerTapTime: Date = Date.distantPast
    private(set) var phase: Level3Phase = .placingScene
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
    private(set) var progressCelebration: LessonProgressCelebration?
    
    private(set) var isShadowInfoOpen = false

    @ObservationIgnored private let progressStore: GameProgressStore
    @ObservationIgnored private var sceneWorldPosition: SIMD3<Float>?
    @ObservationIgnored private var previousCameraPosition: SIMD3<Float>?
    @ObservationIgnored private var resumePhaseAfterPlacement: Level3Phase?
    
    // MARK: - AR Guide (Bayo) State
    @ObservationIgnored private var guideRoot: Entity?
    @ObservationIgnored private var guideCharacter: Entity?
    @ObservationIgnored private var guideCharacterAsset: CharacterGuideAsset?
    @ObservationIgnored private var guideCloud: Entity?
    @ObservationIgnored private var guideText: String?
    @ObservationIgnored private var guideNeedsPlacement = true

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

    // MARK: - Narration & Audio Interception untuk Marker
    
    var narrationText: String {
        // 1. Jika ada marker yang dipilih, timpa teks dengan penjelasan bayangan
        if let concept = arSceneViewModel.selectedConcept {
            return text(for: concept)
        }
        
        switch phase {
        case .onboarding: return currentOnboardingLine.text
        case .placingScene: return "Arahkan titik tengah layar ke meja atau lantai, lalu tekan Taruh Benda di Tengah."
        case .surfaceReady: return "Permukaan sudah siap."
        case .shadowExploration: return hasCompletedShadowTask ? "Bagus! Kamu sudah melihat bayangan dari beberapa sisi." : "Jalan pelan mengelilingi benda dan cari bayangannya."
        case .shadowTrivia: return currentShadowTriviaLine.text
        case .shadowTypesInteraction: return currentShadowTypesLine.text
        case .shapeComparison: return "Pilih kubus dan bola. Bandingkan bentuk bayangan yang dihasilkan keduanya."
        case .closing: return currentClosingLine.text
        case .review: return "Bayangan dipengaruhi oleh bentuk benda yang menghalangi cahaya."
        case .completed: return "Level tiga selesai. Kamu hebat, Detektif Bayangan!"
        }
    }
    
    var narrationAudioFileName: String? {
        // 2. Jika ada marker yang dipilih, timpa audio dengan file spesifik
        if let concept = arSceneViewModel.selectedConcept {
            return audioFileName(for: concept)
        }
        
        switch phase {
        case .onboarding: return currentOnboardingLine.audioFileName
        case .shadowTrivia: return currentShadowTriviaLine.audioFileName
        case .shadowTypesInteraction: return currentShadowTypesLine.audioFileName
        case .closing: return currentClosingLine.audioFileName
        default: return nil
        }
    }
    
    private var currentGuideAsset: CharacterGuideAsset {
        // 3. Ubah pose Bayo menjadi menunjuk saat menjelaskan marker
        if arSceneViewModel.selectedConcept != nil {
            return .bayoPoint
        }
        
        switch phase {
        case .onboarding: return .bayoIdle
        case .shadowTrivia: return .bayoPoint
        case .shadowTypesInteraction: return .bayoQuestion
        case .shapeComparison: return .bayoPointWink
        case .closing, .review: return .bayoIdle
        default: return .bayoIdle
        }
    }
    
    var narrationID: String {
        "\(phase)-\(onboardingIndex)-\(shadowTriviaIndex)-\(shadowTypesIndex)-\(closingIndex)-\(arSceneViewModel.selectedConcept?.rawValue ?? "none")"
    }
    
    // Fungsi tambahan untuk sinkronisasi paksa saat marker ditekan
    func forceSyncGuideForConcept() {
        syncGuidePresentation()
    }
    
    // MARK: - Helper Mapping Concept ke Teks & Audio
            
    private func text(for concept: ShadowConcept) -> String {
        switch concept {
        case .castShadow:
            return "Bayangan gelap yang muncul di lantai karena cahaya terhalang."
        case .reflectedLight:
            return "Cahaya pantulan dari lantai yang memantul kembali ke bola."
        case .coreShadow, .shadowSide, .terminator, .contactShadow:
            return "Sisi gelap karena cahayanya tidak sampai ke sini."
        case .highlight, .lightSide:
            return "Sisi terang karena langsung menghadap ke lampu."
        }
    }
    
    private func audioFileName(for concept: ShadowConcept) -> String? {
        switch concept {
        case .castShadow:
            return "level-3/marker/[marker] Bayangan gelap yang muncul di lantai karena cahaya terhalang.mp3"
        case .reflectedLight:
            return "level-3/marker/[marker] Cahaya pantulan dari lantai yang memantul kembali ke bola.mp3"
        case .coreShadow, .shadowSide, .terminator, .contactShadow:
            return "level-3/marker/[marker] Sisi gelap karena cahayanya tidak sampai ke sini.mp3"
        case .highlight, .lightSide:
            return "level-3/marker/[marker] Sisi terang karena langsung menghadap ke lampu.mp3"
        }
    }

    var shadowProgress: Int { min(visitedShadowSectors.count, 3) }

    func advanceOnboarding() {
        guard phase == .onboarding else { return }
        if onboardingIndex == Level3Content.onboardingDialog.count - 1 { phase = .placingScene } else { onboardingIndex += 1 }
        syncGuidePresentation()
    }

    func sceneDidPlace(at worldPosition: SIMD3<Float>) {
        sceneWorldPosition = worldPosition
        previousCameraPosition = nil
        
        // Langsung pindah ke dialog Bayo begitu benda ditaruh otomatis
        if phase == .placingScene || phase == .surfaceReady {
            phase = .onboarding
        }
        
        setupGuideCharacterIfNeeded()
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
        
        arSceneViewModel.placeSceneAtScreenCenter()
    }

    func sceneDidReset() {
        sceneWorldPosition = nil
        previousCameraPosition = nil
        visitedShadowSectors.removeAll()
        hasCompletedShadowTask = false
        shadowVisible = false
        isShadowInfoOpen = false
        guideNeedsPlacement = true
        guideRoot?.isEnabled = false
        guard phase != .onboarding && phase != .completed else { return }
        resumePhaseAfterPlacement = (phase == .placingScene || phase == .surfaceReady) ? nil : phase
        phase = .placingScene
    }

    func lightDidSelect() {}

    func advancePhaseOnTap() {
            // Kalau marker lagi kebuka, tap layar kosong HANYA untuk menutup marker
            if arSceneViewModel.selectedConcept != nil {
                arSceneViewModel.selectedConcept = nil
                return
            }

            // Jika layar benar-benar kosong, majukan fase/cerita
            switch phase {
            case .onboarding: advanceOnboarding()
            case .shadowExploration:
                if hasCompletedShadowTask { continueFromShadowTask() }
            case .shadowTrivia: advanceShadowTrivia()
            case .shadowTypesInteraction: advanceShadowTypes()
            case .shapeComparison:
                if hasComparedShapes { finishShapeComparison() }
            case .closing: advanceClosing()
            default: break
            }
        }
    
    func cameraDidUpdate(position: SIMD3<Float>) {
        // Logika tracker guide AR dari posisi kamera
        updateGuidePosition(cameraPosition: position)
        
        guard phase == .shadowExploration, !hasCompletedShadowTask, let center = sceneWorldPosition else { return }
        defer { previousCameraPosition = position }
        let offset = SIMD2<Float>(position.x - center.x, position.z - center.z)
        let radius = simd_length(offset)
        guard radius >= 0.3 && radius <= 3 else { return }
        let angle = atan2(offset.y, offset.x) + .pi
        let sector = Int(floor(angle / (2 * .pi) * 8)) % 8
        visitedShadowSectors.insert(sector)
        if visitedShadowSectors.count >= 3 {
            hasCompletedShadowTask = true
            successFeedbackTrigger += 1
            celebrate(title: "Tiga Bayangan Ditemukan!", detail: "Kamu berhasil mengamati bayangan dari beberapa sisi.")
        }
    }

    func continueFromShadowTask() { guard hasCompletedShadowTask else { return }; phase = .shadowTrivia; shadowTriviaIndex = 0; syncGuidePresentation() }
    
    func advanceShadowTrivia() {
        guard phase == .shadowTrivia else { return }
        if shadowTriviaIndex == Level3Content.shadowTrivia.count - 1 { phase = .shadowTypesInteraction; shadowTypesIndex = 0 } else { shadowTriviaIndex += 1 }
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

    func closeShadowInfo() {
        if isShadowInfoOpen {
            isShadowInfoOpen = false
            arSceneViewModel.showShadowInformation = false
        }
    }
    
    func advanceShadowTypes() {
        guard phase == .shadowTypesInteraction else { return }
        if shadowTypesIndex == Level3Content.shadowTypesTrivia.count - 1 { phase = .shapeComparison } else { shadowTypesIndex += 1 }
        syncGuidePresentation()
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
        guard phase == .shapeComparison, hasComparedShapes else { return }
        phase = .closing
        closingIndex = 0
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
        guard phase == .closing else { return }
        if closingIndex == Level3Content.closingDialog.count - 1 { phase = .review } else { closingIndex += 1 }
        syncGuidePresentation()
    }

    func finishReview() {
        guard phase == .review else { return }
        phase = .completed
        progressStore.markLevelCompleted(Level3Content.levelID)
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

        arSceneViewModel.objectDirectManipulationLocked = true
        arSceneViewModel.directManipulationRotatesOnly = true
        arSceneViewModel.interactionMode = .moveLight
        arSceneViewModel.lightDirectionFollowsGesture = true
        arSceneViewModel.autoPlaceOnSurfaceFound = true
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
    
    // MARK: - AR Guide Character Logic (Bayo)
    
    private func setupGuideCharacterIfNeeded() {
        guard guideRoot == nil else { return }
        let guide = Entity()
        guide.name = "Level 3 Guide — Bayo"
        guide.isEnabled = false
        let asset = currentGuideAsset
        if let character = CharacterGuideFactory.makeCharacter(asset: asset, width: 0.10, height: 0.14) {
            guide.addChild(character)
            guideCharacter = character
            guideCharacterAsset = asset
        }
        
        // Memasukkan guide ke dalam root entitas dari ARSceneViewModel
        arSceneViewModel.addEntityToScene(guide)
        guideRoot = guide
    }
    
    private func updateGuidePosition(cameraPosition: SIMD3<Float>) {
            guard let guide = guideRoot, let center = sceneWorldPosition else { return }
            
            // ⭐️ Jika marker sedang dipilih, kita bisa arahkan Bayo sedikit di depan objek/center
            if arSceneViewModel.selectedConcept != nil {
                let offsetDirection = cameraPosition - center
                let normalizedOffset = simd_normalize(SIMD3<Float>(offsetDirection.x, 0, offsetDirection.z))
                // Letakkan Bayo di dekat objek utama menghadap kamera
                var conceptDestination = center + normalizedOffset * 0.45
                conceptDestination.y = center.y + 0.075
                
                guide.position = conceptDestination
                guide.look(at: cameraPosition, from: guide.position, relativeTo: nil)
                guideCloud?.position = SIMD3<Float>(0.22, 0.14, 0)
                return
            }
            
            // Logika normal penempatan Bayo biasa...
            let horizontalForward = SIMD2<Float>(center.x - cameraPosition.x, center.z - cameraPosition.z)
            let length = simd_length(horizontalForward)
            guard length > 0.001 else { return }
            
            let forward = SIMD3<Float>(horizontalForward.x / length, 0, horizontalForward.y / length)
            let right = SIMD3<Float>(-forward.z, 0, forward.x)
            
            var destination = cameraPosition + forward * 0.60 + right * 0.28
            destination.y = center.y + 0.075
            
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
            
            // ⭐️ FIX: Jika ada marker yang dipilih (selectedConcept != nil), paksa Bayo muncul meskipun di fase lain!
            let isConceptActive = arSceneViewModel.selectedConcept != nil
            guide.isEnabled = (shouldShowGuide && !guideNeedsPlacement) || isConceptActive
            
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
            cloud.position = SIMD3<Float>(0.22, 0.14, 0)
            guide.addChild(cloud)
            guideCloud = cloud
        }
    
    private var shouldShowGuide: Bool {
        phase != .placingScene && phase != .completed
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
