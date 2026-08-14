import SwiftUI

struct Level2ReviewOverlay: View {
    let replayNarration: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ingat Tiga Penemuanmu! 🌟")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .center)

            ForEach(Level2Content.reviewPoints, id: \.self) { point in
                Label(point, systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Level2ReplayNarrationButton(action: replayNarration)
                .frame(maxWidth: .infinity)

            Button("Selesaikan Level 2", action: onFinish)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }
}
