import SwiftUI

struct Level2GesturePromptOverlay: View {
    let prompt: Level2GesturePrompt
    let text: String?
    var intensityPercentage: Int = 50
    var showsBrightnessControl = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch prompt {
                case .touchTwoFingers:
                    gestureAsset(.touchTwoFingers, in: proxy.size)
                case .spreadOut:
                    gestureAsset(.spreadOut, in: proxy.size)
                case .pinchIn:
                    gestureAsset(.pinchIn, in: proxy.size)
                case .verticalSlide:
                    if showsBrightnessControl {
                        brightnessControl(in: proxy.size, fillPercentage: intensityPercentage)
                    } else {
                        verticalSlidePrompt(in: proxy.size)
                    }
                case .brightnessSlider:
                    if showsBrightnessControl {
                        brightnessControl(in: proxy.size, fillPercentage: intensityPercentage)
                    }
                }

                if let text, prompt != .brightnessSlider {
                    Level2BottomInstruction(text: text)
                } else if prompt == .brightnessSlider {
                    Level2BottomInstruction(
                        text: "Geser jarimu di sebelah kiri layar!\nNaik untuk lebih terang, turun untuk lebih redup."
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func gestureAsset(_ prompt: Level2GesturePrompt, in size: CGSize) -> some View {
        Level2GestureAssetImage(prompt: prompt)
            .frame(width: min(size.width * 0.28, 300), height: min(size.height * 0.34, 260))
            .position(x: size.width * 0.82, y: size.height * 0.70)
    }

    private func verticalSlidePrompt(in size: CGSize) -> some View {
        Level2GestureAssetImage(prompt: .verticalSlide, showsPulse: false)
            .frame(width: min(size.width * 0.18, 210), height: min(size.height * 0.28, 230))
            .position(x: size.width * 0.12, y: size.height * 0.47)
    }

    private func brightnessControl(in size: CGSize, fillPercentage: Int) -> some View {
        Level2BrightnessControl(intensityPercentage: fillPercentage)
            .position(x: size.width * 0.10, y: size.height * 0.50)
            .transition(.opacity)
    }
}

struct Level2BrightnessControl: View {
    let intensityPercentage: Int

    var body: some View {
        let sliderHeight: CGFloat = 190
        let fillRatio = min(max(CGFloat(intensityPercentage) / 100, 0), 1)

        VStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(.white.opacity(0.50))
                    .frame(width: 15, height: sliderHeight)
                Capsule()
                    .fill(Color.blue)
                    .frame(width: 15, height: max(18, sliderHeight * fillRatio))
                    .animation(.easeOut(duration: 0.12), value: intensityPercentage)
            }

            Image(systemName: "sun.min.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(.black.opacity(0.12), in: Capsule())
    }
}

struct Level2GestureAssetImage: View {
    let prompt: Level2GesturePrompt
    var showsPulse = true
    var pulseScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let frameSize = proxy.size
            let imageFrame = renderedImageFrame(in: frameSize)

            ZStack {
                if showsPulse {
                    ForEach(Array(pulseSourcePoints.enumerated()), id: \.offset) { _, point in
                        Level2AnimatedPromptPulse(scale: pulseScale)
                            .position(
                                x: imageFrame.minX + point.x * imageFrame.width / assetPixelSize.width,
                                y: imageFrame.minY + point.y * imageFrame.height / assetPixelSize.height
                            )
                    }
                }

                Image(assetName)
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    private var assetName: String {
        switch prompt {
        case .touchTwoFingers:
            "gesture1v1"
        case .spreadOut:
            "gesture1v2"
        case .pinchIn:
            "gesture2"
        case .verticalSlide, .brightnessSlider:
            "gestureIntensity"
        }
    }

    private var assetPixelSize: CGSize {
        switch prompt {
        case .touchTwoFingers:
            CGSize(width: 216, height: 277)
        case .spreadOut:
            CGSize(width: 295, height: 318)
        case .pinchIn:
            CGSize(width: 231, height: 271)
        case .verticalSlide, .brightnessSlider:
            CGSize(width: 167, height: 284)
        }
    }

    private var pulseSourcePoints: [CGPoint] {
        switch prompt {
        case .touchTwoFingers:
            return [
                CGPoint(x: 12, y: 108),
                CGPoint(x: 52, y: 56)
            ]
        case .spreadOut:
            return [
                CGPoint(x: 90, y: 148),
                CGPoint(x: 130, y: 96)
            ]
        case .pinchIn:
            return [
                CGPoint(x: 10, y: 123),
                CGPoint(x: 160, y: 10)
            ]
        case .verticalSlide, .brightnessSlider:
            return [
                CGPoint(x: 160, y: 10)
            ]
        }
    }

    private func renderedImageFrame(in frameSize: CGSize) -> CGRect {
        let scale = min(frameSize.width / assetPixelSize.width, frameSize.height / assetPixelSize.height)
        let renderedSize = CGSize(width: assetPixelSize.width * scale, height: assetPixelSize.height * scale)
        return CGRect(
            x: (frameSize.width - renderedSize.width) / 2,
            y: (frameSize.height - renderedSize.height) / 2,
            width: renderedSize.width,
            height: renderedSize.height
        )
    }
}

private struct Level2AnimatedPromptPulse: View {
    let scale: CGFloat
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.28), lineWidth: 1)
                .frame(width: 64 * scale, height: 64 * scale)
                .scaleEffect(isPulsing ? 1.24 : 0.78)
                .opacity(isPulsing ? 0.10 : 0.75)

            Circle()
                .stroke(.white.opacity(0.46), lineWidth: 1)
                .frame(width: 50 * scale, height: 50 * scale)
                .scaleEffect(isPulsing ? 1.12 : 0.88)
                .opacity(isPulsing ? 0.18 : 0.82)

            Circle()
                .fill(Color.red)
                .frame(width: 36 * scale, height: 36 * scale)
                .overlay(Circle().stroke(.white, lineWidth: 2))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

private struct Level2BottomInstruction: View {
    let text: String

    var body: some View {
        VStack {
            Spacer()
            highlightedText(text, highlightedWords: [])
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 34)
                .frame(minHeight: 66)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 34)
        }
    }
}

#Preview("Gesture Pulse Positions") {
    VStack(spacing: 28) {
        HStack(spacing: 32) {
            Level2GestureAssetImage(prompt: .touchTwoFingers)
                .frame(width: 216, height: 277)
                .background(Color.black.opacity(0.35))

            Level2GestureAssetImage(prompt: .spreadOut)
                .frame(width: 295, height: 318)
                .background(Color.black.opacity(0.35))

            Level2GestureAssetImage(prompt: .pinchIn)
                .frame(width: 231, height: 271)
                .background(Color.black.opacity(0.35))

            Level2GestureAssetImage(prompt: .verticalSlide, showsPulse: false)
                .frame(width: 167, height: 284)
                .background(Color.black.opacity(0.35))
        }

        Text("Preview pakai frame pixel asli PNG supaya posisi pulse bisa dicek langsung.")
            .font(.headline)
            .foregroundStyle(.white)
    }
    .padding(40)
    .background(Color.black.opacity(0.82))
}

#Preview("Free Explore Modal") {
    Level2FreeExploreInstructionsOverlay(action: { })
        .background(Color.gray)
}
