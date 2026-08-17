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
                telemetryDelegate: viewModel
            )
            .ignoresSafeArea()

            Level2GestureLayer(viewModel: viewModel)
                .ignoresSafeArea()

            switch viewModel.phase {
            case .onboarding:
                Level2DialogOverlay(
                    line: viewModel.currentOnboardingLine,
                    buttonTitle: onboardingButtonTitle,
                    replayNarration: replayNarration,
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
            case .shadowExploration:
                Level2ShadowExplorationOverlay(
                    viewModel: viewModel,
                    replayNarration: replayNarration
                )
            case .shadowTrivia:
                Level2DialogOverlay(
                    line: viewModel.currentShadowTriviaLine,
                    buttonTitle: shadowTriviaButtonTitle,
                    replayNarration: replayNarration,
                    action: viewModel.advanceShadowTrivia
                )
            case .spreadTransition:
                Level2DialogOverlay(
                    line: viewModel.currentSpreadTransitionLine,
                    buttonTitle: spreadTransitionButtonTitle,
                    replayNarration: replayNarration,
                    action: viewModel.advanceSpreadTransition
                )
            case .spreadExploration:
                Level2SpreadExplorationOverlay(
                    viewModel: viewModel,
                    replayNarration: replayNarration
                )
            case .spreadTrivia:
                Level2DialogOverlay(
                    line: viewModel.currentSpreadTriviaLine,
                    buttonTitle: spreadTriviaButtonTitle,
                    replayNarration: replayNarration,
                    action: viewModel.advanceSpreadTrivia
                )
            case .intensityExploration:
                Level2IntensityExplorationOverlay(
                    viewModel: viewModel,
                    replayNarration: replayNarration
                )
            case .intensityTrivia:
                Level2DialogOverlay(
                    line: viewModel.currentIntensityTriviaLine,
                    buttonTitle: intensityTriviaButtonTitle,
                    replayNarration: replayNarration,
                    action: viewModel.advanceIntensityTrivia
                )
            case .closing:
                Level2DialogOverlay(
                    line: viewModel.currentClosingLine,
                    buttonTitle: closingButtonTitle,
                    replayNarration: replayNarration,
                    action: viewModel.advanceClosing
                )
            case .review:
                Level2ReviewOverlay(
                    replayNarration: replayNarration,
                    onFinish: viewModel.finishReview
                )
            case .completed:
                EndLevelView(
                    data: EndLevelViewModel.data(for: Level2Content.levelID),
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
        .sensoryFeedback(.success, trigger: viewModel.successFeedbackTrigger)
        .task(id: viewModel.narrationID) {
            narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName)
        }
        .onDisappear(perform: narrator.stop)
        .onChange(of: viewModel.arSceneViewModel.surfaceState) { _, _ in
            viewModel.surfaceDidBecomeReady()
        }
        .navigationBarBackButtonHidden(true)
    }

    private var onboardingButtonTitle: String {
        viewModel.onboardingIndex == Level2Content.onboardingDialog.count - 1
            ? "Cari Tempat!"
            : "Lanjut"
    }

    private var shadowTriviaButtonTitle: String {
        viewModel.shadowTriviaIndex == Level2Content.shadowTrivia.count - 1
            ? "Coba Lebar Cahaya"
            : "Lanjut"
    }

    private var spreadTransitionButtonTitle: String {
        viewModel.spreadTransitionIndex == Level2Content.spreadTransition.count - 1
            ? "Ayo Coba!"
            : "Lanjut"
    }

    private var spreadTriviaButtonTitle: String {
        viewModel.spreadTriviaIndex == Level2Content.spreadTrivia.count - 1
            ? "Coba Terang dan Redup"
            : "Lanjut"
    }

    private var intensityTriviaButtonTitle: String {
        viewModel.intensityTriviaIndex == Level2Content.intensityTrivia.count - 1
            ? "Lihat Hasil Belajar"
            : "Lanjut"
    }

    private var closingButtonTitle: String {
        viewModel.closingIndex == Level2Content.closingDialog.count - 1
            ? "Lihat Rangkuman"
            : "Lanjut"
    }

    private func replayNarration() {
        narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName)
    }
}
