import SwiftUI
import Foundation

// MARK: - Reusable Controls

struct Level2ReplayNarrationButton: View {
    let action: () -> Void

    var body: some View {
        LevelActionButton(
            title: "Dengarkan Lagi",
            systemImage: "speaker.wave.2.fill",
            role: .secondary,
            action: action
        )
            .accessibilityHint("Memutar ulang petunjuk kegiatan")
    }
}

struct Level2TopModeLabel: View {
    let title: String
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        Text(title)
            .font(.system(size: compact ? 17 : 20, weight: .bold))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: compact ? 224 : 280, height: compact ? 44 : 52)
            .background(fillColor, in: Capsule())
            .overlay(Capsule().stroke(strokeColor, lineWidth: 2))
            .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
            .accessibilityAddTraits(.isHeader)
    }

    private var fillColor: Color {
        switch mode {
        case .object:
            Color(hex: "BDE0FF")
        case .light:
            Color(hex: "FFF0A1")
        case .lookAround:
            Color(hex: "C8FFD8")
        }
    }

    private var strokeColor: Color {
        switch mode {
        case .object:
            Color(hex: "4E9FE6")
        case .light:
            Color(hex: "FF9533")
        case .lookAround:
            Color(hex: "52B878")
        }
    }

    private var textColor: Color {
        mode == .light ? Color(hex: "2B1A08") : Color(hex: "21415D")
    }

    private var mode: Mode {
        let normalizedTitle = title.lowercased()
        if normalizedTitle.contains("objek") {
            return .object
        }
        if normalizedTitle.contains("lihat") {
            return .lookAround
        }
        return .light
    }

    private enum Mode: Equatable {
        case object
        case light
        case lookAround
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
            Text(line.characterName)
                .font(.headline)
                .foregroundStyle(Color(hex: "9FA60C"))
            Text(line.text).font(.title3).bold().multilineTextAlignment(.center)
            Level2ReplayNarrationButton(action: replayNarration)
            LevelActionButton(
                title: buttonTitle,
                systemImage: "arrow.right",
                action: action
            )
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
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 12) {
            SurfaceScanInstruction(sceneViewModel: sceneViewModel)
            Text(guidanceText)
                .font(compact ? .subheadline.weight(.semibold) : .headline)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            LevelActionButton(
                title: "Taruh Benda",
                systemImage: "cube.fill",
                action: sceneViewModel.placeSceneAtScreenCenter
            )
                .accessibilityHint("Menaruh benda pada permukaan di tengah layar")
            if let placementFeedback = sceneViewModel.placementFeedback {
                Label(placementFeedback, systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.subheadline).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            Level2ReplayNarrationButton(action: replayNarration)
        }
        .padding(compact ? 12 : 20)
        .frame(maxWidth: compact ? 540 : 620)
        .background(.thinMaterial, in: .rect(cornerRadius: compact ? 18 : 24))
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.bottom, compact ? 16 : 28)
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
    var advancesOnTap: Bool = true
    let action: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            if advancesOnTap {
                LevelTapToAdvanceOverlay(showsCaption: false, action: action)
            }

            if showsButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        LevelActionButton(
                            title: buttonTitle,
                            systemImage: "arrow.right",
                            action: action
                        )
                        .padding(.trailing, compact ? 16 : 42)
                        .padding(.bottom, compact ? 16 : 36)
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()

            VStack(spacing: compact ? 16 : 28) {
                HStack(spacing: compact ? 18 : 78) {
                    Level2GestureReminder(
                        prompt: .pinchIn,
                        title: "Rapatkan dua jari untuk\nmengecilkan cahaya"
                    )
                    Level2GestureReminder(
                        prompt: .spreadOut,
                        title: "Lebarkan dua jari untuk\nmelebarkan cahaya"
                    )
                }

                LevelActionButton(
                    title: "Oke, Sudah Ingat!",
                    action: action
                )
            }
            .padding(compact ? 18 : 44)
            .frame(maxWidth: compact ? 560 : 840)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: compact ? 20 : 28))
            .overlay(RoundedRectangle(cornerRadius: compact ? 20 : 28).stroke(.white.opacity(0.28), lineWidth: 1))
            .padding(.horizontal, compact ? 12 : 44)
        }
    }
}

struct Level2FreeExploreOverlay: View {
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }
    
    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                Spacer()
                LevelActionButton(
                    title: "Selanjutnya",
                    systemImage: "arrow.right",
                    action: action
                )
                .padding(.trailing, compact ? 16 : 42)
                .padding(.bottom, compact ? 16 : 36)
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
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }
    
    var body: some View {
        VStack {
            Spacer()
            highlightedText(text, highlightedWords: [])
                .font(.system(size: compact ? 16 : 20, weight: .regular))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, compact ? 18 : 34)
                .frame(minHeight: compact ? 54 : 66)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, compact ? 16 : 34)
        }
    }
}

private struct Level2GestureReminder: View {
    let prompt: Level2GesturePrompt
    let title: String
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 24) {
            Level2GestureAssetImage(prompt: prompt, pulseScale: compact ? 0.62 : 0.72)
            .frame(width: compact ? 160 : 230, height: compact ? 118 : 170)

            Text(title)
                .font(.system(size: compact ? 16 : 21, weight: .medium))
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

// MARK: - Level 2 Responsive Guide

struct Level2ResponsiveGuideOverlay: View {
    let text: String
    let assetName: String
    let screenPosition: CGPoint?
    let showsTapToContinueCaption: Bool
    let bottomPadding: CGFloat

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { proxy in
            let bubbleWidth = min(compact ? 320 : 420, proxy.size.width * (compact ? 0.40 : 0.54))

            let characterSize = CGSize(width: compact ? 80 : 104, height: compact ? 110 : 144)

            let spacing: CGFloat = compact ? 8 : 12

            let groupHeight = max(characterSize.height, compact ? 150 : 180)

            HStack(alignment: .bottom, spacing: spacing) {

                LevelSpeechBubble(text: text, showsTapToContinueCaption: showsTapToContinueCaption)
                .frame(width: bubbleWidth)
                .fixedSize(horizontal: false, vertical: true)

                LevelGuideCharacterImage(assetName: assetName)
                .frame(width: characterSize.width, height: characterSize.height)
            }
            .position(overlayPosition(in: proxy.size, groupWidth: bubbleWidth + spacing + characterSize.width, groupHeight: groupHeight))
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func overlayPosition(in size: CGSize, groupWidth: CGFloat, groupHeight: CGFloat) -> CGPoint {

        let halfWidth = groupWidth / 2
        let halfHeight = groupHeight / 2

        let proposed = screenPosition
            ?? CGPoint(
                x: size.width - halfWidth - (compact ? 12 : 20), y: size.height - bottomPadding - halfHeight
            )

        let minX = halfWidth + (compact ? 8 : 12)
        let maxX = max(minX, size.width - halfWidth - (compact ? 8 : 12))
        let minY = halfHeight + 8
        let maxY = max(minY, size.height - bottomPadding - halfHeight)

        return CGPoint(
            x: min(max(proposed.x, minX), maxX), y: min(max(proposed.y, minY), maxY)
        )
    }
}

// MARK: - Completion

struct Level2ReviewOverlay: View {
    let replayNarration: () -> Void
    let onFinish: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 16) {
            Text("Ingat Tiga Penemuanmu! 🌟")
                .font(compact ? .headline.bold() : .title2.bold())
                .frame(maxWidth: .infinity, alignment: .center)

            ForEach(Level2Content.reviewPoints, id: \.self) { point in
                Label(point, systemImage: "star.fill")
                .font(compact ? .subheadline : .headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Level2ReplayNarrationButton(action: replayNarration)
            .frame(maxWidth: .infinity)

            LevelActionButton(
                title: "Selesaikan Level 2",
                systemImage: "checkmark",
                action: onFinish
            )
            .frame(maxWidth: .infinity)
        }
        .padding(compact ? 14 : 22)
        .frame(maxWidth: compact ? 560 : .infinity)
        .background(.thinMaterial, in: .rect(cornerRadius: compact ? 18 : 24))
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.bottom, compact ? 16 : 28)
    }
}

struct Level2CompletedOverlay: View {
    let onFinish: () -> Void
    let onNext: (() -> Void)?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }
    
    var body: some View {
        VStack(spacing: compact ? 10 : 16) {
            Text("🏆")
                .font(compact ? .largeTitle.scaled(by: 1.35) : .largeTitle.scaled(by: 1.7))
                .accessibilityHidden(true)

            Text("Level 2 Selesai!")
                .font(compact ? .title2.bold() : .title.bold())

            Text("Kamu hebat, Detektif Cahaya!")
                .font(compact ? .headline.bold() : .title3.bold())
                .multilineTextAlignment(.center)

            LevelActionButton(
                title: onNext == nil ? "Kembali ke Menu" : "Selanjutnya",
                systemImage: onNext == nil ? "house.fill" : "arrow.right",
                role: onNext == nil ? .menu : .primary,
                action: finish
            )
        }
        .padding(compact ? 16 : 24)
        .frame(maxWidth: compact ? 520 : .infinity)
        .background(.thinMaterial, in: .rect(cornerRadius: compact ? 20 : 28))
        .padding(.horizontal, compact ? 12 : 24)
        .padding(.bottom, compact ? 20 : 48)
    }

    private func finish() {
        if let onNext {
            onNext()
        } else {
            onFinish()
        }
    }
}
