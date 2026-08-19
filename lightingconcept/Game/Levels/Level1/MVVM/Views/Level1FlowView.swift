//
//  Level1FlowView.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI
import UIKit

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
            case .returningToFirstObject:
                EmptyView()
            case .textureTapPrompt:
                Level1TextureTapPromptOverlay(viewModel: viewModel)
            case .textureExploration:
                Level1TextureOverlay(viewModel: viewModel)
            case .shapeChange:
                Level1ShapeChangeOverlay(viewModel: viewModel)
            case .drawingPrompt, .drawingReady, .drawingActive:
                Level1DrawingOverlay(viewModel: viewModel)
            case .photoPrompt:
                Level1PhotoOverlay(viewModel: viewModel)
            case .photoComparison:
                Level1PhotoSavedOverlay(viewModel: viewModel)
            case .completed:
                EndLevelView(
                    data: EndLevelViewModel.data(for: Level1Content.levelID),
                    onBack: dismiss.callAsFunction,
                    onNext: onNextLevel
                )
                .padding(.bottom, 24)
            }

            if viewModel.showsGuideOverlay {
                Level1GuideOverlay(viewModel: viewModel)
            }

            if viewModel.showsPhotoComparisonPanel {
                Level1PhotoComparisonOverlay(viewModel: viewModel)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed {
                LevelBackButton { showsExitConfirmation = true }
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            Level1DevFlowMenu(viewModel: viewModel)
                .padding(.trailing, 16)
                .padding(.top, 12)
        }
        #endif
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
        .gameDialog(
            isPresented: viewModel.showsFreezeSceneConfirmation,
            title: viewModel.isPreparingFrozenScene ? "Menyiapkan scene" : "Scene akan di-freeze",
            message: "Pastikan layarmu menangkap objek.",
            primaryTitle: "Iya, lanjut",
            secondaryTitle: "Sebentar aku arahkan lagi",
            isLoading: viewModel.isPreparingFrozenScene,
            loadingMessage: "Sebentar ya, gambarnya sedang disiapkan.",
            primaryAction: viewModel.confirmFreezeSceneAndStartDrawing,
            secondaryAction: viewModel.cancelFreezeSceneConfirmation
        )
        .gameDialog(
            isPresented: viewModel.photoSaveMessage != nil,
            title: "Foto Gambar",
            message: viewModel.photoSaveMessage ?? "",
            primaryTitle: "OK",
            primaryAction: viewModel.clearPhotoSaveMessage
        )
        .levelExitConfirmation(isPresented: $showsExitConfirmation) {
            dismiss()
        }
        .fullScreenCover(isPresented: $viewModel.showsDrawingCamera) {
            DrawingCameraView(
                onImagePicked: viewModel.completeUserDrawingPhoto,
                onCancel: viewModel.cancelDrawingCamera
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
        .sensoryFeedback(.success, trigger: viewModel.successFeedbackTrigger)
        .task(id: viewModel.narrationID) {
            // Saat scanning, anak hanya melihat instruksi scan. Lumi dan
            // narasinya baru mulai setelah surface stabil dan scene siap.
            guard viewModel.phase != .scanningSurface else {
                narrator.stop()
                return
            }
            narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName)
        }
        .onAppear(perform: BackgroundMusicPlayer.shared.useGameplayVolume)
        .onDisappear {
            narrator.stop()
            BackgroundMusicPlayer.shared.useMenuVolume()
        }
        .navigationBarBackButtonHidden(true)
    }
}

private struct Level1GuideOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        GeometryReader { proxy in
            guideContent
                .position(overlayPosition(in: proxy.size))
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var guideContent: some View {
        HStack(alignment: .bottom, spacing: 12) {
            SpeechBubble(text: viewModel.narrationText, tail: .bottomTrailing)
                .frame(maxWidth: 420)
                .fixedSize(horizontal: false, vertical: true)

            guideImage
                .frame(width: 104, height: 144)
        }
    }

    private func overlayPosition(in size: CGSize) -> CGPoint {
        if let arPosition = viewModel.guideOverlayScreenPosition {
            let x = min(max(arPosition.x, 280), size.width - 120)
            let y = min(max(arPosition.y, 150), size.height - bottomPadding)
            return CGPoint(x: x, y: y)
        }

        return CGPoint(x: size.width - 280, y: size.height - bottomPadding)
    }

    private var guideImage: some View {
        Group {
            if let image = UIImage(named: viewModel.guideOverlayAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "sparkles")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }

    private var bottomPadding: CGFloat {
        switch viewModel.phase {
        case .textureExploration, .shapeChange, .drawingReady, .photoPrompt:
            132
        default:
            32
        }
    }
}

#if DEBUG
private struct Level1DevFlowMenu: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        Menu {
            ForEach(Level1DevFlow.allCases) { flow in
                Button(flow.rawValue) {
                    viewModel.jumpToDevFlow(flow)
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.44), in: Circle())
        }
        .accessibilityLabel("Debug flow")
    }
}
#endif

private struct Level1OpeningOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        EmptyView()
    }
}

private struct Level1LightShadowOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        EmptyView()
    }
}

private struct Level1FindShapeOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        EmptyView()
    }
}

private struct Level1TextureTapPromptOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        GeometryReader { proxy in
            TouchGestureImage()
                .frame(width: 82, height: 164)
                .rotationEffect(.degrees(210))
                .position(handPosition(in: proxy.size))
                .allowsHitTesting(false)
        }
        .transition(.opacity)
    }

    private func handPosition(in size: CGSize) -> CGPoint {
        let objectPosition = viewModel.textureTapObjectScreenPosition
            ?? CGPoint(x: size.width * 0.5, y: size.height * 0.56)

        return CGPoint(
            x: min(max(objectPosition.x - 58, 70), size.width - 70),
            y: min(max(objectPosition.y + 62, 120), size.height - 90)
        )
    }
}

private struct Level1TextureOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack {
            if viewModel.showsExperimentControls {
                VStack {
                    Spacer()
                    Level1ExperimentControls(viewModel: viewModel)
                }
            }
        }
    }
}

private struct Level1ShapeChangeOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack {
            if viewModel.showsExperimentControls {
                VStack {
                    Spacer()
                    Level1ExperimentControls(viewModel: viewModel)
                }
            } else if viewModel.canConfirmDrawingChoices {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Level1PrimaryActionButton(title: "Aku Pilih Ini", action: viewModel.confirmDrawingChoices)
                            .padding(.trailing, 42)
                            .padding(.bottom, 36)
                    }
                }
            }
        }
    }
}

struct Level1PrimaryActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.blue, in: Capsule())
    }
}

private struct Level1DrawingOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        if viewModel.phase == .drawingReady || viewModel.phase == .drawingActive {
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 14) {
                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        DrawingInstructionBubble(text: "Kalau sudah, tekan tombol ini ya!")
                            .frame(width: 310)

                        HStack(alignment: .bottom, spacing: 14) {
                            Level1OverlayGuideCharacter(assetName: viewModel.guideOverlayAssetName)
                                .frame(width: 128, height: 150)

                            Button("Aku Selesai Gambar", action: viewModel.finishDrawing)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.blue, in: Capsule())
                                .padding(.bottom, 18)
                        }
                    }
                    .padding(.trailing, 42)
                    .padding(.bottom, 22)
                }
            }
            .allowsHitTesting(true)
        }
    }
}

private struct DrawingInstructionBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 40)
            .background {
                SpeechBubbleShape(tail: .bottomTrailing)
                    .fill(.white.opacity(0.88))
                    .stroke(.white, lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

private struct Level1PhotoOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(viewModel.isSavingDrawingPhoto ? "Menyimpan..." : "Foto Gambarku") {
                    viewModel.captureDrawingPhoto()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.blue, in: Capsule())
                .disabled(viewModel.isSavingDrawingPhoto)
                .padding(.trailing, 42)
                .padding(.bottom, 36)
            }
        }
    }
}

private struct Level1PhotoSavedOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Level1PrimaryActionButton(title: "Lihat Gambar", action: viewModel.showPhotoComparisonPanel)
                    .padding(.trailing, 42)
                    .padding(.bottom, 36)
            }
        }
    }
}

/// Kontrol interaksi mengikuti panel Figma: daftar vertikal di kiri dan
/// tombol mode kecil di bawahnya agar area AR tetap terbuka.
private struct Level1PhotoComparisonOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    comparisonImage(title: "Contoh", image: viewModel.frozenSceneImage)
                    comparisonImage(title: "Hasil Gambar Kamu", image: viewModel.userDrawingImage)
                }

                Button("Selesai", action: viewModel.completeLevelAfterPhotoComparison)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                    .background(Color.red, in: Capsule())
            }
            .padding(26)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 1080)
            .padding(.horizontal, 32)
        }
    }

    private func comparisonImage(title: String, image: UIImage?) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white.opacity(0.18)
                }
            }
            .frame(width: 480, height: 440)
            .background(Color.black.opacity(0.18))
            .clipped()
        }
    }
}

private struct Level1OverlayGuideCharacter: View {
    let assetName: String

    var body: some View {
        Group {
            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "sparkles")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

private struct DrawingCameraView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }
            onImagePicked(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
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
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color(UIColor.darkGray))
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(0.95))
            }
            .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
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
