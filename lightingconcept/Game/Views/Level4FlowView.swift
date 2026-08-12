import SwiftUI
import RealityKit

/// Root view Level 4. Kamera AR (lengkap dengan lampu, objek, dan bayangan
/// ground-projection yang sudah ditangani `ARSceneCoordinator`) selalu tampil
/// di background; overlay di atasnya berganti sesuai `viewModel.phase`.
struct Level4FlowView: View {
    @StateObject private var viewModel = Level4ViewModel()
    @StateObject private var arViewHandle = ARViewHandle()
    @Environment(\.dismiss) private var dismiss
    @State private var showsExitConfirmation = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Level4ARContainerView(viewModel: viewModel.arSceneViewModel, handle: arViewHandle)
                .ignoresSafeArea()

            switch viewModel.phase {
            case .onboarding:
                DialogOverlay(
                    line: viewModel.currentOnboardingLine,
                    buttonTitle: viewModel.isLastOnboardingLine ? "Ayo Coba!" : "Lanjut",
                    action: viewModel.advanceOnboarding
                )
            case .scanningSurface:
                ScanningSurfaceOverlay(viewModel: viewModel)
            case .positioning:
                PositioningOverlay(viewModel: viewModel, arViewHandle: arViewHandle)
            case .transitionTrivia:
                DialogOverlay(
                    line: viewModel.currentTransitionLine,
                    buttonTitle: viewModel.isLastTransitionLine ? "Mulai Jelajah!" : "Lanjut",
                    action: viewModel.advanceTransition
                )
            case .exploring:
                ExploringOverlay(viewModel: viewModel, arViewHandle: arViewHandle)
            case .closing:
                DialogOverlay(
                    line: viewModel.currentClosingLine,
                    buttonTitle: viewModel.isLastClosingLine ? "Lihat Rangkuman" : "Lanjut",
                    action: viewModel.advanceClosing
                )
            case .review:
                ReviewOverlay(points: viewModel.reviewPoints, onFinish: viewModel.finishReview)
            case .completed:
                LevelCompletedOverlay { dismiss() }
            }
        }
        // Tombol kembali khas level (lihat `LevelExitControls.swift`). Tidak
        // ditampilkan lagi begitu level sudah `.completed` — di fase itu
        // sudah ada tombol "Kembali ke Menu" sendiri di `LevelCompletedOverlay`
        // dan tidak ada progress tersisa yang perlu dikonfirmasi.
        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed {
                LevelBackButton { showsExitConfirmation = true }
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
        }
        .levelExitConfirmation(isPresented: $showsExitConfirmation) { dismiss() }
        .animation(.easeInOut, value: viewModel.phase)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Kartu dialog generik (dipakai di onboarding/transisi/closing)

private struct DialogOverlay: View {
    let line: DialogLine
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("🦉").font(.system(size: 56))
            Text(line.characterName)
                .font(.headline)
                .foregroundStyle(.blue)
            Text(line.text)
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text(buttonTitle)
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(.white)
            }
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26))
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

// MARK: - Scan permukaan (sebelum cube + lampu muncul)

/// Sama persis dengan `ScanningSurfaceOverlay` di `Level1FlowView` — pakai
/// `LiDARScanProgressCard` yang sama supaya semua level (1 & 4) menampilkan
/// progres scan permukaan dengan cara yang konsisten. Bedanya cuma teks
/// instruksinya (Level 4 nunggu kubus + lampu, bukan jalur checkpoint).
private struct ScanningSurfaceOverlay: View {
    @ObservedObject var viewModel: Level4ViewModel

    var body: some View {
        VStack {
            Text("📱👇 Arahkan iPad pelan-pelan ke lantai atau meja ya!")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(.top, 24)

            if viewModel.arSceneViewModel.isLiDARAvailable {
                LiDARScanProgressCard(viewModel: viewModel.arSceneViewModel)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            // TOMBOL DEBUG: Hapus tombol ini nanti kalau mau dirilis ke anak-anak
            Button(action: {
                viewModel.finishScanning() // Paksa lanjut ke fase positioning
            }) {
                Text("🛠 [Dev] Paksa Lewati Scan")
                    .font(.footnote.bold())
                    .padding(10)
                    .background(.red.opacity(0.8), in: Capsule())
                    .foregroundColor(.white)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tombol hold berbasis delta kamera (inti interaksi Level 4)

/// Tekan & tahan -> anak "jadi" lampu atau objek. Posisi kamera saat tombol
/// mulai ditekan jadi titik nol, lalu benda bergerak mengikuti delta kamera
/// selama ditahan. Lepas -> balik ke mode lihat, posisi terakhir dipertahankan.
private struct HoldToWalkButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let role: HoldRole
    @ObservedObject var viewModel: Level4ViewModel
    let arViewHandle: ARViewHandle

    @State private var isHolding = false
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isHolding ? tint : tint.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(.white)
            .scaleEffect(isHolding ? 1.05 : 1)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in pressing ? startHold() : stopHold() },
                perform: {}
            )
            .onDisappear {
                stopHold()
            }
    }

    private func startHold() {
        // Kalau scene belum ditempel (anchor belum ada), jangan mulai hold sama sekali.
        guard !isHolding,
              let startCameraPosition = arViewHandle.currentCameraPositionInSceneAnchorSpace else { return }

        isHolding = true
        viewModel.beginHold(as: role, cameraPosition: startCameraPosition)

        // ARViewHandle dan Level4ViewModel sama-sama main-actor owned.
        // Task ini juga berjalan di MainActor, sehingga pembacaan kamera tidak
        // lagi terjadi di Timer @Sendable closure (Swift 6 concurrency error).
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            while !Task.isCancelled && isHolding {
                if let position = arViewHandle.currentCameraPositionInSceneAnchorSpace {
                    viewModel.updateHold(cameraPosition: position)
                }

                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func stopHold() {
        guard isHolding else { return }

        isHolding = false
        pollTask?.cancel()
        pollTask = nil
        viewModel.endHold()
    }
}

// MARK: - Fase positioning (percobaan pertama hold-to-walk)

private struct PositioningOverlay: View {
    @ObservedObject var viewModel: Level4ViewModel
    let arViewHandle: ARViewHandle

    var body: some View {
        VStack(spacing: 14) {
            Text("Tahan tombol lalu gerakkan iPad untuk memindahkan posisi. Geser layar tanpa menahan tombol hanya mengubah arah.")
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                HoldToWalkButton(
                    title: "Jadi Lampu", systemImage: "lightbulb.fill", tint: .orange,
                    role: .light, viewModel: viewModel, arViewHandle: arViewHandle
                )
                HoldToWalkButton(
                    title: "Jadi Objek", systemImage: "cube.fill", tint: .blue,
                    role: .object, viewModel: viewModel, arViewHandle: arViewHandle
                )
            }

            if viewModel.hasPositionedOnce {
                Button("Lanjut") { viewModel.proceedToTransitionTrivia() }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Coba geser dulu salah satunya ya!")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }
}

// MARK: - Fase eksplorasi bebas (mekanisme sama, tanpa gating)

private struct ExploringOverlay: View {
    @ObservedObject var viewModel: Level4ViewModel
    let arViewHandle: ARViewHandle

    var body: some View {
        VStack(spacing: 14) {
            Text("Tahan tombol untuk memindahkan. Geser layar untuk mengubah arah lampu atau objek, lalu lihat bayangannya berubah 👀")
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                HoldToWalkButton(
                    title: "Jadi Lampu", systemImage: "lightbulb.fill", tint: .orange,
                    role: .light, viewModel: viewModel, arViewHandle: arViewHandle
                )
                HoldToWalkButton(
                    title: "Jadi Objek", systemImage: "cube.fill", tint: .blue,
                    role: .object, viewModel: viewModel, arViewHandle: arViewHandle
                )
            }

            Button("Selesai Menjelajah") { viewModel.finishExploring() }
                .buttonStyle(.bordered)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }
}

// MARK: - Learning review

private struct ReviewOverlay: View {
    let points: [String]
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Yuk, Ingat-Ingat Lagi! 📝")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .center)

            ForEach(points, id: \.self) { point in
                HStack(alignment: .top, spacing: 8) {
                    Text("⭐️")
                    Text(point)
                        .font(.subheadline)
                }
            }

            Button("Selesai") { onFinish() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }
}

// MARK: - Level selesai

private struct LevelCompletedOverlay: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🏆").font(.system(size: 64))
            Text("Level 4 Selesai!")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            Text("Kamu sudah paham posisi lampu dan bayangan (ground projection)!")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Kembali ke Menu") { onFinish() }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 24)
        .padding(.bottom, 60)
    }
}
