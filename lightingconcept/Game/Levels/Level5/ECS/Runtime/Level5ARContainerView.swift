//
//  L.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 28/09/26.
//

import ARKit
import Combine
import RealityKit
import SwiftUI

struct Level5ARContainerView:
    UIViewRepresentable {

    let viewModel:
        Level5ViewModel

    func makeCoordinator()
        -> Coordinator {

        Coordinator(
            viewModel:
                viewModel
        )
    }

    func makeUIView(
        context: Context
    ) -> ARView {

        let arView =
            ARView(
                frame: .zero
            )

        context.coordinator
            .configure(
                arView:
                    arView
            )

        return arView
    }

    func updateUIView(
        _ uiView: ARView,
        context: Context
    ) {
        context.coordinator
            .requestSceneSynchronization()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        private let viewModel:
            Level5ViewModel

        private let arCoordinator:
            ARSceneCoordinator

        private weak var arView: ARView?

        private var guideAnchor: AnchorEntity?

        private var sceneUpdateSubscription:
            (any Cancellable)?

        private var sceneStateSubscription:
            AnyCancellable?

        private static let selectionHighlightName =
            "Level 5 Light Selection Highlight"

        private var highlightedLightID:
            UUID?

        init(
            viewModel:
                Level5ViewModel
        ) {

            self.viewModel =
                viewModel

            self.arCoordinator =
                ARSceneCoordinator(
                    viewModel:
                        viewModel
                            .arSceneViewModel,

                    gesturePolicy:
                        .placementOnly,

                    lessonECSMode:
                        .none,

                    telemetryDelegate:
                        viewModel
                )
            super.init()
        }

        func configure(
            arView:
                ARView
        ) {

            self.arView =
                arView

            arCoordinator
                .configure(
                    arView:
                        arView
                )

            let follow = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleDeviceFollow(_:))
            )
            follow.minimumPressDuration = 0.55
            follow.allowableMovement = 18
            follow.delegate = self
            arView.addGestureRecognizer(follow)

            let guideAnchor = AnchorEntity(world: .zero)
            guideAnchor.name = "Level 5 Guide Root Anchor"
            arView.scene.addAnchor(guideAnchor)
            self.guideAnchor = guideAnchor
            viewModel.attachGuideIfNeeded(to: guideAnchor)

            sceneStateSubscription = viewModel.arSceneViewModel.objectWillChange
                .sink { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.requestSceneSynchronization()
                    }
                }

            var lastGuideUpdateTimestamp: CFTimeInterval = 0
            sceneUpdateSubscription =
                arView.scene.subscribe(
                    to:
                        SceneEvents.Update.self
                ) { [weak self] _ in

                    guard let self else {
                        return
                    }

                    let now = CACurrentMediaTime()
                    guard now - lastGuideUpdateTimestamp >= (1.0 / 30.0) else { return }
                    lastGuideUpdateTimestamp = now
                    self.updateDeviceFollowCameraState(in: arView)
                    self.syncGuide(in: arView)
                }
        }

        @objc private func handleDeviceFollow(_ gesture: UILongPressGestureRecognizer) {
            guard let arView else { return }

            switch gesture.state {
            case .began:
                guard viewModel.beginDeviceFollow(),
                      let cameraTransform = arView.session.currentFrame?.camera.transform,
                      let lightEntity = selectedLightEntity(in: arView) else { return }

                let cameraPosition = Self.position(from: cameraTransform)
                lightEntity.components.set(Level6DeviceFollowComponent(
                    isActive: true,
                    startCameraWorldPosition: cameraPosition,
                    currentCameraWorldPosition: cameraPosition,
                    startLightLocalPosition: lightEntity.position,
                    minimumLocalPosition: SIMD3<Float>(-1.2, 0.18, -1.2),
                    maximumLocalPosition: SIMD3<Float>(1.2, 2.0, 1.2),
                    aimTargetLocalPosition: SIMD3<Float>(
                        0,
                        SceneObjectSystem.cubeSize * 0.85 / 2,
                        0
                    )
                ))
            case .ended, .cancelled, .failed:
                stopDeviceFollow(in: arView)
            default:
                break
            }
        }

        private func updateDeviceFollowCameraState(in arView: ARView) {
            guard viewModel.isDeviceFollowing,
                  let cameraTransform = arView.session.currentFrame?.camera.transform,
                  let lightEntity = selectedLightEntity(in: arView),
                  var follow = lightEntity.components[Level6DeviceFollowComponent.self],
                  follow.isActive else { return }

            follow.currentCameraWorldPosition = Self.position(from: cameraTransform)
            lightEntity.components.set(follow)
            if let configuration = lightEntity.components[SceneLightComponent.self]?.configuration {
                arCoordinator.refreshEducationalOverlays(using: configuration)
            }
        }

        private func stopDeviceFollow(in arView: ARView) {
            guard let lightEntity = selectedLightEntity(in: arView) else {
                viewModel.endDeviceFollow(configuration: nil)
                return
            }

            if var follow = lightEntity.components[Level6DeviceFollowComponent.self] {
                follow.isActive = false
                lightEntity.components.set(follow)
            }
            viewModel.endDeviceFollow(
                configuration: lightEntity.components[SceneLightComponent.self]?.configuration
            )
            arCoordinator.requestSceneSynchronization()
        }

        private func selectedLightEntity(in arView: ARView) -> Entity? {
            let selectedID = viewModel.arSceneViewModel.selectedLightID
            for anchor in arView.scene.anchors {
                if let light = SceneLightSystem.entityWithLightID(selectedID, in: anchor) {
                    return light
                }
            }
            return nil
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
            gestureRecognizer is UITapGestureRecognizer
                || otherGestureRecognizer is UITapGestureRecognizer
        }

        func requestSceneSynchronization() {

            arCoordinator
                .requestSceneSynchronization()

            if let arView {
                syncGuide(in: arView)
                updateSelectionHighlight(in: arView)
            }
        }

        private func updateSelectionHighlight(
            in arView: ARView
        ) {
            guard viewModel.phase == .exploration,
                  !viewModel.isLookAroundMode else {
                removeSelectionHighlights(in: arView)
                highlightedLightID = nil
                return
            }

            let selectedLightID =
                viewModel.arSceneViewModel.selectedLightID

            guard highlightedLightID != selectedLightID else {
                return
            }

            removeSelectionHighlights(in: arView)

            for anchor in arView.scene.anchors {
                guard let lightRoot =
                    SceneLightSystem.entityWithLightID(
                        selectedLightID,
                        in: anchor
                    ) else {
                    continue
                }

                let highlight =
                    Level6SelectionHighlight.makeEntity()
                highlight.name =
                    Self.selectionHighlightName
                highlight.components.set(
                    BillboardComponent()
                )
                lightRoot.addChild(highlight)
                highlightedLightID =
                    selectedLightID
                break
            }
        }

        private func removeSelectionHighlights(
            in arView: ARView
        ) {
            for anchor in arView.scene.anchors {
                removeSelectionHighlights(
                    from: anchor
                )
            }
        }

        private func removeSelectionHighlights(
            from entity: Entity
        ) {
            entity.children
                .first(where: {
                    $0.name ==
                        Self.selectionHighlightName
                })?
                .removeFromParent()

            for child in entity.children {
                removeSelectionHighlights(
                    from: child
                )
            }
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
}
