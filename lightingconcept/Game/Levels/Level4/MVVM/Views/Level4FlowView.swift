import SwiftUI

struct Level4FlowView: View {
    @StateObject private var viewModel = Level4ViewModel()
    @State private var narrator = LessonAudioNarrator(playbackRate: 1.35)
    @Environment(\.dismiss) private var dismiss
    @State private var showsExitConfirmation = false

    var body: some View {
        ZStack {
            Level4ARContainerView(
                sceneViewModel: viewModel.sceneViewModel,
                viewModel: viewModel
            )
            .ignoresSafeArea()

            Level4PhaseOverlay(
                viewModel: viewModel,
                returnToMenu: { dismiss() }
            )
        }
        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed {
                LevelBackButton(action: { showsExitConfirmation = true })
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
        }
        .overlay {
            if let warning = viewModel.sceneViewModel.safetyWarning {
                SafetyWarningDialog(
                    warning: warning,
                    onDismiss: viewModel.sceneViewModel.dismissSafetyWarning
                )
            }
        }
        .levelExitConfirmation(isPresented: $showsExitConfirmation) {
            dismiss()
        }
        .task(id: viewModel.narrationID) {
            guard viewModel.shouldSpeakNarration else {
                narrator.stop()
                return
            }
            narrator.speak(viewModel.narrationText)
        }
        .onDisappear { narrator.stop() }
        .navigationBarBackButtonHidden(true)
    }
}

private struct Level4PhaseOverlay: View {
    @ObservedObject var viewModel: Level4ViewModel
    let returnToMenu: () -> Void

    var body: some View {
        switch viewModel.phase {
        case .placingScene:
            Level4PlacementOverlay(sceneViewModel: viewModel.sceneViewModel)

        case .introduction, .objectExplanation, .lightIntroduction, .lightExplanation, .closing:
            if let dialog = viewModel.dialog {
                Level4TappableDialog(
                    dialog: dialog,
                    screenPosition: viewModel.guideOverlayScreenPosition,
                    action: viewModel.advanceDialog
                )
            }

        case .selectingObject:
            Level4SelectionInstruction(
                title: "Pilih objek",
                text: "Ketuk kubus yang berkilau"
            )

        case .objectMovementTutorial:
            Level4HoldMovementTutorial(
                modeTitle: "Kamu jadi objek!",
                subject: "benda",
                action: viewModel.startObjectMovementPractice
            )

        case .movingObject:
            Level4ActivityControls(
                modeTitle: viewModel.topModeTitle,
                message: "Gerakkan perangkat untuk memindahkan benda.",
                buttonTitle: "Aku Sudah Mencoba",
                touchPoint: viewModel.gestureTouchPoint,
                isMoving: viewModel.isDeviceFollowing,
                action: viewModel.confirmObjectWasMoved
            )

        case .selectingLight:
            Level4SelectionInstruction(
                title: "Pilih cahaya",
                text: "Ketuk lampu yang berkilau"
            )

        case .lightMovementTutorial:
            Level4HoldMovementTutorial(
                modeTitle: "Kamu jadi cahaya!",
                subject: "cahaya",
                action: viewModel.startLightMovementPractice
            )

        case .movingLight:
            Level4ActivityControls(
                modeTitle: viewModel.topModeTitle,
                message: "Gerakkan perangkat untuk memindahkan cahaya.",
                buttonTitle: "Aku Sudah Mencoba",
                touchPoint: viewModel.gestureTouchPoint,
                isMoving: viewModel.isDeviceFollowing,
                action: viewModel.confirmLightWasMoved
            )

        case .exploring:
            Level4ActivityControls(
                modeTitle: viewModel.topModeTitle,
                message: "Ketuk benda atau lampu, lalu pindahkan.",
                buttonTitle: "Selesai Eksplor",
                touchPoint: viewModel.gestureTouchPoint,
                isMoving: viewModel.isDeviceFollowing,
                action: viewModel.finishExploring
            )

        case .review:
            Level4ReviewOverlay(
                points: Level4Content.reviewPoints,
                action: viewModel.finishReview
            )

        case .completed:
            EndLevelView(
                data: EndLevelModel(
                    id: 4,
                    levelNumber: 4,
                    message: "Kamu hebat!\nSekarang kamu tahu posisi benda mengubah bayangan.",
                    mascotImageName: "lumiPointwink"
                ),
                onBack: returnToMenu,
                backTitle: "Balik ke menu"
            )
            .padding(.bottom, 24)
        }
    }
}

private struct Level4PlacementOverlay: View {
    @ObservedObject var sceneViewModel: ARSceneViewModel

    var body: some View {
        VStack(spacing: 12) {
            if sceneViewModel.isReadyForPlacement {
                Image(systemName: "checkmark.viewfinder")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.green)
                Text("Permukaan siap!")
                    .font(.title2.bold())
                Text("Ketuk permukaan tempat kamu ingin menaruh benda")
                    .font(.headline)
            } else {
                Image(systemName: "viewfinder")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.cyan)
                Text("Scan Ruangan")
                    .font(.title2.bold())
                ProgressView(value: scanProgress)
                    .tint(.cyan)
                    .frame(maxWidth: 280)
                Text("Gerakkan iPad perlahan untuk memindai meja atau lantai")
                    .font(.headline)
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private var scanProgress: Double {
        if sceneViewModel.surfaceState == .found || sceneViewModel.surfaceState == .placed {
            return 1
        }
        return sceneViewModel.isLiDARAvailable
            ? Double(sceneViewModel.lidarPlacementProgress)
            : 0.12
    }
}

private struct Level4TappableDialog: View {
    let dialog: Level4Dialog
    let screenPosition: CGPoint?
    let action: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(.rect)
                .onTapGesture(perform: action)

            VStack {
                Spacer()
                LevelGuideOverlay(
                    text: dialog.text,
                    assetName: dialog.assetName,
                    screenPosition: screenPosition,
                    showsTapToContinueCaption: true,
                    bottomPadding: 36
                )
            }
        }
    }
}

private struct Level4SelectionInstruction: View {
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(text)
                .font(.title3.bold())
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.yellow.opacity(0.94), in: Capsule())
        .overlay(Capsule().stroke(.orange, lineWidth: 2))
        .padding(.top, 30)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

private struct Level4HoldMovementTutorial: View {
    let modeTitle: String
    let subject: String
    let action: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()

                Level2TopModeLabel(title: modeTitle)
                    .position(x: proxy.size.width * 0.50, y: 64)

                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 92, weight: .semibold))
                    .foregroundStyle(.white)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.46), lineWidth: 2)
                            .frame(width: 150, height: 150)
                    }
                    .position(
                        x: proxy.size.width * 0.50,
                        y: proxy.size.height * 0.46
                    )

                Level6BottomGestureInstruction(
                    text: "Tahan layar, lalu gerakkan perangkat. \(subject.capitalized) akan mengikutimu."
                )
            }
        }
        .contentShape(.rect)
        .onTapGesture(perform: action)
        .accessibilityLabel("Tekan dan tahan layar, lalu gerakkan perangkat untuk memindahkan \(subject).")
        .accessibilityHint("Ketuk sekali untuk melanjutkan tutorial.")
    }
}

private struct Level4ActivityControls: View {
    let modeTitle: String
    let message: String
    let buttonTitle: String
    let touchPoint: CGPoint?
    let isMoving: Bool
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Level4MovementFeedback(touchPoint: touchPoint, isMoving: isMoving)

            VStack {
                Level2TopModeLabel(title: modeTitle)
                    .padding(.top, 34)
                Spacer()
            }
            .frame(maxWidth: .infinity)

            HStack(alignment: .bottom, spacing: 16) {
                Spacer()
                VStack(alignment: .trailing, spacing: 12) {
                    LevelSpeechBubble(text: message)
                        .frame(width: 330)
                    LevelActionButton(title: buttonTitle, action: action)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }
}

private struct Level4MovementFeedback: View {
    let touchPoint: CGPoint?
    let isMoving: Bool

    var body: some View {
        ZStack {
            if let touchPoint {
                Level6TouchIndicator()
                    .position(touchPoint)
            }

            if isMoving {
                Level6BottomGestureInstruction(
                    text: "Tetap tahan layar dan gerakkan perangkat."
                )
                .padding(.bottom, 74)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Level4ReviewOverlay: View {
    let points: [String]
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Yuk, Ingat Lagi!")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .center)
            ForEach(points, id: \.self) { point in
                Label(point, systemImage: "star.fill")
                    .foregroundStyle(.primary, .yellow)
                    .font(.subheadline)
            }
            LevelActionButton(title: "Selesai", action: action)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: 560)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 18)
        .padding(.bottom, 28)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
