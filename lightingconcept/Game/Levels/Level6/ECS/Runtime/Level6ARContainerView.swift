import ARKit
import Combine
import RealityKit
import SwiftUI

struct Level6ARContainerView: UIViewRepresentable {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    @ObservedObject var viewModel: Level6ViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneViewModel: sceneViewModel, viewModel: viewModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.configure(arView: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.synchronize(snapshotRequestID: viewModel.snapshotRequestID)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let viewModel: Level6ViewModel
        private let arCoordinator: ARSceneCoordinator
        private weak var arView: ARView?
        private var lastSnapshotRequestID: UUID
        private var sceneUpdateSubscription: (any Cancellable)?
        private var activeVerticalControl: VerticalControl?
        private weak var shadowMarkerParent: Entity?
        private var shadowMarkerEntity: Entity?
        private var shadowIntersectionWorldPosition: SIMD3<Float>?
        private var hidesShadowMarkerForSnapshot = false

        private static let shadowMarkerName = "level6-shadow-marker"
        private static let shadowMarkerDashName = "level6-shadow-marker-connector-dash"

        init(sceneViewModel: ARSceneViewModel, viewModel: Level6ViewModel) {
            self.viewModel = viewModel
            self.arCoordinator = ARSceneCoordinator(
                viewModel: sceneViewModel,
                // Level 6 owns its movement gestures. Shared direct manipulation
                // stays disabled so lights cannot move during the color lesson.
                gesturePolicy: .placementOnly,
                telemetryDelegate: viewModel
            )
            self.lastSnapshotRequestID = viewModel.snapshotRequestID
            super.init()
        }

        func configure(arView: ARView) {
            self.arView = arView
            arCoordinator.configure(arView: arView)
            installLightGestures(on: arView)

            var lastFrameUpdateTimestamp: CFTimeInterval = 0
            sceneUpdateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak arView] _ in
                guard let self, let arView else { return }
                self.updateDeviceFollowCameraState(in: arView)
                self.applyTransientLightStateToECS(in: arView)

                let now = CACurrentMediaTime()
                guard now - lastFrameUpdateTimestamp >= (1.0 / 30.0) else { return }
                lastFrameUpdateTimestamp = now
                self.updateGuidePosition(in: arView, timestamp: now)
                self.updateShadowMarkerPosition(in: arView)
                self.refreshMovingLightRays(in: arView)
            }
        }

        func synchronize(snapshotRequestID: UUID) {
            arCoordinator.requestSceneSynchronization()
            if let arView {
                updateSelectionHighlight(in: arView)
            }
            guard snapshotRequestID != lastSnapshotRequestID else { return }
            lastSnapshotRequestID = snapshotRequestID
            hidesShadowMarkerForSnapshot = true
            removeShadowMarker()
            captureSnapshot()
        }

        private func updateGuidePosition(in arView: ARView, timestamp: CFTimeInterval) {
            guard let transform = arView.session.currentFrame?.camera.transform else { return }
            let cameraPosition = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let forward = -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
            let right = SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)
            let up = SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
            let bob = Float(sin(timestamp * 2.2)) * 0.025
            let worldPosition = cameraPosition + forward * 0.9 + right * 0.34 + up * (-0.08 + bob)
            viewModel.updateGuideOverlayScreenPosition(arView.project(worldPosition))
        }

        private func refreshMovingLightRays(in arView: ARView) {
            guard viewModel.isDeviceFollowing,
                  let light = selectedLightEntity(in: arView),
                  let configuration = light.components[SceneLightComponent.self]?.configuration else { return }
            arCoordinator.refreshEducationalOverlays(using: configuration)
        }

        private func updateShadowMarkerPosition(in arView: ARView) {
            guard shouldShowShadowMarker,
                  !hidesShadowMarkerForSnapshot,
                  let firstLightID = viewModel.firstLightID,
                  let secondLightID = viewModel.secondLightID,
                  let firstLight = lightEntity(with: firstLightID, in: arView),
                  let secondLight = lightEntity(with: secondLightID, in: arView),
                  let object = selectedObjectEntity(in: arView),
                  let anchor = object.parent else {
                removeShadowMarker()
                viewModel.updateShadowMarkerScreenPosition(nil)
                return
            }

            if shadowIntersectionWorldPosition == nil {
                shadowIntersectionWorldPosition = Self.shadowIntersectionWorldPosition(
                    firstLightPosition: firstLight.position(relativeTo: nil),
                    secondLightPosition: secondLight.position(relativeTo: nil),
                    objectBounds: object.visualBounds(relativeTo: nil),
                    groundY: anchor.position(relativeTo: nil).y + 0.018
                )
            }
            guard let shadowPosition = shadowIntersectionWorldPosition else {
                removeShadowMarker()
                viewModel.updateShadowMarkerScreenPosition(nil)
                return
            }

            let markerOffset = simd_normalize(SIMD3<Float>(-1, 1, 1)) * 0.40
            let markerPosition = shadowPosition + markerOffset
            let marker = ensureShadowMarker(parent: anchor)
            marker.position = anchor.convert(position: markerPosition, from: nil)

            let shadowLocalPosition = anchor.convert(position: shadowPosition, from: nil)
            updateShadowMarkerDashes(
                in: marker,
                targetOffset: shadowLocalPosition - marker.position
            )
            viewModel.updateShadowMarkerScreenPosition(arView.project(markerPosition))
            viewModel.updateShadowExplanationScreenPosition(
                arView.project(markerPosition + SIMD3<Float>(0.18, 0.08, 0.12))
            )
        }

        private var shouldShowShadowMarker: Bool {
            switch viewModel.phase {
            case .colorShadowPrompt,
                 .colorShadowExplanation,
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

        private func ensureShadowMarker(parent: Entity) -> Entity {
            if let shadowMarkerEntity, shadowMarkerParent === parent {
                return shadowMarkerEntity
            }

            removeShadowMarker()

            let markerTint = EducationalMarkerStyle.palette(for: .medium).primary
            let marker = Entity()
            marker.name = Self.shadowMarkerName
            marker.components.set(CollisionComponent(shapes: [
                .generateSphere(radius: EducationalMarkerStyle.ringTapTargetRadius)
            ]))
            marker.components.set(InputTargetComponent())

            let dot = ModelEntity(
                mesh: .generateSphere(radius: EducationalMarkerStyle.dotRadius),
                materials: [UnlitMaterial(color: markerTint)]
            )
            dot.name = "\(Self.shadowMarkerName)-center"
            dot.components.set(DynamicLightShadowComponent(castsShadow: false))
            marker.addChild(dot)

            let ring = ModelEntity(
                mesh: .generatePlane(
                    width: EducationalMarkerStyle.ringDiameter,
                    height: EducationalMarkerStyle.ringDiameter
                ),
                materials: [EducationalMarkerStyle.ringMaterial(alpha: 1, tint: markerTint)]
            )
            ring.name = "\(Self.shadowMarkerName)-ring"
            ring.components.set(BillboardComponent())
            ring.components.set(DynamicLightShadowComponent(castsShadow: false))
            ring.components.set(PulseAnimationComponent(
                baseScale: 1,
                speed: 3.8,
                amplitude: 0.45,
                isActiveTarget: true
            ))
            marker.addChild(ring)

            let dashMaterial = UnlitMaterial(
                color: markerTint.withAlphaComponent(0.9)
            )
            for _ in 0..<7 {
                let dash = ModelEntity(
                    mesh: .generateSphere(radius: 0.0032),
                    materials: [dashMaterial]
                )
                dash.name = Self.shadowMarkerDashName
                dash.components.set(DynamicLightShadowComponent(castsShadow: false))
                marker.addChild(dash)
            }

            parent.addChild(marker)
            shadowMarkerParent = parent
            shadowMarkerEntity = marker
            return marker
        }

        private func updateShadowMarkerDashes(
            in marker: Entity,
            targetOffset: SIMD3<Float>
        ) {
            let fractions: [Float] = [0.14, 0.26, 0.38, 0.50, 0.62, 0.74, 0.86]
            let dashes = marker.children.filter { $0.name == Self.shadowMarkerDashName }
            for (dash, fraction) in zip(dashes, fractions) {
                dash.position = targetOffset * fraction
            }
        }

        private func removeShadowMarker() {
            shadowMarkerEntity?.removeFromParent()
            shadowMarkerEntity = nil
            shadowMarkerParent = nil
        }

        private func updateSelectionHighlight(in arView: ARView) {
            for anchor in arView.scene.anchors {
                removeSelectionHighlights(from: anchor)
            }

            let showsHighlight = switch viewModel.phase {
            case .changingFirstColor, .changingSecondColor:
                true
            case .colorExploration, .positionExploration:
                !viewModel.isLookAroundMode
            default:
                false
            }
            guard showsHighlight else { return }

            for anchor in arView.scene.anchors {
                guard let lightRoot = SceneLightSystem.entityWithLightID(
                    viewModel.sceneViewModel.selectedLightID,
                    in: anchor
                ) else { continue }
                lightRoot.addChild(Level6SelectionHighlight.makeEntity())
                break
            }
        }

        private func removeSelectionHighlights(from entity: Entity) {
            entity.children.first(where: { $0.name == Level6SelectionHighlight.entityName })?.removeFromParent()
            for child in entity.children {
                removeSelectionHighlights(from: child)
            }
        }

        private enum VerticalControl {
            case intensity
            case height
        }

        private func installLightGestures(on arView: ARView) {
            let shadowMarkerTap = UITapGestureRecognizer(
                target: self,
                action: #selector(handleShadowMarkerTap(_:))
            )
            shadowMarkerTap.delegate = self
            arView.addGestureRecognizer(shadowMarkerTap)

            let verticalPan = UIPanGestureRecognizer(target: self, action: #selector(handleVerticalPan(_:)))
            verticalPan.minimumNumberOfTouches = 1
            verticalPan.maximumNumberOfTouches = 1
            verticalPan.delegate = self
            arView.addGestureRecognizer(verticalPan)

            let spread = UIPinchGestureRecognizer(target: self, action: #selector(handleSpread(_:)))
            spread.delegate = self
            arView.addGestureRecognizer(spread)

            let follow = UILongPressGestureRecognizer(target: self, action: #selector(handleDeviceFollow(_:)))
            follow.minimumPressDuration = 0.55
            follow.allowableMovement = 18
            follow.delegate = self
            arView.addGestureRecognizer(follow)

        }

        @objc private func handleShadowMarkerTap(_ gesture: UITapGestureRecognizer) {
            guard shouldShowShadowMarker, let arView else { return }
            let location = gesture.location(in: arView)
            guard let hitEntity = arView.entity(at: location) else {
                viewModel.enterLookAroundMode()
                return
            }

            var candidate: Entity? = hitEntity
            while let entity = candidate {
                if entity.name.hasPrefix(Self.shadowMarkerName) {
                    viewModel.revealColorExplanation()
                    return
                }
                candidate = entity.parent
            }

            // Lampu ditangani recognizer utama ARSceneCoordinator. Objek juga
            // tidak mengubah mode. Entity lain dan permukaan berarti observasi.
            if SceneLightSystem.selectLight(containing: hitEntity) != nil
                || SceneObjectSystem.selectObject(containing: hitEntity) != nil {
                return
            }
            viewModel.enterLookAroundMode()
        }

        @objc private func handleVerticalPan(_ gesture: UIPanGestureRecognizer) {
            guard let arView else { return }

            switch gesture.state {
            case .began:
                viewModel.updateGestureTouchPoints([gesture.location(in: arView)])
                activeVerticalControl = gesture.location(in: arView).x <= arView.bounds.width * 0.24
                    ? .intensity
                    : .height
                if activeVerticalControl == .intensity {
                    viewModel.beginIntensityGesture()
                } else {
                    viewModel.beginHeightGesture()
                }
            case .changed:
                viewModel.updateGestureTouchPoints([gesture.location(in: arView)])
                let verticalTranslation = gesture.translation(in: arView).y
                if activeVerticalControl == .intensity {
                    viewModel.updateIntensityGesture(verticalTranslation: verticalTranslation)
                } else {
                    viewModel.updateHeightGesture(verticalTranslation: verticalTranslation)
                }
                applyTransientLightStateToECS(in: arView)
                arCoordinator.requestSceneSynchronization()
            case .ended, .cancelled, .failed:
                if activeVerticalControl == .intensity {
                    viewModel.endIntensityGesture()
                } else if activeVerticalControl == .height {
                    viewModel.endHeightGesture()
                }
                activeVerticalControl = nil
                viewModel.clearGestureTouchPoints()
                selectedLightEntity(in: arView)?.components.remove(
                    Level6LightControlComponent.self
                )
                arCoordinator.requestSceneSynchronization()
            default:
                break
            }
        }

        @objc private func handleSpread(_ gesture: UIPinchGestureRecognizer) {
            guard let arView else { return }
            switch gesture.state {
            case .began:
                updatePinchTouchPoints(from: gesture, in: arView)
                viewModel.beginSpreadGesture()
            case .changed:
                updatePinchTouchPoints(from: gesture, in: arView)
                viewModel.updateSpreadGesture(magnification: gesture.scale)
                applyTransientLightStateToECS(in: arView)
                arCoordinator.requestSceneSynchronization()
            case .ended, .cancelled, .failed:
                viewModel.endSpreadGesture()
                viewModel.clearGestureTouchPoints()
                selectedLightEntity(in: arView)?.components.remove(
                    Level6LightControlComponent.self
                )
                arCoordinator.requestSceneSynchronization()
            default:
                break
            }
        }

        @objc private func handleDeviceFollow(_ gesture: UILongPressGestureRecognizer) {
            guard let arView else { return }

            switch gesture.state {
            case .began:
                viewModel.updateGestureTouchPoints([gesture.location(in: arView)])
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
            case .changed:
                viewModel.updateGestureTouchPoints([gesture.location(in: arView)])
            case .ended, .cancelled, .failed:
                viewModel.clearGestureTouchPoints()
                stopDeviceFollow(in: arView)
            default:
                break
            }
        }

        private func updatePinchTouchPoints(
            from gesture: UIPinchGestureRecognizer,
            in arView: ARView
        ) {
            guard gesture.numberOfTouches >= 2 else { return }
            viewModel.updateGestureTouchPoints([
                gesture.location(ofTouch: 0, in: arView),
                gesture.location(ofTouch: 1, in: arView)
            ])
        }

        private func applyTransientLightStateToECS(in arView: ARView) {
            guard viewModel.sceneViewModel.hasTransientLight,
                  let lightEntity = selectedLightEntity(in: arView) else { return }
            let light = viewModel.sceneViewModel.selectedLight
            let control = Level6LightControlComponent(
                intensity: light.intensity,
                outerAngleInDegrees: light.effectiveOuterAngleDegrees,
                localPosition: light.position,
                aimTargetLocalPosition: SIMD3<Float>(
                    0,
                    SceneObjectSystem.cubeSize * 0.85 / 2,
                    0
                )
            )
            if lightEntity.components[Level6LightControlComponent.self] != control {
                lightEntity.components.set(control)
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
            lightEntity(
                with: viewModel.sceneViewModel.selectedLightID,
                in: arView
            )
        }

        private func lightEntity(with id: UUID, in arView: ARView) -> Entity? {
            for anchor in arView.scene.anchors {
                if let light = SceneLightSystem.entityWithLightID(id, in: anchor) {
                    return light
                }
            }
            return nil
        }

        private func selectedObjectEntity(in arView: ARView) -> Entity? {
            let selectedID = viewModel.sceneViewModel.selectedObjectID
            for anchor in arView.scene.anchors {
                if let object = SceneObjectSystem.entityWithObjectID(selectedID, in: anchor) {
                    return object
                }
            }
            return nil
        }

        private static func shadowIntersectionWorldPosition(
            firstLightPosition: SIMD3<Float>,
            secondLightPosition: SIMD3<Float>,
            objectBounds: BoundingBox,
            groundY: Float
        ) -> SIMD3<Float>? {
            let objectCorners = [objectBounds.min.x, objectBounds.max.x].flatMap { x in
                [objectBounds.min.y, objectBounds.max.y].flatMap { y in
                    [objectBounds.min.z, objectBounds.max.z].map { z in
                        SIMD3<Float>(x, y, z)
                    }
                }
            }

            func footprint(from lightPosition: SIMD3<Float>) -> [SIMD2<Float>] {
                let points = objectCorners.compactMap {
                    ShadowGeometryCalculator.projectPointFromLight(
                        lightPosition: lightPosition,
                        objectPoint: $0,
                        planeY: groundY
                    )
                }
                return convexHull(points.map { SIMD2<Float>($0.x, $0.z) })
            }

            let firstShadow = footprint(from: firstLightPosition)
            let secondShadow = footprint(from: secondLightPosition)
            let overlap = intersectConvexPolygons(firstShadow, secondShadow)
            guard let center = polygonCentroid(overlap) else { return nil }

            let objectCenter = SIMD2<Float>(objectBounds.center.x, objectBounds.center.z)
            let objectMinimum = SIMD2<Float>(objectBounds.min.x, objectBounds.min.z)
            let objectMaximum = SIMD2<Float>(objectBounds.max.x, objectBounds.max.z)
            let visibleCandidates = overlap.map { vertex in
                // Pull the vertex slightly toward the overlap center so the
                // target remains strictly inside both shadow polygons.
                vertex * 0.86 + center * 0.14
            }.filter { point in
                let padding: Float = 0.018
                return point.x < objectMinimum.x - padding
                    || point.x > objectMaximum.x + padding
                    || point.y < objectMinimum.y - padding
                    || point.y > objectMaximum.y + padding
            }

            // The overlap centroid can lie beneath the cube. Aim at the exposed
            // portion of the shared shadow instead, while staying inside both
            // projected footprints.
            let target = visibleCandidates.max {
                simd_distance_squared($0, objectCenter)
                    < simd_distance_squared($1, objectCenter)
            } ?? center
            return SIMD3<Float>(target.x, groundY + 0.006, target.y)
        }

        private static func convexHull(_ points: [SIMD2<Float>]) -> [SIMD2<Float>] {
            let sorted = points.sorted {
                $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x
            }
            guard sorted.count > 2 else { return sorted }

            func cross(
                _ origin: SIMD2<Float>,
                _ first: SIMD2<Float>,
                _ second: SIMD2<Float>
            ) -> Float {
                let a = first - origin
                let b = second - origin
                return a.x * b.y - a.y * b.x
            }

            var lower: [SIMD2<Float>] = []
            for point in sorted {
                while lower.count >= 2,
                      cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 {
                    lower.removeLast()
                }
                lower.append(point)
            }

            var upper: [SIMD2<Float>] = []
            for point in sorted.reversed() {
                while upper.count >= 2,
                      cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 {
                    upper.removeLast()
                }
                upper.append(point)
            }

            lower.removeLast()
            upper.removeLast()
            return lower + upper
        }

        private static func intersectConvexPolygons(
            _ subject: [SIMD2<Float>],
            _ clip: [SIMD2<Float>]
        ) -> [SIMD2<Float>] {
            guard subject.count >= 3, clip.count >= 3 else { return [] }
            var output = subject

            for index in clip.indices {
                let edgeStart = clip[index]
                let edgeEnd = clip[(index + 1) % clip.count]
                let input = output
                output.removeAll(keepingCapacity: true)
                guard var previous = input.last else { return [] }

                for current in input {
                    let currentIsInside = isInside(
                        current,
                        edgeStart: edgeStart,
                        edgeEnd: edgeEnd
                    )
                    let previousIsInside = isInside(
                        previous,
                        edgeStart: edgeStart,
                        edgeEnd: edgeEnd
                    )

                    if currentIsInside {
                        if !previousIsInside,
                           let intersection = lineIntersection(
                            previous,
                            current,
                            edgeStart,
                            edgeEnd
                           ) {
                            output.append(intersection)
                        }
                        output.append(current)
                    } else if previousIsInside,
                              let intersection = lineIntersection(
                                previous,
                                current,
                                edgeStart,
                                edgeEnd
                              ) {
                        output.append(intersection)
                    }
                    previous = current
                }
            }
            return output
        }

        private static func isInside(
            _ point: SIMD2<Float>,
            edgeStart: SIMD2<Float>,
            edgeEnd: SIMD2<Float>
        ) -> Bool {
            let edge = edgeEnd - edgeStart
            let relativePoint = point - edgeStart
            return edge.x * relativePoint.y - edge.y * relativePoint.x >= -0.00001
        }

        private static func lineIntersection(
            _ firstStart: SIMD2<Float>,
            _ firstEnd: SIMD2<Float>,
            _ secondStart: SIMD2<Float>,
            _ secondEnd: SIMD2<Float>
        ) -> SIMD2<Float>? {
            let firstDirection = firstEnd - firstStart
            let secondDirection = secondEnd - secondStart
            let denominator = firstDirection.x * secondDirection.y
                - firstDirection.y * secondDirection.x
            guard abs(denominator) > 0.00001 else { return nil }

            let offset = secondStart - firstStart
            let distance = (
                offset.x * secondDirection.y
                    - offset.y * secondDirection.x
            ) / denominator
            return firstStart + firstDirection * distance
        }

        private static func polygonCentroid(
            _ polygon: [SIMD2<Float>]
        ) -> SIMD2<Float>? {
            guard !polygon.isEmpty else { return nil }
            guard polygon.count >= 3 else {
                return polygon.reduce(.zero, +) / Float(polygon.count)
            }

            var signedArea: Float = 0
            var weightedCenter = SIMD2<Float>.zero
            for index in polygon.indices {
                let current = polygon[index]
                let next = polygon[(index + 1) % polygon.count]
                let cross = current.x * next.y - next.x * current.y
                signedArea += cross
                weightedCenter += (current + next) * cross
            }

            guard abs(signedArea) > 0.00001 else {
                return polygon.reduce(.zero, +) / Float(polygon.count)
            }
            return weightedCenter / (3 * signedArea)
        }

        private static func position(from transform: simd_float4x4) -> SIMD3<Float> {
            SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UITapGestureRecognizer {
                return shouldShowShadowMarker
            }

            guard viewModel.canUseLightGestures, let arView else { return false }
            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let horizontalPosition = pan.location(in: arView).x / max(arView.bounds.width, 1)
                return horizontalPosition <= 0.24 || horizontalPosition >= 0.76
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            if gestureRecognizer is UITapGestureRecognizer
                || otherGestureRecognizer is UITapGestureRecognizer {
                return true
            }
            return gestureRecognizer is UIPinchGestureRecognizer
                || otherGestureRecognizer is UIPinchGestureRecognizer
        }

        private func captureSnapshot() {
            guard let arView else {
                viewModel.receiveSceneSnapshot(nil)
                return
            }
            arView.snapshot(saveToHDR: false) { [weak self] image in
                Task { @MainActor in
                    self?.viewModel.receiveSceneSnapshot(image)
                }
            }
        }
    }
}
