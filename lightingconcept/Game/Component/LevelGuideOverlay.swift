import SwiftUI

/// Bubble dan karakter pendamping yang dipakai bersama oleh seluruh level AR.
struct LevelGuideOverlay: View {
    let text: String
    let assetName: String
    var screenPosition: CGPoint?
    var showsTapToContinueCaption = false
    var bottomPadding: CGFloat = 32

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 12) {
                LevelSpeechBubble(
                    text: text,
                    showsTapToContinueCaption: showsTapToContinueCaption
                )
                .frame(maxWidth: 420)
                .fixedSize(horizontal: false, vertical: true)

                LevelGuideCharacterImage(assetName: assetName)
                    .frame(width: 104, height: 144)
            }
            .position(overlayPosition(in: proxy.size))
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func overlayPosition(in size: CGSize) -> CGPoint {
        let proposedPosition = screenPosition
            ?? CGPoint(x: size.width - 280, y: size.height - bottomPadding)
        let minimumX = min(280, size.width * 0.5)
        let maximumX = max(minimumX, size.width - 280)
        let minimumY = min(150, size.height * 0.5)
        let maximumY = max(minimumY, size.height - bottomPadding)

        return CGPoint(
            x: min(max(proposedPosition.x, minimumX), maximumX),
            y: min(max(proposedPosition.y, minimumY), maximumY)
        )
    }
}
