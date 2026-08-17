//
//  Level1FlowView.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI

struct Level1FlowView: View {
    @StateObject private var viewModel = Level1ViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var narrator = LessonAudioNarrator()
    @State private var showsExitConfirmation = false
    let onNextLevel: (() -> Void)?

    init(onNextLevel: (() -> Void)? = nil) {
        self.onNextLevel = onNextLevel
    }

    var body: some View {
        ZStack {
            Level1ARView(viewModel: viewModel)
                .ignoresSafeArea()

            switch viewModel.phase {
            case .onboarding:
                Level1OpeningOverlay(viewModel: viewModel)
            case .scanningSurface:
                VStack {
                    SurfaceScanInstruction(sceneViewModel: viewModel.arSceneViewModel)
                    Spacer()
                }
            case .surfaceReady:
                EmptyView()
            case .lightShadowIntro:
                Level1LightShadowOverlay(viewModel: viewModel)
            case .findingShapes:
                Level1FindShapeOverlay(viewModel: viewModel)
            case .textureTapPrompt:
                Level1TextureTapPromptOverlay()
            case .textureExploration:
                Level1TextureOverlay(viewModel: viewModel)
            case .shapeChange:
                Level1ShapeChangeOverlay(viewModel: viewModel)
            case .completed:
                EndLevelView(
                    data: EndLevelViewModel.data(for: Level1Content.levelID),
                    onBack: dismiss.callAsFunction,
                    onNext: onNextLevel
                )
                .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed {
                LevelBackButton { showsExitConfirmation = true }
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
        }
        .overlay(alignment: .top) {
            if viewModel.showsObjectModeBadge {
                Text("Kamu jadi objek!")
                    .font(.headline.bold())
                    .foregroundStyle(Color(hex: "21415D"))
                    .padding(.horizontal, 34)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.74, green: 0.88, blue: 1.0), in: Capsule())
                    .overlay(Capsule().stroke(.blue, lineWidth: 2))
                    .padding(.top, 28)
            }
        }
        .overlay(alignment: .top) {
            if let celebration = viewModel.checkpointCelebration {
                ShapeFoundToast(celebration: celebration)
                    .id(celebration.id)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .padding(.top, 64)
                    .allowsHitTesting(false)
            }
        }
        .levelExitConfirmation(isPresented: $showsExitConfirmation) {
            dismiss()
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: viewModel.checkpointCelebration)
        .sensoryFeedback(.success, trigger: viewModel.successFeedbackTrigger)
        .task(id: viewModel.narrationID) {
            narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName)
        }
        .onDisappear(perform: narrator.stop)
        .navigationBarBackButtonHidden(true)
    }
}

private struct Level1OpeningOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 18) {
                    SpeechBubble(text: viewModel.currentDialogLine.text, tail: .bottomTrailing)
                    Button(viewModel.isLastDialogLine ? "Mulai" : "Selanjutnya", action: viewModel.advanceDialog)
                        .font(.headline.bold())
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .frame(maxWidth: 430)
                .padding(.trailing, 80)
                .padding(.bottom, 82)
            }
        }
    }
}

private struct Level1LightShadowOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 16) {
                        if viewModel.currentLightShadowInstruction.radarTarget != nil || viewModel.selectedRadarTarget == nil {
                            SpeechBubble(text: viewModel.currentLightShadowInstruction.text, tail: .bottomTrailing)
                        }

                        if viewModel.currentLightShadowInstruction.radarTarget == nil {
                            Button(lightShadowButtonTitle, action: viewModel.continueLightShadowIntro)
                                .font(.headline.bold())
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        }
                    }
                    .frame(maxWidth: 450)
                    .padding(.trailing, 64)
                    .padding(.bottom, 78)
                }
            }
        }
    }

    private var lightShadowButtonTitle: String {
        viewModel.lightShadowIndex == 0 ? "Lihat Cahaya" : "Selanjutnya"
    }
}

private struct Level1FindShapeOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if viewModel.hasFoundAllShapes {
                    Button("Selanjutnya", action: viewModel.continueToTextureLesson)
                        .font(.headline.bold())
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.blue, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.trailing, 54)
                        .padding(.bottom, 46)
                } else {
                    SpeechBubble(text: "Selain kotak, coba temukan bentuk yang lain di sekitarmu!", tail: .bottomTrailing)
                        .frame(maxWidth: 430)
                        .padding(.trailing, 70)
                        .padding(.bottom, 92)
                }
            }
        }
    }
}

private struct Level1TextureTapPromptOverlay: View {
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Image("Finger")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 74, height: 160)
                        .opacity(0.9)
                        .padding(.leading, 118)
                        .padding(.bottom, 126)
                    Spacer()
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    SpeechBubble(text: "Coba tekan sekali kotaknya! Kita lihat tekstur yang lain yaa!", tail: .bottomTrailing)
                        .frame(maxWidth: 430)
                        .padding(.trailing, 66)
                        .padding(.bottom, 82)
                }
            }
        }
    }
}

private struct Level1TextureOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack {
            HStack {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(viewModel.textureStops.enumerated()), id: \.element.id) { index, texture in
                        Button {
                            viewModel.selectTexture(at: index)
                        } label: {
                            HStack(spacing: 14) {
                                Text(texture.name)
                                    .font(.headline)
                                    .frame(width: 118, alignment: .leading)
                                TextureSwatch(texture: texture.material)
                            }
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .padding(.leading, 70)
                .padding(.bottom, 86)

                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 14) {
                        SpeechBubble(text: textureMessage, tail: .bottomTrailing)
                            .frame(maxWidth: 470)
                        if viewModel.hasExploredAllTextures {
                            Button("Selanjutnya", action: viewModel.startShapeChange)
                                .font(.headline.bold())
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        }
                    }
                    .padding(.trailing, 66)
                    .padding(.bottom, 78)
                }
            }
        }
    }

    private var textureMessage: String {
        viewModel.hasExploredAllTextures
            ? "Kerja bagus! Kamu berhasil mengganti tekstur benda ini."
            : "Wah, teksturnya berubah! Coba lihat bayangannya."
    }
}

private struct Level1ShapeChangeOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack {
            HStack {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(viewModel.shapeOptions.enumerated()), id: \.element.id) { index, shape in
                        Button {
                            viewModel.selectShape(at: index)
                        } label: {
                            HStack(spacing: 16) {
                                Text(shape.displayName)
                                    .font(.headline)
                                    .frame(width: 118, alignment: .leading)
                                Image(systemName: shape.quizSymbolName)
                                    .font(.title2)
                                    .frame(width: 42, height: 42)
                                    .foregroundStyle(index == viewModel.selectedShapeIndex ? .white : .secondary)
                            }
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .padding(.leading, 70)
                .padding(.bottom, 72)

                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 14) {
                        SpeechBubble(text: viewModel.hasChangedShape ? "Kerja bagus! Kamu berhasil mengganti bentuk benda ini." : "Wah, ada banyak bentuk. Kamu bisa ganti bentuk yang lain lho!", tail: .bottomTrailing)
                            .frame(maxWidth: 450)

                        if viewModel.hasChangedShape {
                            Button("Selanjutnya", action: viewModel.finishLevel)
                                .font(.headline.bold())
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(.blue, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.trailing, 54)
                    .padding(.bottom, 46)
                }
            }
        }
    }
}

private struct SpeechBubble: View {
    enum Tail {
        case bottomLeading
        case bottomTrailing
    }

    let text: String
    var tail: Tail = .bottomTrailing

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background {
                SpeechBubbleShape(tail: tail)
                    .fill(.white.opacity(0.82))
                    .stroke(.white, lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

private struct SpeechBubbleShape: Shape {
    let tail: SpeechBubble.Tail

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 4
        let tailHeight: CGFloat = 34
        let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)

        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: radius, height: radius))

        switch tail {
        case .bottomLeading:
            path.move(to: CGPoint(x: bubbleRect.minX + 70, y: bubbleRect.maxY - 1))
            path.addLine(to: CGPoint(x: bubbleRect.minX + 28, y: rect.maxY))
            path.addLine(to: CGPoint(x: bubbleRect.minX + 116, y: bubbleRect.maxY - 1))
        case .bottomTrailing:
            path.move(to: CGPoint(x: bubbleRect.maxX - 116, y: bubbleRect.maxY - 1))
            path.addLine(to: CGPoint(x: bubbleRect.maxX - 28, y: rect.maxY))
            path.addLine(to: CGPoint(x: bubbleRect.maxX - 70, y: bubbleRect.maxY - 1))
        }

        path.closeSubpath()
        return path
    }
}

private struct TextureSwatch: View {
    let texture: MaterialTexture

    var body: some View {
        Circle()
            .fill(texture.fallbackColor.swiftUIColor)
            .frame(width: 46, height: 46)
            .overlay {
                Image(systemName: texture.previewSystemImage)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.82))
            }
    }
}

private struct ShapeFoundToast: View {
    let celebration: CheckpointCelebration

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.green)
            Text("Yeay, ketemu! Ada bentuk apa lagi, ya?")
                .font(.headline.bold())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }
}
