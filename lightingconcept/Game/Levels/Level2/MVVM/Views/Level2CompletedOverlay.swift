import SwiftUI

struct Level2CompletedOverlay: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🏆")
                .font(.largeTitle.scaled(by: 1.7))
                .accessibilityHidden(true)

            Text("Level 2 Selesai!")
                .font(.title)
                .bold()

            Text("Kamu hebat, Detektif Cahaya!")
                .font(.title3)
                .bold()
                .multilineTextAlignment(.center)

            Button("Kembali ke Menu", action: onFinish)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }
}
