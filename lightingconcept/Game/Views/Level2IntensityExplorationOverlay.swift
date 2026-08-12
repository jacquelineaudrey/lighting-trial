import SwiftUI

struct Level2IntensityExplorationOverlay: View {
    let viewModel: Level2ViewModel
    let replayNarration: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Label("Misi: Terang dan Redup", systemImage: "sun.max.fill")
                .font(.title3)
                .bold()

            Text("Usap naik atau turun di sisi kiri atau kanan layar.")
                .font(.headline)
                .multilineTextAlignment(.center)

            ProgressView(value: Double(viewModel.intensityPercentage), total: 100)
                .tint(.yellow)
                .accessibilityLabel("Kekuatan cahaya")
                .accessibilityValue("\(viewModel.intensityPercentage) persen, \(intensityName)")

            HStack {
                Label(
                    "Redup",
                    systemImage: viewModel.hasReachedDimIntensity ? "checkmark.circle.fill" : "circle"
                )
                Spacer()
                Label(intensityName, systemImage: intensitySymbol)
                    .font(.title3)
                    .bold()
                Spacer()
                Label(
                    "Terang",
                    systemImage: viewModel.hasReachedBrightIntensity ? "checkmark.circle.fill" : "circle"
                )
            }
            .font(.subheadline)

            Text("Percobaan \(viewModel.intensityProgress) dari 2")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Level2ReplayNarrationButton(action: replayNarration)

            if viewModel.hasCompletedIntensityTask {
                Label("Cahaya redup dan terang sudah dicoba!", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)

                Button("Lanjut", action: viewModel.continueFromIntensityTask)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(20)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }

    private var intensityName: String {
        if viewModel.intensityPercentage < 34 {
            "Redup"
        } else if viewModel.intensityPercentage > 70 {
            "Terang"
        } else {
            "Sedang"
        }
    }

    private var intensitySymbol: String {
        if viewModel.intensityPercentage < 34 {
            "sun.min.fill"
        } else if viewModel.intensityPercentage > 70 {
            "sun.max.fill"
        } else {
            "sun.max"
        }
    }
}
