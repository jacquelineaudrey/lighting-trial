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
                    .foregroundStyle(Color(hex: "313131"))

                Spacer()

                Text(volume, format: .percent.precision(.fractionLength(0)))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color(hex: "313131"))
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color(hex: "313131"))

            HStack(spacing: 14) {
                Image(systemName: "speaker.slash.fill")
                    .accessibilityHidden(true)

                Slider(value: $volume, in: 0...1, step: 0.05)
                    .tint(Color(hex: "9FA60C"))
                    .accessibilityLabel(title)
                    .accessibilityValue(
                        Text(volume, format: .percent.precision(.fractionLength(0)))
                    )

                Image(systemName: "speaker.wave.3.fill")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color(hex: "9FA60C"))
        }
        .padding(20)
        .background(Color(hex: "D6CF91").opacity(0.25), in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(hex: "D6CF91"), lineWidth: 2)
        )
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
    .background(Color(hex: "EBE9CE"))
}
