import SwiftUI

struct LevelSpeechBubble: View {
    let text: String
    var showsTapToContinueCaption = false

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            Text(text)
                .font(.title3)
                .foregroundStyle(Color(hex: "313131"))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.82)

            if showsTapToContinueCaption {
                LevelTapToContinueCaption()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.95))
                .stroke(Color(hex: "9FA60C").opacity(0.45), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        showsTapToContinueCaption
            ? "\(text). Ketuk dimana saja untuk lanjut."
            : text
    }
}
