import SwiftUI

struct Level6ColorButton: View {
    enum Size {
        case regular
        case compact

        var buttonSize: CGFloat {
            switch self {
            case .regular: 32
            case .compact: 26
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .regular: 20
            case .compact: 18
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .regular: 14
            case .compact: 13
            }
        }
    }

    var size: Size = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.orange,
                                Color.orange,
                                Color.red,
                                Color.purple,
                                Color.blue,
                                Color.cyan,
                                Color.green,
                                Color.green,
                                Color.yellow,
                                Color.yellow
                            ]),
                            center: .center
                        )
                    )
                    .frame(
                        width: size.buttonSize,
                        height: size.buttonSize
                    )

                Text("Warna Cahaya")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(
                .ultraThinMaterial,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        Color.white.opacity(0.28),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Warna Cahaya")
        .accessibilityHint(
            "Membuka pilihan warna untuk cahaya yang dipilih"
        )
    }
}

#Preview("Warna Cahaya Button") {
    ZStack {
        LinearGradient(
            colors: [.indigo, .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        Level6ColorButton(action: {})
    }
}
