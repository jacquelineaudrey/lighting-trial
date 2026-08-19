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
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.phase != .completed {
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
            if let celebration = viewModel.progressCelebration {
                LessonProgressCelebrationOverlay(celebration: celebration)
                    .id(celebration.id)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .padding(.top, 56)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 10) {
                if viewModel.phase == .review {
                    ZStack(alignment: .topTrailing) {
                        Level3InfoMenu(
                            isOpen: viewModel.isShadowInfoOpen,
                            areMarkersVisible: viewModel.areReviewMarkersVisible,
                            onInfoTap: viewModel.handleInfoButtonTap,
                            onTypesTap: viewModel.handleShadowTypesMenuTap
                        )

                        if viewModel.shouldShowInfoGesture {
                            Level3InfoGestureImage()
                                .frame(width: 82, height: 82)
                                .offset(infoGestureOffset)
                                .allowsHitTesting(false)
                        }
                    }
                }

                #if DEBUG
                if viewModel.phase != .completed {
                    Level3DevFlowMenu(viewModel: viewModel)
                }
                #endif
            }
            .padding(.trailing, 18)
            .padding(.top, 12)
        }
        .overlay {
            if viewModel.showsFreezeSceneConfirmation {
                Level3GreenConfirmationOverlay(
                    title: "Scene akan di-freeze",
                    message: "Pastikan objek dan bayangannya sudah terlihat jelas sebelum mulai menggambar.",
                    confirmTitle: "Iya, lanjut",
                    cancelTitle: "Sebentar",
                    onConfirm: viewModel.confirmFreezeSceneAndStartDrawing,
                    onCancel: viewModel.cancelFreezeSceneConfirmation
                )
            }
        }
        .overlay(alignment: .top) {
            if let message = viewModel.photoSaveMessage {
                Level3GreenNotice(message: message, onDismiss: viewModel.clearPhotoSaveMessage)
                    .padding(.top, 54)
                    .padding(.horizontal, 20)
            }
        }
        .gameDialog(
            isPresented: viewModel.showsFreezeSceneConfirmation,
            title: "Scene akan di-freeze",
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
            try? await Task.sleep(for: .milliseconds(150))
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

    private var infoGestureOffset: CGSize {
        viewModel.isShadowInfoOpen
            ? CGSize(width: -92, height: 50)
            : CGSize(width: -20, height: 0)
    }

    @ViewBuilder
    private var overlay: some View {
        switch viewModel.phase {
        case .onboarding:
            if !viewModel.arSceneViewModel.isObjectPlaced {
                Level3DialogTapCatcher(
                    isEnabled: viewModel.canAdvanceCurrentDialog,
                    action: viewModel.advanceOnboarding
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
                action: viewModel.advanceShadowTrivia
            )

        case .closing:
            Level3DialogTapCatcher(
                isEnabled: viewModel.canAdvanceCurrentDialog,
                action: viewModel.advanceClosing
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
                Level3NextButton(title: "Selanjutnya", action: viewModel.advanceReview)
            } else {
                EmptyView()
            }

        case .drawingPrompt:
            Level3DialogTapCatcher(
                isEnabled: viewModel.canAdvanceCurrentDialog,
                action: viewModel.requestFreezeSceneForDrawing
            )

        case .drawingReady:
            Level3FrozenDrawingOverlay(
                text: viewModel.currentDrawingLine.text,
                actionTitle: "Sudah Menggambar",
                isActionDisabled: !viewModel.canAdvanceCurrentDialog,
                action: viewModel.finishDrawing
            )

        case .photoPrompt:
            Level3FrozenDrawingOverlay(
                text: viewModel.currentDrawingLine.text,
                actionTitle: viewModel.isSavingDrawingPhoto ? "Menyimpan..." : "Foto Gambarku",
                isActionDisabled: viewModel.isSavingDrawingPhoto || !viewModel.canAdvanceCurrentDialog,
                action: viewModel.captureDrawingPhoto
            )

        case .photoComparison:
            Level3PhotoComparisonOverlay(
                frozenSceneImage: viewModel.frozenSceneImage,
                userDrawingImage: viewModel.userDrawingImage,
                isActionDisabled: !viewModel.canAdvanceCurrentDialog,
                action: viewModel.completeLevelAfterPhotoComparison
            )

        case .completed:
            EndLevelView(
                data: EndLevelViewModel.data(for: Level3Content.levelID),
                onBack: returnToLevelMenu,
                backTitle: "Kembali ke Menu"
            )
            .padding(.bottom, 24)

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
        LevelTapToAdvanceOverlay(isEnabled: isEnabled, action: action)
    }
}

private struct Level3InfoMenu: View {
    let isOpen: Bool
    let areMarkersVisible: Bool
    let onInfoTap: () -> Void
    let onTypesTap: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button(action: onInfoTap) {
                Image(systemName: "info.circle")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color(hex: "21415D"))
                    .frame(width: 52, height: 52)
                    .background(.thinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color(hex: "9FA60C").opacity(0.55), lineWidth: 2)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOpen ? "Tutup info bayangan" : "Buka info bayangan")

            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onTypesTap) {
                        Text(areMarkersVisible ? "Tutup Mark" : "Buka Mark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.82))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)

                    Divider()
                        .padding(.horizontal, 14)

                    Text("Jenis Bayangan")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.32))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 14)
                    .frame(minHeight: 48)
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

#if DEBUG
private struct Level3DevFlowMenu: View {
    let viewModel: Level3ViewModel

    var body: some View {
        Menu {
            ForEach(Level3DevFlow.allCases) { flow in
                Button(flow.rawValue) {
                    viewModel.jumpToDevFlow(flow)
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.44), in: Circle())
        }
        .accessibilityLabel("Debug flow")
    }
}
#endif

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
        ZStack(alignment: .bottomLeading) {
            HStack(alignment: .bottom, spacing: 8) {
                bayoImage
                    .frame(width: 120, height: 148)
                    .padding(.leading, 24)

                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(minWidth: 230, maxWidth: 360, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        TrianglePointer()
                            .fill(.ultraThinMaterial)
                            .frame(width: 18, height: 16)
                            .rotationEffect(.degrees(180))
                            .offset(x: -14),
                        alignment: .leading
                    )
                    .padding(.bottom, 42)

                Spacer()
            }

            HStack {
                Spacer()
                LevelActionButton(
                    title: actionTitle,
                    systemImage: "pencil.and.outline",
                    isDisabled: isActionDisabled,
                    action: action
                )
                    .padding(.trailing, 24)
                    .padding(.bottom, 34)
            }
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var bayoImage: some View {
        if let image = UIImage(named: "bayoPointWink") ?? UIImage(named: "bayoPoint") ?? UIImage(named: "bayoIdle") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(hex: "A86CE8"))
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
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 1080)
            .padding(.horizontal, 28)
        }
    }

    private func comparisonImage(title: String, image: UIImage?) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
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
            .frame(width: 440, height: 360)
            .background(Color.black.opacity(0.18))
            .clipped()
        }
    }
}

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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
            Button(title, action: action)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isDisabled ? Color.gray : Color.blue, in: Capsule())
                .buttonStyle(.plain)
                .disabled(isDisabled)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 34)
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
                    .padding(.leading, 24)

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
                 ? "Ketuk dimana saja untuk lanjut"
                 : "Pilih kedua bentuk, lalu bandingkan bayangannya.")
            .font(.subheadline)
            
            Level2ReplayNarrationButton(action: replayNarration)
        }
        .padding(22)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
    }
}
