import SwiftUI

/// Instruksi dan progres scan yang identik di seluruh level AR.
struct SurfaceScanInstruction: View {
    @ObservedObject var sceneViewModel: ARSceneViewModel

    var body: some View {
        VStack {
            Text("📱👇 Arahkan iPad pelan-pelan ke lantai atau meja beberapa detik ya!")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(.top, 24)

            if sceneViewModel.isLiDARAvailable {
                LiDARScanProgressCard(viewModel: sceneViewModel)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            } else if sceneViewModel.surfaceState == .scanning {
                ProgressView("Scanning surface...")
                    .font(.subheadline)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
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
