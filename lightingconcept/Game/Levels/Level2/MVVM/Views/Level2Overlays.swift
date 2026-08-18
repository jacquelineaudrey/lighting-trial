import SwiftUI
import Foundation

// MARK: - Reusable Controls

struct Level2ReplayNarrationButton: View {
    let action: () -> Void

    var body: some View {
        Button("Dengarkan Lagi", systemImage: "speaker.wave.2.fill", action: action)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("Memutar ulang petunjuk kegiatan")
    }
}

struct Level2TopModeLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Color(hex: "2B1A08"))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: 280, height: 52)
            .background(fillColor, in: Capsule())
            .overlay(Capsule().stroke(strokeColor, lineWidth: 2))
            .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
            .accessibilityAddTraits(.isHeader)
    }

    private var fillColor: Color {
        title == "Mode lihat-lihat" ? Color(hex: "C8FFD8") : Color(hex: "FFF0A1")
    }

    private var strokeColor: Color {
        title == "Mode lihat-lihat" ? Color(hex: "52B878") : Color(hex: "FF9533")
    }
}

// MARK: - Dialog & Placement

struct Level2DialogOverlay: View {
    let line: DialogLine
    let buttonTitle: String
    let replayNarration: () -> Void
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(line.characterName).font(.headline).foregroundStyle(.blue)
            Text(line.text).font(.title3).bold().multilineTextAlignment(.center)
            Level2ReplayNarrationButton(action: replayNarration)
            Button(buttonTitle, action: action)
                .font(.title3).bold().buttonStyle(.borderedProminent)
                .controlSize(.large).frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
    }
}

struct Level2PlacementOverlay: View {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    let replayNarration: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            SurfaceScanInstruction(sceneViewModel: sceneViewModel)
            Text(guidanceText).font(.headline).multilineTextAlignment(.center)
            Button("Taruh Benda di Tengah", systemImage: "cube.fill", action: sceneViewModel.placeSceneAtScreenCenter)
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityHint("Menaruh benda pada permukaan di tengah layar")
            if let placementFeedback = sceneViewModel.placementFeedback {
                Label(placementFeedback, systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.subheadline).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            Level2ReplayNarrationButton(action: replayNarration)
        }
        .padding(20)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }

    private var guidanceText: String {
        switch sceneViewModel.surfaceState {
        case .scanning: "Arahkan titik tengah layar ke meja atau lantai, lalu tekan tombol di bawah."
        case .found: "Tempatnya ditemukan! Tekan tombol untuk menaruh benda."
        case .placed: "Benda sudah siap!"
        }
    }
}

// MARK: - Level 2 Flow Overlays

struct Level2MascotDialogOverlay: View {
    let line: Level2OverlayLine
    var buttonTitle: String = "Lanjut"
    var showsButton: Bool = false
    var buttonTint: Color = .blue
    var advancesOnTap: Bool = true
    let action: () -> Void

    var body: some View {
        ZStack {
            if advancesOnTap {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: action)
            }

            if showsButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(buttonTitle, action: action)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(buttonTint, in: Capsule())
                            .padding(.trailing, 42)
                            .padding(.bottom, 36)
                    }
                }
            }
        }
    }
}

struct Level2SpreadTutorialOverlay: View {
    let step: Level2TutorialStep
    let activeTouchCount: Int
    let beamSpreadDegrees: Float
    let action: () -> Void

    var body: some View {
        ZStack {
            if let mascot = step.mascot, let text = step.text {
                Level2MascotDialogOverlay(
                    line: Level2OverlayLine(
                        text: text,
                        mascot: mascot,
                        bubble: step.bubble,
                        highlightedWords: step.highlightedWords
                    ),
                    action: action
                )
            }

            if let gesture = step.gesture, shouldShowGestureAsset(for: gesture) {
                Level2GesturePromptOverlay(prompt: gesture, text: step.text)
            }
        }
    }

    private func shouldShowGestureAsset(for gesture: Level2GesturePrompt) -> Bool {
        switch gesture {
        case .touchTwoFingers:
            activeTouchCount < 2
        case .spreadOut:
            beamSpreadDegrees < Level2ViewModel.maximumBeamAngle - 10
        case .pinchIn:
            beamSpreadDegrees > Level2ViewModel.minimumBeamAngle + 10
        case .verticalSlide, .brightnessSlider:
            true
        }
    }
}

struct Level2FreeExploreInstructionsOverlay: View {
    let action: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()

            VStack(spacing: 28) {
                HStack(spacing: 78) {
                    Level2GestureReminder(
                        prompt: .pinchIn,
                        title: "Rapatkan dua jari untuk\nmengecilkan cahaya"
                    )
                    Level2GestureReminder(
                        prompt: .spreadOut,
                        title: "Lebarkan dua jari untuk\nmelebarkan cahaya"
                    )
                }

                Button("Oke, Sudah Ingat!", action: action)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.blue, in: Capsule())
            }
            .padding(44)
            .frame(maxWidth: 840)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.28), lineWidth: 1))
            .padding(.horizontal, 44)
        }
    }
}

struct Level2FreeExploreOverlay: View {
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                Spacer()
                Button("Selanjutnya", action: action)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.blue, in: Capsule())
                    .padding(.trailing, 42)
                    .padding(.bottom, 36)
            }
        }
    }
}

struct Level2IntensityTutorialOverlay: View {
    let step: Level2TutorialStep
    let intensityPercentage: Int
    let showsBrightnessControl: Bool
    var advancesOnTap = true
    let action: () -> Void

    var body: some View {
        ZStack {
            if let mascot = step.mascot, let text = step.text {
                Level2MascotDialogOverlay(
                    line: Level2OverlayLine(
                        text: text,
                        mascot: mascot,
                        bubble: step.bubble,
                        highlightedWords: step.highlightedWords
                    ),
                    advancesOnTap: advancesOnTap,
                    action: action
                )
            }

            if let gesture = step.gesture, !showsBrightnessControl {
                Level2GesturePromptOverlay(
                    prompt: gesture,
                    text: step.text,
                    intensityPercentage: intensityPercentage,
                    showsBrightnessControl: false
                )
            }
        }
    }
}

struct Level2MissionOverlay: View {
    let line: Level2OverlayLine
    let missionIndex: Int
    let action: () -> Void

    var body: some View {
        Level2MascotDialogOverlay(
            line: line,
            buttonTitle: "Selesai",
            showsButton: missionIndex == 5,
            buttonTint: .red,
            advancesOnTap: missionIndex != 1 && missionIndex != 3 && missionIndex != 5,
            action: action
        )
    }
}

private struct Level2StaticPulse: View {
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.32), lineWidth: 1).frame(width: 54, height: 54)
            Circle().stroke(.white.opacity(0.52), lineWidth: 1).frame(width: 42, height: 42)
            Circle().fill(Color.red).frame(width: 28, height: 28).overlay(Circle().stroke(.white, lineWidth: 2))
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

private struct Level2GestureReminder: View {
    let prompt: Level2GesturePrompt
    let title: String

    var body: some View {
        VStack(spacing: 24) {
            Level2GestureAssetImage(prompt: prompt, pulseScale: 0.72)
                .frame(width: 230, height: 170)

            Text(title)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
    }
}

#Preview("Free Explore Gesture Reminder") {
    ZStack {
        Color.black.opacity(0.82).ignoresSafeArea()

        Level2FreeExploreInstructionsOverlay(action: { })
    }
}

// MARK: - Speech Bubble & Mascot

private struct Level2FloatingMascot: View {
    let assetName: String
    let size: CGSize
    @State private var floatsUp = false

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .offset(y: floatsUp ? -8 : 7)
            .animation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true), value: floatsUp)
            .onAppear { floatsUp = true }
            .accessibilityHidden(true)
    }
}

private struct Level2SpeechBubble: View {
    let text: String
    let highlightedWords: [String]
    let tail: Level2SpeechBubbleShape.Tail

    var body: some View {
        highlightedText(text, highlightedWords: highlightedWords)
            .font(.system(size: 23, weight: .regular))
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 34)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background {
                Level2SpeechBubbleShape(tail: tail)
                    .fill(.white.opacity(0.82))
                    .stroke(.white, lineWidth: 1.4)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }
}

private struct Level2SpeechBubbleShape: Shape {
    enum Tail {
        case bottomTrailing
        case bottomLeading
        case right
        case none
    }

    let tail: Tail

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 2
        let tailSize: CGFloat = 38
        let bubbleRect: CGRect

        switch tail {
        case .bottomTrailing, .bottomLeading:
            bubbleRect = rect.insetBy(dx: 0, dy: 0).offsetBy(dx: 0, dy: 0).divided(atDistance: rect.height - tailSize, from: .minYEdge).slice
        case .right:
            bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width - tailSize, height: rect.height)
        case .none:
            bubbleRect = rect
        }

        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: radius, height: radius))

        switch tail {
        case .bottomTrailing:
            path.move(to: CGPoint(x: bubbleRect.maxX - 110, y: bubbleRect.maxY - 1))
            path.addLine(to: CGPoint(x: bubbleRect.maxX - 46, y: rect.maxY))
            path.addLine(to: CGPoint(x: bubbleRect.maxX - 76, y: bubbleRect.maxY - 1))
        case .bottomLeading:
            path.move(to: CGPoint(x: bubbleRect.minX + 76, y: bubbleRect.maxY - 1))
            path.addLine(to: CGPoint(x: bubbleRect.minX + 18, y: bubbleRect.maxY + 18))
            path.addLine(to: CGPoint(x: bubbleRect.minX + 118, y: bubbleRect.maxY - 1))
        case .right:
            path.move(to: CGPoint(x: bubbleRect.maxX - 1, y: bubbleRect.midY - 18))
            path.addLine(to: CGPoint(x: rect.maxX, y: bubbleRect.midY))
            path.addLine(to: CGPoint(x: bubbleRect.maxX - 1, y: bubbleRect.midY + 18))
        case .none:
            break
        }

        path.closeSubpath()
        return path
    }
}

private struct Level2MascotDialogLayout {
    let placement: Level2BubblePlacement
    let size: CGSize

    var bubbleSize: CGSize {
        switch placement {
        case .wideLower:
            CGSize(width: min(size.width * 0.54, 680), height: 138)
        case .upperCenter:
            CGSize(width: min(size.width * 0.32, 390), height: 178)
        case .lowerLeading:
            CGSize(width: min(size.width * 0.32, 380), height: 148)
        default:
            CGSize(width: min(size.width * 0.33, 400), height: 178)
        }
    }

    var mascotSize: CGSize {
        switch placement {
        case .upperCenter:
            CGSize(width: 330, height: 330)
        case .lowerLeading:
            CGSize(width: 180, height: 180)
        default:
            CGSize(width: 190, height: 220)
        }
    }

    var bubbleCenter: CGPoint {
        switch placement {
        case .lowerTrailing:
            CGPoint(x: size.width * 0.67, y: size.height * 0.81)
        case .upperTrailing:
            CGPoint(x: size.width * 0.78, y: size.height * 0.46)
        case .upperCenter:
            CGPoint(x: size.width * 0.70, y: size.height * 0.43)
        case .lowerLeading:
            CGPoint(x: size.width * 0.39, y: size.height * 0.82)
        case .wideLower:
            CGPoint(x: size.width * 0.52, y: size.height * 0.80)
        }
    }

    var mascotCenter: CGPoint {
        switch placement {
        case .upperCenter:
            CGPoint(x: size.width * 0.88, y: size.height * 0.80)
        case .lowerLeading:
            CGPoint(x: size.width * 0.15, y: size.height * 0.78)
        default:
            CGPoint(x: size.width * 0.89, y: size.height * 0.76)
        }
    }

    var buttonCenter: CGPoint {
        switch placement {
        case .lowerLeading:
            CGPoint(x: size.width * 0.91, y: size.height * 0.88)
        default:
            CGPoint(x: size.width * 0.89, y: size.height * 0.88)
        }
    }

    var tail: Level2SpeechBubbleShape.Tail {
        switch placement {
        case .lowerLeading:
            .bottomLeading
        case .wideLower, .lowerTrailing:
            .right
        case .upperTrailing, .upperCenter:
            .bottomTrailing
        }
    }
}

func highlightedText(_ text: String, highlightedWords: [String]) -> Text {
    var markdown = text
    for word in highlightedWords {
        markdown = markdown.replacingOccurrences(of: word, with: "**\(word)**")
    }

    if let attributedText = try? AttributedString(
        markdown: markdown,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    ) {
        return Text(attributedText)
    }

    return Text(text)
}

// MARK: - Completion

struct Level2ReviewOverlay: View {
    let replayNarration: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ingat Tiga Penemuanmu! 🌟").font(.title2).bold().frame(maxWidth: .infinity, alignment: .center)
            ForEach(Level2Content.reviewPoints, id: \.self) { point in
                Label(point, systemImage: "star.fill").font(.headline).foregroundStyle(.primary)
            }
            Level2ReplayNarrationButton(action: replayNarration).frame(maxWidth: .infinity)
            Button("Selesaikan Level 2", action: onFinish).buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
        }
        .padding(22).background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16).padding(.bottom, 28)
    }
}

struct Level2CompletedOverlay: View {
    let onFinish: () -> Void
    let onNext: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Text("🏆").font(.largeTitle.scaled(by: 1.7)).accessibilityHidden(true)
            Text("Level 2 Selesai!").font(.title).bold()
            Text("Kamu hebat, Detektif Cahaya!").font(.title3).bold().multilineTextAlignment(.center)
            Button(onNext == nil ? "Kembali ke Menu" : "Selanjutnya") {
                if let onNext {
                    onNext()
                } else {
                    onFinish()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24).background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 24).padding(.bottom, 48)
    }
}
