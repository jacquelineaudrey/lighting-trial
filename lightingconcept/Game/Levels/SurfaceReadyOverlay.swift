import SwiftUI

/// Instruksi dan progres scan yang identik di seluruh level AR.
struct SurfaceScanInstruction: View {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    @State private var fallbackProgress = 0.08

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: sceneViewModel.surfaceState == .found ? "checkmark.viewfinder" : "viewfinder")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(sceneViewModel.surfaceState == .found ? .green : .cyan)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(sceneViewModel.surfaceState == .found ? "Siap" : "Scan")
                            .font(.headline.weight(.bold))
                        Spacer()
                        Text("\(Int(scanProgress * 100))%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: scanProgress)
                        .tint(sceneViewModel.surfaceState == .found ? .green : .cyan)

                    HStack(spacing: 8) {
                        scanDot(isActive: scanProgress >= 0.25)
                        scanDot(isActive: scanProgress >= 0.55)
                        scanDot(isActive: scanProgress >= 0.85)
                    }
                    .accessibilityHidden(true)
                }
            }
            .padding(14)
            .frame(maxWidth: 420)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
        .onAppear(perform: startFallbackProgress)
    }

    private var scanProgress: Double {
        switch sceneViewModel.surfaceState {
        case .found, .placed:
            1
        case .scanning:
            sceneViewModel.isLiDARAvailable
                ? Double(sceneViewModel.lidarPlacementProgress)
                : fallbackProgress
        }
    }

    private func scanDot(isActive: Bool) -> some View {
        Circle()
            .fill(isActive ? Color.green : Color.secondary.opacity(0.28))
            .frame(width: 8, height: 8)
    }

    private func startFallbackProgress() {
        guard !sceneViewModel.isLiDARAvailable else { return }
        withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: false)) {
            fallbackProgress = 0.82
        }
    }
}

/// Konfirmasi singkat setelah permukaan dan posisi benda sudah dipilih.
/// Dipakai konsisten oleh semua level sebelum materi dimulai.
struct SurfaceReadyOverlay: View {
    let onContinue: () -> Void
    let onRescan: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Label("Permukaan Siap", systemImage: "checkmark.viewfinder")
                .font(.title3.bold())

            Text("Permukaan sudah ditemukan. Mau lanjut untuk menaruh benda, atau scan ulang permukaannya?")
                .font(.subheadline)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Scan Ulang", systemImage: "arrow.clockwise", action: onRescan)
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Button("Lanjut", systemImage: "arrow.right", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(20)
        .frame(maxWidth: 620)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }
}

struct LessonProgressCelebration: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
}

struct LessonProgressCelebrationOverlay: View {
    let celebration: LessonProgressCelebration

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(celebration.title).font(.headline.bold())
                Text(celebration.detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(celebration.title). \(celebration.detail)")
    }
}
