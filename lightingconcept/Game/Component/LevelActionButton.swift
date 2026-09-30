import SwiftUI

/// Tombol aksi level dengan ukuran sentuh yang konsisten dan mudah dijangkau anak.
struct LevelActionButton: View {
    enum Role {
        case primary
        case secondary
        case menu
        case previousStep
    }

    let title: String
    var systemImage: String?
    var role: Role = .primary
    var isDisabled = false
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }
    
    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.system(size: isCompactWidth ? 15 : 17, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(foregroundStyle)
            .frame(width: isCompactWidth ? 180 : 220, height: isCompactWidth ? 48 : 52)
            .background(backgroundStyle, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderStyle, lineWidth: 2)
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .accessibilityHint(accessibilityHint)
    }

    private var foregroundStyle: Color {
        switch role {
        case .primary, .menu:
            .white
        case .secondary:
            Color(hex: "9FA60C")
        case .previousStep:
            Color(hex: "553C16")
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        switch role {
        case .primary:
            AnyShapeStyle(Color(hex: "9FA60C"))
        case .secondary:
            AnyShapeStyle(.regularMaterial)
        case .menu:
            AnyShapeStyle(Color(hex: "21415D"))
        case .previousStep:
            AnyShapeStyle(Color(hex: "F4C95D"))
        }
    }

    private var borderStyle: Color {
        switch role {
        case .primary:
            .clear
        case .secondary:
            Color(hex: "9FA60C").opacity(0.55)
        case .menu:
            Color(hex: "8AC7E8")
        case .previousStep:
            Color(hex: "C98928")
        }
    }

    private var accessibilityHint: String {
        switch role {
        case .primary:
            "Aksi utama."
        case .secondary:
            "Aksi tambahan."
        case .menu:
            "Keluar dari permainan dan kembali ke menu level."
        case .previousStep:
            "Mengulang satu langkah permainan sebelumnya."
        }
    }
}
