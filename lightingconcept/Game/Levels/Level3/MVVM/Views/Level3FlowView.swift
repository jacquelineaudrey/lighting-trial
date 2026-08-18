import SwiftUI
import Combine

struct Level3FlowView: View {
    @State private var viewModel = Level3ViewModel()
    @State private var narrator = LessonAudioNarrator() // Diganti menggunakan audio narration Level 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var showsExitConfirmation = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Level3ARContainerView(sceneViewModel: viewModel.arSceneViewModel, telemetryDelegate: viewModel)
                .ignoresSafeArea()
            
            overlay
        }
//        .overlay {
//            Level3ConceptOverlayContainer(sceneViewModel: viewModel.arSceneViewModel)
//        }
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
        .animation(.easeInOut(duration: 0.2), value: viewModel.arSceneViewModel.selectedConcept)
        .sensoryFeedback(.success, trigger: viewModel.successFeedbackTrigger)
        .task(id: viewModel.narrationID) {
            guard viewModel.phase != .placingScene else {
                narrator.stop()
                return
            }
            narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName)
        }
        .onAppear(perform: BackgroundMusicPlayer.shared.useGameplayVolume)
        .onDisappear {
            narrator.stop()
            BackgroundMusicPlayer.shared.useMenuVolume()
        }
        .onChange(of: viewModel.arSceneViewModel.surfaceState) { _, _ in
            viewModel.surfaceDidBecomeReady()
        }
        .onChange(of: viewModel.arSceneViewModel.selectedConcept) { _, newConcept in
            viewModel.forceSyncGuideForConcept()
            
            if newConcept != nil {
                // Bayo mulai ngomong sesuai penjelasan marker yang diketuk
                narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName)
            } else {
                // Jika marker ditutup, hentikan suara dan kembalikan ke narasi fase level
                narrator.stop()
                narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // Overlay mengikuti layout "unblocked AR" mirip Level 1
    @ViewBuilder private var overlay: some View {
            switch viewModel.phase {
            case .placingScene:
                VStack(spacing: 12) {
                    SurfaceScanInstruction(sceneViewModel: viewModel.arSceneViewModel)
                    Text(viewModel.arSceneViewModel.surfaceState == .found
                         ? "Tempat ditemukan! Ketuk layar untuk menaruh benda."
                         : "Arahkan iPad pelan-pelan ke lantai atau meja yaaa!")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: 620)
                .background(.thinMaterial, in: .rect(cornerRadius: 24))
                .padding(16)
                
            case .surfaceReady:
                SurfaceReadyOverlay(
                    onContinue: viewModel.continueAfterSurfaceCheck,
                    onRescan: viewModel.rescanSurface
                )
                
            case .shadowExploration:
                // ⭐️ FIX: Parameter button diganti jadi nil biar nggak ada tombol "Lanjut"
                Level3TaskCard(title: "Cari bayangan", progress: viewModel.shadowProgress, total: 3, button: nil, replayNarration: { narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName) }, action: {})
                
            case .shadowTypesInteraction:
                VStack {
                    Spacer()
                    HStack {
                        Button(viewModel.shadowVisible ? "Sembunyikan Bayangan" : "Tampilkan Bayangan", action: viewModel.toggleShadow)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.orange, in: Capsule())
                            .padding(.leading, 24)
                        
                        Spacer()
                        // ⭐️ FIX: Tombol Selanjutnya dihapus dari sini!
                    }
                    .padding(.bottom, 36)
                }
                
            case .shapeComparison:
                Level3ShapeComparison(viewModel: viewModel, replayNarration: { narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName) })
                
            case .review:
                Level3Review(points: Level3Content.reviewPoints, replayNarration: { narrator.speak(viewModel.narrationText, audioFileName: viewModel.narrationAudioFileName) }, action: viewModel.finishReview)
                
            case .completed:
                EndLevelView(
                    data: EndLevelViewModel.data(for: Level3Content.levelID),
                    onBack: dismiss.callAsFunction,
                )
                .padding(.bottom, 24)
                
            default:
                EmptyView()
            }
        }
}

private struct Level3NextButtonOverlay: View {
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

// ⭐️ Wrapper View untuk Marker
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
    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.title3).bold();
            ProgressView(value: Double(progress), total: Double(total));
            Level2ReplayNarrationButton(action: replayNarration);
            if let button { Button(button, action: action).buttonStyle(.borderedProminent) }
        }
        .padding(22)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
    }
}

private struct Level3ShapeComparison: View {
    let viewModel: Level3ViewModel; let replayNarration: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Text("Bentuk berbeda, bayangan berbeda").font(.title3).bold()
            HStack {
                ForEach(Level3ViewModel.ComparisonShape.allCases) { shape in
                    Button(shape.rawValue) { viewModel.chooseComparison(shape) }.buttonStyle(.borderedProminent)
                }
            }
            Text(viewModel.hasComparedShapes
                 ? "Ketuk layar untuk melanjutkan."
                 : "Pilih kedua bentuk, lalu bandingkan bayangannya.")
            .font(.subheadline)
            
            Level2ReplayNarrationButton(action: replayNarration)
            // ⭐️ FIX: Button "Selanjutnya" dihapus dari sini!
        }
        .padding(22)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
    }
}

private struct Level3Review: View {
    let points: [String]; let replayNarration: () -> Void; let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Learning Review").font(.title2).bold();
            ForEach(points, id: \.self) { Text("• \($0)") };
            Level2ReplayNarrationButton(action: replayNarration);
            Button("Selesai", action: action).buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: 620)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .padding(16)
    }
}
