import Combine
import SwiftUI
import UIKit

@MainActor
final class Level6ViewModel: ObservableObject, ARSceneTelemetryDelegate {
    @Published private(set) var phase: Level6Phase = .placingScene
    @Published private(set) var firstLightID: UUID?
    @Published private(set) var secondLightID: UUID?
    @Published private(set) var firstColor: Level6LightColor = .yellow
    @Published private(set) var secondColor: Level6LightColor = .yellow
    @Published private(set) var firstShadowColor: Level6LightColor = .yellow
    @Published private(set) var secondShadowColor: Level6LightColor = .yellow
    @Published var showsColorPanel = false
    @Published var showsDrawingCamera = false
    @Published private(set) var frozenSceneImage: UIImage?
    @Published private(set) var drawingImage: UIImage?
    @Published private(set) var snapshotRequestID = UUID()
    @Published private(set) var guideOverlayScreenPosition: CGPoint?
    @Published private(set) var shadowMarkerScreenPosition: CGPoint?
    @Published private(set) var shadowExplanationScreenPosition: CGPoint?
    @Published private(set) var showsShadowExplanation = false
    @Published private(set) var positionGuidanceStep: Level6PositionGuidanceStep = .complete
    @Published private(set) var isLookAroundMode = false
    @Published private(set) var isDeviceFollowing = false
    @Published private(set) var isAdjustingIntensity = false
    @Published private(set) var isAdjustingHeight = false
    @Published private(set) var gestureTouchPoints: [CGPoint] = []

    private var planarGestureStartPosition: SIMD3<Float>?
    private var heightGestureStartPosition: SIMD3<Float>?
    private var spreadGestureStartAngle: Float?
    private var canModifyLight: Bool {
        let supportsFullLightControls = phase == .drawingChoice
            || (phase == .positionExploration && positionGuidanceStep == .complete)
        return supportsFullLightControls && !isLookAroundMode
    }

    private var minimumBeamAngle: Float { 24 }
    private var maximumBeamAngle: Float { 88 }

    private var minimumIntensity: Float { 450 }
    private var maximumIntensity: Float { 6_500 }

    private var spreadGestureStart: Float?
    private var intensityGestureStart: Float?
    private var heightGestureStart: Float?

    let sceneViewModel = ARSceneViewModel()

    init() {
        configureScene()
    }

    var currentIntroduction: Level6Dialog? {
        guard case let .introduction(index) = phase,
              Level6Content.introduction.indices.contains(index) else { return nil }
        return Level6Content.introduction[index]
    }

    var selectedColor: Level6LightColor {
        color(for: sceneViewModel.selectedLightID)
    }

    var topModeTitle: String {
        isLookAroundMode ? "Mode lihat-lihat" : "Kamu jadi cahaya!"
    }

    var canUseLightGestures: Bool {
        canModifyLight
    }

    var intensityPercentage: Int {
        let range = maximumIntensity - minimumIntensity
        return Int(((sceneViewModel.selectedLight.intensity - minimumIntensity) / range * 100).rounded())
    }

    var heightPercentage: Int {
        let minimumHeight: Float = 0.18
        let maximumHeight: Float = 2.0
        let height = sceneViewModel.selectedLight.position.y
        return Int(((height - minimumHeight) / (maximumHeight - minimumHeight) * 100).rounded())
    }

    var mixingResult: Level6LightColor {
        Level6ColorMixing.result(for: firstColor, and: secondColor)
    }

    var mixingExplanation: String {
        "Wah! \(firstColor.displayName.capitalized) dicampur \(secondColor.displayName) jadinya \(mixingResult.displayName)!"
    }

    func advanceIntroduction() {
        guard case let .introduction(index) = phase else { return }
        if index + 1 < Level6Content.introduction.count {
            phase = .introduction(index + 1)
        } else {
            phase = .selectingFirstLight
        }
    }

    func lightSelected(_ id: UUID) {
        switch phase {
        case .selectingFirstLight:
            sceneViewModel.selectedLightID = id
            firstLightID = id
            isLookAroundMode = false
            phase = .changingFirstColor
        case .selectingSecondLight:
            guard id != firstLightID else { return }
            sceneViewModel.selectedLightID = id
            secondLightID = id
            isLookAroundMode = false
            phase = .changingSecondColor
        case .colorExploration, .positionExploration, .drawingChoice:
            sceneViewModel.selectedLightID = id
            isLookAroundMode = false
        default:
            return
        }
        sceneViewModel.interactionMode = .moveLight
    }

    func openColorPanel() {
        guard phase == .changingFirstColor
                || phase == .changingSecondColor
                || ((phase == .colorExploration
                    || phase == .positionExploration
                    || phase == .drawingChoice)
                    && !isLookAroundMode) else { return }
        showsColorPanel = true
    }

    func closeColorPanel() {
        showsColorPanel = false
    }

    func chooseColor(_ color: Level6LightColor) {
        let selectedID = sceneViewModel.selectedLightID

        let selectedLightIsFirst = selectedID == firstLightID
        let selectedLightIsSecond = selectedID == secondLightID

        sceneViewModel.updateSelectedLight { light in
            light.color = color.color
        }

        // Setiap bayangan mengikuti warna lampu yang menghasilkannya.
        if selectedLightIsFirst {
            firstShadowColor = color
        } else if selectedLightIsSecond {
            secondShadowColor = color
        }

        if selectedLightIsFirst {
            firstColor = color
        } else if selectedLightIsSecond {
            secondColor = color
        }

        showsColorPanel = false

        switch phase {
        case .changingFirstColor:
            phase = .firstColorResult

        case .changingSecondColor:
            phase = .colorShadowPrompt

        default:
            break
        }
    }

    func askForSecondLight() {
        guard phase == .firstColorResult else { return }
        phase = .selectingSecondLight
    }

    func revealColorExplanation() {
        if phase == .colorShadowPrompt {
            phase = .colorShadowExplanation
        } else if showsPersistentShadowMarker {
            showsShadowExplanation = true
        }
    }

    func dismissShadowExplanation() {
        showsShadowExplanation = false
    }

    private var showsPersistentShadowMarker: Bool {
        switch phase {
        case .colorShadowExplanation,
             .colorExplorationIntro,
             .colorExploration,
             .positionExplorationIntro,
             .positionExploration,
             .drawingIntro,
             .drawingChoice:
            true
        default:
            false
        }
    }

    func beginColorExploration() {
        guard phase == .colorShadowExplanation else { return }
        phase = .colorExplorationIntro
    }

    func showColorExploration() {
        guard phase == .colorExplorationIntro else { return }
        phase = .colorExploration
        isLookAroundMode = false
    }

    func finishColorExploration() {
        guard phase == .colorExploration else { return }
        phase = .positionExplorationIntro
    }

    func beginPositionExploration() {
        guard phase == .positionExplorationIntro else { return }
        phase = .positionExploration
        positionGuidanceStep = .planarMovement
        // Eksplorasi posisi selalu dimulai dalam mode observasi. Pengguna harus
        // mengetuk salah satu lampu sebelum kontrol modifikasi diaktifkan.
        isLookAroundMode = true
        sceneViewModel.interactionMode = .moveLight
    }

    func advancePositionGuidance() {
        switch positionGuidanceStep {
        case .planarMovement:
            positionGuidanceStep = .height
        case .height:
            positionGuidanceStep = .overview
        case .overview:
            positionGuidanceStep = .complete
        case .complete:
            break
        }
    }

    func beginSpreadGesture() {
        guard canModifyLight else { return }

        spreadGestureStart =
            sceneViewModel.selectedLight.effectiveOuterAngleDegrees
    }

    func updateSpreadGesture(magnification: CGFloat) {
        guard canModifyLight else { return }

        let start = spreadGestureStart
            ?? sceneViewModel.selectedLight.effectiveOuterAngleDegrees

        let nextValue = clamped(
            start + (Float(magnification) - 1) * 90,
            minimumBeamAngle,
            maximumBeamAngle
        )

        sceneViewModel.updateSelectedLightTransient(
            beamOuterAngleDegrees: nextValue
        )
    }

    func endSpreadGesture() {
        spreadGestureStart = nil
        sceneViewModel.commitSelectedLightState()
    }

    func updateLightSpread(magnification: CGFloat) {
        guard canModifyLight else { return }
        let start = spreadGestureStartAngle ?? sceneViewModel.selectedLight.effectiveOuterAngleDegrees
        if spreadGestureStartAngle == nil {
            spreadGestureStartAngle = start
        }
        sceneViewModel.updateSelectedLight { light in
            light.beamOuterAngleDegrees = clamped(start * Float(magnification), 18, 92)
        }
    }

    func updateGestureTouchPoints(_ points: [CGPoint]) {
        if gestureTouchPoints != points {
            gestureTouchPoints = points
        }
    }

    func clearGestureTouchPoints() {
        if !gestureTouchPoints.isEmpty {
            gestureTouchPoints = []
        }
    }

    func beginHeightGesture() {
        guard canModifyLight else { return }
        heightGestureStart = sceneViewModel.selectedLight.position.y
        isAdjustingHeight = true
    }

    func updateHeightGesture(verticalTranslation: CGFloat) {
        guard canModifyLight else { return }
        let start = heightGestureStart ?? sceneViewModel.selectedLight.position.y
        var position = sceneViewModel.selectedLight.position
        position.y = clamped(
            start - Float(verticalTranslation) / 500,
            0.18,
            2.0
        )
        sceneViewModel.updateSelectedLightTransient(position: position)
    }

    func endHeightGesture() {
        heightGestureStart = nil
        isAdjustingHeight = false
        sceneViewModel.commitSelectedLightState()
    }

    func beginDeviceFollow() -> Bool {
        guard canModifyLight else { return false }
        isDeviceFollowing = true
        return true
    }

    func endDeviceFollow(configuration: LightConfiguration?) {
        if let configuration,
           configuration.id == sceneViewModel.selectedLightID {
            sceneViewModel.updateSelectedLight { light in
                light.position = configuration.position
                light.yawDegrees = configuration.yawDegrees
                light.pitchDegrees = configuration.pitchDegrees
            }
        }
        isDeviceFollowing = false
    }

    func beginIntensityGesture() {
        guard canModifyLight else { return }

        intensityGestureStart = sceneViewModel.selectedLight.intensity
        isAdjustingIntensity = true
    }

    func updateIntensityGesture(verticalTranslation: CGFloat) {
        guard canModifyLight else { return }

        let start = intensityGestureStart
            ?? sceneViewModel.selectedLight.intensity

        let nextValue = clamped(
            start - Float(verticalTranslation) * 18,
            minimumIntensity,
            maximumIntensity
        )

        sceneViewModel.updateSelectedLightTransient(
            intensity: nextValue
        )
    }

    func endIntensityGesture() {
        intensityGestureStart = nil
        isAdjustingIntensity = false
        sceneViewModel.commitSelectedLightState()
    }

    func enterLookAroundMode() {
        guard phase == .colorExploration
                || phase == .positionExploration
                || phase == .drawingChoice else { return }
        isLookAroundMode = true
        showsColorPanel = false
        planarGestureStartPosition = nil
        heightGestureStartPosition = nil
        spreadGestureStartAngle = nil
        spreadGestureStart = nil
        intensityGestureStart = nil
        heightGestureStart = nil
        isDeviceFollowing = false
    }

    func finishPositionExploration() {
        guard phase == .positionExploration else { return }
        isLookAroundMode = true
        phase = .drawingIntro
    }

    func beginDrawingChoice() {
        guard phase == .drawingIntro else { return }
        phase = .drawingChoice
    }

    func chooseSceneForDrawing() {
        guard phase == .drawingChoice else { return }
        showsShadowExplanation = false
        snapshotRequestID = UUID()
    }

    func receiveSceneSnapshot(_ image: UIImage?) {
        guard phase == .drawingChoice else { return }
        frozenSceneImage = image
        phase = .drawingOnPaper
    }

    func finishDrawingOnPaper() {
        guard phase == .drawingOnPaper else { return }
        phase = .photoPrompt
    }

    func openDrawingCamera() {
        guard phase == .photoPrompt else { return }
        showsDrawingCamera = true
    }

    func cancelDrawingCamera() {
        showsDrawingCamera = false
    }

    func receiveDrawingPhoto(_ image: UIImage) {
        showsDrawingCamera = false
        drawingImage = image
        phase = .photoComparison
    }

    func completeLevel() {
        guard phase == .photoComparison else { return }
        GameProgressStore.shared.unlockSandboxFromLevel6()
        phase = .completed
    }

    func sceneDidPlace(at worldPosition: SIMD3<Float>) {
        guard phase == .placingScene else { return }
        phase = .introduction(0)
    }

    func sceneDidReset() {
        phase = .placingScene
    }

    func cameraDidUpdate(position: SIMD3<Float>) {}

    func updateGuideOverlayScreenPosition(_ position: CGPoint?) {
        switch (guideOverlayScreenPosition, position) {
        case let (current?, next?) where hypot(current.x - next.x, current.y - next.y) < 3:
            return
        case (nil, nil):
            return
        default:
            guideOverlayScreenPosition = position
        }
    }

    func updateShadowExplanationScreenPosition(_ position: CGPoint?) {
        switch (shadowExplanationScreenPosition, position) {
        case let (current?, next?) where hypot(current.x - next.x, current.y - next.y) < 3:
            return
        case (nil, nil):
            return
        default:
            shadowExplanationScreenPosition = position
        }
    }

    func updateShadowMarkerScreenPosition(_ position: CGPoint?) {
        switch (shadowMarkerScreenPosition, position) {
        case let (current?, next?) where hypot(current.x - next.x, current.y - next.y) < 3:
            return
        case (nil, nil):
            return
        default:
            shadowMarkerScreenPosition = position
        }
    }

    func lightDidSelect() {
        lightSelected(sceneViewModel.selectedLightID)
    }

    func sceneDidReceiveWorldTap() {
        enterLookAroundMode()
    }

    func shadowConceptDidSelect(_ concept: ShadowConcept) {}

    func markerSurfaceToneDidChange(_ tone: EducationalMarkerStyle.SurfaceTone) {}

    func safetyWarningDidChange(_ warning: SafetyProximityWarning?) {
        sceneViewModel.updateSafetyWarning(warning)
    }

    private func configureScene() {
        sceneViewModel.requiresLiDARScanBeforePlacement = true
        sceneViewModel.usesLiDARSceneReconstruction = true
        sceneViewModel.usesLiDARPhysicsInteraction = true
        sceneViewModel.usesRealisticEnvironmentLighting = false

        sceneViewModel.showLightDirection = true
        sceneViewModel.showLightRays = true
        sceneViewModel.showGroundProjection = true
        sceneViewModel.showProjectionLines = false
        sceneViewModel.objectDirectManipulationLocked = true

        sceneViewModel.updateSelectedObject { object in
            object.type = .cube
            object.scale = 0.85
        }

        let cubeCenter = SIMD3<Float>(
            0,
            SceneObjectSystem.cubeSize * 0.85 / 2,
            0
        )

        let firstLightPosition = SIMD3<Float>(
            -0.24,
            0.34,
            0.28
        )

        sceneViewModel.updateSelectedLight { light in
            light.type = .spot
            light.color = Level6LightColor.yellow.color
            light.position = firstLightPosition
            light.intensity = 3_200
            light.beamOuterAngleDegrees = 54
            light.markerScale = 0.7

            if let angles = SceneLightSystem.aimingAngles(
                from: firstLightPosition,
                to: cubeCenter
            ) {
                light.yawDegrees = angles.yawDegrees
                light.pitchDegrees = angles.pitchDegrees
            }
        }

        let firstID = sceneViewModel.selectedLightID

        sceneViewModel.addLight()

        let secondLightPosition = SIMD3<Float>(
            0.24,
            0.34,
            0.28
        )

        sceneViewModel.updateSelectedLight { light in
            light.type = .spot
            light.color = Level6LightColor.yellow.color
            light.position = secondLightPosition
            light.intensity = 3_200
            light.beamOuterAngleDegrees = 54
            light.markerScale = 0.7

            if let angles = SceneLightSystem.aimingAngles(
                from: secondLightPosition,
                to: cubeCenter
            ) {
                light.yawDegrees = angles.yawDegrees
                light.pitchDegrees = angles.pitchDegrees
            }
        }

        sceneViewModel.selectedLightID = firstID
    }

    private static func aimAtObject(_ light: inout LightConfiguration) {
        let cubeCenter = SIMD3<Float>(0, SceneObjectSystem.cubeSize * 1.15 / 2, 0)
        guard let angles = SceneLightSystem.aimingAngles(
            from: light.position,
            to: cubeCenter
        ) else { return }
        light.yawDegrees = angles.yawDegrees
        light.pitchDegrees = angles.pitchDegrees
    }

    private func color(for lightID: UUID) -> Level6LightColor {
        if lightID == firstLightID { return firstColor }
        if lightID == secondLightID { return secondColor }
        return .yellow
    }
}
