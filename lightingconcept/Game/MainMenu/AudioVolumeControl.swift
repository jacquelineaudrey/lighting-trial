import SwiftUI

struct AudioVolumeControl: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var volume: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.headline)

                Spacer()

                Text(volume, format: .percent.precision(.fractionLength(0)))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Image(systemName: "speaker.slash.fill")
                    .accessibilityHidden(true)

                Slider(value: $volume, in: 0...1, step: 0.05)
                    .tint(MainMenuLayout.outlineColor)
                    .accessibilityLabel(title)
                    .accessibilityValue(
                        Text(volume, format: .percent.precision(.fractionLength(0)))
                    )

                Image(systemName: "speaker.wave.3.fill")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color(red: 92 / 255, green: 61 / 255, blue: 36 / 255))
        }
        .padding(20)
        .background(.white.opacity(0.72), in: .rect(cornerRadius: 22))
    }
}

#Preview {
    @Previewable @State var volume = 0.5

    AudioVolumeControl(
        title: "Volume Menu",
        subtitle: "Musik pada halaman utama dan pemilihan level.",
        systemImage: "music.note",
        volume: $volume
    )
    .padding()
    .background(Color.brown)
}
