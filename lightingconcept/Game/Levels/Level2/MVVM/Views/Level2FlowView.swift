import SwiftUI

struct Level2FlowView: View {
    @State private var viewModel = Level2ViewModel()
    @State private var narrator = LessonAudioNarrator()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
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
        ZStack(alignment: .bottom) {
            Level2ARContainerView(
                sceneViewModel: viewModel.arSceneViewModel,
                viewModel: viewModel
            )
            .ignoresSafeArea()

            Level2GestureLayer(viewModel: viewModel)
                .ignoresSafeArea()

            switch viewModel.phase {
            case .onboarding:
                Level2MascotDialogOverlay(
                    line: viewModel.currentOnboardingLine,
                    buttonTitle: onboardingButtonTitle,
                    advancesOnTap: !viewModel.waitsForLightTap,
                    action: advanceDialog(viewModel.advanceOnboarding)
                )
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
            case .spreadTutorial:
                Level2SpreadTutorialOverlay(
                    step: viewModel.currentSpreadTutorialStep,
                    activeTouchCount: viewModel.activeTouchCount,
                    beamSpreadDegrees: viewModel.beamSpreadDegrees,
                    action: advanceDialog(viewModel.advanceSpreadTutorial)
                )
            case .spreadFreeIntro:
                Level2MascotDialogOverlay(
                    line: Level2Content.spreadFreeIntro,
                    action: advanceDialog(viewModel.advanceSpreadFreeIntro)
                )
            case .spreadFreeInstructions:
                Level2FreeExploreInstructionsOverlay(action: viewModel.dismissSpreadFreeInstructions)
            case .spreadFreeExploration:
                Level2FreeExploreOverlay(action: viewModel.finishSpreadFreeExploration)
            case .intensityTransition:
                Level2MascotDialogOverlay(
                    line: Level2Content.intensityTransition,
                    action: advanceDialog(viewModel.advanceIntensityTransition)
                )
            case .intensityTutorial:
                Level2IntensityTutorialOverlay(
                    step: viewModel.currentIntensityTutorialStep,
                    intensityPercentage: viewModel.intensityPercentage,
                    showsBrightnessControl: viewModel.isAdjustingIntensity,
                    advancesOnTap: viewModel.intensityTutorialIndex != 0,
                    action: advanceDialog(viewModel.advanceIntensityTutorial)
                )
            case .mission:
                Level2MissionOverlay(
                    line: viewModel.currentMissionLine,
                    missionIndex: viewModel.missionIndex,
                    action: advanceDialog(viewModel.advanceMission)
                )
            case .closing:
                Level2MascotDialogOverlay(
                    line: Level2OverlayLine(text: viewModel.currentClosingLine.text, mascot: .idle),
                    buttonTitle: closingButtonTitle,
                    action: advanceDialog(viewModel.advanceClosing)
                )
            case .review:
                Level2ReviewOverlay(
                    replayNarration: replayNarration,
                    onFinish: viewModel.finishReview
                )
            case .completed:
                ZStack {
                    EndLevelView(
                        data: EndLevelViewModel.data(for: Level2Content.levelID),
                        onBack: returnToLevelMenu,
                        onNext: onNextLevel,
                        backTitle: "Kembali ke Menu"
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

            if viewModel.isAdjustingIntensity {
                GeometryReader { proxy in
                    Level2BrightnessControl(intensityPercentage: viewModel.intensityPercentage)
                        .position(x: proxy.size.width * 0.10, y: proxy.size.height * 0.50)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed {
                LevelBackButton(action: { showsExitConfirmation = true })
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.phase != .completed,
               viewModel.canGoBackToPreviousState {
                LevelRepeatStepButton(
                    isDisabled: viewModel.isTransitioning,
                    action: viewModel.goBackToPreviousState
                )
                .padding(.trailing, 16)
                .padding(.top, 12)
            }
        }
        .overlay(alignment: .top) {
            if let topModeTitle = viewModel.topModeTitle {
                Level2TopModeLabel(title: topModeTitle)
                    .padding(.top, 34)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
        .levelExitConfirmation(isPresented: $showsExitConfirmation) {
            returnToLevelMenu()
        }
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.phase)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.topModeTitle)
        .sensoryFeedback(.success, trigger: viewModel.successFeedbackTrigger)
        .task(id: viewModel.narrationID) {
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
        .navigationBarBackButtonHidden(true)
    }

    private var onboardingButtonTitle: String {
        if viewModel.onboardingIndex == 0 && !viewModel.arSceneViewModel.isObjectPlaced {
            return "Cari Tempat!"
        }
        return viewModel.onboardingIndex == Level2Content.onboardingDialog.count - 1
            ? "Mulai"
            : "Lanjut"
    }

    private var closingButtonTitle: String {
        viewModel.closingIndex == Level2Content.closingDialog.count - 1
            ? "Lihat Rangkuman"
            : "Lanjut"
    }

    /// Membungkus aksi lanjut dialog supaya ketukan pertama otomatis
    /// menghentikan narasi yang masih berjalan sebelum melanjutkan.
    private func advanceDialog(_ advance: @escaping () -> Void) -> () -> Void {
        {
            if !viewModel.isNarrationComplete {
                narrator.stop()
                viewModel.narrationDidFinish()
            }
            advance()
        }
    }

    private func replayNarration() {
        narrator.speak(
            viewModel.narrationText,
            audioFileNames: viewModel.narrationAudioFileNames
        )
    }

    private var guideBottomPadding: CGFloat {
        switch viewModel.phase {
        case .spreadFreeExploration:
            112
        case .mission where viewModel.missionIndex == 5:
            112
        default:
            32
        }
    }

    private func returnToLevelMenu() {
        onReturnToLevelMenu?()
        dismiss()
    }
}
