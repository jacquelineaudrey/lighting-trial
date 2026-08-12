import Foundation
import Combine
import RealityKit

/// Fase-fase Level 4.
///
/// onboarding -> scanningSurface -> positioning -> transitionTrivia ->
/// exploring -> closing -> review -> completed
///
/// Catatan: fase navigasi/waypoint (pilih arah + jalan ke titik hijau) SUDAH
/// DIHAPUS. Begitu onboarding selesai, anak langsung bisa menahan tombol
/// "Jadi Lampu"/"Jadi Objek" di fase `.positioning` — tidak perlu jalan ke
/// titik tertentu dulu.
///
/// `.scanningSurface` (SAMA seperti fase di `Level1Phase`) dipasang di
/// antara `.onboarding` dan `.positioning` karena "Jadi Lampu"/"Jadi Objek"
/// di `.positioning` cuma berfungsi begitu scene (cube + lampu) sudah
/// ditempel `ARSceneCoordinator` — dan itu baru terjadi setelah permukaan
/// selesai di-scan. Sebelumnya anak bisa sampai di `.positioning` sebelum
/// scan selesai tanpa tahu kenapa tombolnya belum berfungsi.
enum Level4Phase: Equatable {
    case onboarding               // dialog karakter sebelum interaksi
    case scanningSurface          // ARKit lagi scan lantai/permukaan (sebelum cube+lampu muncul)
    case positioning              // hold-button pertama: geser posisi lampu/objek
    case transitionTrivia         // dialog transisi menjelaskan light & ground projection
    case exploring                // eksplorasi bebas dengan mekanisme hold yang sama
    case closing                   // dialog penutup
    case review                    // ringkasan pembelajaran
    case completed
}

/// Siapa yang sedang "dikendalikan" anak lewat tombol hold saat ini.
enum HoldRole: Equatable {
    case none
    case light
    case object
}

/// Tanggung jawab file:
/// - state machine fase Level 4 (mirip pola `Level1ViewModel`),
/// - logic "hold button -> jadi lampu/objek -> jalan buat ganti posisi" yang
///   menerjemahkan pergerakan kamera (device berjalan) menjadi perubahan
///   posisi lampu/objek di `ARSceneViewModel` — TANPA menyentuh
///   `ARSceneCoordinator`/rendering shadow yang sudah ada & sudah teruji.
///
/// Catatan penting soal koordinat: `ARSceneViewModel` menyimpan posisi
/// lampu/objek dalam ruang LOKAL relatif ke anchor tempat scene ditempatkan.
/// `cameraPosition`/`cameraForward` yang masuk ke `updateHold` di bawah ini
/// SUDAH dalam ruang lokal yang sama itu — dikonversi oleh pemanggilnya lewat
/// `ARViewHandle.currentCameraPositionInSceneAnchorSpace` &
/// `currentHorizontalForwardInSceneAnchorSpace` (yang memakai
/// `anchor.convert(position:from:)`/`anchor.convert(direction:from:)`, pola
/// yang sama dengan `ARSceneCoordinator.moveObject`/`moveSelectedLight`).
///
/// Mekanisme geser memakai delta kamera selama tombol ditahan: posisi awal
/// lampu/objek tetap jadi anchor, lalu perpindahan kamera dari titik awal hold
/// diterapkan ke posisi itu. Jadi benda tidak meloncat ke dekat kamera saat
/// tombol ditekan.
@MainActor
final class Level4ViewModel: ObservableObject {

    /// ViewModel scene AR yang sudah ada di project ini — dipakai apa adanya
    /// supaya shadow & ground projection tetap dihitung oleh
    /// `ARSceneCoordinator` yang sudah ada, bukan ditulis ulang.
    let arSceneViewModel = ARSceneViewModel()

    let onboardingDialog = Level4Content.onboardingDialog
    let transitionDialog = Level4Content.transitionDialog
    let closingDialog = Level4Content.closingDialog
    let reviewPoints = Level4Content.learningReviewPoints

    @Published private(set) var phase: Level4Phase = .onboarding
    @Published private(set) var onboardingIndex = 0
    @Published private(set) var transitionIndex = 0
    @Published private(set) var closingIndex = 0

    @Published private(set) var activeHoldRole: HoldRole = .none
    /// Sudah pernah menggeser lampu/objek minimal sekali — dipakai untuk
    /// membuka tombol "Lanjut" di fase positioning (anak harus coba dulu
    /// sebelum lanjut ke penjelasan).
    @Published private(set) var hasPositionedOnce = false

    /// Posisi kamera dan benda saat hold dimulai. Selama tombol ditahan, gerak
    /// kamera dari titik awal ini diterapkan ke posisi awal benda.
    private var holdStartCameraPosition: SIMD3<Float>?
    private var holdStartEntityPosition: SIMD3<Float>?

    private let progressStore: GameProgressStore
    private var cancellables = Set<AnyCancellable>()

    init(progressStore: GameProgressStore? = nil) {
        self.progressStore = progressStore ?? GameProgressStore.shared
        // Level 4 tidak pernah menampilkan instruksi "tap layar untuk menaruh
        // object" ke anak — jadi scene (cube + lampu) harus muncul otomatis
        // begitu ARKit menemukan permukaan datar, sama seperti jalur checkpoint
        // di Level 1 yang ditaruh otomatis saat overlay scan non-aktif.
        arSceneViewModel.autoPlaceOnSurfaceFound = true

        // Posisi hanya boleh berubah ketika tombol "Jadi Lampu" atau
        // "Jadi Objek" sedang ditahan. Drag biasa di atas scene diarahkan ke
        // rotasi/arah, bukan ke pemindahan posisi.
        arSceneViewModel.directManipulationRotatesOnly = true

        // Level 4 harus pakai cube AR yang polos/jelas, sama seperti Level 1 —
        // BUKAN object yang menyatu photoreal dengan pencahayaan ruangan asli
        // (yang bikin kelihatan seperti "benda sungguhan"). Dipaksa eksplisit
        // di sini (bukan cuma mengandalkan default `ObjectConfiguration`)
        // supaya tetap benar walau default berubah nanti.
        arSceneViewModel.usesRealisticEnvironmentLighting = false
        arSceneViewModel.updateSelectedObject { object in
            object.type = .cube
            object.importedModel = nil
        }

        // Begitu `ARSceneCoordinator` selesai menempel cube+lampu (dipicu
        // otomatis oleh `autoPlaceOnSurfaceFound` saat permukaan ketemu),
        // `arSceneViewModel.isObjectPlaced` jadi true. Itu sinyal yang sama
        // dipakai `ContentView`/sandbox untuk tahu penempatan selesai — di
        // sini dipakai untuk lulus dari `.scanningSurface`, mirip
        // `Level1ViewModel.finishScanning()`.
        arSceneViewModel.$isObjectPlaced
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaced in
                guard isPlaced else { return }
                self?.finishScanning()
            }
            .store(in: &cancellables)
    }

    // MARK: - 1. Onboarding

    var currentOnboardingLine: DialogLine { onboardingDialog[onboardingIndex] }
    var isLastOnboardingLine: Bool { onboardingIndex == onboardingDialog.count - 1 }

    func advanceOnboarding() {
        guard phase == .onboarding else { return }
        if isLastOnboardingLine {
            // Sebelum bisa geser lampu/objek, permukaan harus selesai
            // di-scan dulu — lihat `.scanningSurface` di `Level4Phase`.
            phase = .scanningSurface
        } else {
            onboardingIndex += 1
        }
    }

    // MARK: - 1b. Scan permukaan (sebelum cube + lampu muncul)

    /// Dipanggil otomatis begitu `arSceneViewModel.isObjectPlaced` jadi true
    /// (lihat `init`), atau lewat tombol debug di `ScanningSurfaceOverlay`.
    func finishScanning() {
        guard phase == .scanningSurface else { return }
        phase = .positioning
    }

    // MARK: - 2 & 4. Hold berbasis delta kamera (dipakai di fase positioning DAN exploring)

    /// Dipanggil saat tombol "Jadi Lampu"/"Jadi Objek" mulai ditahan. Cuma
    /// perlu tahu posisi kamera dan posisi benda SAAT INI supaya `updateHold`
    /// bisa menerapkan delta kamera tanpa membuat benda meloncat ke kamera.
    func beginHold(as role: HoldRole, cameraPosition: SIMD3<Float>) {
        guard phase == .positioning || phase == .exploring, role != .none else { return }
        activeHoldRole = role
        holdStartCameraPosition = cameraPosition
        holdStartEntityPosition = role == .light
            ? arSceneViewModel.selectedLight.position
            : arSceneViewModel.selectedObject.position
        arSceneViewModel.interactionMode = role == .light ? .moveLight : .moveObject
    }

    /// Dipanggil berulang kali (mis. tiap tick timer ~15-30Hz) selama tombol
    /// masih ditahan, dengan posisi kamera device SAAT ITU JUGA (sudah dalam
    /// ruang lokal anchor scene — lihat catatan koordinat di atas). Objek
    /// bergerak horizontal mengikuti kamera, sedangkan lampu juga mengikuti
    /// perubahan tinggi kamera supaya bisa digeser pada sumbu y.
    func updateHold(cameraPosition: SIMD3<Float>) {
        guard activeHoldRole != .none,
              let startCameraPosition = holdStartCameraPosition,
              let startEntityPosition = holdStartEntityPosition else { return }

        let cameraDelta = cameraPosition - startCameraPosition

        switch activeHoldRole {
        case .light:
            let newPosition = startEntityPosition + cameraDelta
            arSceneViewModel.updateLightPosition(id: arSceneViewModel.selectedLightID, position: newPosition)
        case .object:
            let newPosition = startEntityPosition + SIMD3<Float>(cameraDelta.x, 0, cameraDelta.z)
            arSceneViewModel.updateObjectPosition(id: arSceneViewModel.selectedObjectID, position: newPosition)
        case .none:
            break
        }
    }

    /// Dipanggil saat tombol dilepas — kembali ke mode "lihat scene" biasa.
    /// Posisi terakhir lampu/objek dibiarkan apa adanya (tidak "dilepas jatuh").
    func endHold() {
        guard activeHoldRole != .none else { return }
        activeHoldRole = .none
        holdStartCameraPosition = nil
        holdStartEntityPosition = nil
        hasPositionedOnce = true
    }

    // MARK: - 3. Transisi ke penjelasan light & ground projection

    func proceedToTransitionTrivia() {
        guard phase == .positioning, hasPositionedOnce else { return }
        phase = .transitionTrivia
        transitionIndex = 0
    }

    var currentTransitionLine: DialogLine { transitionDialog[transitionIndex] }
    var isLastTransitionLine: Bool { transitionIndex == transitionDialog.count - 1 }

    func advanceTransition() {
        guard phase == .transitionTrivia else { return }
        if isLastTransitionLine {
            phase = .exploring
        } else {
            transitionIndex += 1
        }
    }

    // MARK: - 5. Eksplorasi bebas -> closing

    func finishExploring() {
        guard phase == .exploring else { return }
        phase = .closing
        closingIndex = 0
    }

    var currentClosingLine: DialogLine { closingDialog[closingIndex] }
    var isLastClosingLine: Bool { closingIndex == closingDialog.count - 1 }

    func advanceClosing() {
        guard phase == .closing else { return }
        if isLastClosingLine {
            phase = .review
        } else {
            closingIndex += 1
        }
    }

    // MARK: - 6. Learning review -> selesai

    func finishReview() {
        guard phase == .review else { return }
        phase = .completed
        progressStore.markLevelCompleted(Level4Content.levelID)
    }
}
