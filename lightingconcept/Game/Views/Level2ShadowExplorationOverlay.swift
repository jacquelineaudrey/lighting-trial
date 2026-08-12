import SwiftUI

struct Level2ShadowExplorationOverlay: View {
    let viewModel: Level2ViewModel
    let replayNarration: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Label("Misi: Cari Bayangan", systemImage: "figure.walk")
                .font(.title3)
                .bold()

            Text("Jalan pelan mengelilingi benda. Lihat bayangannya dari tiga sisi!")
                .font(.headline)
                .multilineTextAlignment(.center)

            ProgressView(value: Double(viewModel.shadowProgress), total: 3)
                .tint(.blue)
                .accessibilityLabel("Sisi bayangan yang ditemukan")
                .accessibilityValue("\(viewModel.shadowProgress) dari 3 sisi")

            Text("⭐️ \(viewModel.shadowProgress) dari 3 sisi ditemukan")
                .font(.headline)

            Level2ReplayNarrationButton(action: replayNarration)

            if viewModel.hasCompletedShadowTask {
                Label("Hebat! Semua sisi ditemukan!", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                Button("Pelajari Bayangan", action: viewModel.continueFromShadowTask)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                Text("Lihat jalan di sekitarmu dan pegang iPad dengan erat.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                #if DEBUG
                Button("Lewati Misi Bayangan (Debug)", action: viewModel.completeShadowTaskForDebugging)
                    .font(.footnote)
                    .buttonStyle(.bordered)
                #endif
            }
        }
        .padding(20)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }
}
