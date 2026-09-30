//
//  Level5FlowView.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 28/09/26.
//

import SwiftUI
import UIKit

struct Level5FlowView: View {

    @State private var viewModel = Level5ViewModel()
    @State private var narrator = LessonAudioNarrator()
    @State private var showsExitConfirmation = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let onReturnToLevelMenu: (() -> Void)?

    init(onReturnToLevelMenu: (() -> Void)? = nil) {
        self.onReturnToLevelMenu = onReturnToLevelMenu
    }

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            Level5ARContainerView(viewModel: viewModel).ignoresSafeArea()
            
            overlay

            if let warning = viewModel.arSceneViewModel.safetyWarning {
                SafetyWarningDialog(warning: warning, onDismiss: viewModel.dismissSafetyWarning)
            }
        }

        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed && viewModel.phase != .photoComparison {
                LevelBackButton {
                    showsExitConfirmation = true
                }
                .padding(.leading, compact ? 10 : 16)
                .padding(.top, compact ? 8 : 12)
            }
        }

        .overlay(alignment: .top) {

            if viewModel.phase == .exploration {
                Text("Mode Lihat-Lihat")
                    .font(.system(size: compact ? 15 : 19, weight: .bold))
                    .foregroundStyle(Color(hex: "21415D"))
                    .padding(.horizontal, compact ? 18 : 24)
                    .padding(.vertical, compact ? 8 : 10)
                    .background(.white.opacity(0.92), in: Capsule())
                    .padding(.top, compact ? 18 : 28)
            }
        }

        .overlay(alignment: .topTrailing) {
            if viewModel.phase == .exploration {

                Level5LightPicker(
                    lights: viewModel.arSceneViewModel.lights,
                    selectedLightID: viewModel.selectedLightIDForUI,
                    compact: compact,
                    onSelect: viewModel.selectLight
                )
                .padding(.trailing, compact ? 10 : 18)
                .padding(.top, compact ? 56 : 72)
            }
        }

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

            Level5DrawingCameraView(
                onImagePicked: viewModel.completeUserDrawingPhoto,
                onCancel: viewModel.cancelDrawingCamera
            )
            .ignoresSafeArea()
        }

        .onReceive(viewModel.arSceneViewModel.$capturedSnapshotImage) { image in
            viewModel.handleCapturedARSnapshot(image)
        }

        .onAppear {
            BackgroundMusicPlayer.shared.playGameplayMusic()
        }

        .onDisappear {
            narrator.stop()

            BackgroundMusicPlayer.shared.playMenuMusic()
        }

        .task(id: viewModel.narrationID) {

            guard viewModel.shouldSpeakNarration
            else {
                narrator.stop()
                return
            }

            viewModel.narrationWillStart()

            try? await Task.sleep(
                nanoseconds:
                    120_000_000
            )

            guard !Task.isCancelled
            else {
                return
            }

            narrator.speak(
                viewModel.narrationText,
                audioFileName: nil,
                onCompletion:
                    viewModel.narrationDidFinish
            )
        }

        .animation(
            reduceMotion
                ? nil
                : .easeInOut(
                    duration: 0.25
                ),
            value:
                viewModel.phase
        )

        .sensoryFeedback(
            .success,
            trigger:
                viewModel.successFeedbackTrigger
        )

        .navigationBarBackButtonHidden(
            true
        )
    }

    @ViewBuilder
    private var overlay: some View {

        switch viewModel.phase {

        case .placingScene:

            Level5PlacementOverlay(
                compact:
                    compact
            )

        case .singleLightIntro:

            Level5ActionPanel(
                text:
                    Level5Content
                        .singleLightIntroText,

                buttonTitle:
                    "Tambahkan Lampu 2",

                compact:
                    compact,

                action:
                    viewModel.addSecondLight
            )

        case .twoLightIntro:

            Level5ActionPanel(
                text:
                    Level5Content
                        .twoLightIntroText,

                buttonTitle:
                    "Masuk Mode Lihat-Lihat",

                compact:
                    compact,

                action:
                    viewModel.beginExploration
            )

        case .exploration:

            Level5ExplorationOverlay(
                instruction:
                    viewModel
                        .explorationInstruction,

                hasMovedLeft:
                    viewModel.hasMovedLeft,

                hasMovedRight:
                    viewModel.hasMovedRight,

                canLockArrangement:
                    viewModel
                        .canLockArrangement,

                compact:
                    compact,

                action:
                    viewModel.confirmArrangement
            )

        case .drawingActive:

            Level5DrawingOverlay(
                compact:
                    compact,

                action:
                    viewModel.finishDrawing
            )

        case .photoPrompt:

            Level5ActionPanel(
                text:
                    Level5Content
                        .photoPromptText,

                buttonTitle:
                    viewModel
                        .arSceneViewModel
                        .isSavingSnapshot
                    ? "Menyiapkan..."
                    : "Foto Gambar",

                compact:
                    compact,

                isDisabled:
                    viewModel
                        .arSceneViewModel
                        .isSavingSnapshot,

                action:
                    viewModel
                        .captureDrawingPhoto
            )

        case .photoComparison:

            Level5PhotoComparisonOverlay(
                example:
                    viewModel.frozenSceneImage,

                result:
                    viewModel.userDrawingImage,

                compact:
                    compact,

                action:
                    viewModel
                        .completePhotoComparison
            )

        case .completed:

            Level5CompletedOverlay(
                compact:
                    compact,

                action:
                    returnToLevelMenu
            )
        }
    }

    private func returnToLevelMenu() {
        onReturnToLevelMenu?()
        dismiss()
    }
}

private struct Level5PlacementOverlay: View {

    let compact: Bool

    var body: some View {

        VStack {

            Spacer()

            Text(
                Level5Content.placementText
            )
            .font(
                .system(
                    size:
                        compact ? 16 : 20,
                    weight: .medium
                )
            )
            .multilineTextAlignment(
                .center
            )
            .foregroundStyle(
                .black
            )
            .padding(
                .horizontal,
                compact ? 18 : 28
            )
            .padding(
                .vertical,
                compact ? 12 : 18
            )
            .frame(
                maxWidth:
                    compact ? 420 : 620
            )
            .background(
                .white.opacity(0.92),
                in:
                    RoundedRectangle(
                        cornerRadius:
                            compact ? 16 : 22
                    )
            )
            .padding(
                .horizontal,
                compact ? 12 : 20
            )
            .padding(
                .bottom,
                compact ? 18 : 28
            )
        }
    }
}

private struct Level5ActionPanel: View {

    let text: String
    let buttonTitle: String
    let compact: Bool

    var isDisabled = false

    let action: () -> Void

    var body: some View {

        VStack {

            Spacer()

            VStack(
                spacing:
                    compact ? 10 : 14
            ) {

                Text(text)
                    .font(
                        .system(
                            size:
                                compact ? 16 : 20,
                            weight: .medium
                        )
                    )
                    .multilineTextAlignment(
                        .center
                    )
                    .foregroundStyle(
                        .black
                    )
                    .lineLimit(4)
                    .minimumScaleFactor(
                        0.78
                    )

                LevelActionButton(
                    title:
                        buttonTitle,

                    isDisabled:
                        isDisabled,

                    action:
                        action
                )
            }
            .padding(
                compact ? 14 : 22
            )
            .frame(
                maxWidth:
                    compact ? 540 : 700
            )
            .background(
                .regularMaterial,
                in:
                    RoundedRectangle(
                        cornerRadius:
                            compact ? 18 : 24
                    )
            )
            .padding(
                .horizontal,
                compact ? 12 : 24
            )
            .padding(
                .bottom,
                compact ? 14 : 28
            )
        }
    }
}

private struct Level5LightPicker: View {

    let lights: [LightConfiguration]
    let selectedLightID: UUID
    let compact: Bool
    let onSelect: (UUID) -> Void

    var body: some View {

        HStack(
            spacing:
                compact ? 6 : 8
        ) {

            ForEach(
                lights.prefix(2)
            ) { light in

                Button {
                    onSelect(light.id)
                } label: {

                    Text(light.name)
                        .font(
                            .system(
                                size:
                                    compact ? 14 : 17,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            light.id ==
                                selectedLightID
                            ? .white
                            : Color(
                                hex: "21415D"
                            )
                        )
                        .padding(
                            .horizontal,
                            compact ? 12 : 16
                        )
                        .padding(
                            .vertical,
                            compact ? 8 : 10
                        )
                        .background(
                            light.id ==
                                selectedLightID
                            ? Color(
                                hex:
                                    "9FA60C"
                            )
                            : Color.white
                                .opacity(0.88),
                            in: Capsule()
                        )
                }
                .buttonStyle(
                    .plain
                )
            }
        }
    }
}

private struct Level5ExplorationOverlay: View {

    let instruction: String
    let hasMovedLeft: Bool
    let hasMovedRight: Bool
    let canLockArrangement: Bool
    let compact: Bool
    let action: () -> Void

    var body: some View {

        VStack {

            Spacer()

            HStack {

                VStack(
                    alignment:
                        .leading,

                    spacing:
                        compact ? 8 : 10
                ) {

                    Text(instruction)
                        .font(
                            .system(
                                size:
                                    compact ? 15 : 18,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            .black
                        )
                        .multilineTextAlignment(
                            .leading
                        )
                        .lineLimit(4)
                        .minimumScaleFactor(
                            0.8
                        )

                    HStack(
                        spacing:
                            compact ? 8 : 10
                    ) {

                        movementBadge(
                            title:
                                "Kiri",
                            done:
                                hasMovedLeft
                        )

                        movementBadge(
                            title:
                                "Kanan",
                            done:
                                hasMovedRight
                        )
                    }

                    LevelActionButton(
                        title:
                            "Aku Pilih Ini",

                        isDisabled:
                            !canLockArrangement,

                        action:
                            action
                    )
                }
                .padding(
                    compact ? 14 : 20
                )
                .frame(
                    maxWidth:
                        compact ? 420 : 520,
                    alignment:
                        .leading
                )
                .background(
                    .regularMaterial,
                    in:
                        RoundedRectangle(
                            cornerRadius:
                                compact ? 18 : 24
                        )
                )

                Spacer()
            }
            .padding(
                .horizontal,
                compact ? 12 : 22
            )
            .padding(
                .bottom,
                compact ? 14 : 26
            )
        }
    }

    private func movementBadge(
        title: String,
        done: Bool
    ) -> some View {

        Label(
            title,
            systemImage:
                done
                    ? "checkmark.circle.fill"
                    : "circle"
        )
        .font(
            .system(
                size:
                    compact ? 13 : 15,
                weight: .semibold
            )
        )
        .foregroundStyle(
            done
                ? Color(
                    hex:
                        "6E8E15"
                )
                : .secondary
        )
    }
}

private struct Level5DrawingOverlay: View {

    let compact: Bool
    let action: () -> Void

    var body: some View {

        VStack {

            Spacer()

            HStack {

                Spacer()

                VStack(
                    alignment:
                        .trailing,

                    spacing:
                        compact ? 10 : 14
                ) {

                    Text(
                        Level5Content
                            .drawingText
                    )
                    .font(
                        .system(
                            size:
                                compact ? 16 : 20,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .black
                    )
                    .multilineTextAlignment(
                        .leading
                    )
                    .padding(
                        .horizontal,
                        compact ? 18 : 24
                    )
                    .padding(
                        .vertical,
                        compact ? 12 : 18
                    )
                    .frame(
                        maxWidth:
                            compact ? 330 : 420
                    )
                    .background(
                        .white.opacity(0.92),
                        in:
                            RoundedRectangle(
                                cornerRadius:
                                    compact ? 16 : 22
                            )
                    )

                    LevelActionButton(
                        title:
                            "Aku Selesai Gambar",

                        action:
                            action
                    )
                }
                .padding(
                    .trailing,
                    compact ? 14 : 30
                )
                .padding(
                    .bottom,
                    compact ? 14 : 24
                )
            }
        }
    }
}

private struct Level5PhotoComparisonOverlay: View {

    let example: UIImage?
    let result: UIImage?
    let compact: Bool
    let action: () -> Void

    var body: some View {

        GeometryReader { proxy in

            let horizontalPadding:
                CGFloat =
                    compact ? 10 : 26

            let spacing:
                CGFloat =
                    compact ? 10 : 20

            let availableWidth =
                proxy.size.width
                - (horizontalPadding * 2)
                - spacing

            let imageWidth =
                min(
                    compact ? 320 : 480,
                    max(
                        140,
                        availableWidth / 2
                    )
                )

            let imageHeight =
                compact
                    ? min(
                        215,
                        imageWidth * 0.70
                    )
                    : 440

            ZStack {

                Color.black
                    .opacity(0.38)
                    .ignoresSafeArea()

                VStack(
                    spacing:
                        compact ? 10 : 18
                ) {

                    Text(
                        "Perbandingan Gambar"
                    )
                    .font(
                        .system(
                            size:
                                compact ? 20 : 26,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        .white
                    )

                    HStack(
                        spacing:
                            spacing
                    ) {

                        imageCard(
                            title:
                                "Contoh",

                            image:
                                example,

                            width:
                                imageWidth,

                            height:
                                imageHeight
                        )

                        imageCard(
                            title:
                                "Hasil",

                            image:
                                result,

                            width:
                                imageWidth,

                            height:
                                imageHeight
                        )
                    }

                    LevelActionButton(
                        title:
                            "Selesai",

                        systemImage:
                            "checkmark",

                        action:
                            action
                    )
                }
                .padding(
                    compact ? 12 : 24
                )
                .background(
                    .ultraThinMaterial,
                    in:
                        RoundedRectangle(
                            cornerRadius:
                                compact ? 18 : 26
                        )
                )
                .frame(
                    maxWidth:
                        compact
                            ? proxy.size.width - 18
                            : 1100
                )
                .padding(
                    .horizontal,
                    horizontalPadding
                )
            }
        }
    }

    private func imageCard(
        title: String,
        image: UIImage?,
        width: CGFloat,
        height: CGFloat
    ) -> some View {

        VStack(spacing: 7) {

            Text(title)
                .font(
                    .system(
                        size:
                            compact ? 15 : 20,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    .white
                )
                .lineLimit(1)
                .minimumScaleFactor(
                    0.75
                )

            Group {

                if let image {

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                } else {

                    Color.white
                        .opacity(0.16)
                }
            }
            .frame(
                width: width,
                height: height
            )
            .background(
                Color.black.opacity(
                    0.18
                )
            )
            .clipped()
        }
    }
}

private struct Level5CompletedOverlay: View {

    let compact: Bool
    let action: () -> Void

    var body: some View {

        ZStack {

            Color.black
                .opacity(0.30)
                .ignoresSafeArea()

            VStack(
                spacing:
                    compact ? 12 : 18
            ) {

                Text("🎉")
                    .font(
                        .system(
                            size:
                                compact ? 52 : 72
                        )
                    )
                    .accessibilityHidden(
                        true
                    )

                Text("Kamu hebat!")
                    .font(
                        .system(
                            size:
                                compact ? 28 : 38,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        .white
                    )

                Text(
                    Level5Content
                        .completionText
                )
                .font(
                    .system(
                        size:
                            compact ? 16 : 21,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .white
                )
                .multilineTextAlignment(
                    .center
                )
                .frame(
                    maxWidth:
                        compact ? 500 : 650
                )

                LevelActionButton(
                    title:
                        "Selesai",

                    systemImage:
                        "checkmark",

                    action:
                        action
                )
            }
            .padding(
                compact ? 20 : 30
            )
            .background(
                .ultraThinMaterial,
                in:
                    RoundedRectangle(
                        cornerRadius:
                            compact ? 20 : 28
                    )
            )
            .padding(
                .horizontal,
                compact ? 12 : 24
            )
        }
    }
}

private struct Level5DrawingCameraView:
    UIViewControllerRepresentable {

    let onImagePicked:
        (UIImage) -> Void

    let onCancel:
        () -> Void

    func makeUIViewController(
        context: Context
    ) -> UIImagePickerController {

        let picker =
            UIImagePickerController()

        picker.sourceType =
            UIImagePickerController
                .isSourceTypeAvailable(
                    .camera
                )
            ? .camera
            : .photoLibrary

        picker.delegate =
            context.coordinator

        return picker
    }

    func updateUIViewController(
        _ uiViewController:
            UIImagePickerController,
        context: Context
    ) {}

    func makeCoordinator()
        -> Coordinator {

        Coordinator(
            onImagePicked:
                onImagePicked,

            onCancel:
                onCancel
        )
    }

    final class Coordinator:
        NSObject,
        UINavigationControllerDelegate,
        UIImagePickerControllerDelegate {

        let onImagePicked:
            (UIImage) -> Void

        let onCancel:
            () -> Void

        init(
            onImagePicked:
                @escaping
                    (UIImage) -> Void,

            onCancel:
                @escaping
                    () -> Void
        ) {
            self.onImagePicked =
                onImagePicked

            self.onCancel =
                onCancel
        }

        func imagePickerController(
            _ picker:
                UIImagePickerController,

            didFinishPickingMediaWithInfo info:
                [
                    UIImagePickerController.InfoKey:
                        Any
                ]
        ) {

            guard let image =
                info[.originalImage]
                    as? UIImage
            else {
                onCancel()
                return
            }

            onImagePicked(image)
        }

        func imagePickerControllerDidCancel(
            _ picker:
                UIImagePickerController
        ) {
            onCancel()
        }
    }
}
