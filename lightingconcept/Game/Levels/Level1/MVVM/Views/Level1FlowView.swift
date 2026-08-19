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
    let onReturnToLevelMenu: (() -> Void)?
    let onNextLevel: (() -> Void)?

    init(
        onReturnToLevelMenu: (() -> Void)? = nil,
        onNextLevel: (() -> Void)? = nil
    ) {
        self.onReturnToLevelMenu = onReturnToLevelMenu
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
                    SurfaceScanInstruction(
                        sceneViewModel: viewModel.arSceneViewModel,
                        progressOverride: viewModel.roomScanProgress,
                        title: "Scan Ruangan",
                        guidanceText: viewModel.roomScanGuidanceText
                    )
                    Spacer()
                }
            case .surfaceReady:
                VStack {
                    Spacer()
                    SurfaceReadyOverlay(
                        onContinue: viewModel.startLessonAfterRoomScan,
                        onRescan: viewModel.rescanSurface,
                        title: "Ruangan Siap",
                        message: "Tempat yang aman untuk semua bentuk sudah ditemukan. Yuk, mulai bermain!"
                    )
                }
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
                    onBack: returnToLevelMenu,
                    onNext: onNextLevel,
                    backTitle: "Kembali ke Menu"
                )
                .padding(.bottom, 24)
            }

            if viewModel.showsGuideOverlay {
                LevelGuideOverlay(
                    text: viewModel.narrationText,
                    assetName: viewModel.guideOverlayAssetName,
                    screenPosition: viewModel.guideOverlayScreenPosition,
                    showsTapToContinueCaption: viewModel.showsTapToContinueCaption,
                    bottomPadding: guideBottomPadding
                )
            }

            if viewModel.showsPhotoComparisonPanel {
                Level1PhotoComparisonOverlay(viewModel: viewModel)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed,
               !viewModel.showsPhotoComparisonPanel,
               viewModel.canGoBackToPreviousState {
                LevelActionButton(
                    title: "Ulangi Langkah",
                    systemImage: "arrow.uturn.backward",
                    role: .previousStep,
                    isDisabled: viewModel.isTransitioning,
                    action: viewModel.goBackToPreviousState
                )
                .padding(.leading, 16)
                .padding(.top, 12)
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.phase != .completed, !viewModel.showsPhotoComparisonPanel {
                LevelActionButton(
                    title: "Kembali ke Menu",
                    systemImage: "house.fill",
                    role: .menu,
                    action: { showsExitConfirmation = true }
                )
                .padding(.trailing, 16)
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
        .gameDialog(
            isPresented: viewModel.showsFreezeSceneConfirmation,
            title: viewModel.isPreparingFrozenScene ? "Menyiapkan scene" : "Scene akan dibekukan",
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
            returnToLevelMenu()
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
            guard viewModel.phase != .scanningSurface,
                  viewModel.phase != .surfaceReady else {
                narrator.stop()
                return
            }
            let narrationID = viewModel.narrationID
            viewModel.narrationWillStart(id: narrationID)
            narrator.speak(
                viewModel.narrationText,
                audioFileName: viewModel.narrationAudioFileName,
                onCompletion: { viewModel.narrationDidFinish(id: narrationID) }
            )
        }
        .onAppear(perform: BackgroundMusicPlayer.shared.playGameplayMusic)
        .onDisappear {
            narrator.stop()
            BackgroundMusicPlayer.shared.playMenuMusic()
        }
        .navigationBarBackButtonHidden(true)
    }

    private func returnToLevelMenu() {
        onReturnToLevelMenu?()
        dismiss()
    }

    private var guideBottomPadding: CGFloat {
        switch viewModel.phase {
        case .textureExploration, .shapeChange, .drawingReady, .photoPrompt:
            132
        default:
            32
        }
    }
}

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
                .frame(width: 72, height: 166)
                .rotationEffect(.degrees(-12))
                .position(handPosition(in: proxy.size))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .transition(.opacity)
    }

    private func handPosition(in size: CGSize) -> CGPoint {
        let objectPosition = viewModel.textureTapObjectScreenPosition
            ?? CGPoint(x: size.width * 0.5, y: size.height * 0.56)

        return CGPoint(
            // Ujung telunjuk tetap menempel pada objek; badan tangan berada di
            // bawah-kanannya agar objek tidak tertutup setelah ukurannya mengecil.
            x: min(max(objectPosition.x + 13, 42), size.width - 42),
            y: min(max(objectPosition.y + 60, 84), size.height - 84)
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
                        LevelActionButton(title: "Aku Pilih Ini", action: viewModel.confirmDrawingChoices)
                            .padding(.trailing, 42)
                            .padding(.bottom, 36)
                    }
                }
            }
        }
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

                            LevelActionButton(
                                title: "Aku Selesai Gambar",
                                isDisabled: !viewModel.isNarrationComplete || viewModel.isTransitioning,
                                action: viewModel.finishDrawing
                            )
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
                LevelActionButton(
                    title: viewModel.isSavingDrawingPhoto ? "Menyimpan..." : "Foto Gambarku",
                    systemImage: "camera.fill",
                    isDisabled: viewModel.isSavingDrawingPhoto
                        || !viewModel.isNarrationComplete
                        || viewModel.isTransitioning,
                    action: viewModel.captureDrawingPhoto
                )
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
                LevelActionButton(
                    title: "Lihat Gambar",
                    systemImage: "photo.on.rectangle.angled",
                    isDisabled: !viewModel.isNarrationComplete || viewModel.isTransitioning,
                    action: viewModel.showPhotoComparisonPanel
                )
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

                HStack(spacing: 14) {
                    LevelActionButton(
                        title: "Kembali",
                        systemImage: "chevron.left",
                        role: .secondary,
                        action: viewModel.hidePhotoComparisonPanel
                    )

                    LevelActionButton(
                        title: "Selesai",
                        systemImage: "checkmark",
                        action: viewModel.completeLevelAfterPhotoComparison
                    )
                }
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

private struct SpeechBubbleShape: Shape {
    enum Tail {
        case bottomLeading
        case bottomTrailing
    }

    let tail: Tail

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
