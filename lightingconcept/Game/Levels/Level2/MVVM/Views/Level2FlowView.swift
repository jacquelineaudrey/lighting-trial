import SwiftUI

struct Level2FlowView: View {
    @State private var viewModel = Level2ViewModel()
    @State private var narrator = LessonAudioNarrator()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var showsExitConfirmation = false
    let onNextLevel: (() -> Void)?

    init(onNextLevel: (() -> Void)? = nil) {
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
                    action: viewModel.advanceOnboarding
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
                    action: viewModel.advanceSpreadTutorial
                )
            case .spreadFreeIntro:
                Level2MascotDialogOverlay(
                    line: Level2Content.spreadFreeIntro,
                    action: viewModel.advanceSpreadFreeIntro
                )
            case .spreadFreeInstructions:
                Level2FreeExploreInstructionsOverlay(action: viewModel.dismissSpreadFreeInstructions)
            case .spreadFreeExploration:
                Level2FreeExploreOverlay(action: viewModel.finishSpreadFreeExploration)
            case .intensityTransition:
                Level2MascotDialogOverlay(
                    line: Level2Content.intensityTransition,
                    action: viewModel.advanceIntensityTransition
                )
            case .intensityTutorial:
                Level2IntensityTutorialOverlay(
                    step: viewModel.currentIntensityTutorialStep,
                    intensityPercentage: viewModel.intensityPercentage,
                    showsBrightnessControl: viewModel.isAdjustingIntensity,
                    advancesOnTap: viewModel.intensityTutorialIndex != 0,
                    action: viewModel.advanceIntensityTutorial
                )
            case .mission:
                Level2MissionOverlay(
                    line: viewModel.currentMissionLine,
                    missionIndex: viewModel.missionIndex,
                    action: viewModel.advanceMission
                )
            case .closing:
                Level2MascotDialogOverlay(
                    line: Level2OverlayLine(text: viewModel.currentClosingLine.text, mascot: .idle),
                    buttonTitle: closingButtonTitle,
                    action: viewModel.advanceClosing
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
                        onBack: dismiss.callAsFunction,
                        onNext: onNextLevel
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
                LevelBackButton { showsExitConfirmation = true }
                    .padding(.leading, 16)
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
            dismiss()
        }
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.phase)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.topModeTitle)
        .sensoryFeedback(.success, trigger: viewModel.successFeedbackTrigger)
        .task(id: viewModel.narrationID) {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            narrator.speak(
                viewModel.narrationText,
                audioFileNames: viewModel.narrationAudioFileNames
            )
        }
        .onAppear(perform: BackgroundMusicPlayer.shared.useGameplayVolume)
        .onDisappear {
            narrator.stop()
            BackgroundMusicPlayer.shared.useMenuVolume()
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

    private func replayNarration() {
        narrator.speak(
            viewModel.narrationText,
            audioFileNames: viewModel.narrationAudioFileNames
        )
    }
}
