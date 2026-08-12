import SwiftUI
import RealityKit

/// Root view Level 4. Kamera AR (lengkap dengan lampu, objek, dan bayangan
/// ground-projection yang sudah ditangani `ARSceneCoordinator`) selalu tampil
/// di background; overlay di atasnya berganti sesuai `viewModel.phase`.
struct Level4FlowView: View {
    @StateObject private var viewModel = Level4ViewModel()
    @StateObject private var arViewHandle = ARViewHandle()
    @Environment(\.dismiss) private var dismiss

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

// MARK: - Tombol hold-to-walk (inti interaksi Level 4)

/// Tekan & tahan -> anak "jadi" lampu atau objek, dan berjalan memindahkan
/// posisinya lewat `Level4ViewModel.updateHold`. Lepas -> balik ke mode lihat.
private struct HoldToWalkButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let role: HoldRole
    @ObservedObject var viewModel: Level4ViewModel
    let arViewHandle: ARViewHandle

    @State private var isHolding = false
    @State private var pollTimer: Timer?

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
    }

    private func startHold() {
        guard !isHolding, let start = arViewHandle.currentCameraPosition else { return }
        isHolding = true
        viewModel.beginHold(as: role, cameraPosition: start)

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { _ in
            guard let position = arViewHandle.currentCameraPosition else { return }
            Task { @MainActor in viewModel.updateHold(cameraPosition: position) }
        }
    }

    private func stopHold() {
        guard isHolding else { return }
        isHolding = false
        pollTimer?.invalidate()
        pollTimer = nil
        viewModel.endHold()
    }
}

// MARK: - Fase positioning (percobaan pertama hold-to-walk)

private struct PositioningOverlay: View {
    @ObservedObject var viewModel: Level4ViewModel
    let arViewHandle: ARViewHandle

    var body: some View {
        VStack(spacing: 14) {
            Text("Tahan salah satu tombol lalu jalan untuk menggeser posisinya")
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
            Text("Jelajahi bebas! Coba geser lampu dan objeknya, lihat bayangannya berubah 👀")
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
