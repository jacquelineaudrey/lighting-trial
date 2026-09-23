import SwiftUI

struct SafetyWarningDialog: View {
    let warning: SafetyProximityWarning
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Label("Hati-Hati!", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(hex: "313131"))

                Text(warning.message)
                    .font(.body)
                    .foregroundStyle(Color(hex: "313131"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Oke", action: onDismiss)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: "FF383C"))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.black.opacity(0.08), in: Capsule())
            }
            .padding(24)
            .frame(maxWidth: 330)
            .background(Color(hex: "EFEBCF"), in: .rect(cornerRadius: 35))
            .overlay {
                RoundedRectangle(cornerRadius: 35)
                    .stroke(Color(hex: "D6CF91"), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
            .accessibilityElement(children: .contain)
        }
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }
}
