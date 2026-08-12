import ARKit
import RealityKit
import SwiftUI
import Combine
import QuartzCore

@MainActor
final class Level1ARCoordinator: NSObject, ARSessionDelegate, ARCoachingOverlayViewDelegate {

    private let viewModel: Level1ViewModel
    private weak var arView: ARView?
    private var coachingOverlay: ARCoachingOverlayView?

    /// Radius dipakai HANYA di fallback pola lingkaran lama (kalau
    /// `randomScatterPoint` gagal dapat titik acak yang valid setelah semua
    /// percobaan — lihat `makeCheckpointShapePositions`).
    private static let pathRadius: Float = 3.2
    /// Ukuran bentuk 3D checkpoint, kira-kira setinggi 115cm di dunia nyata
    /// (sebelumnya 150cm, sebelum itu 100cm, dan sebelum itu 0.42m).
    /// Diperkecil dikit dari 150cm supaya bentuknya tidak terlalu "penuh"
    /// dibanding lingkaran checkpoint (`markerRadius`) yang sekarang sengaja
    /// dibuat lebih besar dari objeknya sendiri — lihat catatan di
    /// `markerRadius`.
    private static let childTargetHeight: Float = 1.15
    /// Radius lingkaran biru checkpoint (marker kedatangan). SEKARANG SENGAJA
    /// dibuat lebih besar dari objek 3D-nya (diameter marker ~2.0m vs objek
    /// ~1.15m) supaya lingkaran checkpoint-nya sendiri kelihatan jelas
    /// mengelilingi bentuknya dari jauh, bukan cuma nempel pas-pasan di
    /// dasarnya. Nilai ini juga dipakai sebagai jarak trigger kedatangan di
    /// `session(_:didUpdate:)`, jadi radius yang lebih besar otomatis
    /// membuat area "sampai di checkpoint"-nya ikut lebih lega.
    private static let markerRadius: Float = 1.0
    /// Offset marker (lingkaran biru target) dari titik pusat shape.
    /// SEBELUMNYA 0.75 (marker digeser ke depan shape, terpisah dari objek).
    /// Sekarang 0 supaya lingkaran target persis di TENGAH-TENGAH objek —
    /// anak tinggal mendekati objeknya langsung, tanpa perlu menebak titik
    /// tersembunyi di depannya.
    private static let markerOffsetFromShape: Float = 0
    private static let minimumScanDuration: Duration = .seconds(4)
    /// Jarak minimum antar checkpoint (dipakai `makeCheckpointShapePositions`
    /// buat memilih titik yang tidak saling tumpang tindih). Dengan
    /// `markerRadius` sekarang 1.0m (diameter lingkaran checkpoint ~2.0m),
    /// spacing 3.0m menyisakan jarak bersih ~1.0m antar TEPI lingkaran biru
    /// dua checkpoint bersebelahan — cukup lega buat anak jalan tanpa
    /// lingkaran-lingkarannya nempel/tumpang tindih.
    private static let checkpointMinimumSpacing: Float = 3.0
    /// Rentang jarak "satu langkah petualangan" dari satu checkpoint ke
    /// checkpoint berikutnya, dipakai `randomScatterPoint` buat menyebar
    /// jalur ke arah acak (lihat `makeCheckpointShapePositions`). Batas bawah
    /// sengaja > `checkpointMinimumSpacing` supaya rejection sampling jarang
    /// gagal, batas atas dijaga tidak terlalu jauh supaya masih dalam area
    /// yang sudah di-scan LiDAR.
    private static let scatterStepRange: ClosedRange<Float> = 3.2...4.6
    /// Batas jarak maksimum tiap checkpoint dari titik asal (tempat anak
    /// berdiri saat scan lantai selesai), supaya jalur petualangan yang
    /// menyebar ke berbagai arah tidak sampai keluar dari ruangan / area yang
    /// sudah dipindai.
    private static let scatterMaxRadiusFromOrigin: Float = 7.0
    /// Berapa kali `randomScatterPoint` mencoba titik acak sebelum menyerah
    /// dan jatuh ke fallback pola lingkaran lama.
    private static let scatterPlacementAttempts = 60
    /// Warna neon dipakai untuk label nama bentuk (teks + lempeng glow di
    /// belakangnya) di atas tiap checkpoint — kuning-hijau terang ala tanda
    /// neon, kontras tinggi dengan hampir semua warna tekstur & latar kamera,
    /// jadi nama bentuknya gampang terbaca dari jauh.
    private static let neonLabelColor = UIColor(red: 0.75, green: 1.0, blue: 0.15, alpha: 1.0)

    private var hasPlacedPath = false
    private var latestHorizontalPlaneAnchor: ARPlaneAnchor?
    private var pathCenterXZ: SIMD2<Float> = .zero
    /// Satu-satunya anchor RealityKit untuk seluruh jalur checkpoint. Semua
    /// bentuk checkpoint dan marker adalah child dari anchor ini (posisi
    /// lokal relatif ke titik tengah jalur), BUKAN masing-masing punya
    /// `AnchorEntity(world:)` sendiri-sendiri. Sebelumnya tiap checkpoint dan
    /// marker punya anchor dunia terpisah, jadi kalau ARKit melakukan koreksi
    /// tracking, tiap bentuk bisa "mengambang"/bergeser sendiri-sendiri
    /// relatif satu sama lain alih-alih tetap menyatu sebagai satu jalur.
    private var pathAnchor: AnchorEntity?
    private var checkpointWorldPositions: [SIMD3<Float>] = []
    private var markerWorldPositions: [SIMD3<Float>] = []
    private var checkpointEntities: [ModelEntity] = []
    private var markerEntities: [ModelEntity] = []
    private var lastAppliedTextureID: [Int: String] = [:]
    private var lastArrivedIndex: Int?
    private var lastMarkerState: [Int: MarkerState] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var automaticPlacementTask: Task<Void, Never>?
    private var pulseDisplayLink: CADisplayLink?

    /// Reuse mesin lighting dari lightingconcept (`SceneLightEntityFactory` +
    /// `LightConfiguration`) supaya bentuk checkpoint di Level 1 benar-benar
    /// disinari lampu virtual dan melempar shadow nyata ke lantai (lewat LiDAR
    /// mesh occlusion yang sudah diaktifkan di `configure`), bukan cuma
    /// mengandalkan ambient light AR default seperti sebelumnya.
    private var pathLightBundle: RealityKitLightEntityBundle?
    /// Reuse `CollisionSystem` yang sama dipakai scene editor lightingconcept,
    /// supaya jarak antar checkpoint/marker/lampu di jalur Level 1 juga
    /// dijaga tidak saling tumpang tindih dengan aturan collision yang sama.
    private let collisionSystem = CollisionSystem()
    private let pathLightID = UUID()
    /// `CollisionSystem` butuh key `UUID`, sedangkan `Checkpoint.id` di Level 1
    /// berupa `String` ("cp-0", dst). Cache ini memberi setiap checkpoint UUID
    /// yang stabil sepanjang hidup coordinator, tanpa mengubah model `Checkpoint`.
    private var checkpointObstacleIDs: [String: UUID] = [:]

    /// Reuse `ShadowReceiverManager` dari lightingconcept: box tipis tak-kasat-mata
    /// dengan `OcclusionMaterial(receivesDynamicLighting: true)` yang jadi
    /// permukaan penerima shadow yang stabil di AR, dipakai supaya shadow dari
    /// lampu di atas benar-benar terlihat jatuh ke "lantai" jalur checkpoint.
    private let shadowReceiverManager = ShadowReceiverManager()

    /// Reuse `LiDARMeshOcclusionManager` dari lightingconcept: sama persis
    /// dipakai `ARSceneCoordinator` untuk memvisualisasikan mesh cyan hasil
    /// scan LiDAR & menghitung progres scan (`meshCount`/`faceCount`) yang
    /// diteruskan ke `viewModel.arSceneViewModel.updateLiDARScan`, sumber data
    /// buat `LiDARScanProgressCard` di `ScanningSurfaceOverlay`.
    private let lidarMeshOcclusionManager = LiDARMeshOcclusionManager()
    private var usesSceneReconstruction = false

    private func obstacleID(for checkpointID: String) -> UUID {
        if let existing = checkpointObstacleIDs[checkpointID] {
            return existing
        }
        let id = UUID()
        checkpointObstacleIDs[checkpointID] = id
        return id
    }

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
            usesSceneReconstruction = true
            // Reuse penanda LiDAR yang sama dipakai `ARSceneCoordinator` di mode
            // sandbox, supaya `LiDARScanProgressCard` yang dipasang di
            // `ScanningSurfaceOverlay` tahu kapan harus tampil.
            viewModel.arSceneViewModel.isLiDARAvailable = true
            viewModel.arSceneViewModel.resetLiDARScan()
        } else {
            usesSceneReconstruction = false
            viewModel.arSceneViewModel.isLiDARAvailable = false
        }
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        observeViewModelChanges()
        startPulseAnimation()
    }

    deinit {
        automaticPlacementTask?.cancel()
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
        guard let arView else { return }
        scheduleAutomaticPlacement(in: arView)
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        automaticPlacementTask?.cancel()
        automaticPlacementTask = nil
        hasPlacedPath = false
        latestHorizontalPlaneAnchor = nil
        arView?.scene.anchors.removeAll()
        pathAnchor = nil
        checkpointEntities.removeAll()
        markerEntities.removeAll()
        checkpointWorldPositions.removeAll()
        markerWorldPositions.removeAll()
        lastMarkerState.removeAll()
        lastAppliedTextureID.removeAll()
        pathLightBundle = nil
        collisionSystem.removeAll()
        checkpointObstacleIDs.removeAll()
        shadowReceiverManager.reset()
        lidarMeshOcclusionManager.reset()
        viewModel.arSceneViewModel.resetLiDARScan()
        viewModel.clearWaypoint()
    }

    private func observeViewModelChanges() {
        // Observer untuk sinkronisasi material dan warna marker
        viewModel.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.syncActiveCheckpointMaterial()
                    self?.syncMarkerStates()
                    self?.syncCheckpointVisibility()
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
                    self.scheduleAutomaticPlacement(in: arView)
                }
                else if phase == .exploring {
                    self.automaticPlacementTask?.cancel()
                    self.automaticPlacementTask = nil
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
                else if phase != .exploring && phase != .returningToStart {
                    // Fase ini (onboarding/scanning/quiz/completed) tidak
                    // punya "tujuan berjalan" — matikan panah waypoint supaya
                    // tidak nyangkut ke posisi checkpoint terakhir.
                    self.viewModel.clearWaypoint()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Penempatan jalur checkpoint (bentuk lingkaran)

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        trackLatestHorizontalPlane(from: anchors)
        updateLiDARMeshOcclusion(from: anchors)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        trackLatestHorizontalPlane(from: anchors)
        updateLiDARMeshOcclusion(from: anchors)
    }

    private func scheduleAutomaticPlacement(in arView: ARView) {
        guard automaticPlacementTask == nil else { return }
        automaticPlacementTask = Task { [weak self, weak arView] in
            try? await Task.sleep(for: Self.minimumScanDuration)
            guard !Task.isCancelled, let self, let arView else { return }
            await MainActor.run {
                guard self.viewModel.phase == .scanningSurface else { return }
                self.placePathIfNeeded(in: arView, allowsFallback: true)
            }
        }
    }

    private func placePathIfNeeded(in arView: ARView, allowsFallback: Bool) {
        guard !hasPlacedPath else { return }

        let planeAnchor = latestHorizontalPlaneAnchor
            ?? arView.session.currentFrame?.anchors
                .compactMap({ $0 as? ARPlaneAnchor })
                .first(where: { $0.alignment == .horizontal })

        if let validPlane = planeAnchor {
            placeCheckpointCircle(fromPlane: validPlane, in: arView)
        } else if allowsFallback {
            print("⚠️ Peringatan: ARKit belum menemukan anchor lantai. Menggunakan fallback otomatis.")
            let camPos = arView.cameraTransform.matrix.columns.3
            placeCheckpointCircle(floorY: camPos.y - 1.2, originXZ: SIMD2<Float>(camPos.x, camPos.z), in: arView)
        } else {
            return
        }

        automaticPlacementTask?.cancel()
        automaticPlacementTask = nil
        coachingOverlay?.setActive(false, animated: true)
        viewModel.finishScanning()
    }

    private func trackLatestHorizontalPlane(from anchors: [ARAnchor]) {
        guard !hasPlacedPath else { return }
        if let planeAnchor = anchors.compactMap({ $0 as? ARPlaneAnchor })
            .filter({ $0.alignment == .horizontal })
            .max(by: { planeArea($0) < planeArea($1) }) {
            if let existing = latestHorizontalPlaneAnchor {
                let existingArea = planeArea(existing)
                let candidateArea = planeArea(planeAnchor)
                if candidateArea > existingArea {
                    latestHorizontalPlaneAnchor = planeAnchor
                }
            } else {
                latestHorizontalPlaneAnchor = planeAnchor
            }
        }
    }

    private func planeArea(_ planeAnchor: ARPlaneAnchor) -> Float {
        planeAnchor.planeExtent.width * planeAnchor.planeExtent.height
    }

    /// Sama persis dengan `ARSceneCoordinator.updateLiDARMeshOcclusion`: kasih
    /// makan mesh anchor LiDAR ke `LiDARMeshOcclusionManager`, lalu teruskan
    /// jumlah mesh/face-nya ke `ARSceneViewModel.updateLiDARScan` supaya kartu
    /// persentase (`LiDARScanProgressCard`) di `ScanningSurfaceOverlay` ikut
    /// bergerak sesuai progres scan yang sesungguhnya.
    private func updateLiDARMeshOcclusion(from anchors: [ARAnchor]) {
        guard usesSceneReconstruction, let arView else { return }
        let result = lidarMeshOcclusionManager.update(from: anchors, in: arView)
        if result.updatedCount > 0 {
            viewModel.arSceneViewModel.updateLiDARScan(meshCount: result.meshCount, faceCount: result.faceCount)
        }
    }

    private func placeCheckpointCircle(fromPlane planeAnchor: ARPlaneAnchor, in arView: ARView) {
        let planeCenter = planeAnchor.transform * SIMD4<Float>(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z, 1)
        let floorY = planeCenter.y
        let originXZ = SIMD2<Float>(planeCenter.x, planeCenter.z)
        placeCheckpointCircle(floorY: floorY, originXZ: originXZ, in: arView)
    }

    private func placeCheckpointCircle(floorY: Float, originXZ: SIMD2<Float>, in arView: ARView) {
        hasPlacedPath = true

        let checkpointCount = viewModel.checkpoints.count
        let forwardXZ = horizontalForward(of: arView.cameraTransform.matrix)
        let shapePositionsXZ = makeCheckpointShapePositions(originXZ: originXZ, forwardXZ: forwardXZ, count: checkpointCount)
        pathCenterXZ = averagePosition(shapePositionsXZ)

        checkpointWorldPositions.removeAll()
        markerWorldPositions.removeAll()
        checkpointEntities.removeAll()
        markerEntities.removeAll()
        collisionSystem.removeAll()

        // SATU anchor untuk seluruh jalur, ditempatkan di titik tengah lingkaran
        // checkpoint. Semua bentuk & marker jadi child anchor ini dengan posisi
        // LOKAL (offset dari titik tengah), bukan masing-masing punya anchor
        // dunia sendiri. Ini membuat seluruh jalur bergerak/terkoreksi sebagai
        // satu kesatuan yang solid saat ARKit menyesuaikan tracking, alih-alih
        // tiap bentuk mengambang independen satu sama lain.
        let anchor = AnchorEntity(world: translationMatrix(SIMD3<Float>(pathCenterXZ.x, floorY, pathCenterXZ.y)))
        arView.scene.addAnchor(anchor)
        pathAnchor = anchor
        shadowReceiverManager.setupReceiver(on: anchor, usesFlatFallback: true, surfaceTexture: .defaultGrid)
        // Sama seperti `ARSceneCoordinator.placeScene`: matikan visualisasi mesh
        // cyan begitu penempatan selesai, supaya tidak menutupi jalur checkpoint
        // selagi bermain.
        lidarMeshOcclusionManager.setVisualizationEnabled(false)
        viewModel.arSceneViewModel.isObjectPlaced = true

        for (index, checkpoint) in viewModel.checkpoints.enumerated() {
            let shapeXZ = shapePositionsXZ[index]
            let shapeWorldPosition = SIMD3<Float>(shapeXZ.x, floorY, shapeXZ.y)
            checkpointWorldPositions.append(shapeWorldPosition)
            let shapeLocalPosition = SIMD3<Float>(shapeXZ.x - pathCenterXZ.x, 0, shapeXZ.y - pathCenterXZ.y)

            // Marker (lingkaran biru trigger) digeser dari shape sebesar
            // `markerOffsetFromShape` ke arah maju kamera saat jalur dibuat.
            // Dengan `markerOffsetFromShape == 0` ini efektif menaruh marker
            // persis di tengah-tengah shape.
            let markerDirection = forwardXZ
            let markerXZ = shapeXZ + markerDirection * Self.markerOffsetFromShape
            let markerWorldPosition = SIMD3<Float>(markerXZ.x, floorY + 0.005, markerXZ.y)
            markerWorldPositions.append(markerWorldPosition)
            let markerLocalPosition = SIMD3<Float>(markerXZ.x - pathCenterXZ.x, 0.005, markerXZ.y - pathCenterXZ.y)

            let shapeEntity = makeCheckpointEntity(for: checkpoint, worldPosition: shapeWorldPosition)
            shapeEntity.position += shapeLocalPosition
            checkpointEntities.append(shapeEntity)
            anchor.addChild(shapeEntity)

            let markerEntity = makeMarkerEntity()
            markerEntity.position = markerLocalPosition
            markerEntities.append(markerEntity)
            anchor.addChild(markerEntity)

            // Daftarkan checkpoint & marker sebagai obstacle di `CollisionSystem`
            // yang sama dipakai lightingconcept, supaya benda-benda sepanjang
            // jalur ini dijaga tidak saling tumpang tindih oleh aturan collision
            // yang sudah teruji di scene editor utama.
            collisionSystem.registerObstacle(
                id: obstacleID(for: checkpoint.id),
                position: shapeWorldPosition,
                radius: Self.childTargetHeight / 2
            )
        }

        placePathLight(anchor: anchor, floorY: floorY)
        syncMarkerStates()
        syncCheckpointVisibility()
    }

    /// Susun titik checkpoint sebagai jalur "petualangan" yang menyebar ke
    /// berbagai arah (bukan cuma pola tetap di depan user seperti
    /// sebelumnya). Checkpoint pertama tetap dekat titik asal (biar gampang
    /// ditemukan pertama kali), lalu tiap checkpoint berikutnya dilempar ke
    /// arah ACAK (360°) dengan jarak acak dari checkpoint sebelumnya —
    /// membentuk rantai jalan yang berbeda-beda tiap kali level dimainkan,
    /// jadi anak benar-benar harus berputar/menjelajah ruangan alih-alih
    /// jalan lurus mengikuti pola yang selalu sama.
    private func makeCheckpointShapePositions(originXZ: SIMD2<Float>, forwardXZ: SIMD2<Float>, count: Int) -> [SIMD2<Float>] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [originXZ] }

        var selected: [SIMD2<Float>] = [originXZ]
        for _ in 1..<count {
            let anchorPoint = selected.last!
            if let next = randomScatterPoint(from: anchorPoint, avoiding: selected, originXZ: originXZ) {
                selected.append(next)
            } else {
                break
            }
        }

        if selected.count == count {
            return selected
        }

        // Fallback (jarang terjadi): kalau rejection sampling gagal dapat
        // cukup titik acak yang valid, jatuh balik ke pola lingkaran lama
        // supaya tetap ada checkpoint yang valid & tidak tumpang tindih.
        let centerXZ = originXZ + forwardXZ * Self.pathRadius
        let angleToStart = atan2(originXZ.y - centerXZ.y, originXZ.x - centerXZ.x)
        let angleStep = (2 * Float.pi) / Float(count)
        return (0..<count).map { index in
            let angle = angleToStart + angleStep * Float(index)
            return centerXZ + SIMD2<Float>(cos(angle), sin(angle)) * Self.pathRadius
        }
    }

    /// Cari satu titik acak (360°, jarak `scatterStepRange`) dari `anchor`
    /// yang masih cukup jauh dari semua titik di `existing` (>=
    /// `checkpointMinimumSpacing`) dan masih dalam radius `scatterMaxRadiusFromOrigin`
    /// dari `originXZ`. `nil` kalau `scatterPlacementAttempts` percobaan
    /// semuanya gagal.
    private func randomScatterPoint(from anchor: SIMD2<Float>, avoiding existing: [SIMD2<Float>], originXZ: SIMD2<Float>) -> SIMD2<Float>? {
        for _ in 0..<Self.scatterPlacementAttempts {
            let angle = Float.random(in: 0..<(2 * Float.pi))
            let distance = Float.random(in: Self.scatterStepRange)
            let candidate = anchor + SIMD2<Float>(cos(angle), sin(angle)) * distance

            let isClearOfOthers = existing.allSatisfy { simd_distance(candidate, $0) >= Self.checkpointMinimumSpacing }
            let isWithinRoom = simd_distance(candidate, originXZ) <= Self.scatterMaxRadiusFromOrigin
            if isClearOfOthers && isWithinRoom {
                return candidate
            }
        }
        return nil
    }

    private func averagePosition(_ positions: [SIMD2<Float>]) -> SIMD2<Float> {
        guard !positions.isEmpty else { return .zero }
        let total = positions.reduce(SIMD2<Float>.zero, +)
        return total / Float(positions.count)
    }

    // MARK: - Reuse lighting engine lightingconcept

    /// Membuat satu lampu spot nyata dengan `SceneLightEntityFactory` (mesin
    /// lighting yang sama dipakai layar utama lightingconcept), lalu
    /// menempatkannya di atas jalur checkpoint supaya bentuk Kubus & Bola
    /// benar-benar disinari dan melempar shadow dinamis ke lantai nyata
    /// (dukungan shadow ini datang dari LiDAR mesh occlusion yang sudah
    /// diaktifkan di `configure`).
    private func placePathLight(anchor: AnchorEntity, floorY: Float) {
        let lightHeight: Float = 1.4
        let defaults = LightConfiguration.defaultLight()
        let configuration = LightConfiguration(
            id: pathLightID,
            name: "Level 1 Path Light",
            type: defaults.type,
            color: defaults.color,
            intensity: defaults.intensity,
            // Posisi lokal relatif ke `anchor` (titik tengah jalur): tepat di
            // atas titik tengah jalur checkpoint.
            position: SIMD3<Float>(0, lightHeight, 0),
            yawDegrees: 0,
            // Pitch curam ke bawah supaya cone cahaya menyinari lantai jalur,
            // bukan menembak lurus ke horizon.
            pitchDegrees: -70,
            beamSpread: .spread
        )

        let bundle = SceneLightEntityFactory.makeLight(configuration: configuration, selected: false)
        anchor.addChild(bundle.root)
        pathLightBundle = bundle

        collisionSystem.registerObstacle(
            id: pathLightID,
            position: SIMD3<Float>(anchor.position.x, floorY + lightHeight, anchor.position.z),
            radius: SceneLightSystem.lightObstacleRadius
        )
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

        // `UnlitMaterial` (bukan `SimpleMaterial`) supaya teksnya tidak kena
        // shading dari lampu virtual jalur (`placePathLight`) — hasilnya
        // warnanya selalu tampil PENUH & rata seperti menyala sendiri,
        // persis efek tanda neon, bukan teks putih polos yang bisa terlihat
        // agak redup kalau posisinya membelakangi lampu.
        let material = UnlitMaterial(color: Self.neonLabelColor)
        let label = ModelEntity(mesh: mesh, materials: [material])
        label.scale = SIMD3<Float>(repeating: 0.5)

        // BillboardComponent bikin teks selalu menghadap kamera, jadi tidak
        // ikut berputar dengan orientasi checkpoint shape (yang bisa punya
        // rotasi sendiri). Tanpa ini teks bisa terbaca dari samping/belakang
        // saat anak mengelilingi checkpoint. Pusat rotasi billboard ada di
        // titik asal entity, jadi bounds sudah otomatis "centered" terhadap
        // sumbu itu tanpa perlu koreksi tambahan.
        label.components.set(BillboardComponent())

        let bounds = mesh.bounds
        label.position = SIMD3<Float>(-bounds.extents.x * 0.25, aboveHeight + 0.2, 0)

        // Lempeng tipis transparan warna sama tepat di belakang teks — bikin
        // efek "glow"/halo neon di sekitar hurufnya, karena tanpa backdrop
        // teks tipis kadang tenggelam dengan latar kamera yang ramai warna.
        // Ditaruh sebagai child label supaya otomatis ikut billboard yang
        // sama dan posisinya selalu pas di belakang teks.
        label.addChild(makeLabelGlow(textBounds: bounds))

        return label
    }

    /// Lempeng persegi tipis, translucent, warna neon yang sama dengan teks
    /// label — dipasang tepat di belakang teks (`makeLabel`) sebagai
    /// backdrop bercahaya, supaya nama bentuk makin gampang terbaca dari
    /// jauh di tengah pencahayaan AR yang berubah-ubah.
    private func makeLabelGlow(textBounds: BoundingBox) -> ModelEntity {
        let horizontalPadding: Float = 0.09
        let verticalPadding: Float = 0.07
        let width = max(textBounds.extents.x + horizontalPadding, 0.05)
        let height = max(textBounds.extents.y + verticalPadding, 0.05)

        let mesh = MeshResource.generatePlane(width: width, height: height)
        var material = UnlitMaterial(color: Self.neonLabelColor.withAlphaComponent(0.35))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.35))
        let glow = ModelEntity(mesh: mesh, materials: [material])

        // Sedikit mundur di sumbu Z (belakang teks) supaya tidak z-fighting
        // dengan huruf yang punya extrusion tipis, dan disejajarkan ke
        // tengah bounding box teks.
        glow.position = SIMD3<Float>(textBounds.center.x, textBounds.center.y, textBounds.center.z - 0.01)
        return glow
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

    // MARK: - Objek muncul satu per satu (bukan langsung semua bersamaan)

    /// Sembunyikan bentuk 3D checkpoint yang belum giliran ditemukan. Cuma
    /// checkpoint yang SUDAH pernah didatangi + checkpoint yang sedang jadi
    /// target sekarang (`nextTargetCheckpointIndex`) yang ditampilkan;
    /// checkpoint berikutnya baru muncul begitu anak sampai di checkpoint
    /// sebelumnya. Kalau tidak ada target lagi (semua sudah dikunjungi, atau
    /// fase sudah lewat eksplorasi seperti quiz/kembali ke start), semua
    /// checkpoint ditampilkan lagi supaya tetap kelihatan di background.
    private func syncCheckpointVisibility() {
        guard !checkpointEntities.isEmpty else { return }
        let targetIndex = viewModel.nextTargetCheckpointIndex

        for index in checkpointEntities.indices {
            let shouldShow: Bool
            if let target = targetIndex {
                shouldShow = index <= target
            } else {
                shouldShow = true
            }
            checkpointEntities[index].isEnabled = shouldShow
        }
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
        let cameraTransform = frame.camera.transform
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
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

        updateWaypoint(cameraTransform: cameraTransform, cameraPosition: cameraPosition, targetPosition: markerWorldPositions[index])

        let distance = horizontalDistance(cameraPosition, markerWorldPositions[index])

        if distance < Self.markerRadius {
            guard lastArrivedIndex != index else { return }
            lastArrivedIndex = index
            viewModel.arrive(atCheckpointIndex: index)
        } else if lastArrivedIndex == index {
            lastArrivedIndex = nil
        }
    }

    /// Hitung sudut panah kompas ke checkpoint tujuan, RELATIF terhadap arah
    /// hadap kamera sekarang (0° = tujuan persis di depan). Dipakai
    /// `WaypointArrowOverlay` (SwiftUI) buat memutar ikon panah supaya anak
    /// tahu harus belok ke arah mana untuk menemukan checkpoint berikutnya.
    private func updateWaypoint(cameraTransform: simd_float4x4, cameraPosition: SIMD3<Float>, targetPosition: SIMD3<Float>) {
        let forward = horizontalForward(of: cameraTransform)
        let toTarget = SIMD2<Float>(targetPosition.x - cameraPosition.x, targetPosition.z - cameraPosition.z)
        let toTargetLength = simd_length(toTarget)
        guard toTargetLength > 0.01 else { return }
        let toTargetNormalized = toTarget / toTargetLength

        // Sudut bertanda antara arah hadap kamera & arah ke target: dot buat
        // besar sudut, cross (komponen-z 2D) buat tandanya (kiri/kanan).
        let dot = forward.x * toTargetNormalized.x + forward.y * toTargetNormalized.y
        let cross = forward.x * toTargetNormalized.y - forward.y * toTargetNormalized.x
        let angleDegrees = Double(atan2(cross, dot) * 180 / .pi)

        viewModel.updateWaypoint(bearingDegrees: angleDegrees, distanceMeters: Double(toTargetLength))
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
