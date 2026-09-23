import SwiftUI
import UIKit

struct Level6FlowView: View {
    @StateObject private var viewModel = Level6ViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showsExitConfirmation = false
    @State private var showsSandbox = false

    var body: some View {
        ZStack {
            Level6ARContainerView(
                sceneViewModel: viewModel.sceneViewModel,
                viewModel: viewModel
            )
            .ignoresSafeArea()

            if shouldShowFrozenScene, let image = viewModel.frozenSceneImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            Level6PhaseOverlay(
                viewModel: viewModel,
                returnToMenu: { dismiss() },
                openSandbox: { showsSandbox = true }
            )

            if viewModel.showsShadowExplanation {
                Level6ColorExplanation(
                    text: viewModel.mixingExplanation,
                    screenPosition: viewModel.shadowExplanationScreenPosition,
                    action: viewModel.dismissShadowExplanation
                )
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.phase != .completed {
                LevelBackButton(action: { showsExitConfirmation = true })
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .levelExitConfirmation(isPresented: $showsExitConfirmation) {
            dismiss()
        }
        .fullScreenCover(isPresented: $viewModel.showsDrawingCamera) {
            Level6DrawingCameraView(
                onImagePicked: viewModel.receiveDrawingPhoto,
                onCancel: viewModel.cancelDrawingCamera
            )
            .ignoresSafeArea()
        }
        .navigationDestination(isPresented: $showsSandbox) {
            ContentView()
        }
        .task(id: viewModel.phase) {
            guard viewModel.phase == .drawingOnPaper else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, viewModel.phase == .drawingOnPaper else { return }
            viewModel.finishDrawingOnPaper()
        }
        .overlay {
            if let warning = viewModel.sceneViewModel.safetyWarning {
                SafetyWarningDialog(
                    warning: warning,
                    onDismiss: viewModel.sceneViewModel.dismissSafetyWarning
                )
            }
        }
    }

    private var shouldShowFrozenScene: Bool {
        viewModel.phase == .drawingOnPaper || viewModel.phase == .photoPrompt
    }
}

private struct Level6PhaseOverlay: View {
    @ObservedObject var viewModel: Level6ViewModel
    let returnToMenu: () -> Void
    let openSandbox: () -> Void

    var body: some View {
        switch viewModel.phase {
        case .placingScene:
            Level6PlacementOverlay(sceneViewModel: viewModel.sceneViewModel)
        case .introduction:
            if let dialog = viewModel.currentIntroduction {
                Level6TappableDialog(
                    dialog: dialog,
                    screenPosition: viewModel.guideOverlayScreenPosition,
                    action: viewModel.advanceIntroduction
                )
            }
        case .selectingFirstLight:
            Level6SelectionInstruction(text: "Tekan salah satu cahaya untuk memilihnya")
        case .changingFirstColor, .changingSecondColor:
            Level6ColorControls(viewModel: viewModel)
        case .firstColorResult:
            Level6TappableDialog(
                dialog: Level6Dialog(
                    text: "Wah! Warna bayangannya berubah sesuai dengan warna cahaya!",
                    assetName: "bayoIdle"
                ),
                screenPosition: viewModel.guideOverlayScreenPosition,
                action: viewModel.askForSecondLight
            )
        case .selectingSecondLight:
            Level6TappableDialog(
                dialog: Level6Dialog(
                    text: "Gimana kalau kita ubah warna cahaya yang satu lagi?",
                    assetName: "lumiQuestion"
                ),
                screenPosition: viewModel.guideOverlayScreenPosition,
                footer: "Tekan cahaya yang belum diubah"
            )
        case .colorShadowPrompt:
            Level6ColorShadowPrompt(
                hasVisibleMarker: viewModel.shadowMarkerScreenPosition != nil
            )
        case .colorShadowExplanation:
            Level6ColorExplanation(
                text: viewModel.mixingExplanation,
                screenPosition: viewModel.shadowExplanationScreenPosition,
                action: viewModel.beginColorExploration
            )
        case .colorExplorationIntro:
            Level6TappableDialog(
                dialog: Level6Dialog(
                    text: "Yuk, kita main-main warna lain yaaa!",
                    assetName: "lumiIdle"
                ),
                screenPosition: viewModel.guideOverlayScreenPosition,
                action: viewModel.showColorExploration
            )
        case .colorExploration:
            Level6ExplorationControls(
                viewModel: viewModel,
                message: "Kalau sudah selesai coba warna, tekan tombol ini ya!",
                buttonTitle: "Selanjutnya",
                action: viewModel.finishColorExploration
            )
        case .positionExplorationIntro:
            Level6TappableDialog(
                dialog: Level6Dialog(
                    text: "Sekarang, kita coba ubah posisi dan ketinggian cahaya juga ya!",
                    assetName: "lumiQuestion"
                ),
                screenPosition: viewModel.guideOverlayScreenPosition,
                action: viewModel.beginPositionExploration
            )
        case .positionExploration:
            Level6ExplorationControls(
                viewModel: viewModel,
                message: "Kalau sudah selesai eksplor, tekan tombol ini ya!",
                buttonTitle: "Selesai Eksplor",
                action: viewModel.finishPositionExploration
            )
        case .drawingIntro:
            Level6TappableDialog(
                dialog: Level6Dialog(
                    text: "Sekarang, kita coba menggambar yaa!",
                    assetName: "lumiIdle"
                ),
                screenPosition: viewModel.guideOverlayScreenPosition,
                action: viewModel.beginDrawingChoice
            )
        case .drawingChoice:
            Level6ExplorationControls(
                viewModel: viewModel,
                message: "Sudah suka gambarnya? Tekan “Pilih Ini” untuk jadi contoh gambar!",
                buttonTitle: "Pilih Ini",
                action: viewModel.chooseSceneForDrawing
            )
        case .drawingOnPaper:
            Level6DrawingPrompt(
                text: "Sekarang, mari kita gambar di kertas ya!",
                buttonTitle: nil,
                showsModeLabel: false,
                showsCharacter: true,
                action: nil
            )
        case .photoPrompt:
            Level6DrawingPrompt(
                text: "Kalau sudah selesai gambar, ayuk foto gambarmu!",
                buttonTitle: "Foto Gambarku",
                showsModeLabel: false,
                showsCharacter: false,
                action: viewModel.openDrawingCamera
            )
        case .photoComparison:
            Level6PhotoComparison(
                sceneImage: viewModel.frozenSceneImage,
                drawingImage: viewModel.drawingImage,
                action: viewModel.completeLevel
            )
        case .completed:
            Level6CompletionOverlay(returnToMenu: returnToMenu, openSandbox: openSandbox)
        }
    }
}

private struct Level6PlacementOverlay: View {
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

private struct Level6TappableDialog: View {
    let dialog: Level6Dialog
    var screenPosition: CGPoint?
    var footer: String?
    var action: (() -> Void)?

    var body: some View {
        ZStack {
            if let action {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture(perform: action)
            }

            VStack {
                Spacer()
                LevelGuideOverlay(
                    text: dialog.text,
                    assetName: dialog.assetName,
                    screenPosition: screenPosition,
                    showsTapToContinueCaption: action != nil,
                    bottomPadding: 36
                )
                if let footer {
                    Text(footer)
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 18)
                }
            }
        }
    }
}

private struct Level6SelectionInstruction: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title3.bold())
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.yellow.opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(.orange, lineWidth: 2))
            .padding(.top, 30)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }
}

private struct Level6ColorControls: View {
    @ObservedObject var viewModel: Level6ViewModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack {
                Text("Pilih warna untuk cahaya yang sudah dipilih")
                    .font(.headline.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.top, 34)
                Spacer()
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                if viewModel.showsColorPanel {
                    Level6ColorPalette(
                        selectedColor: viewModel.selectedColor,
                        selectColor: viewModel.chooseColor,
                        close: viewModel.closeColorPanel
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Level6ColorButton(action: viewModel.openColorPanel)
            }
            .padding(.leading, 24)
            .padding(.bottom, 22)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showsColorPanel)
    }
}

private struct Level6ColorShadowPrompt: View {
    let hasVisibleMarker: Bool

    var body: some View {
        GeometryReader { proxy in
            LevelGuideOverlay(
                text: hasVisibleMarker
                    ? "Yuk, tekan lingkaran yang ada di bayangan!"
                    : "Bayangannya masih tertutup benda. Coba lihat dari arah lain!",
                assetName: "bayoPoint",
                screenPosition: CGPoint(x: proxy.size.width * 0.70, y: proxy.size.height * 0.78),
                bottomPadding: 28
            )
        }
        .allowsHitTesting(false)
    }
}

private struct Level6ColorExplanation: View {
    let text: String
    let screenPosition: CGPoint?
    let action: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture(perform: action)

                LevelGuideOverlay(
                    text: text,
                    assetName: "bayoPointWink",
                    screenPosition: screenPosition
                        ?? CGPoint(x: proxy.size.width * 0.72, y: proxy.size.height * 0.70),
                    showsTapToContinueCaption: true,
                    bottomPadding: 28
                )
            }
        }
    }
}

private struct Level6ExplorationControls: View {
    @ObservedObject var viewModel: Level6ViewModel
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if (viewModel.phase == .positionExploration
                && viewModel.positionGuidanceStep == .complete
                || viewModel.phase == .drawingChoice),
               !viewModel.isLookAroundMode {
                Level6PositionGestureSurface(viewModel: viewModel)
            }

            VStack {
                Level2TopModeLabel(title: viewModel.topModeTitle)
                    .padding(.top, 34)
                Spacer()
            }
            .frame(maxWidth: .infinity)

            if viewModel.phase != .positionExploration
                || viewModel.positionGuidanceStep == .complete {
                HStack(alignment: .bottom, spacing: 16) {
                    if (viewModel.phase == .colorExploration
                        || viewModel.phase == .positionExploration
                        || viewModel.phase == .drawingChoice),
                       !viewModel.isLookAroundMode {
                        Level6ColorButton(
                            size: .compact,
                            action: viewModel.openColorPanel
                        )
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 12) {
                        LevelSpeechBubble(text: message)
                            .frame(width: 310)
                        LevelActionButton(title: buttonTitle, action: action)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }

            if viewModel.showsColorPanel {
                Level6ColorPalette(
                    selectedColor: viewModel.selectedColor,
                    selectColor: viewModel.chooseColor,
                    close: viewModel.closeColorPanel
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 24)
                    .padding(.bottom, 84)
            }

            if viewModel.positionGuidanceStep != .complete {
                Level6PositionGuidance(
                    step: viewModel.positionGuidanceStep,
                    action: viewModel.advancePositionGuidance
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct Level6DrawingPrompt: View {
    let text: String
    let buttonTitle: String?
    var showsModeLabel = true
    var showsCharacter = true
    let action: (() -> Void)?

    var body: some View {
        VStack {
            if showsModeLabel {
                Level2TopModeLabel(title: "Mode lihat-lihat")
                    .padding(.top, 34)
            }

            Spacer()

            HStack(alignment: .bottom, spacing: 14) {
                Spacer()
                VStack(alignment: .trailing, spacing: 12) {
                    LevelSpeechBubble(text: text)
                        .frame(width: 350)
                    if let buttonTitle, let action {
                        LevelActionButton(title: buttonTitle, action: action)
                    }
                }
                .padding(.bottom, showsCharacter ? 72 : 0)

                if showsCharacter {
                    LevelGuideCharacterImage(assetName: "lumiPoint")
                        .frame(width: 150, height: 210)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)
        }
    }
}

private struct Level6PhotoComparison: View {
    let sceneImage: UIImage?
    let drawingImage: UIImage?
    let action: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 20) {
//                Text("Bandingkan hasil pengamatan dan gambarmu")
//                    .font(.title2.bold())
//                    .foregroundStyle(.white)

                HStack(spacing: 20) {
                    comparisonImage(title: "Contoh", image: sceneImage)
                    comparisonImage(title: "Gambarku", image: drawingImage)
                }

                LevelActionButton(
                    title: "Selesai",
//                    systemImage: "checkmark",
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
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
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

private struct Level6CompletionOverlay: View {
    let returnToMenu: () -> Void
    let openSandbox: () -> Void

    var body: some View {
        EndLevelView(
            data: EndLevelModel(
                id: 6,
                levelNumber: 6,
                message: "Yay, semua level selesai !\nSekarang kamu bebas bermain bentuk dan cahaya",
                mascotImageName: "lumiPointwink"
            ),
            onBack: returnToMenu,
            onNext: openSandbox,
            backTitle: "Balik ke menu",
            nextTitle: "Mulai eksperimen"
        )
        .padding(.bottom, 24)
    }
}

private struct Level6DrawingCameraView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
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

#Preview(traits: .landscapeLeft) {
    NavigationStack {
        Level6FlowView()
    }
}
