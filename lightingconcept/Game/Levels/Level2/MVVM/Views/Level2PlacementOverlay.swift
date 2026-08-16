import Combine
import SwiftUI

struct Level2PlacementOverlay: View {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    let replayNarration: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Label("Cari Tempat untuk Benda", systemImage: "viewfinder")
                .font(.title3)
                .bold()

            Text(guidanceText)
                .font(.headline)
                .multilineTextAlignment(.center)

            if sceneViewModel.isLiDARAvailable {
                LiDARScanProgressCard(viewModel: sceneViewModel)
            } else if sceneViewModel.surfaceState == .scanning {
                ProgressView("Scanning surface...")
                    .font(.subheadline)
            }

            Button(
                "Taruh Benda di Tengah",
                systemImage: "cube.fill",
                action: sceneViewModel.placeSceneAtScreenCenter
            )
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Menaruh benda pada permukaan di tengah layar")

            if let placementFeedback = sceneViewModel.placementFeedback {
                Label(placementFeedback, systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Level2ReplayNarrationButton(action: replayNarration)
        }
        .padding(20)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }

    private var guidanceText: String {
        switch sceneViewModel.surfaceState {
        case .scanning:
            "Arahkan titik tengah layar ke meja atau lantai, lalu tekan tombol di bawah."
        case .found:
            "Tempatnya ditemukan! Tekan tombol untuk menaruh benda."
        case .placed:
            "Benda sudah siap!"
        }
    }
}
