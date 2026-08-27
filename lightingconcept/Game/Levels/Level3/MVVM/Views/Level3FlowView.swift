import SwiftUI
import UIKit

struct Level3FlowView: View {
    @State private var viewModel = Level3ViewModel()
    @State private var narrator = LessonAudioNarrator()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var showsExitConfirmation = false
    let onReturnToLevelMenu: (() -> Void)?

    init(onReturnToLevelMenu: (() -> Void)? = nil) {
        self.onReturnToLevelMenu = onReturnToLevelMenu
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Level3ARContainerView(viewModel: viewModel)
                .ignoresSafeArea()
            
            overlay

            if viewModel.showsGuideOverlay {
                LevelGuideOverlay(
                    text: viewModel.narrationText,
                    assetName: viewModel.guideOverlayAssetName,
                    screenPosition: viewModel.guideOverlayScreenPosition,
                    showsTapToContinueCaption: viewModel.showsTapToContinueCaption,
                    bottomPadding: guideBottomPadding
                )
            }
        }
        .overlay(alignment: .top) {
            if let celebration = viewModel.progressCelebration {
                LessonProgressCelebrationOverlay(celebration: celebration)
                    .id(celebration.id)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .padding(.top, 56)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed, viewModel.phase != .photoComparison {
                LevelBackButton(action: { showsExitConfirmation = true })
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.phase != .completed {
                HStack(alignment: .top, spacing: 12) {
                    if viewModel.canGoBackToPreviousState {
                        LevelRepeatStepButton(
                            isDisabled: viewModel.isTransitioning,
                            action: viewModel.goBackToPreviousState
                        )
                    }

                    if viewModel.phase == .review {
                        Level3InfoMenu(
                            isOpen: viewModel.isShadowInfoOpen,
                            areMarkersVisible: viewModel.areReviewMarkersVisible,
                            showsGesture: viewModel.shouldShowInfoGesture,
                            onInfoTap: viewModel.handleInfoButtonTap,
                            onTypesTap: viewModel.handleShadowTypesMenuTap
                        )
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 12)
            }
        }
        .gameDialog(
            isPresented: viewModel.showsFreezeSceneConfirmation,
            title: "Scene akan dibekukan",
            message: "Pastikan objek dan bayangannya sudah terlihat jelas sebelum mulai menggambar.",
            primaryTitle: "Iya, lanjut",
            secondaryTitle: "Sebentar aku arahkan lagi",
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
            Level3DrawingCameraView(
                onImagePicked: viewModel.completeUserDrawingPhoto,
                onCancel: viewModel.cancelDrawingCamera
            )
            .ignoresSafeArea()
        }
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.phase)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.arSceneViewModel.selectedConcept)
        .sensoryFeedback(.success, trigger: viewModel.successFeedbackTrigger)
        .task(id: viewModel.narrationID) {
            guard viewModel.shouldSpeakNarration else {
                narrator.stop()
                return
            }
            viewModel.narrationWillStart()
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            narrator.speak(
                viewModel.narrationText,
                audioFileNames: viewModel.narrationAudioFileNames,
                onCompletion: viewModel.narrationDidFinish
            )
        }
        .onAppear(perform: BackgroundMusicPlayer.shared.playGameplayMusic)
        .onDisappear {
            narrator.stop()
            BackgroundMusicPlayer.shared.playMenuMusic()
        }
        .onChange(of: viewModel.arSceneViewModel.surfaceState) { _, _ in
            viewModel.surfaceDidBecomeReady()
        }
        .onChange(of: viewModel.arSceneViewModel.selectedConcept) { _, _ in
            viewModel.forceSyncGuideForConcept()
        }
        .onChange(of: viewModel.markerNarrationTrigger) { _, _ in
            guard viewModel.arSceneViewModel.selectedConcept != nil else { return }
            viewModel.narrationWillStart()
            narrator.speak(
                viewModel.narrationText,
                audioFileNames: viewModel.narrationAudioFileNames,
                onCompletion: viewModel.narrationDidFinish
            )
        }
        .onChange(of: viewModel.arSceneViewModel.capturedSnapshotImage) { _, image in
            viewModel.completeFrozenSceneSnapshot(image)
        }
        .navigationBarBackButtonHidden(true)
    }

    private var guideBottomPadding: CGFloat {
        switch viewModel.phase {
        case .shapeComparison:
            190
        case .shadowTypesInteraction, .drawingPrompt:
            112
        default:
            32
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch viewModel.phase {
        case .onboarding:
            if !viewModel.arSceneViewModel.isObjectPlaced {
                Level3DialogTapCatcher(
                    isEnabled: viewModel.canAdvanceCurrentDialog,
                    action: advanceDialog(viewModel.advanceOnboarding)
                )
            } else {
                EmptyView()
            }

        case .placingScene:
            Level2PlacementOverlay(
                sceneViewModel: viewModel.arSceneViewModel,
                replayNarration: replayNarration
            )

        case .surfaceReady:
            SurfaceReadyOverlay(
                onContinue: viewModel.continueAfterSurfaceCheck,
                onRescan: viewModel.rescanSurface
            )

        case .shadowExploration:
            EmptyView()

        case .shadowTrivia:
            Level3DialogTapCatcher(
                isEnabled: viewModel.canAdvanceCurrentDialog,
                action: advanceDialog(viewModel.advanceShadowTrivia)
            )

        case .closing:
            Level3DialogTapCatcher(
                isEnabled: viewModel.canAdvanceCurrentDialog,
                action: advanceDialog(viewModel.advanceClosing)
            )

        case .shadowTypesInteraction:
            Level3ShadowToggleButton(
                title: viewModel.shadowVisible ? "Sembunyikan Bayangan" : "Tampilkan Bayangan",
                action: viewModel.toggleShadow
            )

        case .shapeComparison:
            Level3ShapeComparison(viewModel: viewModel, replayNarration: replayNarration)

        case .review:
            if viewModel.reviewIndex == Level3Content.reviewDialog.count - 1 {
                Level3NextButton(title: "Selanjutnya", action: advanceDialog(viewModel.advanceReview))
            } else {
                EmptyView()
            }

        case .drawingPrompt:
            Level3NextButton(
                title: "Selanjutnya",
                isDisabled: !viewModel.canAdvanceCurrentDialog,
                action: advanceDialog(viewModel.requestFreezeSceneForDrawing)
            )

        case .drawingReady:
            Level3FrozenDrawingOverlay(
                text: viewModel.currentDrawingLine.text,
                actionTitle: "Sudah Menggambar",
                isActionDisabled: !viewModel.canAdvanceCurrentDialog,
                action: advanceDialog(viewModel.finishDrawing)
            )

        case .photoPrompt:
            Level3FrozenDrawingOverlay(
                text: viewModel.currentDrawingLine.text,
                actionTitle: viewModel.isSavingDrawingPhoto ? "Menyimpan..." : "Foto Gambarku",
                isActionDisabled: viewModel.isSavingDrawingPhoto || !viewModel.canAdvanceCurrentDialog,
                action: advanceDialog(viewModel.captureDrawingPhoto)
            )

        case .photoComparison:
            Level3PhotoComparisonOverlay(
                frozenSceneImage: viewModel.frozenSceneImage,
                userDrawingImage: viewModel.userDrawingImage,
                isActionDisabled: !viewModel.canAdvanceCurrentDialog,
                action: advanceDialog(viewModel.completeLevelAfterPhotoComparison)
            )

        case .completed:
            ZStack {
                EndLevelView(
                    data: EndLevelViewModel.data(for: Level3Content.levelID),
                    onBack: returnToLevelMenu
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        }
    }

    /// Menghentikan narasi yang sedang berjalan dan menandainya selesai,
    /// supaya efek samping fase (mis. pindah fase, menyelesaikan konsep
    /// bayangan terpilih) tetap berjalan seperti biasa walau di-skip.
    private func skipNarrationIfNeeded() {
        guard !viewModel.isNarrationComplete else { return }
        narrator.stop()
        viewModel.narrationDidFinish()
    }

    /// Membungkus aksi lanjut dialog supaya ketukan pertama otomatis
    /// men-skip narasi yang masih berjalan sebelum melanjutkan.
    private func advanceDialog(_ advance: @escaping () -> Void) -> () -> Void {
        {
            skipNarrationIfNeeded()
            advance()
        }
    }

    private func replayNarration() {
        guard viewModel.shouldSpeakNarration else {
            narrator.stop()
            return
        }
        viewModel.narrationWillStart()
        narrator.speak(
            viewModel.narrationText,
            audioFileNames: viewModel.narrationAudioFileNames,
            onCompletion: viewModel.narrationDidFinish
        )
    }

    private func returnToLevelMenu() {
        onReturnToLevelMenu?()
        dismiss()
    }
}

private struct Level3DialogTapCatcher: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        LevelTapToAdvanceOverlay(
            isEnabled: isEnabled,
            showsCaption: false,
            action: action
        )
    }
}

private struct Level3InfoMenu: View {
    let isOpen: Bool
    let areMarkersVisible: Bool
    let showsGesture: Bool
    let onInfoTap: () -> Void
    let onTypesTap: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button("Info Bayangan", systemImage: "info.circle", action: onInfoTap)
                .labelStyle(.iconOnly)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 48, height: 48)
                .background(.thinMaterial, in: Circle())
                .shadow(radius: 3, y: 1)
                .buttonStyle(.plain)
                .overlay {
                    if showsGesture && !isOpen {
                        Level3InfoGestureImage()
                            .frame(width: 82, height: 82)
                            .offset(x: -23, y: 23)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }

            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onTypesTap) {
                        Text(areMarkersVisible ? "Tutup Mark" : "Buka Mark")
                            .font(.headline)
                            .foregroundStyle(Color(hex: "21415D"))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .overlay {
                        if showsGesture {
                            Level3InfoGestureImage()
                                .frame(width: 82, height: 82)
                                .offset(x: -23, y: 23)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }

                    Divider()
                        .padding(.horizontal, 14)

                    Text("Jenis Bayangan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                }
                .fixedSize(horizontal: true, vertical: false)
                .background(.thinMaterial, in: .rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }
}

private struct Level3InfoGestureImage: View {
    var body: some View {
        if let image = Self.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "hand.point.up.left.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
    }

    private static var image: UIImage? {
        ["gestureLevel3v1", "Gestures/gestureLevel3v1"]
            .lazy
            .compactMap { UIImage(named: $0) }
            .first
    }
}

private struct Level3FrozenDrawingOverlay: View {
    let text: String
    let actionTitle: String
    let isActionDisabled: Bool
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    HStack(alignment: .bottom, spacing: 12) {
                        LevelSpeechBubble(text: text)
                            .frame(maxWidth: 420)
                            .fixedSize(horizontal: false, vertical: true)

                        LevelGuideCharacterImage(assetName: "bayoPointWink")
                            .frame(width: 104, height: 144)
                    }

                    LevelActionButton(
                        title: actionTitle,
                        isDisabled: isActionDisabled,
                        action: action
                    )
                    .padding(.trailing, 116)
                }
                .padding(.trailing, 42)
                .padding(.bottom, 22)
            }
        }
    }
}

private struct Level3PhotoComparisonOverlay: View {
    let frozenSceneImage: UIImage?
    let userDrawingImage: UIImage?
    let isActionDisabled: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(spacing: 18) {
                    comparisonImage(title: "Scene Freeze", image: frozenSceneImage)
                    comparisonImage(title: "Gambar Kamu", image: userDrawingImage)
                }

                LevelActionButton(
                    title: "Selesai",
                    systemImage: "checkmark",
                    isDisabled: isActionDisabled,
                    action: action
                )
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
                .font(.title3.bold())
                .foregroundStyle(.white)

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
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

private struct Level3DrawingCameraView: UIViewControllerRepresentable {
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

private struct Level3NextButton: View {
    let title: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            LevelActionButton(
                title: title,
                systemImage: "arrow.right",
                isDisabled: isDisabled,
                action: action
            )
        }
        .padding(.trailing, 42)
        .padding(.bottom, 36)
    }
}

private struct Level3ShadowToggleButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                LevelActionButton(
                    title: title,
                    systemImage: "eye.fill",
                    action: action
                )
                .padding(.leading, 42)

                Spacer()
            }
            .padding(.bottom, 36)
        }
    }
}

private struct Level3ShapeComparison: View {
    let viewModel: Level3ViewModel
    let replayNarration: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Bentuk berbeda, bayangan berbeda")
                .font(.title3)
                .bold()
            HStack {
                ForEach(Level3ViewModel.ComparisonShape.allCases) { shape in
                    LevelActionButton(
                        title: shape.rawValue,
                        systemImage: shape == .cube ? "cube.fill" : "circle.fill",
                        role: viewModel.selectedComparison == shape ? .primary : .secondary,
                        action: { viewModel.chooseComparison(shape) }
                    )
                }
            }
            Text(viewModel.hasComparedShapes
                 ? "Kedua bentuk sudah dibandingkan!"
                 : "Pilih kedua bentuk, lalu bandingkan bayangannya.")
            .font(.headline)
            
            Level2ReplayNarrationButton(action: replayNarration)
        }
        .padding(22)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
    }
}
