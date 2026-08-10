import Foundation
import Combine
import RealityKit

/// Fase-fase Level 4.
///
/// onboarding -> positioning -> transitionTrivia -> exploring -> closing -> review -> completed
enum Level4Phase: Equatable {
    case onboarding          // dialog karakter sebelum interaksi
    case positioning         // hold-button pertama: geser posisi lampu/objek
    case transitionTrivia    // dialog transisi menjelaskan light & ground projection
    case exploring           // eksplorasi bebas dengan mekanisme hold yang sama
    case closing              // dialog penutup
    case review               // ringkasan pembelajaran
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
/// lampu/objek dalam ruang lokal relatif ke anchor tempat scene ditempatkan
/// (skala kecil, meter). Supaya tidak perlu tahu transform anchor itu,
/// kita pakai **delta** posisi kamera dunia nyata sejak hold dimulai, lalu
/// tambahkan delta itu ke posisi tersimpan. Ini valid selama anchor scene
/// tidak berotasi terhadap dunia (anchor ditempatkan lurus, sesuai perilaku
/// placement yang ada sekarang).
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

    private var holdStartCameraPosition: SIMD3<Float>?
    private var holdStartConfiguredPosition: SIMD3<Float>?

    private let progressStore: GameProgressStore

    init(progressStore: GameProgressStore = .shared) {
        self.progressStore = progressStore
    }

    // MARK: - 1. Onboarding

    var currentOnboardingLine: DialogLine { onboardingDialog[onboardingIndex] }
    var isLastOnboardingLine: Bool { onboardingIndex == onboardingDialog.count - 1 }

    func advanceOnboarding() {
        guard phase == .onboarding else { return }
        if isLastOnboardingLine {
            phase = .positioning
        } else {
            onboardingIndex += 1
        }
    }

    // MARK: - 2 & 4. Hold-to-walk (dipakai di fase positioning DAN exploring)

    /// Dipanggil saat tombol "Jadi Lampu"/"Jadi Objek" mulai ditahan.
    func beginHold(as role: HoldRole, cameraPosition: SIMD3<Float>) {
        guard phase == .positioning || phase == .exploring, role != .none else { return }
        activeHoldRole = role
        holdStartCameraPosition = cameraPosition
        holdStartConfiguredPosition = role == .light
            ? arSceneViewModel.selectedLight.position
            : arSceneViewModel.selectedObject.position
        arSceneViewModel.interactionMode = role == .light ? .moveLight : .moveObject
    }

    /// Dipanggil berulang kali (mis. tiap tick timer ~15-30Hz) selama tombol
    /// masih ditahan, dengan posisi kamera device saat ini.
    func updateHold(cameraPosition: SIMD3<Float>) {
        guard activeHoldRole != .none,
              let startCamera = holdStartCameraPosition,
              let startConfigured = holdStartConfiguredPosition else { return }

        let delta = cameraPosition - startCamera
        // Cuma geser horizontal (mengikuti arah jalan anak) — tinggi lampu/objek
        // tetap seperti semula supaya hasilnya tidak liar kalau device sedikit naik-turun.
        var newPosition = startConfigured
        newPosition.x += delta.x
        newPosition.z += delta.z

        switch activeHoldRole {
        case .light:
            arSceneViewModel.updateLightPosition(id: arSceneViewModel.selectedLightID, position: newPosition)
        case .object:
            arSceneViewModel.updateObjectPosition(id: arSceneViewModel.selectedObjectID, position: newPosition)
        case .none:
            break
        }
    }

    /// Dipanggil saat tombol dilepas — kembali ke mode "lihat scene" biasa.
    func endHold() {
        guard activeHoldRole != .none else { return }
        activeHoldRole = .none
        holdStartCameraPosition = nil
        holdStartConfiguredPosition = nil
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
