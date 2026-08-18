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

            overlay
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
            guard viewModel.phase != .placingScene else {
                narrator.stop()
                return
            }
            narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName)
        }
        .onDisappear(perform: narrator.stop)
        .onChange(of: viewModel.arSceneViewModel.surfaceState) { _, _ in
            viewModel.surfaceDidBecomeReady()
        }
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder private var overlay: some View {
        switch viewModel.phase {
        case .onboarding:
            Level2NextButtonOverlay(title: "Selanjutnya", action: viewModel.advanceOnboarding)
        case .placingScene:
            Level2PlacementOverlay(
                sceneViewModel: viewModel.arSceneViewModel,
                replayNarration: { narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName) }
            )
        case .surfaceReady:
            SurfaceReadyOverlay(
                onContinue: viewModel.continueAfterSurfaceCheck,
                onRescan: viewModel.rescanSurface
            )
        case .shadowExploration:
            Level2TaskCard(
                title: "Cari Bayangan",
                progress: viewModel.shadowProgress,
                total: 3,
                button: viewModel.hasCompletedShadowTask ? "Selanjutnya" : nil,
                replayNarration: { narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName) },
                action: viewModel.continueFromShadowTask
            )
        case .shadowTrivia:
            Level2NextButtonOverlay(title: "Selanjutnya", action: viewModel.advanceShadowTrivia)
        case .spreadTransition:
            Level2NextButtonOverlay(title: "Selanjutnya", action: viewModel.advanceSpreadTransition)
        case .spreadExploration:
            Level2SpreadExplorationOverlay(
                viewModel: viewModel,
                replayNarration: { narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName) }
            )
        case .spreadTrivia:
            Level2NextButtonOverlay(title: "Selanjutnya", action: viewModel.advanceSpreadTrivia)
        case .intensityExploration:
            Level2IntensityExplorationOverlay(
                viewModel: viewModel,
                replayNarration: { narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName) }
            )
        case .intensityTrivia:
            Level2NextButtonOverlay(title: "Selanjutnya", action: viewModel.advanceIntensityTrivia)
        case .closing:
            Level2NextButtonOverlay(title: "Selanjutnya", action: viewModel.advanceClosing)
        case .review:
            Level2ReviewOverlay(
                replayNarration: { narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName) },
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
}

// MARK: - Overlay Unblocked AR Styles

struct Level2NextButtonOverlay: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(title, action: action)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.blue, in: Capsule())
                    .padding(.trailing, 42)
                    .padding(.bottom, 36)
            }
        }
    }
}

struct Level2TaskCard: View {
    let title: String
    let progress: Int
    let total: Int
    let button: String?
    let replayNarration: () -> Void
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.title3).bold()
            ProgressView(value: Double(progress), total: Double(total))
            Level2ReplayNarrationButton(action: replayNarration)
            if let button {
                Button(button, action: action).buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
    }
}
