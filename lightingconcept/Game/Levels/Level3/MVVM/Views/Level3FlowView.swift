import SwiftUI
import UIKit

struct Level3FlowView: View {
    @State private var viewModel = Level3ViewModel()
    @State private var narrator = LessonAudioNarrator(playbackRate: 1.5)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }
    
    @State private var showsExitConfirmation = false
    @State private var showsSkipIntroPrompt: Bool
    private let shouldAskToSkipIntro: Bool
    let onReturnToLevelMenu: (() -> Void)?

    init(
        shouldAskToSkipIntro: Bool = false,
        onReturnToLevelMenu: (() -> Void)? = nil
    ) {
        self.shouldAskToSkipIntro = shouldAskToSkipIntro
        _showsSkipIntroPrompt = State(initialValue: shouldAskToSkipIntro)
        self.onReturnToLevelMenu = onReturnToLevelMenu
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Level3ARContainerView(viewModel: viewModel)
                .ignoresSafeArea()
            
            overlay

            if viewModel.showsGuideOverlay {
                Level3ResponsiveGuideOverlay(
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
                    .padding(.top, isCompactWidth ? 42 : 56)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed, viewModel.phase != .photoComparison {
                LevelBackButton(action: { showsExitConfirmation = true })
                    .padding(.leading, isCompactWidth ? 10 : 16)
                    .padding(.top, isCompactWidth ? 8 : 12)
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
                .padding(.trailing, isCompactWidth ? 10 : 16)
                .padding(.top, isCompactWidth ? 8 : 12)
            }
        }
        .overlay {
            if let safetyWarning = viewModel.safetyWarning {
                SafetyWarningDialog(
                    warning: safetyWarning,
                    onDismiss: viewModel.dismissSafetyWarning
                )
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
        .gameDialog(
            isPresented: showsSkipIntroPrompt,
            title: "Do you want to skip the intro?",
            message: "",
            primaryTitle: "Yes",
            secondaryTitle: "No",
            primaryAction: skipIntroForReplay,
            secondaryAction: playIntroNormally
        )
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
        .task(id: "\(viewModel.narrationID)-skipPrompt-\(showsSkipIntroPrompt)") {
            guard !showsSkipIntroPrompt else {
                narrator.stop()
                return
            }
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
        .onAppear {
            showsSkipIntroPrompt = shouldAskToSkipIntro
            BackgroundMusicPlayer.shared.playGameplayMusic()
        }
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
            return isCompactWidth ? 120 : 190

        case .shadowTypesInteraction, .drawingPrompt:
            return isCompactWidth ? 76 : 112

        default:
            return isCompactWidth ? 20 : 32
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
                Level3ResponsiveEndLevelView(
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

    private func skipIntroForReplay() {
        narrator.stop()
        showsSkipIntroPrompt = false
        viewModel.narrationDidFinish()
        viewModel.startCompletedLevelReplayAtTask()
    }

    private func playIntroNormally() {
        showsSkipIntroPrompt = false
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {

            Button("Info Bayangan", systemImage: "info.circle", action: onInfoTap)
            .labelStyle(.iconOnly)
            .font(.system(size: compact ? 18 : 22, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: compact ? 42 : 48, height: compact ? 42 : 48)
            .background(.thinMaterial, in: Circle())
            .shadow(radius: 3, y: 1)
            .buttonStyle(.plain)
            .overlay {
                if showsGesture && !isOpen {
                    Level3InfoGestureImage()
                        .frame(width: compact ? 64 : 82, height: compact ? 64 : 82)
                        .offset(x: compact ? -18 : -23, y: compact ? 18 : 23)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }

            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onTypesTap) {
                        Text(areMarkersVisible ? "Tutup Mark" : "Buka Mark")
                        .font(compact ? .subheadline.weight(.semibold) : .headline)
                        .foregroundStyle(Color(hex: "21415D"))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, compact ? 11 : 14)
                    .padding(.vertical, compact ? 9 : 11)
                    .overlay {
                        if showsGesture {
                            Level3InfoGestureImage()
                                .frame(width: compact ? 64 : 82, height: compact ? 64 : 82)
                                .offset(x: compact ? -18 : -23, y: compact ? 18 : 23)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }

                    Divider()
                        .padding(.horizontal, compact ? 11 : 14)

                    Text("Jenis Bayangan")
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, compact ? 11 : 14)
                        .padding(.vertical, compact ? 9 : 11)
                }
                .fixedSize(horizontal: true, vertical: false)
                .background(.thinMaterial, in: .rect(cornerRadius: compact ? 12 : 14))
                .overlay(RoundedRectangle(cornerRadius: compact ? 12 : 14)
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack {
            Spacer()

            HStack(alignment: .bottom, spacing: compact ? 8 : 12) {
                Spacer()

                VStack(alignment: .trailing, spacing: compact ? 8 : 10) {
                    HStack(alignment: .bottom, spacing: compact ? 8 : 12) {
                        LevelSpeechBubble(text: text)
                            .frame(maxWidth: compact ? 300 : 420)
                            .fixedSize(horizontal: false, vertical: true)

                        LevelGuideCharacterImage(assetName: "bayoPointWink")
                            .frame(width: compact ? 80 : 104, height: compact ? 112 : 144)
                    }

                    LevelActionButton(
                        title: actionTitle,
                        isDisabled: isActionDisabled,
                        action: action
                    )
                    .padding(.trailing, compact ? 92 : 116)
                }
                .padding(.trailing, compact ? 14 : 42)
                .padding(.bottom, compact ? 12 : 22)
            }
        }
    }
}

private struct Level3PhotoComparisonOverlay: View {
    let frozenSceneImage: UIImage?
    let userDrawingImage: UIImage?
    let isActionDisabled: Bool
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { proxy in

            let horizontalPadding: CGFloat = compact ? 12 : 26

            let spacing: CGFloat = compact ? 10 : 18

            let availableWidth = proxy.size.width - (horizontalPadding * 2) - spacing

            let imageWidth = compact ? min(310, max(140, availableWidth / 2)) : 480

            let imageHeight = compact ? min(210, imageWidth * 0.70) : 440

            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                VStack(spacing: compact ? 12 : 18) {

                    HStack(spacing: spacing) {
                        comparisonImage(
                            title: "Scene Freeze",
                            image: frozenSceneImage,
                            width: imageWidth,
                            height: imageHeight
                        )

                        comparisonImage(
                            title: "Gambar Kamu",
                            image: userDrawingImage,
                            width: imageWidth,
                            height: imageHeight
                        )
                    }

                    LevelActionButton(
                        title: "Selesai",
                        systemImage: "checkmark",
                        isDisabled: isActionDisabled,
                        action: action
                    )
                }
                .padding(compact ? 14 : 26)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: compact ? 16 : 8))
                .frame(maxWidth: compact ? proxy.size.width - 20 : 1080)
                .padding(.horizontal, compact ? 10 : 32)
            }
        }
    }

    private func comparisonImage(title: String, image: UIImage?, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(compact ? .subheadline.bold() : .title3.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.white.opacity(0.18)
                }
            }
            .frame(width: width, height: height)
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

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
        .padding(.trailing, compact ? 14 : 42)
        .padding(.bottom, compact ? 14 : 36)
    }
}

private struct Level3ShadowToggleButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack {
            Spacer()

            HStack {
                LevelActionButton(
                    title: title,
                    systemImage: "eye.fill",
                    action: action
                )
                .padding(.leading, compact ? 14 : 42)

                Spacer()
            }
            .padding(.bottom, compact ? 14 : 36)
        }
    }
}

private struct Level3ShapeComparison: View {
    let viewModel: Level3ViewModel
    let replayNarration: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: compact ? 9 : 12) {
            Text("Bentuk berbeda, bayangan berbeda")
                .font(compact ? .headline : .title3)
                .bold()
                .multilineTextAlignment(.center)

            HStack(spacing: compact ? 8 : 12) {
                ForEach(Level3ViewModel.ComparisonShape.allCases) { shape in

                    LevelActionButton(
                        title: shape.rawValue,
                        systemImage: shape == .cube ? "cube.fill" : "circle.fill",
                        role: viewModel.selectedComparison == shape ? .primary : .secondary,
                        action: { viewModel.chooseComparison(shape) }
                    )
                }
            }

            Text(viewModel.hasComparedShapes ? "Kedua bentuk sudah dibandingkan!" : "Pilih kedua bentuk, lalu bandingkan bayangannya.")
            .font(compact ? .subheadline : .headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Level2ReplayNarrationButton(action: replayNarration)
        }
        .padding(compact ? 14 : 22)
        .frame(maxWidth: compact ? 560 : .infinity)
        .background(.thinMaterial, in: .rect(cornerRadius: compact ? 20 : 28))
        .padding(.horizontal, compact ? 12 : 20)
        .padding(.bottom, compact ? 14 : 36)
    }
}

private struct Level3ResponsiveGuideOverlay: View {
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
            let bubbleWidth = min(compact ? 300 : 420, proxy.size.width * (compact ? 0.42 : 0.54))

            let characterWidth: CGFloat = compact ? 80 : 104

            let characterHeight: CGFloat = compact ? 112 : 144

            let spacing: CGFloat = compact ? 8 : 12

            let groupWidth = bubbleWidth + spacing + characterWidth

            let groupHeight = max(bubbleWidth * 0.55, characterHeight)

            HStack(alignment: .bottom, spacing: spacing) {

                LevelSpeechBubble(text: text, showsTapToContinueCaption: showsTapToContinueCaption)
                .frame(maxWidth: bubbleWidth)
                .fixedSize(horizontal: false, vertical: true)

                LevelGuideCharacterImage(assetName: assetName)
                .frame(width: characterWidth, height: characterHeight)
            }
            .position(overlayPosition(in: proxy.size, groupWidth: groupWidth, groupHeight: groupHeight))
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func overlayPosition(in size: CGSize, groupWidth: CGFloat, groupHeight: CGFloat) -> CGPoint {
        let halfWidth = groupWidth / 2
        let halfHeight = groupHeight / 2

        let proposed = screenPosition ?? CGPoint(x: size.width - halfWidth - (compact ? 12 : 20), y: size.height - bottomPadding - halfHeight)

        let minX = halfWidth + 8

        let maxX = max(minX, size.width - halfWidth - 8)

        let minY = halfHeight + 8

        let maxY = max(minY, size.height - bottomPadding - halfHeight)

        return CGPoint(x: min(max(proposed.x, minX), maxX), y: min(max(proposed.y, minY), maxY))
    }
}

private struct Level3ResponsiveEndLevelView: View {
    let data: EndLevelModel
    let onBack: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("containerWood")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                VStack(spacing: compact ? 22 : 70) {
                    ZStack {
                        Image("ribbonBlue")
                            .resizable()
                            .scaledToFit()
                            .frame(width: compact ? min(proxy.size.width * 0.45, 300) : 378)

                        Text("LEVEL \(data.levelNumber)")
                            .font(.system(size: compact ? 24 : 36, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(y: compact ? -4 : -7)
                    }

                    Text(data.message)
                        .font(compact ? .system(size: 20, weight: .semibold) : .title.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                        .frame(width: min(compact ? 520 : 625, proxy.size.width - (compact ? 24 : 40)), height: compact ? 88 : 130)
                        .background(RoundedRectangle(cornerRadius: compact ? 18 : 25)
                            .fill(Color(hex: "C98928"))
                        )
                        .overlay(RoundedRectangle(cornerRadius: compact ? 18 : 25)
                            .stroke(Color(hex: "7E520E"),lineWidth: 2)
                        )

                    HStack(spacing: compact ? 10 : 24) {
                        LevelActionButton(
                            title: "Kembali ke Menu",
                            systemImage: "house.fill",
                            role: .menu,
                            action: onBack
                        )
                    }
                    .frame(maxWidth: proxy.size.width - (compact ? 24 : 48))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, compact ? 8 : 20)

                Image(data.mascotImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 86 : 160, height: compact ? 120 : 220)
                    .position(x: proxy.size.width - (compact ? 58 : 115), y: proxy.size.height - (compact ? 54 : 82))
            }
        }
        .ignoresSafeArea()
    }
}
