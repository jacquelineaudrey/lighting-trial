import ARKit
import RealityKit
import SwiftUI
import Combine

struct Level4ARContainerView: UIViewRepresentable {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    @ObservedObject var viewModel: Level4ViewModel
    typealias Coordinator = Level4ARContainerCoordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneViewModel: sceneViewModel, viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.configure(arView: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.requestSceneSynchronization()
    }
}

@MainActor
final class Level4ARContainerCoordinator: NSObject, UIGestureRecognizerDelegate {
    private let viewModel: Level4ViewModel
    private let arCoordinator: ARSceneCoordinator
    private weak var arView: ARView?
    private var guideAnchor: AnchorEntity?
    private var sceneUpdateSubscription: (any Cancellable)?
    private var followStartCameraWorldPosition: SIMD3<Float>?
    private var followStartObjectWorldPosition: SIMD3<Float>?

    private static let selectionHighlightName = "Level 4 Selection Highlight"
    private var highlightedPhase: Level4Phase?
    private var highlightedEntityID: UUID?

    init(sceneViewModel: ARSceneViewModel, viewModel: Level4ViewModel) {
        self.viewModel = viewModel
        self.arCoordinator = ARSceneCoordinator(
            viewModel: sceneViewModel,
            gesturePolicy: .placementOnly,
            lessonECSMode: .level3ShadowPresentation,
            telemetryDelegate: viewModel
        )
        super.init()
    }

    func configure(arView: ARView) {
        self.arView = arView
        arCoordinator.configure(arView: arView)
        installObjectGestures(on: arView)
        let anchor = AnchorEntity(world: .zero)
        anchor.name = "Level 4 Guide Root Anchor"
        arView.scene.addAnchor(anchor)
        guideAnchor = anchor
        viewModel.attachGuideIfNeeded(to: anchor)

        var lastUpdate: CFTimeInterval = 0
        sceneUpdateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak arView] _ in
            guard let self, let arView else { return }
            let now = CACurrentMediaTime()
            guard now - lastUpdate >= (1.0 / 30.0) else { return }
            lastUpdate = now
            self.updateDeviceFollow(in: arView)
            self.syncGuide(in: arView)
        }
    }

    func requestSceneSynchronization() {
        arCoordinator.requestSceneSynchronization()
        if let arView {
            updateSelectionHighlight(in: arView)
        }
    }

    private func installObjectGestures(on arView: ARView) {
        let selectionTap = UITapGestureRecognizer(target: self, action: #selector(handleObjectSelection(_:)))
        selectionTap.delegate = self
        arView.addGestureRecognizer(selectionTap)

        let follow = UILongPressGestureRecognizer(target: self, action: #selector(handleDeviceFollow(_:)))
        follow.minimumPressDuration = 0.55
        follow.allowableMovement = 18
        follow.delegate = self
        arView.addGestureRecognizer(follow)
    }

    @objc private func handleObjectSelection(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended,
              viewModel.canSelectObject,
              let arView,
              let entity = arView.entity(at: gesture.location(in: arView)),
              let objectID = SceneObjectSystem.selectObject(containing: entity) else { return }
        viewModel.selectObject(objectID)
    }

    @objc private func handleDeviceFollow(_ gesture: UILongPressGestureRecognizer) {
        guard let arView else { return }

        switch gesture.state {
        case .began:
            guard let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
            switch viewModel.sceneViewModel.interactionMode {
            case .moveObject:
                guard let object = selectedObjectEntity(in: arView),
                      viewModel.beginDeviceFollow(at: gesture.location(in: arView)) else { return }
                followStartCameraWorldPosition = Self.position(from: cameraTransform)
                followStartObjectWorldPosition = object.position(relativeTo: nil)
            case .moveLight:
                guard let light = selectedLightEntity(in: arView),
                      viewModel.beginDeviceFollow(at: gesture.location(in: arView)) else { return }
                let cameraPosition = Self.position(from: cameraTransform)
                light.components.set(Level6DeviceFollowComponent(
                    isActive: true,
                    startCameraWorldPosition: cameraPosition,
                    currentCameraWorldPosition: cameraPosition,
                    startLightLocalPosition: light.position,
                    minimumLocalPosition: SIMD3<Float>(-1.2, 0.18, -1.2),
                    maximumLocalPosition: SIMD3<Float>(1.2, 2.0, 1.2),
                    aimTargetLocalPosition: SIMD3<Float>(
                        0,
                        SceneObjectSystem.cubeSize * 0.85 / 2,
                        0
                    )
                ))
            }
        case .changed:
            viewModel.updateDeviceFollowTouch(at: gesture.location(in: arView))
        case .ended, .cancelled, .failed:
            finishDeviceFollow(in: arView)
        default:
            break
        }
    }

    private func updateDeviceFollow(in arView: ARView) {
        guard viewModel.isDeviceFollowing,
              let cameraTransform = arView.session.currentFrame?.camera.transform else { return }

        switch viewModel.sceneViewModel.interactionMode {
        case .moveObject:
            guard let startCamera = followStartCameraWorldPosition,
                  let startObject = followStartObjectWorldPosition,
                  let object = selectedObjectEntity(in: arView),
                  let parent = object.parent else { return }
            let movement = Self.position(from: cameraTransform) - startCamera
            let targetWorld = SIMD3<Float>(
                startObject.x + movement.x,
                startObject.y,
                startObject.z + movement.z
            )
            var targetLocal = parent.convert(position: targetWorld, from: nil)
            targetLocal.x = min(max(targetLocal.x, -1.2), 1.2)
            targetLocal.z = min(max(targetLocal.z, -1.2), 1.2)
            object.position = targetLocal

        case .moveLight:
            guard let light = selectedLightEntity(in: arView),
                  var follow = light.components[Level6DeviceFollowComponent.self] else { return }
            follow.currentCameraWorldPosition = Self.position(from: cameraTransform)
            light.components.set(follow)
            if let configuration = light.components[SceneLightComponent.self]?.configuration {
                arCoordinator.refreshEducationalOverlays(using: configuration)
            }
        }
    }

    private func finishDeviceFollow(in arView: ARView) {
        switch viewModel.sceneViewModel.interactionMode {
        case .moveObject:
            viewModel.endObjectDeviceFollow(
                position: selectedObjectEntity(in: arView)?.position
            )
        case .moveLight:
            let light = selectedLightEntity(in: arView)
            if var follow = light?.components[Level6DeviceFollowComponent.self] {
                follow.isActive = false
                light?.components.set(follow)
            }
            viewModel.endLightDeviceFollow(
                configuration: light?.components[SceneLightComponent.self]?.configuration
            )
        }
        followStartCameraWorldPosition = nil
        followStartObjectWorldPosition = nil
        arCoordinator.requestSceneSynchronization()
    }

    private func selectedObjectEntity(in arView: ARView) -> Entity? {
        let id = viewModel.sceneViewModel.selectedObjectID
        for anchor in arView.scene.anchors {
            if let object = SceneObjectSystem.entityWithObjectID(id, in: anchor) {
                return object
            }
        }
        return nil
    }

    private func selectedLightEntity(in arView: ARView) -> Entity? {
        let id = viewModel.sceneViewModel.selectedLightID
        for anchor in arView.scene.anchors {
            if let light = SceneLightSystem.entityWithLightID(id, in: anchor) {
                return light
            }
        }
        return nil
    }

    private func updateSelectionHighlight(in arView: ARView) {
        let target: Entity?
        let targetID: UUID?
        let scale: Float
        switch viewModel.phase {
        case .selectingObject:
            target = selectedObjectEntity(in: arView)
            targetID = viewModel.sceneViewModel.selectedObjectID
            scale = 2.8
        case .selectingLight:
            target = selectedLightEntity(in: arView)
            targetID = viewModel.sceneViewModel.selectedLightID
            scale = 1
        default:
            guard highlightedPhase != nil else { return }
            for anchor in arView.scene.anchors {
                removeSelectionHighlights(from: anchor)
            }
            highlightedPhase = nil
            highlightedEntityID = nil
            return
        }

        guard highlightedPhase != viewModel.phase || highlightedEntityID != targetID,
              let target else { return }
        for anchor in arView.scene.anchors {
            removeSelectionHighlights(from: anchor)
        }
        let highlight = Level6SelectionHighlight.makeEntity()
        highlight.name = Self.selectionHighlightName
        highlight.components.set(BillboardComponent())
        highlight.scale = SIMD3<Float>(repeating: scale)
        if viewModel.phase == .selectingObject {
            highlight.position.y = SceneObjectSystem.cubeSize * 0.85 / 2
        }
        target.addChild(highlight)
        highlightedPhase = viewModel.phase
        highlightedEntityID = targetID
    }

    private func removeSelectionHighlights(from entity: Entity) {
        entity.children.first(where: { $0.name == Self.selectionHighlightName })?.removeFromParent()
        for child in entity.children {
            removeSelectionHighlights(from: child)
        }
    }

    private static func position(from transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer is UITapGestureRecognizer || otherGestureRecognizer is UITapGestureRecognizer
    }

    private func syncGuide(in arView: ARView) {
        guard let guideAnchor,
              let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
        viewModel.attachGuideIfNeeded(to: guideAnchor)
        let position = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let forward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        viewModel.updateGuide(cameraPosition: position, forward: forward)
        viewModel.updateGuideOverlayScreenPosition(viewModel.guideOverlayWorldPosition.flatMap(arView.project))
    }
}
