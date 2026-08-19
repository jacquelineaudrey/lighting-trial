//
//  Level1FlowView.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI
import UIKit

struct Level1FlowView: View {
    @StateObject private var viewModel = Level1ViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var narrator = LessonAudioNarrator()
    @State private var showsExitConfirmation = false
    let onNextLevel: (() -> Void)?

    init(onNextLevel: (() -> Void)? = nil) {
        self.onNextLevel = onNextLevel
    }

    var body: some View {
        ZStack {
            Level1ARView(viewModel: viewModel)
                .ignoresSafeArea()

            switch viewModel.phase {
            case .onboarding:
                Level1OpeningOverlay(viewModel: viewModel)
            case .scanningSurface:
                VStack {
                    SurfaceScanInstruction(sceneViewModel: viewModel.arSceneViewModel)
                    Spacer()
                }
            case .surfaceReady:
                EmptyView()
            case .lightShadowIntro:
                Level1LightShadowOverlay(viewModel: viewModel)
            case .findingShapes:
                Level1FindShapeOverlay(viewModel: viewModel)
            case .returningToFirstObject:
                EmptyView()
            case .textureTapPrompt:
                Level1TextureTapPromptOverlay()
            case .textureExploration:
                Level1TextureOverlay(viewModel: viewModel)
            case .shapeChange:
                Level1ShapeChangeOverlay(viewModel: viewModel)
            case .drawingPrompt, .drawingReady, .drawingActive:
                Level1DrawingOverlay(viewModel: viewModel)
            case .photoPrompt:
                Level1PhotoOverlay(viewModel: viewModel)
            case .photoComparison:
                Level1PhotoComparisonOverlay(viewModel: viewModel)
            case .completed:
                EndLevelView(
                    data: EndLevelViewModel.data(for: Level1Content.levelID),
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
            if viewModel.showsObjectModeBadge {
                Text("Kamu jadi objek!")
                    .font(.headline.bold())
                    .foregroundStyle(Color(hex: "21415D"))
                    .padding(.horizontal, 34)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.74, green: 0.88, blue: 1.0), in: Capsule())
                    .overlay(Capsule().stroke(.blue, lineWidth: 2))
                    .padding(.top, 28)
            }
        }
        .alert("Scene akan di-freeze", isPresented: $viewModel.showsFreezeSceneConfirmation) {
            Button("Iya, lanjut") {
                viewModel.confirmFreezeSceneAndStartDrawing()
            }
            Button("Sebentar aku arahkan lagi", role: .cancel) {
                viewModel.cancelFreezeSceneConfirmation()
            }
        } message: {
            Text("Pastikan layarmu menangkap objek.")
        }
        .alert(
            "Foto Gambar",
            isPresented: Binding(
                get: { viewModel.photoSaveMessage != nil },
                set: { _ in viewModel.clearPhotoSaveMessage() }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.clearPhotoSaveMessage() }
        } message: {
            Text(viewModel.photoSaveMessage ?? "")
        }
        .levelExitConfirmation(isPresented: $showsExitConfirmation) {
            dismiss()
        }
        .fullScreenCover(isPresented: $viewModel.showsDrawingCamera) {
            DrawingCameraView(
                onImagePicked: viewModel.completeUserDrawingPhoto,
                onCancel: viewModel.cancelDrawingCamera
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
        .sensoryFeedback(.success, trigger: viewModel.successFeedbackTrigger)
        .task(id: viewModel.narrationID) {
            // Saat scanning, anak hanya melihat instruksi scan. Lumi dan
            // narasinya baru mulai setelah surface stabil dan scene siap.
            guard viewModel.phase != .scanningSurface else {
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
        .navigationBarBackButtonHidden(true)
    }
}

private struct Level1OpeningOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        EmptyView()
    }
}

private struct Level1LightShadowOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        EmptyView()
    }
}

private struct Level1FindShapeOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        EmptyView()
    }
}

private struct Level1TextureTapPromptOverlay: View {
    var body: some View {
        EmptyView()
    }
}

private struct Level1TextureOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack {
            if viewModel.showsExperimentControls {
                VStack {
                    Spacer()
                    Level1ExperimentControls(viewModel: viewModel)
                }
            }
        }
    }
}

private struct Level1ShapeChangeOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack {
            if viewModel.showsExperimentControls {
                VStack {
                    Spacer()
                    Level1ExperimentControls(viewModel: viewModel)
                }
            } else if viewModel.canConfirmDrawingChoices {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Level1PrimaryActionButton(title: "Aku Pilih Ini", action: viewModel.confirmDrawingChoices)
                            .padding(.trailing, 42)
                            .padding(.bottom, 36)
                    }
                }
            }
        }
    }
}

private struct Level1PrimaryActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.blue, in: Capsule())
    }
}

private struct Level1DrawingOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 10) {
                Spacer()
                if viewModel.phase == .drawingReady || viewModel.phase == .drawingActive {
                    Button("Aku Selesai Gambar", action: viewModel.finishDrawing)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue, in: Capsule())
                        .padding(.trailing, 42)
                        .padding(.bottom, 32)
                }
            }
        }
    }
}

private struct Level1PhotoOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(viewModel.isSavingDrawingPhoto ? "Menyimpan..." : "Foto Gambarku") {
                    viewModel.captureDrawingPhoto()
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.blue, in: Capsule())
                .disabled(viewModel.isSavingDrawingPhoto)
                .padding(.trailing, 42)
                .padding(.bottom, 36)
            }
        }
    }
}

/// Kontrol interaksi mengikuti panel Figma: daftar vertikal di kiri dan
/// tombol mode kecil di bawahnya agar area AR tetap terbuka.
private struct Level1PhotoComparisonOverlay: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    comparisonImage(title: "Contoh", image: viewModel.frozenSceneImage)
                    comparisonImage(title: "Hasil Gambar Kamu", image: viewModel.userDrawingImage)
                }

                Button("Selesai", action: viewModel.completeLevelAfterPhotoComparison)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                    .background(Color.red, in: Capsule())
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
                        .scaledToFit()
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

private struct DrawingCameraView: UIViewControllerRepresentable {
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

private struct Level1ExperimentControls: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .contentShape(.rect)
                .onTapGesture(perform: viewModel.closeExperimentPanel)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.activeExperimentPanel == .texture {
                        texturePicker
                    } else if viewModel.activeExperimentPanel == .shape {
                        shapePicker
                    }

                    modeButtons
                }
                .padding(.leading, 26)
                .padding(.bottom, 28)

                Spacer()

                if viewModel.canContinueToShapeSelection {
                    Level1PrimaryActionButton(title: "Selanjutnya", action: viewModel.continueToShapeSelection)
                        .padding(.trailing, 42)
                        .padding(.bottom, 36)
                } else if viewModel.canConfirmDrawingChoices {
                    Level1PrimaryActionButton(title: "Aku Pilih Ini", action: viewModel.confirmDrawingChoices)
                        .padding(.trailing, 42)
                        .padding(.bottom, 36)
                }
            }

            if viewModel.showsTextureControlGesture || viewModel.showsShapeControlGesture {
                TouchGestureImage()
                    .frame(width: 42, height: 96)
                    .rotationEffect(.degrees(180))
                    .padding(.leading, viewModel.showsTextureControlGesture ? 72 : 30)
                    .padding(.bottom, 24)
                    .allowsHitTesting(false)
            }
        }
    }

    private var texturePicker: some View {
        VStack(spacing: 10) {
            ForEach(Array(viewModel.textureStops.enumerated()), id: \.element.id) { index, texture in
                Button { viewModel.selectTexture(at: index) } label: {
                    HStack(spacing: 12) {
                        Text(texture.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(width: 78, alignment: .leading)

                        TextureSwatch(texture: texture.material, isSelected: index == viewModel.currentTextureIndex)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var shapePicker: some View {
        VStack(spacing: 10) {
            ForEach(Array(viewModel.shapeOptions.enumerated()), id: \.element.id) { index, shape in
                Button { viewModel.selectShape(at: index) } label: {
                    HStack(spacing: 12) {
                        Text(shape.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(width: 78, alignment: .leading)

                        ShapeSwatch(shape: shape, isSelected: index == viewModel.selectedShapeIndex)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var modeButtons: some View {
        HStack(spacing: 8) {
            modeButton(icon: "cube.transparent.fill", isSelected: viewModel.activeExperimentPanel == .shape) {
                viewModel.showShapeControls()
            }
            modeButton(icon: "square.fill", isSelected: viewModel.activeExperimentPanel == .texture) {
                viewModel.showTextureControls()
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func modeButton(icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.86))
                .frame(width: 34, height: 34)
                .background(isSelected ? Color.blue : Color.white.opacity(0.10), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct TouchGestureImage: View {
    var body: some View {
        if let image = Self.touchGestureImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "hand.tap.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.24), radius: 3, y: 1)
        }
    }

    private static var touchGestureImage: UIImage? {
        ["Levels/level1/touchGesture", "Levels/touchGesture", "touchGesture"]
            .lazy
            .compactMap { UIImage(named: $0) }
            .first
    }
}

private struct SpeechBubble: View {
    enum Tail {
        case bottomLeading
        case bottomTrailing
    }

    let text: String
    var tail: Tail = .bottomTrailing

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background {
                SpeechBubbleShape(tail: tail)
                    .fill(.white.opacity(0.82))
                    .stroke(.white, lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

private struct SpeechBubbleShape: Shape {
    let tail: SpeechBubble.Tail

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 4
        let tailHeight: CGFloat = 34
        let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)

        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: radius, height: radius))

        switch tail {
        case .bottomLeading:
            path.move(to: CGPoint(x: bubbleRect.minX + 70, y: bubbleRect.maxY - 1))
            path.addLine(to: CGPoint(x: bubbleRect.minX + 28, y: rect.maxY))
            path.addLine(to: CGPoint(x: bubbleRect.minX + 116, y: bubbleRect.maxY - 1))
        case .bottomTrailing:
            path.move(to: CGPoint(x: bubbleRect.maxX - 116, y: bubbleRect.maxY - 1))
            path.addLine(to: CGPoint(x: bubbleRect.maxX - 28, y: rect.maxY))
            path.addLine(to: CGPoint(x: bubbleRect.maxX - 70, y: bubbleRect.maxY - 1))
        }

        path.closeSubpath()
        return path
    }
}

private struct TextureSwatch: View {
    let texture: MaterialTexture
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(texture.fallbackColor.swiftUIColor)
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: texture.previewSystemImage)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .overlay {
                Circle()
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.24), lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
    }
}

private struct ShapeSwatch: View {
    let shape: GameShape
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(.white.opacity(isSelected ? 0.95 : 0.22))
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: shape.quizSymbolName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? Color.blue : Color.white.opacity(0.9))
            }
            .overlay {
                Circle()
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.24), lineWidth: isSelected ? 2 : 1)
            }
    }
}

private struct ShapeFoundToast: View {
    let celebration: CheckpointCelebration

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.green)
            Text("Yeay, ketemu! Ada bentuk apa lagi, ya?")
                .font(.headline.bold())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }
}
