import SwiftUI
import Combine

struct Level3FlowView: View {
    @State private var viewModel = Level3ViewModel()
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
            Level3ARContainerView(sceneViewModel: viewModel.arSceneViewModel, telemetryDelegate: viewModel)
                .ignoresSafeArea()

            overlay
        }
        // ⭐️ FIX: Memanggil wrapper view yang mengobservasi ARSceneViewModel secara langsung
        .overlay {
            Level3ConceptOverlayContainer(sceneViewModel: viewModel.arSceneViewModel)
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
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            if viewModel.phase != .completed {
                Button("DEV: Lanjut") {
                    viewModel.debugAdvanceCurrentPhase()
                }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.trailing, 16)
                .padding(.top, 12)
            }
        }
        #endif
        .levelExitConfirmation(isPresented: $showsExitConfirmation) {
            dismiss()
        }
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.phase)
        .animation(.easeInOut(duration: 0.2), value: viewModel.arSceneViewModel.selectedConcept)
        .sensoryFeedback(.success, trigger: viewModel.successFeedbackTrigger)
        .task(id: viewModel.narrationID) {
            narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName)
        }
        .onDisappear { narrator.stop() }
        .onChange(of: viewModel.arSceneViewModel.surfaceState) { _, _ in
            viewModel.surfaceDidBecomeReady()
        }
        .navigationBarBackButtonHidden(true)
    }

    private func replayNarration() {
        narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName)
    }

    @ViewBuilder private var overlay: some View {
        switch viewModel.phase {
        case .onboarding:
            Level3Dialog(line: viewModel.currentOnboardingLine, buttonTitle: viewModel.onboardingIndex == Level3Content.onboardingDialog.count - 1 ? "Mulai" : "Lanjut", replayNarration: replayNarration, action: viewModel.advanceOnboarding)
        case .placingScene:
            Level3Placement(sceneViewModel: viewModel.arSceneViewModel, replayNarration: replayNarration, action: viewModel.arSceneViewModel.placeSceneAtScreenCenter)
        case .surfaceReady:
            SurfaceReadyOverlay(
                onContinue: viewModel.continueAfterSurfaceCheck,
                onRescan: viewModel.rescanSurface
            )
        case .shadowExploration:
            Level3TaskCard(title: "Cari bayangan", progress: viewModel.shadowProgress, total: 3, button: viewModel.hasCompletedShadowTask ? "Lihat Penjelasan" : nil, replayNarration: replayNarration, action: viewModel.continueFromShadowTask)
        case .shadowTrivia:
            Level3Dialog(line: viewModel.currentShadowTriviaLine, buttonTitle: viewModel.shadowTriviaIndex == Level3Content.shadowTrivia.count - 1 ? "Lihat Jenis Bayangan" : "Lanjut", replayNarration: replayNarration, action: viewModel.advanceShadowTrivia)
        case .shadowTypesInteraction:
            VStack(spacing: 12) {
                Level3Dialog(line: viewModel.currentShadowTypesLine, buttonTitle: viewModel.shadowTypesIndex == Level3Content.shadowTypesTrivia.count - 1 ? "Bandingkan Bentuk" : "Lanjut", replayNarration: replayNarration, action: viewModel.advanceShadowTypes)
                Button(viewModel.shadowVisible ? "Sembunyikan Bayangan" : "Tampilkan Bayangan", action: viewModel.toggleShadow).buttonStyle(.borderedProminent)
            }
        case .shapeComparison:
            Level3ShapeComparison(viewModel: viewModel, replayNarration: replayNarration)
        case .closing:
            Level3Dialog(line: viewModel.currentClosingLine, buttonTitle: viewModel.closingIndex == Level3Content.closingDialog.count - 1 ? "Lihat Rangkuman" : "Lanjut", replayNarration: replayNarration, action: viewModel.advanceClosing)
        case .review:
            Level3Review(points: Level3Content.reviewPoints, replayNarration: replayNarration, action: viewModel.finishReview)
        case .completed:
            EndLevelView(
                data: EndLevelViewModel.data(for: Level3Content.levelID),
                onBack: dismiss.callAsFunction,
                onNext: onNextLevel
            )
            .padding(.bottom, 24)
        }
    }
}

// ⭐️ FIX: Wrapper View untuk memaksa SwiftUI merender ulang saat marker di-tap
private struct Level3ConceptOverlayContainer: View {
    @ObservedObject var sceneViewModel: ARSceneViewModel
    
    var body: some View {
        if let concept = sceneViewModel.selectedConcept {
            ShadowConceptOverlayView(
                concept: concept,
                tapLocation: sceneViewModel.selectedConceptTapLocation
            ) {
                sceneViewModel.selectedConcept = nil
            }
            .transition(.opacity)
        }
    }
}

private struct Level3Dialog: View {
    let line: DialogLine
    let buttonTitle: String
    let replayNarration: () -> Void
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🦉")
                .font(.largeTitle.scaled(by: 1.6))
                .accessibilityHidden(true)

            Text(line.characterName)
                .font(.headline)
                .foregroundStyle(.blue)

            Text(line.text)
                .font(.title3)
                .bold()
                .multilineTextAlignment(.center)

            Level2ReplayNarrationButton(action: replayNarration)

            Button(buttonTitle, action: action)
                .font(.title3)
                .bold()
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
    }
}

private struct Level3Placement: View {
    @ObservedObject var sceneViewModel: ARSceneViewModel; let replayNarration: () -> Void; let action: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            SurfaceScanInstruction(sceneViewModel: sceneViewModel)
            Text(sceneViewModel.surfaceGuidanceText).multilineTextAlignment(.center)

            Level2ReplayNarrationButton(action: replayNarration)

            Button("Taruh Benda di Tengah", action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: 620)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(16)
    }
}

private struct Level3TaskCard: View {
    let title: String; let progress: Int; let total: Int; let button: String?; let replayNarration: () -> Void; let action: () -> Void
    var body: some View { VStack(spacing: 12) { Text(title).font(.title3).bold(); ProgressView(value: Double(progress), total: Double(total)); Level2ReplayNarrationButton(action: replayNarration); if let button { Button(button, action: action).buttonStyle(.borderedProminent) } }.padding(22)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36) }
}

private struct Level3ShapeComparison: View {
    let viewModel: Level3ViewModel; let replayNarration: () -> Void
    var body: some View { VStack(spacing: 12) { Text("Bentuk berbeda, bayangan berbeda").font(.title3).bold(); HStack { ForEach(Level3ViewModel.ComparisonShape.allCases) { shape in Button(shape.rawValue) { viewModel.chooseComparison(shape) }.buttonStyle(.borderedProminent) } }; Text("Pilih kedua bentuk, lalu bandingkan bayangannya.").font(.subheadline); Level2ReplayNarrationButton(action: replayNarration); Button("Lanjut", action: viewModel.finishShapeComparison).buttonStyle(.borderedProminent).disabled(!viewModel.hasComparedShapes) }.padding(22)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36) }
}

private struct Level3Review: View {
    let points: [String]; let replayNarration: () -> Void; let action: () -> Void
    var body: some View { VStack(alignment: .leading, spacing: 12) { Text("Learning Review").font(.title2).bold(); ForEach(points, id: \.self) { Text("• \($0)") }; Level2ReplayNarrationButton(action: replayNarration); Button("Selesai", action: action).buttonStyle(.borderedProminent) }.padding(20).frame(maxWidth: 620).background(.thinMaterial, in: .rect(cornerRadius: 24)).padding(16) }
}
