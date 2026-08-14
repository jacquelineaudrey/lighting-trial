import SwiftUI

struct Level2SpreadExplorationOverlay: View {
    let viewModel: Level2ViewModel
    let replayNarration: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Label("Misi: Ubah Lebar Cahaya", systemImage: "arrow.left.and.right")
                .font(.title3)
                .bold()

            Text("Rapatkan dan jauhkan dua ibu jari di layar.")
                .font(.headline)
                .multilineTextAlignment(.center)

            ProgressView(
                value: Double(viewModel.beamSpreadDegrees - Level2ViewModel.minimumBeamAngle),
                total: Double(Level2ViewModel.maximumBeamAngle - Level2ViewModel.minimumBeamAngle)
            )
            .tint(.orange)
            .accessibilityLabel("Lebar cahaya")
            .accessibilityValue("\(Int(viewModel.beamSpreadDegrees.rounded())) derajat")

            HStack {
                Label(
                    "Sempit",
                    systemImage: viewModel.hasReachedNarrowSpread ? "checkmark.circle.fill" : "circle"
                )
                Spacer()
                Text("\(Int(viewModel.beamSpreadDegrees.rounded()))°")
                    .font(.title3)
                    .bold()
                Spacer()
                Label(
                    "Lebar",
                    systemImage: viewModel.hasReachedWideSpread ? "checkmark.circle.fill" : "circle"
                )
            }
            .font(.subheadline)

            Text("Percobaan \(viewModel.spreadProgress) dari 2")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Level2ReplayNarrationButton(action: replayNarration)

            if viewModel.hasCompletedSpreadTask {
                Label("Cahaya sempit dan lebar sudah dicoba!", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)

                Button("Lanjut", action: viewModel.continueFromSpreadTask)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(20)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }
}
