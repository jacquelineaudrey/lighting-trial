import ARKit
import RealityKit
import Combine
import QuartzCore

@MainActor
final class Level1ARCoordinator: NSObject, ARSessionDelegate, ARCoachingOverlayViewDelegate {

    private let viewModel: Level1ViewModel
    private weak var arView: ARView?
    private var coachingOverlay: ARCoachingOverlayView?

    private static let pathRadius: Float = 2.0
    private static let childTargetHeight: Float = 0.3 // Ukuran bentuk 3D sementara untuk testing
    private static let markerRadius: Float = 0.55
    private static let markerOffsetFromShape: Float = 0.55

    private var hasPlacedPath = false
    private var latestHorizontalPlaneAnchor: ARPlaneAnchor?
    private var pathCenterXZ: SIMD2<Float> = .zero
    private var checkpointWorldPositions: [SIMD3<Float>] = []
    private var markerWorldPositions: [SIMD3<Float>] = []
    private var checkpointEntities: [ModelEntity] = []
    private var markerEntities: [ModelEntity] = []
    private var lastAppliedTextureID: [Int: String] = [:]
    private var lastArrivedIndex: Int?
    private var lastMarkerState: [Int: MarkerState] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var pulseDisplayLink: CADisplayLink?

    private enum MarkerState: Equatable {
        case active   // target berikutnya -> biru terang & berdenyut
        case visited  // sudah pernah didatangi -> disembunyikan
        case upcoming // belum jadi target -> abu-abu redup
    }

    init(viewModel: Level1ViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    func configure(arView: ARView) {
        self.arView = arView
        arView.session.delegate = self
        arView.environment.sceneUnderstanding.options.insert(.occlusion)

        addCoachingOverlay(to: arView)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        observeViewModelChanges()
        startPulseAnimation()
    }

    deinit {
        pulseDisplayLink?.invalidate()
    }

    // MARK: - Scan permukaan (ARCoachingOverlayView)
    
    private func addCoachingOverlay(to arView: ARView) {
        let overlay = ARCoachingOverlayView()
        overlay.session = arView.session
        overlay.goal = .horizontalPlane
        
        // JANGAN AKTIF OTOMATIS: Kita nyalakan manual saat dialog selesai
        overlay.activatesAutomatically = false
        
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

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        guard !hasPlacedPath, let arView else { return }
        
        // 1. Coba cari kordinat lantai (plane) dari tracking memori ARKit
        let planeAnchor = latestHorizontalPlaneAnchor ?? arView.session.currentFrame?.anchors.compactMap({ $0 as? ARPlaneAnchor }).first(where: { $0.alignment == .horizontal })
        
        if let validPlane = planeAnchor {
            placeCheckpointCircle(fromPlane: validPlane, in: arView)
        } else {
            // 2. FALLBACK SUPER AMAN
            print("⚠️ Peringatan: ARKit kehilangan anchor. Menggunakan mode Fallback (estimasi tinggi lantai).")
            let camPos = arView.cameraTransform.matrix.columns.3
            placeCheckpointCircle(floorY: camPos.y - 1.2, originXZ: SIMD2<Float>(camPos.x, camPos.z), in: arView)
        }
        
        // 3. PAKSA UI pindah fase
        viewModel.finishScanning()
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        hasPlacedPath = false
        latestHorizontalPlaneAnchor = nil
        arView?.scene.anchors.removeAll()
        checkpointEntities.removeAll()
        markerEntities.removeAll()
        checkpointWorldPositions.removeAll()
        markerWorldPositions.removeAll()
        lastMarkerState.removeAll()
        lastAppliedTextureID.removeAll()
    }

    private func observeViewModelChanges() {
        // Observer untuk sinkronisasi material dan warna marker
        viewModel.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.syncActiveCheckpointMaterial()
                    self?.syncMarkerStates()
                }
            }
            .store(in: &cancellables)

        // Observer untuk transisi state dan logika scan/bypass
        viewModel.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                guard let self = self, let arView = self.arView else { return }
                
                if phase == .scanningSurface {
                    // PENTING: ARSession sudah jalan (dan plane detection sudah aktif)
                    // sejak `configure()`, yaitu selagi dialog onboarding masih tampil.
                    // Kalau anak diam sebentar baca dialog, ARKit bisa saja SUDAH
                    // ketemu lantai duluan secara diam-diam sebelum overlay ini
                    // diaktifkan — akibatnya begitu `setActive(true)` dipanggil,
                    // ARCoachingOverlayView langsung menganggap goal-nya sudah
                    // tercapai dan non-aktif lagi seketika (kelihatan seperti UI
                    // scan "tidak pernah muncul"). Reset tracking di sini supaya
                    // ARKit betul-betul mulai scan ulang dari nol tepat saat anak
                    // memencet "Ayo Mulai", jadi overlay selalu sempat tampil.
                    self.latestHorizontalPlaneAnchor = nil
                    if let configuration = arView.session.configuration {
                        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                    }

                    // Nyalakan UI Scan karena anak sudah memencet "Ayo Mulai"
                    self.coachingOverlay?.setActive(true, animated: true)
                }
                else if phase == .exploring {
                    // Matikan UI Scan (berguna jika Bypass ditekan)
                    self.coachingOverlay?.setActive(false, animated: true)
                    
                    // Jika melewati tombol Debug dan bentuk belum ditaruh
                    if !self.hasPlacedPath {
                        print("🛠 Menggunakan jalur pintas Debug: Menaruh objek paksa!")
                        let camPos = arView.cameraTransform.matrix.columns.3
                        self.placeCheckpointCircle(floorY: camPos.y - 1.2,
                                                   originXZ: SIMD2<Float>(camPos.x, camPos.z),
                                                   in: arView)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Penempatan jalur checkpoint (bentuk lingkaran)

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        trackLatestHorizontalPlane(from: anchors)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        trackLatestHorizontalPlane(from: anchors)
    }

    private func trackLatestHorizontalPlane(from anchors: [ARAnchor]) {
        guard !hasPlacedPath else { return }
        if let planeAnchor = anchors.compactMap({ $0 as? ARPlaneAnchor })
            .first(where: { $0.alignment == .horizontal }) {
            latestHorizontalPlaneAnchor = planeAnchor
        }
    }

    private func placeCheckpointCircle(fromPlane planeAnchor: ARPlaneAnchor, in arView: ARView) {
        let floorY = planeAnchor.transform.columns.3.y
        let originXZ = SIMD2<Float>(planeAnchor.transform.columns.3.x, planeAnchor.transform.columns.3.z)
        placeCheckpointCircle(floorY: floorY, originXZ: originXZ, in: arView)
    }

    private func placeCheckpointCircle(floorY: Float, originXZ: SIMD2<Float>, in arView: ARView) {
        hasPlacedPath = true

        let forwardXZ = horizontalForward(of: arView.cameraTransform.matrix)
        pathCenterXZ = originXZ + forwardXZ * Self.pathRadius
        let angleToStart = atan2(originXZ.y - pathCenterXZ.y, originXZ.x - pathCenterXZ.x)
        let checkpointCount = viewModel.checkpoints.count
        let angleStep = (2 * Float.pi) / Float(checkpointCount)

        checkpointWorldPositions.removeAll()
        markerWorldPositions.removeAll()
        checkpointEntities.removeAll()
        markerEntities.removeAll()

        for (index, checkpoint) in viewModel.checkpoints.enumerated() {
            let angle = angleToStart + angleStep * Float(index)
            let shapeXZ = pathCenterXZ + SIMD2<Float>(cos(angle), sin(angle)) * Self.pathRadius
            let shapeWorldPosition = SIMD3<Float>(shapeXZ.x, floorY, shapeXZ.y)
            checkpointWorldPositions.append(shapeWorldPosition)

            let towardCenter = simd_normalize(pathCenterXZ - shapeXZ)
            let markerXZ = shapeXZ + towardCenter * Self.markerOffsetFromShape
            let markerWorldPosition = SIMD3<Float>(markerXZ.x, floorY + 0.005, markerXZ.y)
            markerWorldPositions.append(markerWorldPosition)

            let shapeEntity = makeCheckpointEntity(for: checkpoint, worldPosition: shapeWorldPosition)
            checkpointEntities.append(shapeEntity)
            let shapeAnchor = AnchorEntity(world: translationMatrix(shapeWorldPosition))
            shapeAnchor.addChild(shapeEntity)
            arView.scene.addAnchor(shapeAnchor)

            let markerEntity = makeMarkerEntity()
            markerEntities.append(markerEntity)
            let markerAnchor = AnchorEntity(world: translationMatrix(markerWorldPosition))
            markerAnchor.addChild(markerEntity)
            arView.scene.addAnchor(markerAnchor)
        }

        syncMarkerStates()
    }

    private func makeCheckpointEntity(for checkpoint: Checkpoint, worldPosition: SIMD3<Float>) -> ModelEntity {
        let texture = checkpoint.shape.textures[0].material
        let entity = SceneObjectEntityFactory.makeObject(type: checkpoint.shape.objectType, texture: texture)

        let naturalHeight = SceneObjectEntityFactory.objectHeight(for: checkpoint.shape.objectType)
        let scale = Self.childTargetHeight / naturalHeight
        entity.scale = SIMD3<Float>(repeating: scale)
        entity.position.y = (naturalHeight * scale) / 2

        entity.addChild(makeLabel(text: checkpoint.shape.displayName, aboveHeight: naturalHeight * scale))
        lastAppliedTextureID[checkpoint.order] = checkpoint.shape.textures[0].id
        return entity
    }

    private func makeLabel(text: String, aboveHeight: Float) -> ModelEntity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.004,
            font: .boldSystemFont(ofSize: 0.12),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let material = SimpleMaterial(color: .white, isMetallic: false)
        let label = ModelEntity(mesh: mesh, materials: [material])
        label.scale = SIMD3<Float>(repeating: 0.5)

        let bounds = mesh.bounds
        label.position = SIMD3<Float>(-bounds.extents.x * 0.25, aboveHeight + 0.2, 0)
        return label
    }

    private func makeMarkerEntity() -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: Self.markerRadius)
        var material = UnlitMaterial(color: .systemBlue.withAlphaComponent(0.55))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.55))
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = SIMD3<Float>(1, 0.04, 1)
        return entity
    }

    // MARK: - Ganti tekstur live

    private func syncActiveCheckpointMaterial() {
        let activeIndex = viewModel.currentCheckpointIndex
        guard checkpointEntities.indices.contains(activeIndex), viewModel.hasArrivedAtCurrentCheckpoint else { return }

        let texture = viewModel.currentTexture
        guard lastAppliedTextureID[activeIndex] != texture.id else { return }
        lastAppliedTextureID[activeIndex] = texture.id

        let entity = checkpointEntities[activeIndex]
        entity.model?.materials = [texture.material.makeMaterial()]
    }

    // MARK: - Status lingkaran biru (aktif / sudah dikunjungi / belum giliran)

    private func syncMarkerStates() {
        guard !markerEntities.isEmpty else { return }
        let targetIndex = viewModel.nextTargetCheckpointIndex

        for index in markerEntities.indices {
            let state: MarkerState
            if targetIndex == index {
                state = .active
            } else if let target = targetIndex, index < target {
                state = .visited
            } else if targetIndex == nil {
                state = .visited
            } else {
                state = .upcoming
            }

            guard lastMarkerState[index] != state else { continue }
            lastMarkerState[index] = state
            applyMarkerAppearance(state, to: markerEntities[index])
        }
    }

    private func applyMarkerAppearance(_ state: MarkerState, to entity: ModelEntity) {
        switch state {
        case .active:
            entity.isEnabled = true
            var material = UnlitMaterial(color: .systemBlue.withAlphaComponent(0.65))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.65))
            entity.model?.materials = [material]
        case .upcoming:
            entity.isEnabled = true
            var material = UnlitMaterial(color: .systemGray.withAlphaComponent(0.25))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.25))
            entity.model?.materials = [material]
        case .visited:
            entity.isEnabled = false
        }
    }

    private func startPulseAnimation() {
        let link = CADisplayLink(target: self, selector: #selector(handlePulseTick))
        link.add(to: .main, forMode: .common)
        pulseDisplayLink = link
    }

    @objc private func handlePulseTick(_ link: CADisplayLink) {
        guard let targetIndex = viewModel.nextTargetCheckpointIndex,
              markerEntities.indices.contains(targetIndex) else { return }

        let pulse = 1 + 0.12 * sin(Float(link.timestamp) * 4)
        markerEntities[targetIndex].scale = SIMD3<Float>(pulse, 0.04, pulse)
    }

    // MARK: - Deteksi kedatangan (masuk ke lingkaran biru target)

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard !markerWorldPositions.isEmpty else { return }
        let cameraPosition = SIMD3<Float>(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )

        let candidateIndex: Int?
        switch viewModel.phase {
        case .exploring:
            candidateIndex = viewModel.nextTargetCheckpointIndex
        case .returningToStart:
            candidateIndex = 0
        default:
            candidateIndex = nil
        }

        guard let index = candidateIndex, markerWorldPositions.indices.contains(index) else { return }
        let distance = horizontalDistance(cameraPosition, markerWorldPositions[index])

        if distance < Self.markerRadius {
            guard lastArrivedIndex != index else { return }
            lastArrivedIndex = index
            viewModel.arrive(atCheckpointIndex: index)
        } else if lastArrivedIndex == index {
            lastArrivedIndex = nil
        }
    }

    // MARK: - Util geometri

    private func horizontalDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let dx = a.x - b.x
        let dz = a.z - b.z
        return sqrt(dx * dx + dz * dz)
    }

    private func horizontalForward(of transform: simd_float4x4) -> SIMD2<Float> {
        let forward = -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        let flat = SIMD2<Float>(forward.x, forward.z)
        let length = simd_length(flat)
        return length > 0.0001 ? flat / length : SIMD2<Float>(0, -1)
    }

    private func translationMatrix(_ position: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1)
        return matrix
    }
}
