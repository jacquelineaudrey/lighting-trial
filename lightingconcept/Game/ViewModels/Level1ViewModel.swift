import Foundation
import Combine

/// Fase-fase yang dilalui pemain selama satu sesi Level 1.
///
/// onboarding -> exploring -> quiz -> returningToStart -> completed
enum Level1Phase: Equatable {
    case onboarding          // dialog karakter sebelum interaksi
    case scanningSurface     // ARKit lagi scan lantai/permukaan (sebelum checkpoint 1 muncul)
    case exploring           // jalan antar checkpoint, lihat bentuk & tekstur
    case quiz                // trivia quiz di akhir eksplorasi
    case returningToStart    // diarahkan balik ke checkpoint pertama
    case completed           // level selesai, progres tersimpan
}

/// Tanggung jawab file:
/// - jadi satu-satunya sumber kebenaran untuk state Level 1 (fase, posisi checkpoint,
///   tekstur yang sedang dilihat, progres quiz),
/// - TIDAK tahu apa-apa soal AR/RealityKit — supaya bisa dites & di-preview tanpa device.
///   Saat AR sudah siap, `ARSceneCoordinator`/proximity system tinggal memanggil
///   `arrive(atCheckpointIndex:)` ketika anak berjalan mendekati sebuah ARAnchor.
@MainActor
final class Level1ViewModel: ObservableObject {

    // MARK: Data statis level
    let checkpoints = Level1Content.checkpoints
    let onboardingDialog = Level1Content.onboardingDialog
    let quizQuestions = Level1Content.quiz

    // MARK: State yang dipublish ke UI
    @Published private(set) var phase: Level1Phase = .onboarding

    @Published private(set) var onboardingIndex = 0

    @Published private(set) var currentCheckpointIndex = 0
    @Published private(set) var currentTextureIndex = 0

    /// Index tekstur yang sudah pernah dilihat, per checkpoint — dipakai untuk tahu
    /// kapan anak "selesai" menjelajah satu checkpoint (dan seluruh level).
    private var visitedTextures: [Int: Set<Int>] = [:]

    @Published private(set) var quizIndex = 0
    @Published private(set) var quizScore = 0
    @Published var lastAnswerWasCorrect: Bool?

    // MARK: - Panah waypoint (arah ke checkpoint berikutnya)

    /// Sudut panah kompas dalam derajat, RELATIF terhadap arah hadap kamera:
    /// 0 = checkpoint tujuan persis di depan, positif = anak harus belok
    /// kanan, negatif = belok kiri. Dihitung tiap frame oleh
    /// `Level1ARCoordinator` (lihat `updateWaypoint(cameraTransform:...)`).
    @Published private(set) var waypointBearingDegrees: Double = 0
    /// Jarak lurus (meter) dari kamera ke checkpoint tujuan sekarang.
    @Published private(set) var waypointDistanceMeters: Double = 0
    /// `false` sebelum ada data waypoint pertama, atau saat sedang di fase
    /// yang tidak punya "tujuan berjalan" (mis. quiz, onboarding).
    @Published private(set) var hasWaypointTarget = false

    /// Dipanggil `Level1ARCoordinator` tiap frame ARKit selama fase
    /// eksplorasi/kembali-ke-start. Nilainya dipakai coordinator sendiri
    /// untuk memutar objek panah arah RealityKit (`updateDirectionIndicator`)
    /// yang sekarang mengambang di dunia AR, menggantikan badge kompas
    /// statis SwiftUI yang dulu dipakai di sini.
    func updateWaypoint(bearingDegrees: Double, distanceMeters: Double) {
        waypointBearingDegrees = bearingDegrees
        waypointDistanceMeters = distanceMeters
        hasWaypointTarget = true
    }

    /// Dipanggil saat keluar dari fase yang punya target berjalan (mis. masuk
    /// quiz), supaya panah waypoint tidak nyangkut menunjuk ke checkpoint
    /// lama begitu ditampilkan lagi nanti.
    func clearWaypoint() {
        hasWaypointTarget = false
    }

    private let progressStore: GameProgressStore

    /// Reuse `ARSceneViewModel` dari lightingconcept HANYA untuk mesin
    /// tracking progres LiDAR-nya (`updateLiDARScan`, `resetLiDARScan`,
    /// `lidarPlacementProgress`, `isReadyForPlacement`, `isLiDARAvailable`) —
    /// pola yang sama dengan `Level4ViewModel.arSceneViewModel`. Level 1 tidak
    /// memakai object/light management dari view model ini sama sekali;
    /// `Level1ARCoordinator` cuma memberi makan data mesh scan LiDAR ke sini
    /// supaya `ScanningSurfaceOverlay` bisa menampilkan kartu persentase yang
    /// sama persis dengan `LiDARScanProgressCard` di mode sandbox utama.
    let arSceneViewModel = ARSceneViewModel()

    init(progressStore: GameProgressStore? = nil) {
        self.progressStore = progressStore ?? GameProgressStore.shared
        // Catatan: checkpoint 0 SENGAJA tidak ditandai "sudah dikunjungi" di sini.
        // Sekarang semua checkpoint (termasuk yang pertama) punya lingkaran biru
        // di dunia nyata yang harus didatangi jalan kaki — lihat
        // `nextTargetCheckpointIndex` & `Level1ARCoordinator`.
    }

    // MARK: - 1. Trivia onboarding (dialog karakter)

    var currentDialogLine: DialogLine { onboardingDialog[onboardingIndex] }
    var isLastDialogLine: Bool { onboardingIndex == onboardingDialog.count - 1 }

    func advanceDialog() {
        guard phase == .onboarding else { return }
        if isLastDialogLine {
            phase = .scanningSurface
        } else {
            onboardingIndex += 1
        }
    }

    // MARK: - 1b. Scan permukaan (sebelum checkpoint 1 muncul)

    /// Dipanggil oleh `Level1ARCoordinator` begitu ARKit selesai scan lantai
    /// (coaching overlay selesai) DAN checkpoint sudah ditaruh di dunia nyata.
    func finishScanning() {
        guard phase == .scanningSurface else { return }
        phase = .exploring
    }

    // MARK: - 2. Eksplorasi checkpoint & tekstur

    var currentCheckpoint: Checkpoint { checkpoints[currentCheckpointIndex] }
    var currentTexture: TextureStop { currentCheckpoint.shape.textures[currentTextureIndex] }

    var canGoToPreviousTexture: Bool { currentTextureIndex > 0 }
    var canGoToNextTexture: Bool { currentTextureIndex < currentCheckpoint.shape.textures.count - 1 }

    /// "langsung klik next aja untuk liat texture lain" — geser ke tekstur berikutnya
    /// pada bentuk yang sama, tanpa pindah checkpoint.
    func nextTexture() {
        guard phase == .exploring, canGoToNextTexture else { return }
        currentTextureIndex += 1
        markTextureVisited()
    }

    /// "bisa ada klik back juga liat texture sebelumnya"
    func previousTexture() {
        guard phase == .exploring, canGoToPreviousTexture else { return }
        currentTextureIndex -= 1
        markTextureVisited()
    }

    private func markTextureVisited() {
        visitedTextures[currentCheckpointIndex, default: []].insert(currentTextureIndex)
    }

    /// Sudah lihat semua tekstur di checkpoint yang sedang dikunjungi.
    var hasFinishedCurrentCheckpoint: Bool {
        let seen = visitedTextures[currentCheckpointIndex]?.count ?? 0
        return seen >= currentCheckpoint.shape.textures.count
    }

    /// Sudah lihat semua tekstur di SEMUA checkpoint -> siap ke quiz.
    var hasExploredAllCheckpoints: Bool {
        checkpoints.indices.allSatisfy { index in
            (visitedTextures[index]?.count ?? 0) >= checkpoints[index].shape.textures.count
        }
    }

    /// Sudah pernah tiba di checkpoint yang sedang ditampilkan (dipakai UI untuk
    /// tahu apakah kontrol tekstur boleh ditampilkan, atau anak masih harus
    /// jalan ke lingkaran birunya dulu).
    var hasArrivedAtCurrentCheckpoint: Bool {
        visitedTextures[currentCheckpointIndex] != nil
    }

    /// Checkpoint berikutnya yang jadi target "lingkaran biru" ala GTA — checkpoint
    /// dengan index terkecil yang BELUM pernah dikunjungi sama sekali. `nil` kalau
    /// semua checkpoint sudah dikunjungi (tidak ada target lagi selama eksplorasi).
    /// `Level1ARCoordinator` memakai ini untuk tahu lingkaran biru mana yang harus
    /// menyala & dicek jaraknya ke kamera.
    var nextTargetCheckpointIndex: Int? {
        guard phase == .exploring else { return nil }
        return checkpoints.indices.first { visitedTextures[$0] == nil }
    }

    /// Dipanggil ketika anak tiba di sebuah checkpoint.
    /// - Sumber panggilan utama: `Level1ARCoordinator` (proximity-detection — jarak
    ///   device ke posisi dunia nyata checkpoint di bawah ambang batas tertentu).
    /// - Bisa juga dipanggil manual (mis. tombol debug di simulator/preview) karena
    ///   fungsi ini idempotent terhadap fase yang sedang berjalan.
    /// - Kalau dipanggil dengan index 0 saat fase `.returningToStart`, level dianggap selesai.
    func arrive(atCheckpointIndex index: Int) {
        guard checkpoints.indices.contains(index) else { return }

        if phase == .exploring {
            currentCheckpointIndex = index
            currentTextureIndex = 0
            markTextureVisited()
        } else if phase == .returningToStart, index == 0 {
            completeLevel()
        }
    }

    func goToNextCheckpoint() {
        arrive(atCheckpointIndex: min(currentCheckpointIndex + 1, checkpoints.count - 1))
    }

    func goToPreviousCheckpoint() {
        arrive(atCheckpointIndex: max(currentCheckpointIndex - 1, 0))
    }
    // Catatan: tidak ada lagi navigasi manual lewat tombol antar checkpoint —
    // sekarang murni jalan kaki ke lingkaran biru (lihat `nextTargetCheckpointIndex`
    // & `Level1ARCoordinator`). Kedua fungsi di atas tetap dipertahankan untuk
    // dipakai debug/preview tanpa AR kalau perlu.

    // MARK: - 3. Quiz

    /// "Ketika udah kelar, trivia quiz nanyain bentuk" — hanya bisa dimulai
    /// setelah semua checkpoint & tekstur sudah dijelajahi.
    func startQuiz() {
        guard phase == .exploring, hasExploredAllCheckpoints else { return }
        phase = .quiz
        quizIndex = 0
        quizScore = 0
        lastAnswerWasCorrect = nil
    }

    var currentQuestion: TriviaQuestion { quizQuestions[quizIndex] }

    @discardableResult
    func answer(with shape: GameShape) -> Bool {
        guard phase == .quiz, lastAnswerWasCorrect == nil else { return false }
        let isCorrect = shape.id == currentQuestion.correctShapeID
        lastAnswerWasCorrect = isCorrect
        if isCorrect { quizScore += 1 }
        return isCorrect
    }

    func nextQuestion() {
        guard phase == .quiz else { return }
        lastAnswerWasCorrect = nil
        if quizIndex == quizQuestions.count - 1 {
            // "Arahin user balik ke shape (checkpoint) pertama"
            phase = .returningToStart
        } else {
            quizIndex += 1
        }
    }

    // MARK: - 4. Penyelesaian level

    private func completeLevel() {
        phase = .completed
        progressStore.markLevelCompleted(Level1Content.levelID)
    }
}
