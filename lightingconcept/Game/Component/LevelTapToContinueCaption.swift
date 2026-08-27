import SwiftUI

struct LevelTapToContinueCaption: View {
    // Kept a step smaller than the bubble text (.title3) above it, and at
    // reduced opacity of the same bubble-text color, so it reads as a
    // secondary hint rather than competing with the main dialog line.
    private let captionFont: Font = .subheadline.weight(.semibold)
    private let captionOpacity: Double = 0.60

    var body: some View {
        Label("Ketuk dimana saja untuk lanjut", systemImage: "hand.tap.fill")
            .font(captionFont)
            .foregroundStyle(Color(hex: "313131").opacity(captionOpacity))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Ketuk dimana saja untuk lanjut")
    }
}
