import SwiftUI

struct Level6PositionGestureSurface: View {
    @ObservedObject var viewModel: Level6ViewModel

    var body: some View {
        Level6GestureFeedbackOverlay(
            touchPoints: viewModel.gestureTouchPoints,
            intensityPercentage: viewModel.isAdjustingIntensity
                ? viewModel.intensityPercentage
                : nil,
            heightPercentage: viewModel.isAdjustingHeight
                ? viewModel.heightPercentage
                : nil,
            isDeviceFollowing: viewModel.isDeviceFollowing
        )
    }
}

struct Level6GestureFeedbackOverlay: View {
    let touchPoints: [CGPoint]
    let intensityPercentage: Int?
    let heightPercentage: Int?
    let isDeviceFollowing: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(touchPoints.enumerated()), id: \.offset) { _, point in
                    Level6TouchIndicator()
                        .position(point)
                }

                if let intensityPercentage {
                    Level2BrightnessControl(
                        intensityPercentage: intensityPercentage
                    )
                    .position(
                        x: proxy.size.width * 0.10,
                        y: proxy.size.height * 0.50
                    )
                }

                if let heightPercentage {
                    Level6HeightControl(heightPercentage: heightPercentage)
                        .position(
                            x: proxy.size.width * 0.90,
                            y: proxy.size.height * 0.50
                        )
                }

                if isDeviceFollowing {
                    VStack {
                        Spacer()
                        highlightedText(
                            "Tetap tahan layar. Gerakkan perangkat untuk memindahkan cahaya.",
                            highlightedWords: ["Tetap tahan layar"]
                        )
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)
                        .frame(minHeight: 66)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 108)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Geser sisi kiri untuk intensitas, sisi kanan untuk ketinggian, gunakan dua jari untuk lebar cahaya, atau tahan layar lalu gerakkan perangkat untuk memindahkan cahaya."
        )
    }
}

#Preview("Gesture Feedback — Intensity") {
    Level6GestureFeedbackOverlay(
        touchPoints: [CGPoint(x: 78, y: 260)],
        intensityPercentage: 70,
        heightPercentage: nil,
        isDeviceFollowing: false
    )
    .background(Color.gray)
}

#Preview("Gesture Feedback — Height") {
    Level6GestureFeedbackOverlay(
        touchPoints: [CGPoint(x: 622, y: 260)],
        intensityPercentage: nil,
        heightPercentage: 58,
        isDeviceFollowing: false
    )
    .background(Color.gray)
}

#Preview("Gesture Feedback — Hold") {
    Level6GestureFeedbackOverlay(
        touchPoints: [CGPoint(x: 350, y: 250)],
        intensityPercentage: nil,
        heightPercentage: nil,
        isDeviceFollowing: true
    )
    .background(Color.gray)
}
