import SwiftUI

struct Level2ReplayNarrationButton: View {
    let action: () -> Void

    var body: some View {
        Button("Dengarkan Lagi", systemImage: "speaker.wave.2.fill", action: action)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("Memutar ulang petunjuk kegiatan")
    }
}
