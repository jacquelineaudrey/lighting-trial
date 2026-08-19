import Foundation
import ARKit
import RealityKit
import UIKit
import Photos

/// Selects optional lesson-specific ECS bridges without making the shared
/// sandbox ViewModel aware of a particular learning level.
enum LessonECSMode {
    case none
    case level2LightControl
    case level3ShadowPresentation
}

@MainActor
/// Tanggung jawab file:
/// - menghubungkan SwiftUI state (`ARSceneViewModel`) dengan RealityKit/ARKit scene,
/// - mengatur placement object, light, gesture, LiDAR, receiver shadow, dan overlay edukasi,
/// - memanggil renderer/calculator lain saat data scene berubah.
///
/// Detail rumus cahaya dan bayangan ada di `ProjectionLineRenderer`dan `ShadowGeometryCalculator`.
final class ARSceneCoordinator: NSObject, ARSessionDelegate, ARCoachingOverlayViewDelegate {
    private let viewModel: ARSceneViewModel
    private let gesturePolicy: ARSceneGesturePolicy
    private let lessonECSMode: LessonECSMode
    private weak var telemetryDelegate: (any ARSceneTelemetryDelegate)?
    private weak var arView: ARView?
    private var coachingOverlay: ARCoachingOverlayView?

    private var sceneAnchor: AnchorEntity?
    private var lastTexture: MaterialTexture?

    private let projectionRenderer = ProjectionLineRenderer()
    private let annotationManager = ShadowAnnotationManager()
    private let markerSurfaceToneEstimator = EducationalMarkerSurfaceToneEstimator()
    private let receiverManager = ShadowReceiverManager()
    private let lidarMeshOcclusionManager = LiDARMeshOcclusionManager()
    private static let lidarLightRadius: Float = 0.045
    private static let lidarClearance: Float = 0.006
    /// Nama stabil untuk anchor tempat scene (object + light) ditempel, supaya
    /// bisa dicari dari luar coordinator (lihat `ARViewHandle` di Level 4)
    /// tanpa perlu referensi langsung ke `ARSceneCoordinator`.
    static let sceneAnchorName = "ARSceneCoordinator.sceneAnchor"
    private var usesSceneReconstruction = false

    private var isSynchronizationScheduled = false
    private var lastSceneSignature: SceneUpdateSignature?
    private var lastOverlaySignature: SceneOverlayUpdateSignature?
    private var lastShadowInfoSignature: ShadowInfoUpdateSignature?
    private var lastResetSceneFlag = false
    private var lastRescanFlag = false
    private var lastFrozenFlag = false
    private var lastCaptureFlag = false
    private var lastPlaceSceneAtCenterFlag = false
    private var defaultObjectPosition = SIMD3<Float>(0, 0, 0)
    private var verticalLightPanStartHeight: Float?
    private var lastAppliedObjectYawDegrees: Float?
    private weak var selectedConceptEntity: Entity?
    private var hasLoggedLiDARMeshOcclusion = false
    nonisolated(unsafe) private var lastDispatchedCameraTelemetryTimestamp: TimeInterval = 0

    init(
        viewModel: ARSceneViewModel,
        gesturePolicy: ARSceneGesturePolicy = .full,
        lessonECSMode: LessonECSMode = .none,
        telemetryDelegate: (any ARSceneTelemetryDelegate)? = nil
    ) {
        self.viewModel = viewModel
        self.gesturePolicy = gesturePolicy
        self.lessonECSMode = lessonECSMode
        self.telemetryDelegate = telemetryDelegate
    }

    func configure(arView: ARView) {
        self.arView = arView
        arView.automaticallyConfigureSession = false
        arView.environment.lighting.intensityExponent = 0
        arView.renderOptions.insert(.disableMotionBlur)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disablePersonOcclusion)
        if viewModel.usesLiDARSceneReconstruction {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            arView.environment.sceneUnderstanding.options.insert(.collision)
            arView.environment.sceneUnderstanding.options.insert(.receivesLighting)
            arView.environment.sceneUnderstanding.options.insert(.physics)
        }

        arView.session.delegate = self
        addCoachingOverlay(to: arView)
        addGestures(to: arView)
        runSession(resetTracking: true)
        viewModel.debugLog("AR session start")
    }

    func requestSceneSynchronization() {
        guard !isSynchronizationScheduled else { return }
        isSynchronizationScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isSynchronizationScheduled = false
            self.synchronizeScene()
        }
    }

    func synchronizeScene() {
        guard arView != nil else { return }

        if lastResetSceneFlag != viewModel.pendingResetScene {
            lastResetSceneFlag = viewModel.pendingResetScene
            resetScene()
        }

        if lastRescanFlag != viewModel.pendingRescanSurface {
            lastRescanFlag = viewModel.pendingRescanSurface
            rescanSurface()
        }

        if lastFrozenFlag != viewModel.isViewFrozen {
            lastFrozenFlag = viewModel.isViewFrozen
            setSessionPaused(viewModel.isViewFrozen)
        }

        if lastCaptureFlag != viewModel.pendingCaptureSnapshot {
            lastCaptureFlag = viewModel.pendingCaptureSnapshot
            captureAndSaveSnapshot()
        }

        if lastPlaceSceneAtCenterFlag != viewModel.pendingPlaceSceneAtCenter {
            lastPlaceSceneAtCenterFlag = viewModel.pendingPlaceSceneAtCenter
            placeSceneAtScreenCenter()
        }

        guard sceneAnchor != nil else { return }

        let sceneSignature = currentSceneSignature()
        if sceneSignature != lastSceneSignature {
            syncObjects()
            syncLights()
            receiverManager.updateSurfaceTexture(viewModel.selectedTexture)
            lastSceneSignature = currentSceneSignature()
        }

        let overlaySignature = currentOverlaySignature()
        if overlaySignature != lastOverlaySignature {
            updateEducationalOverlays()
            lastOverlaySignature = overlaySignature
        }

        let shadowInfoSignature = currentShadowInfoSignature()
        if shadowInfoSignature != lastShadowInfoSignature {
            updateShadowInfo()
            lastShadowInfoSignature = shadowInfoSignature
        }

        synchronizeLessonECS()
    }

    private func addCoachingOverlay(to arView: ARView) {
        let overlay = ARCoachingOverlayView()
        overlay.session = arView.session
        overlay.goal = .horizontalPlane
        overlay.activatesAutomatically = true
        overlay.delegate = self
        overlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: arView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])
        coachingOverlay = overlay
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        resetScene()
        if viewModel.isViewFrozen {
            viewModel.isViewFrozen = false
            lastFrozenFlag = false
        }
        viewModel.surfaceState = .scanning
        runSession(resetTracking: true)
        viewModel.debugLog("Coaching overlay requested a full session reset")
    }

    /// Dipanggil ARKit begitu overlay scan permukaan non-aktif (permukaan
    /// datar sudah ketemu). Untuk mode sandbox biasa ini dibiarkan saja
    /// (anak/user tap layar sendiri buat menaruh object, lewat `handleTap`).
    /// Untuk Level 4 (`viewModel.autoPlaceOnSurfaceFound == true`) kita taruh
    /// scene otomatis di sini — sama seperti `Level1ARCoordinator` menaruh
    /// jalur checkpoint otomatis begitu overlay non-aktif — supaya anak tidak
    /// perlu tahu harus tap layar dulu.
    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        guard viewModel.autoPlaceOnSurfaceFound, sceneAnchor == nil, let arView else { return }
        placeSceneAutomatically(in: arView)
    }
    
    private func placeSceneAutomatically(in arView: ARView) {
        // 1. Coba raycast dari tengah layar ke permukaan yang sudah terdeteksi.
        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        if let result = raycastPlane(from: center) {
            placeScene(at: result.worldTransform)
            return
        }
        
        // 2. Fallback: taruh di depan kamera, estimasi tinggi lantai dari posisi kamera
        // (pola yang sama dipakai `Level1ARCoordinator` saat ARKit belum sempat
        // memberi plane anchor yang valid).
        let cameraTransform = arView.cameraTransform.matrix
        let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let forward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        let flatForward = SIMD3<Float>(forward.x, 0, forward.z)
        let normalizedForward = simd_length(flatForward) > 0.0001 ? flatForward / simd_length(flatForward) : SIMD3<Float>(0, 0, -1)
        let placementPosition = cameraPosition + normalizedForward * 0.6
        var fallbackTransform = matrix_identity_float4x4
        fallbackTransform.columns.3 = SIMD4<Float>(placementPosition.x, cameraPosition.y - 1.2, placementPosition.z, 1)
        placeScene(at: fallbackTransform)
    }

    private func placeSceneAtScreenCenter() {
        guard sceneAnchor == nil, let arView else { return }

        guard viewModel.isReadyForPlacement else {
            viewModel.placementFeedback = "Lanjutkan scan permukaan dulu sebelum menaruh benda."
            viewModel.debugLog("Center placement blocked until LiDAR scan reaches target coverage")
            return
        }

        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        guard let result = raycastPlane(from: center) else {
            viewModel.placementFeedback = "Arahkan titik tengah layar ke meja atau lantai dulu."
            viewModel.debugLog("Center placement failed: no horizontal surface at screen center")
            return
        }

        placeScene(at: result.worldTransform)
    }
    
    private func addGestures(to arView: ARView) {
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))

        guard gesturePolicy == .full else { return }

        let horizontalPan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        horizontalPan.minimumNumberOfTouches = 1
        horizontalPan.maximumNumberOfTouches = 1
        arView.addGestureRecognizer(horizontalPan)

        let verticalPan = UIPanGestureRecognizer(target: self, action: #selector(handleVerticalLightPan(_:)))
        verticalPan.minimumNumberOfTouches = 2
        verticalPan.maximumNumberOfTouches = 2
        arView.addGestureRecognizer(verticalPan)
    }

    private func runSession(resetTracking: Bool) {
        guard let arView else { return }
        guard ARWorldTrackingConfiguration.isSupported else {
            viewModel.debugLog("ARWorldTrackingConfiguration is not supported on this device")
            return
        }

        // Konfigurasi utama AR:
        // - horizontal plane untuk meja/lantai
        // - environment texturing + light estimation agar object lebih menyatu dengan kamera
        //   (photoreal PBR look) — TAPI ini yang bikin cube di Level 4 kelihatan seperti
        //   "benda sungguhan" alih-alih cube AR yang polos & jelas seperti di Level 1.
        //   Jadi ini cuma dinyalakan kalau `usesRealisticEnvironmentLighting == true`
        //   (default true, dipakai mode sandbox `ContentView`). Level 4 mematikannya
        //   lewat `Level4ViewModel.init` supaya cube-nya tetap flat/game-like.
        // - LiDAR mesh reconstruction hanya jika device mendukung
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        if viewModel.usesRealisticEnvironmentLighting {
            configuration.environmentTexturing = .automatic
            configuration.isLightEstimationEnabled = true
        } else {
            configuration.environmentTexturing = .none
            configuration.isLightEstimationEnabled = false
        }
        if viewModel.usesLiDARSceneReconstruction,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
            viewModel.debugLog("LiDAR smoothed scene depth enabled")
        }
        if viewModel.usesLiDARSceneReconstruction,
           ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            // Classification data (wall/floor/table/etc) isn't read anywhere in this
            // codebase, only the raw mesh geometry is needed for occlusion. Plain
            // `.mesh` skips ARKit's per-frame classification pass — matches Level1's
            // lighter config and meaningfully reduces thermal load on LiDAR devices.
            configuration.sceneReconstruction = .mesh
            usesSceneReconstruction = true
            publishLiDARAvailability(true, resetScanProgress: true)
            // Mesh cyan hanya feedback scan untuk user. Occlusion visual tetap memakai
            // sceneUnderstanding bawaan RealityKit, bukan mesh occluder custom.
            lidarMeshOcclusionManager.setVisualizationEnabled(true)
            viewModel.debugLog("LiDAR scene reconstruction enabled; real-world mesh occlusion active")
        } else {
            usesSceneReconstruction = false
            publishLiDARAvailability(false, resetScanProgress: false)
            viewModel.debugLog("LiDAR scene reconstruction unavailable; using flat fallback receiver")
        }

        let options: ARSession.RunOptions = resetTracking ? [.resetTracking, .removeExistingAnchors] : []
        arView.session.run(configuration, options: options)
    }

    /// `runSession` dapat dipanggil dari lifecycle `UIViewRepresentable`.
    /// Tunda perubahan `@Published` satu runloop agar SwiftUI tidak menerima
    /// publish saat sedang menjalankan `updateUIView`.
    private func publishLiDARAvailability(_ isAvailable: Bool, resetScanProgress: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.viewModel.isLiDARAvailable = isAvailable
            if resetScanProgress {
                self.viewModel.resetLiDARScan()
            }
        }
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }
        let location = gesture.location(in: arView)

        // Label edukasi adalah entity 3D. Saat diketuk, SwiftUI menampilkan alert penjelasan.
        if let entity = annotationEntity(at: location, in: arView) {
            let conceptName = entity.name.replacingOccurrences(of: "Label: ", with: "")
            if let concept = ShadowConcept.allCases.first(where: { $0.rawValue == conceptName }),
               viewModel.isShadowConceptSelectionEnabled,
               !viewModel.hiddenShadowConcepts.contains(concept) {
                selectedConceptEntity = entity
                viewModel.selectedConceptTapLocation = location
                if viewModel.selectedConcept == concept {
                    viewModel.selectedConcept = nil
                    selectedConceptEntity = nil
                } else {
                    viewModel.selectedConcept = concept
                }
                syncConceptSelection()
                if viewModel.selectedConcept == concept {
                    telemetryDelegate?.shadowConceptDidSelect(concept)
                }
                return
            }
        }

        if let entity = arView.entity(at: location),
           selectLight(containing: entity) {
            viewModel.interactionMode = .moveLight
            telemetryDelegate?.lightDidSelect()
            synchronizeScene()
            return
        }

        if !viewModel.objectDirectManipulationLocked,
           let entity = arView.entity(at: location),
           selectObject(containing: entity) {
            viewModel.interactionMode = .moveObject
            synchronizeScene()
            return
        }

        guard let result = raycastPlane(from: location) else {
            telemetryDelegate?.sceneDidReceiveWorldTap()
            syncConceptSelection()
            return
        }

        if sceneAnchor == nil {
            // Di device LiDAR, placement ditahan sampai coverage scan cukup agar posisi awal
            // object dan receiver tidak terlalu meleset dari meja/lantai yang sebenarnya.
            guard viewModel.isReadyForPlacement else {
                viewModel.debugLog("Object placement blocked until LiDAR scan reaches target coverage")
                return
            }
            placeScene(at: result.worldTransform)
        } else if viewModel.interactionMode == .moveObject,
                  !viewModel.directManipulationRotatesOnly {
            moveObject(to: result)
        } else {
            telemetryDelegate?.sceneDidReceiveWorldTap()
            syncConceptSelection()
        }
    }

    /// Selaraskan tampilan marker dengan pilihan saat ini: marker terpilih
    /// memakai warna status berbeda, dan posisi world-nya
    /// dipublikasikan agar Bayo bisa terbang mendekat. Dipanggil setiap kali
    /// pilihan bisa berubah (tap marker atau tap dunia untuk menutup).
    private func syncConceptSelection() {
        annotationManager.setSelected(viewModel.selectedConcept)
        if viewModel.selectedConcept != nil, let entity = selectedConceptEntity {
            viewModel.selectedConceptWorldPosition = entity.position(relativeTo: nil)
        } else {
            selectedConceptEntity = nil
            viewModel.selectedConceptWorldPosition = nil
        }
    }

    /// A marker can overlap the lesson object in screen space. `entity(at:)`
    /// returns only one (often the object), so inspect all collision hits and
    /// deliberately prefer an educational marker.
    private func annotationEntity(at location: CGPoint, in arView: ARView) -> Entity? {
        arView.hitTest(location, query: .all, mask: .all)
            .map(\.entity)
            .first { $0.name.hasPrefix("Label: ") }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let arView else { return }

        // Level 4 membedakan dua jenis input dengan tegas: perpindahan posisi
        // datang dari tombol tahan (lihat Level4ViewModel.updateHold), sementara
        // drag langsung hanya mengubah arah. Dengan guard ini, drag tidak pernah
        // lolos ke moveObject/moveSelectedLight saat mode Level 4 aktif.
        if viewModel.directManipulationRotatesOnly {
            rotateSelection(from: gesture, in: arView)
            return
        }

        let location = gesture.location(in: arView)
        guard let result = raycastPlane(from: location) else { return }

        switch viewModel.interactionMode {
        case .moveObject:
            moveObject(to: result, logWhenMoved: gesture.state == .ended)
        case .moveLight:
            moveSelectedLight(to: result, logWhenMoved: gesture.state == .ended)
        }
    }

    @objc private func handleVerticalLightPan(_ gesture: UIPanGestureRecognizer) {
        guard let arView, viewModel.interactionMode == .moveLight else { return }

        if viewModel.directManipulationRotatesOnly {
            rotateSelection(from: gesture, in: arView)
            return
        }

        switch gesture.state {
        case .began:
            verticalLightPanStartHeight = viewModel.selectedLight.position.y
        case .changed:
            guard let startHeight = verticalLightPanStartHeight else { return }
            let translation = gesture.translation(in: arView)
            // Dragging upward raises the light; 500 points spans one metre.
            let height = clamped(startHeight - Float(translation.y) / 500, -0.2, 2.0)
            viewModel.updateSelectedLight { $0.position.y = height }
            synchronizeScene()
        case .ended, .cancelled, .failed:
            verticalLightPanStartHeight = nil
        default:
            break
        }
    }

    /// Kontrol arah untuk Level 4. Satu sapuan jari memutar object di sumbu Y;
    /// untuk lampu, sapuan horizontal mengubah yaw dan sapuan vertikal mengubah
    /// pitch. Tidak ada posisi yang disentuh di fungsi ini.
    private func rotateSelection(from gesture: UIPanGestureRecognizer, in arView: ARView) {
        guard gesture.state == .changed else { return }
        let translation = gesture.translation(in: arView)
        gesture.setTranslation(.zero, in: arView)

        // RealityKit memakai local -Z sebagai arah maju: yaw positif justru
        // mengarahkan sorot ke kiri pada layar. Level 2 memilih mapping yang
        // natural: geser kanan = sorot kanan.
        let yawSensitivity: Float = viewModel.lightDirectionFollowsGesture ? -0.35 : 0.35
        let yawDelta = Float(translation.x) * yawSensitivity
        switch viewModel.interactionMode {
        case .moveObject:
            viewModel.updateSelectedObject { object in
                object.yawDegrees += yawDelta
            }
        case .moveLight:
            let pitchDelta = Float(-translation.y) * 0.25
            viewModel.updateSelectedLight { light in
                light.yawDegrees += yawDelta
                // Batas ini menjaga lampu tetap mengarah ke permukaan, bukan
                // berputar melewati atas atau tepat sejajar dengan lantai.
                light.pitchDegrees = clamped(light.pitchDegrees + pitchDelta, -85, -5)
            }
        }

        synchronizeScene()
    }

    private func raycastPlane(from point: CGPoint) -> ARRaycastResult? {
        guard let arView else { return nil }

        // Utamakan bidang horizontal yang sudah benar-benar terdeteksi.
        // Estimated plane hanya fallback supaya app tetap bisa dipakai saat scanning awal.
        if let measuredPlane = arView.raycast(
            from: point,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        ).first {
            return measuredPlane
        }

        return arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal).first
    }

    private func placeScene(at worldTransform: simd_float4x4) {
        guard let arView else { return }
        let anchor = AnchorEntity(world: worldTransform)
        // Nama stabil supaya `ARViewHandle` (dipakai Level 4's hold-to-walk)
        // bisa menemukan anchor scene ini lewat `Scene.findEntity(named:)`
        // tanpa perlu ARSceneCoordinator membocorkan referensi internalnya.
        anchor.name = Self.sceneAnchorName
        arView.scene.addAnchor(anchor)
        sceneAnchor = anchor
        defaultObjectPosition = .zero
        lidarMeshOcclusionManager.setVisualizationEnabled(false)

        // Receiver invisible inilah yang menangkap dynamic shadow.
        // Kamera asli tidak bisa langsung menerima shadow karena hanya video background.
        receiverManager.setupReceiver(
            on: anchor,
            usesFlatFallback: !usesSceneReconstruction,
            surfaceTexture: viewModel.selectedTexture
        )
        projectionRenderer.attach(to: anchor)
        annotationManager.attach(to: anchor)
        syncObjects()
        syncLights()
        // Placement can be initiated directly from an AR tap, before a later
        // SwiftUI render pass reaches `synchronizeScene()`. Build the learning
        // overlays now so Level 3's white explanation markers are immediately
        // available during the first shadow-search challenge.
        updateEducationalOverlays()
        updateShadowInfo()
        synchronizeLessonECS()
        lastSceneSignature = currentSceneSignature()
        lastOverlaySignature = currentOverlaySignature()
        lastShadowInfoSignature = currentShadowInfoSignature()

        viewModel.surfaceState = .placed
        viewModel.placementFeedback = nil
        viewModel.isObjectPlaced = true
        let worldPosition = SIMD3<Float>(
            worldTransform.columns.3.x,
            worldTransform.columns.3.y,
            worldTransform.columns.3.z
        )
        telemetryDelegate?.sceneDidPlace(at: worldPosition)
        viewModel.debugLog("Object placement completed on selected surface")
    }

    private func moveObject(to result: ARRaycastResult, logWhenMoved: Bool = false) {
        let selectedObject = viewModel.selectedObject
        guard let anchor = sceneAnchor,
              let objectEntity = objectEntity(id: selectedObject.id) else { return }
        let worldPosition = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        var localPosition = anchor.convert(position: worldPosition, from: nil)
        localPosition.y = 0

        let height = SceneObjectSystem.objectHeight(for: selectedObject) * selectedObject.scale
        let centerOffset = SIMD3<Float>(0, height / 2, 0)
        let virtualResolution = CollisionSystem.resolvedPosition(
            in: anchor,
            candidatePosition: localPosition + centerOffset,
            movingRadius: SceneObjectSystem.collisionRadius(for: selectedObject),
            excludingID: selectedObject.id
        )
        localPosition = virtualResolution.position - centerOffset
        localPosition.y = 0

        let lidarResolution = resolvedObjectPosition(
            object: selectedObject,
            from: selectedObject.position,
            to: localPosition,
            relativeTo: anchor
        )
        viewModel.updateObjectPosition(id: selectedObject.id, position: lidarResolution.position)
        let updatedObject = viewModel.selectedObject
        if lidarResolution.didCollide {
            viewModel.collisionWarning = "Object stopped by a scanned real-world surface."
        } else if virtualResolution.didCollide {
            viewModel.collisionWarning = "Object stopped by another virtual object."
        } else {
            viewModel.collisionWarning = nil
        }
        SceneObjectSystem.applyTransform(to: objectEntity, configuration: updatedObject)
        updateEducationalOverlays()
        updateShadowInfo()
        lastSceneSignature = currentSceneSignature()
        lastOverlaySignature = currentOverlaySignature()
        lastShadowInfoSignature = currentShadowInfoSignature()
        if logWhenMoved {
            viewModel.debugLog("Object moved")
        }
    }

    private func moveSelectedLight(to result: ARRaycastResult, logWhenMoved: Bool = false) {
        guard let anchor = sceneAnchor else { return }
        let worldPosition = SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        var localPosition = anchor.convert(position: worldPosition, from: nil)
        localPosition.x = clamped(localPosition.x, -0.9, 0.9)
        localPosition.z = clamped(localPosition.z, -0.9, 0.9)

        // Drag satu jari hanya mengubah X/Z. Height dikontrol slider atau two-finger pan
        // supaya light tidak tiba-tiba naik/turun saat user menggeser marker.
        let selectedID = viewModel.selectedLightID
        let currentPosition = viewModel.selectedLight.position
        localPosition.y = currentPosition.y
        let resolution = CollisionSystem.resolvedPosition(
            in: anchor,
            candidatePosition: localPosition,
            movingRadius: SceneLightSystem.lightObstacleRadius,
            excludingID: selectedID
        )
        localPosition = resolution.position
        let collisionWarning: String?
        if resolution.didCollide {
            collisionWarning = "Light stopped by another virtual object."
        } else {
            collisionWarning = nil
        }

        viewModel.updateSelectedLight { light in
            light.position.x = clamped(localPosition.x, -0.9, 0.9)
            light.position.z = clamped(localPosition.z, -0.9, 0.9)
        }
        synchronizeScene()
        viewModel.collisionWarning = collisionWarning
        if logWhenMoved {
            viewModel.debugLog("Selected light moved")
        }
    }

    private func syncObjects() {
        guard let anchor = sceneAnchor else { return }
        SceneObjectSystem.synchronize(
            anchor: anchor,
            requestedObjects: viewModel.objects,
            selectedTexture: viewModel.selectedTexture,
            lastTexture: &lastTexture,
            reportImportedDimensions: { [weak self] id, dimensions in
                self?.viewModel.updateImportedModelDimensions(id: id, dimensions: dimensions)
                self?.lastSceneSignature = nil
                self?.lastOverlaySignature = nil
                self?.lastShadowInfoSignature = nil
            },
            reportModelLoadFailure: { [weak self] name, error in
                self?.viewModel.reportModelLoadFailure(named: name, error: error)
            },
            debugLog: viewModel.debugLog
        )
    }

    private func syncLights() {
        guard let anchor = sceneAnchor else { return }
        viewModel.collisionWarning = SceneLightSystem.synchronize(
            anchor: anchor,
            requestedLights: viewModel.lights,
            selectedLightID: viewModel.selectedLightID,
            updateLightPosition: viewModel.updateLightPosition,
            debugLog: viewModel.debugLog
        )
    }

    /// Bridges MVVM state into level-owned ECS components. The systems apply the
    /// render-side behavior, while this coordinator only writes component data
    /// when SwiftUI asks for a scene synchronization.
    private func synchronizeLessonECS() {
        guard let anchor = sceneAnchor else { return }

        switch lessonECSMode {
        case .none:
            break
        case .level2LightControl:
            if let light = SceneLightSystem.entityWithLightID(viewModel.selectedLightID, in: anchor) {
                let configuration = viewModel.selectedLight
                light.components.set(Level2LightControlComponent(
                    intensity: configuration.intensity,
                    outerAngleInDegrees: configuration.effectiveOuterAngleDegrees,
                    isEnabled: configuration.type == .spot
                ))
            }
            if let object = SceneObjectSystem.entityWithObjectID(viewModel.selectedObjectID, in: anchor) {
                object.components.set(Level3ShadowPresentationComponent(
                    castsShadow: viewModel.showGroundProjection
                ))
            }
        case .level3ShadowPresentation:
            guard let object = SceneObjectSystem.entityWithObjectID(viewModel.selectedObjectID, in: anchor) else { return }
            object.components.set(Level3ShadowPresentationComponent(
                castsShadow: viewModel.showGroundProjection
            ))
        }
    }

    private func resolvedObjectPosition(
        object: ObjectConfiguration,
        from currentGroundPosition: SIMD3<Float>,
        to candidateGroundPosition: SIMD3<Float>,
        relativeTo anchor: Entity
    ) -> (position: SIMD3<Float>, didCollide: Bool) {
        let dimensions = SceneObjectSystem.baseDimensions(for: object) * object.scale
        let height = dimensions.y
        let clearance = Self.lidarClearance
        let centerOffset = SIMD3<Float>(0, height / 2 + clearance, 0)
        let shape: ShapeResource

        if object.importedModel != nil {
            shape = .generateBox(size: SIMD3<Float>(
                max(dimensions.x - clearance * 2, 0.001),
                max(height - clearance * 2, 0.001),
                max(dimensions.z - clearance * 2, 0.001)
            ))
        } else if object.type == .sphere {
            shape = .generateSphere(radius: max(height / 2 - clearance, 0.001))
        } else {
            shape = .generateBox(size: SIMD3<Float>(
                max(dimensions.x - clearance * 2, 0.001),
                max(height - clearance * 2, 0.001),
                max(dimensions.z - clearance * 2, 0.001)
            ))
        }

        let orientation = simd_quatf(
            angle: object.yawDegrees.degreesToRadians,
            axis: SIMD3<Float>(0, 1, 0)
        )
        let resolution = resolvedLiDARPosition(
            from: currentGroundPosition + centerOffset,
            to: candidateGroundPosition + centerOffset,
            shape: shape,
            orientation: orientation,
            relativeTo: anchor,
            ignoringSupportBelow: clearance * 4
        )
        return (resolution.position - centerOffset, resolution.didCollide)
    }

    private func resolvedLiDARPosition(
        from currentPosition: SIMD3<Float>,
        to candidatePosition: SIMD3<Float>,
        shape: ShapeResource,
        orientation: simd_quatf,
        relativeTo anchor: Entity,
        ignoringSupportBelow supportSurfaceMaximumHeight: Float? = nil
    ) -> (position: SIMD3<Float>, didCollide: Bool) {
        guard usesSceneReconstruction, let arView else {
            return (candidatePosition, false)
        }

        var remainingTravel = candidatePosition - currentPosition
        guard simd_length(remainingTravel) > 0.0001 else {
            return (candidatePosition, false)
        }

        var resolvedPosition = currentPosition
        var didCollide = false

        // Resolve once toward the requested point, then once more along the
        // contact plane. This prevents tunnelling while still allowing a drag
        // to glide naturally beside a wall or piece of scanned furniture.
        for _ in 0..<2 {
            let travelDistance = simd_length(remainingTravel)
            guard travelDistance > 0.0001 else { break }

            let direction = remainingTravel / travelDistance
            let destination = resolvedPosition + remainingTravel
            let hits = arView.scene.convexCast(
                convexShape: shape,
                fromPosition: resolvedPosition,
                fromOrientation: orientation,
                toPosition: destination,
                toOrientation: orientation,
                query: .all,
                mask: .sceneUnderstanding,
                relativeTo: anchor
            )
            let blockingHit = hits
                .filter { hit in
                    if let supportSurfaceMaximumHeight,
                       hit.normal.y > 0.65,
                       hit.position.y <= supportSurfaceMaximumHeight {
                        return false
                    }

                    // LiDAR meshes can fluctuate slightly around the current
                    // location. A zero-distance hit must not trap an entity
                    // that is moving out of the reconstructed surface.
                    return hit.distance > Self.lidarClearance
                        || simd_dot(direction, hit.normal) <= 0.05
                }
                .min { $0.distance < $1.distance }

            guard let hit = blockingHit else {
                resolvedPosition = destination
                break
            }

            didCollide = true
            let safeDistance = max(0, min(travelDistance, hit.distance - Self.lidarClearance))
            resolvedPosition += direction * safeDistance

            let unusedTravel = destination - resolvedPosition
            let travelIntoSurface = simd_dot(unusedTravel, hit.normal)
            guard travelIntoSurface < 0 else {
                resolvedPosition = destination
                break
            }

            resolvedPosition += hit.normal * Self.lidarClearance
            remainingTravel = unusedTravel - hit.normal * travelIntoSurface
        }

        return (resolvedPosition, didCollide)
    }

    private func updateEducationalOverlays() {
        guard let anchor = sceneAnchor,
              let objectEntity = objectEntity(id: viewModel.selectedObjectID) else { return }
        let selectedObject = viewModel.selectedObject
        let objectHeight = scaledObjectHeight
        let selectedLight = viewModel.selectedLight
        let anchorTransform = anchor.transformMatrix(relativeTo: nil)
        let worldToAnchorTransform = simd_inverse(anchorTransform)
        let localLightDirection = SceneLightSystem.forwardVector(
            yawDegrees: selectedLight.yawDegrees,
            pitchDegrees: selectedLight.pitchDegrees
        )
        let localLightOrientation = SceneLightSystem.orientation(
            yawDegrees: selectedLight.yawDegrees,
            pitchDegrees: selectedLight.pitchDegrees
        )
        let lightDirection = transformVector(localLightDirection, by: anchorTransform)
        let lightRight = transformVector(localLightOrientation.act(SIMD3<Float>(1, 0, 0)), by: anchorTransform)
        let lightUp = transformVector(localLightOrientation.act(SIMD3<Float>(0, 1, 0)), by: anchorTransform)
        let lightPosition = anchor.convert(position: selectedLight.position, to: nil)
        let groundY = anchorTransform.columns.3.y
        // Overlay memakai transform object dan orientasi light aktual; tidak ikut membuat shadow.
        projectionRenderer.update(
            object: selectedObject,
            objectDimensions: SceneObjectSystem.baseDimensions(for: selectedObject),
            objectTransform: objectEntity.transformMatrix(relativeTo: nil),
            lightPosition: lightPosition,
            selectedLight: selectedLight,
            lightDirection: lightDirection,
            lightRight: lightRight,
            lightUp: lightUp,
            groundY: groundY,
            worldToRenderTransform: worldToAnchorTransform,
            toggles: OverlayToggles(
                showLightDirection: viewModel.showLightDirection,
                showLightRays: viewModel.showLightRays,
                showProjectionLines: viewModel.showProjectionLines,
                showGroundProjection: viewModel.showGroundProjection
            ),
            surfaceIntersection: surfaceIntersectionProvider()
        )
        annotationManager.update(
            visible: viewModel.showShadowLabels,
            objectType: viewModel.selectedObjectType,
            objectPosition: objectGroundPosition,
            objectHeight: objectHeight,
            // `lightDirection` di atas sudah ditransformasi lewat
            // `anchorTransform` (world space), bukan local space lampu —
            // ini yang membuat titik "castShadow" akhirnya sinkron dengan
            // bayangan asli yang dirender, termasuk saat anchor scene
            // punya rotasi (kasus Level 4).
            worldLightDirection: lightDirection,
            hiddenConcepts: viewModel.hiddenShadowConcepts
        )
    }

    private func updateShadowInfo() {
        guard let anchor = sceneAnchor,
              objectEntity(id: viewModel.selectedObjectID) != nil else { return }

        let light = viewModel.selectedLight
        let objectHeight = scaledObjectHeight

        // Sama seperti `updateEducationalOverlays`: arah cahaya harus
        // ditransformasi lewat anchor transform ke world space dulu, bukan
        // dipakai langsung sebagai local direction, supaya info panel ini
        // tetap sinkron dengan bayangan asli saat anchor scene punya rotasi
        // non-identity (mis. Level 4 yang menempatkan scene otomatis dari
        // hasil raycast).
        let localLightDirection = SceneLightSystem.forwardVector(
            yawDegrees: light.yawDegrees,
            pitchDegrees: light.pitchDegrees
        )
        let anchorTransform = anchor.transformMatrix(relativeTo: nil)
        let lightDirection = transformVector(localLightDirection, by: anchorTransform)
        
        let nextInfo = ShadowInfo(
            lightType: light.type.rawValue,
            intensity: light.intensity,
            lightHeight: light.position.y,
            yawDegrees: light.yawDegrees,
            pitchDegrees: light.pitchDegrees,
            beamSpread: light.beamOuterAngleDegrees == nil
                ? light.beamSpread.rawValue
                : "Custom",
            shadowDirectionDegrees: ShadowGeometryCalculator.shadowDirectionDegrees(
                lightDirection: lightDirection
            ),
            shadowLength: ShadowGeometryCalculator.approximateShadowLength(
                lightDirection: lightDirection,
                objectHeight: objectHeight
            )
        )
        
        if viewModel.shadowInfo != nextInfo {
            viewModel.shadowInfo = nextInfo
        }
    }

    private var objectGroundPosition: SIMD3<Float> {
        viewModel.selectedObject.position
    }

    private func resetObjectPosition() {
        viewModel.updateSelectedObject { $0.position = .zero }
        let selectedObject = viewModel.selectedObject
        if let objectEntity = objectEntity(id: selectedObject.id) {
            SceneObjectSystem.applyTransform(to: objectEntity, configuration: selectedObject)
        }
        updateEducationalOverlays()
        updateShadowInfo()
        lastSceneSignature = currentSceneSignature()
        lastOverlaySignature = currentOverlaySignature()
        lastShadowInfoSignature = currentShadowInfoSignature()
        viewModel.debugLog("Object position reset")
    }


    private func resetScene() {
        if let anchor = sceneAnchor {
            anchor.removeFromParent()
        }
        sceneAnchor = nil
        lastTexture = nil
        telemetryDelegate?.sceneDidReset()
        receiverManager.reset()
        projectionRenderer.clear()
        annotationManager.clear()
        lastSceneSignature = nil
        lastOverlaySignature = nil
        lastShadowInfoSignature = nil
        viewModel.isObjectPlaced = false
        viewModel.surfaceState = .found
        viewModel.debugLog("Scene reset")
    }

    private func rescanSurface() {
        lidarMeshOcclusionManager.reset()
        hasLoggedLiDARMeshOcclusion = false
        viewModel.resetLiDARScan()
        resetScene()
        if viewModel.isViewFrozen {
            viewModel.isViewFrozen = false
            lastFrozenFlag = false
        }
        viewModel.surfaceState = .scanning
        runSession(resetTracking: true)
        coachingOverlay?.setActive(true, animated: true)
        viewModel.debugLog("Surface rescan requested")
    }

    /// Freezing pauses the ARSession so the camera feed stops updating, leaving the
    /// last rendered frame on screen (including the placed virtual object and shadows).
    /// Resuming simply restarts the session without resetting tracking/anchors.
    private func setSessionPaused(_ paused: Bool) {
        guard let arView else { return }
        if paused {
            arView.session.pause()
            viewModel.debugLog("AR session paused (view frozen)")
        } else {
            runSession(resetTracking: false)
            viewModel.debugLog("AR session resumed (view unfrozen)")
        }
    }

    private func captureAndSaveSnapshot() {
        guard let arView else {
            viewModel.isSavingSnapshot = false
            return
        }

        // arView.snapshot renders exactly what's currently on screen, which is the
        // frozen frame (virtual content composited over the last camera image).
        arView.snapshot(saveToHDR: false) { [weak self] image in
            Task { @MainActor in
                guard let self else { return }
                guard let image else {
                    self.viewModel.isSavingSnapshot = false
                    self.viewModel.snapshotFeedback = SnapshotFeedback(
                        isSuccess: false,
                        message: "Couldn't capture the AR view."
                    )
                    self.viewModel.debugLog("AR snapshot capture returned no image")
                    return
                }
                self.viewModel.capturedSnapshotImage = image
                self.saveImageToPhotoLibrary(image)
            }
        }
    }

    private func saveImageToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard let self else { return }
            Task { @MainActor [self] in
                switch status {
                case .authorized, .limited:
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    } completionHandler: { success, error in
                        Task { @MainActor in
                            self.viewModel.isSavingSnapshot = false
                            if success {
                                self.viewModel.snapshotFeedback = SnapshotFeedback(
                                    isSuccess: true,
                                    message: "Saved the frozen AR view to your Photos."
                                )
                                self.viewModel.debugLog("AR snapshot saved to Photos")
                            } else {
                                self.viewModel.snapshotFeedback = SnapshotFeedback(
                                    isSuccess: false,
                                    message: "Couldn't save the snapshot. \(error?.localizedDescription ?? "")"
                                )
                                self.viewModel.debugLog("AR snapshot save failed: \(error?.localizedDescription ?? "unknown error")")
                            }
                        }
                    }
                default:
                    self.viewModel.isSavingSnapshot = false
                    self.viewModel.snapshotFeedback = SnapshotFeedback(
                        isSuccess: false,
                        message: "Photo Library access is needed to save snapshots. Enable it in Settings."
                    )
                    self.viewModel.debugLog("Photo library access denied or restricted")
                }
            }
        }
    }

    private func currentSceneSignature() -> SceneUpdateSignature {
        SceneUpdateSignature(
            objects: viewModel.objects,
            selectedObjectID: viewModel.selectedObjectID,
            selectedTexture: viewModel.selectedTexture,
            lights: viewModel.lights,
            selectedLightID: viewModel.selectedLightID
        )
    }

    private func currentOverlaySignature() -> SceneOverlayUpdateSignature {
        let selectedLight = viewModel.selectedLight
        return SceneOverlayUpdateSignature(
            selectedObject: viewModel.selectedObject,
            selectedObjectType: viewModel.selectedObjectType,
            selectedLightID: selectedLight.id,
            selectedLightType: selectedLight.type,
            selectedLightPosition: selectedLight.position,
            selectedLightYawDegrees: selectedLight.yawDegrees,
            selectedLightPitchDegrees: selectedLight.pitchDegrees,
            selectedLightBeamSpread: selectedLight.beamSpread,
            selectedLightOuterAngleDegrees: selectedLight.beamOuterAngleDegrees,
            selectedLightIntensity: selectedLight.intensity,
            showLightDirection: viewModel.showLightDirection,
            showLightRays: viewModel.showLightRays,
            showProjectionLines: viewModel.showProjectionLines,
            showGroundProjection: viewModel.showGroundProjection,
            showShadowLabels: viewModel.showShadowLabels,
            hiddenShadowConcepts: viewModel.hiddenShadowConcepts
        )
    }

    private func currentShadowInfoSignature() -> ShadowInfoUpdateSignature {
        return ShadowInfoUpdateSignature(
            selectedObject: viewModel.selectedObject,
            selectedLight: viewModel.selectedLight
        )
    }

    private func selectLight(containing entity: Entity) -> Bool {
        if let selectedID = SceneLightSystem.selectLight(containing: entity) {
            viewModel.selectedLightID = selectedID
            viewModel.debugLog("Selected light changed")
            return true
        }
        return false
    }

    private func selectObject(containing entity: Entity) -> Bool {
        if let selectedID = SceneObjectSystem.selectObject(containing: entity) {
            viewModel.selectedObjectID = selectedID
            viewModel.debugLog("Selected object changed")
            return true
        }
        return false
    }

    private func objectEntity(id: UUID) -> Entity? {
        guard let anchor = sceneAnchor else { return nil }
        return SceneObjectSystem.entityWithObjectID(id, in: anchor)
    }

    private var scaledObjectHeight: Float {
        let selectedObject = viewModel.selectedObject
        return SceneObjectSystem.objectHeight(for: selectedObject) * selectedObject.scale
    }

    private func surfaceIntersectionProvider() -> ((SIMD3<Float>, SIMD3<Float>, Float) -> SIMD3<Float>?)? {
        guard usesSceneReconstruction, let arView else { return nil }

        return { origin, direction, maximumDistance in
            arView.scene.raycast(
                origin: origin,
                direction: direction,
                length: maximumDistance,
                query: .nearest,
                mask: .sceneUnderstanding,
                relativeTo: nil
            ).first?.position
        }
    }

    private func transformVector(_ vector: SIMD3<Float>, by transform: simd_float4x4) -> SIMD3<Float> {
        let transformed = transform * SIMD4<Float>(vector.x, vector.y, vector.z, 0)
        return simd_normalize(SIMD3<Float>(transformed.x, transformed.y, transformed.z))
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            self.updateLiDARMeshOcclusion(from: anchors)
            if anchors.contains(where: { $0 is ARPlaneAnchor }),
               self.viewModel.surfaceState == .scanning {
                self.viewModel.surfaceState = .found
                self.viewModel.placementFeedback = nil
                self.coachingOverlay?.setActive(false, animated: true)
                self.viewModel.debugLog("Horizontal plane detected")
            }

        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard frame.timestamp - lastDispatchedCameraTelemetryTimestamp >= (1.0 / 30.0) else { return }
        lastDispatchedCameraTelemetryTimestamp = frame.timestamp
        let updatedMarkerSurfaceTone = markerSurfaceToneEstimator.updatedTone(for: frame)

        let cameraTransform = frame.camera.transform
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let cameraForward = -SIMD3<Float>(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        )
        let cameraRight = SIMD3<Float>(
            cameraTransform.columns.0.x,
            cameraTransform.columns.0.y,
            cameraTransform.columns.0.z
        )
        let cameraUp = SIMD3<Float>(
            cameraTransform.columns.1.x,
            cameraTransform.columns.1.y,
            cameraTransform.columns.1.z
        )

        Task { @MainActor in
            guard !self.viewModel.isViewFrozen else { return }

            if let updatedMarkerSurfaceTone {
                self.annotationManager.setSurfaceTone(updatedMarkerSurfaceTone)
                self.telemetryDelegate?.markerSurfaceToneDidChange(updatedMarkerSurfaceTone)
            }

            self.telemetryDelegate?.cameraDidUpdate(
                position: cameraPosition,
                forward: cameraForward,
                right: cameraRight,
                up: cameraUp
            )

            // White mark terpilih diwarnai merah. Recolor hanya saat pilihan
            // berubah supaya tidak mengalokasi material tiap frame. Ini menutup
            // semua cara deselect (tap ulang, tap dunia, atau menutup overlay).
            if self.annotationManager.selectedConcept != self.viewModel.selectedConcept {
                self.annotationManager.setSelected(self.viewModel.selectedConcept)
            }

            guard self.viewModel.selectedConcept != nil,
                  let arView = self.arView,
                  let entity = self.selectedConceptEntity else {
                self.viewModel.selectedConceptWorldPosition = nil
                return
            }

            let worldPosition = entity.position(relativeTo: nil)
            // Bayo (Level 3) memakai posisi world ini untuk terbang mendekat.
            self.viewModel.selectedConceptWorldPosition = worldPosition
            if let screenPoint = arView.project(worldPosition) {
                self.viewModel.selectedConceptTapLocation = screenPoint
            }
        }
    }

    private func updateLiDARMeshOcclusion(from anchors: [ARAnchor]) {
        guard usesSceneReconstruction, let arView else { return }
        let result = lidarMeshOcclusionManager.update(from: anchors, in: arView)
        if result.updatedCount > 0 {
            viewModel.updateLiDARScan(meshCount: result.meshCount, faceCount: result.faceCount)
        }
        if result.updatedCount > 0, !hasLoggedLiDARMeshOcclusion {
            hasLoggedLiDARMeshOcclusion = true
            viewModel.debugLog("LiDAR scan mesh visualization updated; ARKit scene understanding handles occlusion")
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.viewModel.debugLog("AR session error: \(error.localizedDescription)")
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.viewModel.debugLog("AR session interrupted")
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            self.viewModel.debugLog("AR session interruption ended")
            self.runSession(resetTracking: false)
        }
    }
}
