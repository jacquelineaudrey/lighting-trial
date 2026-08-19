//
//  Level1ExperimentControls.swift
//  lightingconcept
//
//  Controls for Level 1 shape and texture selection.
//

import SwiftUI
import UIKit

private enum Level1ExperimentControlMetrics {
    static let rowSpacing: CGFloat = 12
    static let pickerWidth: CGFloat = 200
    // Padding isi picker kiri-kanan
    static let panelHorizontalPadding: CGFloat = 20
    static let panelVerticalPadding: CGFloat = 20
    static let panelCornerRadius: CGFloat = 30
    static let swatchSize: CGFloat = 30
    // MARK: Hand Gesture
    static let handWidth: CGFloat = 70
    static let handHeight: CGFloat = 140

    static let handOffsetX: CGFloat = 56
    static let handOffsetY: CGFloat = -60

    static let handRotation: Double = 180
}

struct Level1ExperimentControls: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .contentShape(.rect)
                .onTapGesture(perform: viewModel.closeExperimentPanel)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.activeExperimentPanel == .texture {
                        Level1TexturePickerPanel(
                            textures: viewModel.textureStops,
                            selectedIndex: viewModel.currentTextureIndex,
                            showsGesture: viewModel.showsTextureControlGesture,
                            onSelect: viewModel.selectTexture(at:)
                        )
                    } else if viewModel.activeExperimentPanel == .shape {
                        Level1ShapePickerPanel(
                            shapes: viewModel.shapeOptions,
                            selectedIndex: viewModel.selectedShapeIndex,
                            showsGesture: viewModel.showsShapeControlGesture,
                            onSelect: viewModel.selectShape(at:)
                        )
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
        }
    }

    private var modeButtons: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 8) {
                modeButton(icon: "cube.transparent.fill", isSelected: viewModel.activeExperimentPanel == .shape) {
                    viewModel.showShapeControls()
                }
                modeButton(icon: "square.fill", isSelected: viewModel.activeExperimentPanel == .texture) {
                    viewModel.showTextureControls()
                }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: Capsule())

            if shouldShowModeGesture {
                TouchGestureImage()
                    .frame(
                        width: Level1ExperimentControlMetrics.handWidth,
                        height: Level1ExperimentControlMetrics.handHeight
                    )
                    .rotationEffect(.degrees(Level1ExperimentControlMetrics.handRotation))
                    .offset(x: modeGestureOffsetX, y: Level1ExperimentControlMetrics.handOffsetY)
                    .allowsHitTesting(false)
            }
        }
    }

    private var shouldShowModeGesture: Bool {
        viewModel.activeExperimentPanel == nil
            && (viewModel.showsTextureControlGesture || viewModel.showsShapeControlGesture)
    }

    private var modeGestureOffsetX: CGFloat {
        viewModel.showsTextureControlGesture ? Level1ExperimentControlMetrics.handOffsetX : -8
    }

    private func modeButton(icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.86))
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.blue : Color.white.opacity(0.10), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct Level1TexturePickerPanel: View {

    let textures: [TextureStop]
    let selectedIndex: Int
    let showsGesture: Bool
    let onSelect: (Int) -> Void

    var body: some View {

        pickerPanel(showsGesture: showsGesture) {

            VStack(
                spacing: Level1ExperimentControlMetrics.rowSpacing
            ) {

                ForEach(
                    Array(textures.enumerated()),
                    id: \.element.id
                ) { index, texture in

                    Button {
                        onSelect(index)
                    } label: {

                        HStack {

                            Text(texture.name)
                                .font(
                                    .system(
                                        size: 14,
                                        weight: .medium
                                    )
                                )
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Spacer()

                            TextureSwatch(
                                texture: texture.material,
                                isSelected: index == selectedIndex
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct Level1ShapePickerPanel: View {

    let shapes: [GameShape]
    let selectedIndex: Int
    let showsGesture: Bool
    let onSelect: (Int) -> Void

    var body: some View {

        pickerPanel(showsGesture: showsGesture) {

            VStack(
                spacing: Level1ExperimentControlMetrics.rowSpacing
            ) {

                ForEach(
                    Array(shapes.enumerated()),
                    id: \.element.id
                ) { index, shape in

                    Button {
                        onSelect(index)
                    } label: {

                        HStack {

                            Text(shape.displayName)
                                .font(
                                    .system(
                                        size: 14,
                                        weight: .medium
                                    )
                                )
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Spacer()

                            ShapeSwatch(
                                shape: shape,
                                isSelected: index == selectedIndex
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private func pickerPanel<Content: View>(
    showsGesture: Bool,
    @ViewBuilder content: () -> Content
) -> some View {

    ZStack(alignment: .bottomTrailing) {

        content()
            .frame(maxWidth: .infinity)
            .padding(
                .horizontal,
                Level1ExperimentControlMetrics.panelHorizontalPadding
            )
            .padding(
                .vertical,
                Level1ExperimentControlMetrics.panelVerticalPadding
            )
            .frame(
                width: Level1ExperimentControlMetrics.pickerWidth
            )
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(
                    cornerRadius:
                        Level1ExperimentControlMetrics.panelCornerRadius
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        Level1ExperimentControlMetrics.panelCornerRadius
                )
                .stroke(
                    .white.opacity(0.28),
                    lineWidth: 1
                )
            }

        if showsGesture {

            TouchGestureImage()
                .frame(
                    width:
                        Level1ExperimentControlMetrics.handWidth,
                    height:
                        Level1ExperimentControlMetrics.handHeight
                )
                .rotationEffect(
                    .degrees(
                        Level1ExperimentControlMetrics.handRotation
                    )
                )
                .offset(
                    x:
                        Level1ExperimentControlMetrics.handOffsetX,
                    y:
                        Level1ExperimentControlMetrics.handOffsetY
                )
                .allowsHitTesting(false)
        }
    }
}

struct TouchGestureImage: View {
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

private struct TextureSwatch: View {
    let texture: MaterialTexture
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(texture.fallbackColor.swiftUIColor)
            .frame(
                width: Level1ExperimentControlMetrics.swatchSize,
                height: Level1ExperimentControlMetrics.swatchSize
            )
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
            .frame(
                width: Level1ExperimentControlMetrics.swatchSize,
                height: Level1ExperimentControlMetrics.swatchSize
            )
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

#Preview("Texture Picker") {
    ZStack(alignment: .bottomLeading) {
        Color.black.opacity(0.45).ignoresSafeArea()
        Level1TexturePickerPanel(
            textures: Level1Content.kubus.textures,
            selectedIndex: 4,
            showsGesture: true,
            onSelect: { _ in }
        )
        .padding(30)
    }
}

#if DEBUG

private struct Level1ExperimentControlsPreviewState: View {

    enum Mode {
        case none
        case texture
        case shape
    }

    @State private var mode: Mode = .none
    @State private var selectedTextureIndex = 0
    @State private var selectedShapeIndex = 0

    var body: some View {
        ZStack(alignment: .bottomLeading) {

            // Simulasi background AR
            LinearGradient(
                colors: [
                    Color.gray.opacity(0.75),
                    Color.black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Simulasi instruction / dialog
            VStack {
                HStack {
                    Spacer()

                    Text(instructionText)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 18)
                        .frame(maxWidth: 430)
                        .background(
                            .white.opacity(0.92),
                            in: RoundedRectangle(cornerRadius: 10)
                        )

                    Spacer()
                }

                .padding(.top, 120)

                Spacer()
            }

            // Controls lengkap
            HStack(alignment: .bottom) {

                VStack(alignment: .leading, spacing: 12) {

                    if mode == .texture {
                        Level1TexturePickerPanel(
                            textures: Level1Content.kubus.textures,
                            selectedIndex: selectedTextureIndex,
                            showsGesture: false
                        ) { index in
                            selectedTextureIndex = index
                        }

                    } else if mode == .shape {
                        Level1ShapePickerPanel(
                            shapes: Level1Content.checkpoints.map(\.shape),
                            selectedIndex: selectedShapeIndex,
                            showsGesture: false
                        ) { index in
                            selectedShapeIndex = index
                        }
                    }

                    HStack(spacing: 8) {

                        previewModeButton(
                            icon: "cube.transparent.fill",
                            isSelected: mode == .shape
                        ) {
                            mode = .shape
                        }

                        previewModeButton(
                            icon: "square.fill",
                            isSelected: mode == .texture
                        ) {
                            mode = .texture
                        }
                    }
                    .padding(6)
                    .background(
                        .ultraThinMaterial,
                        in: Capsule()
                    )
                }

                .padding(.leading, 26)
                .padding(.bottom, 28)

                Spacer()
            }

            // Saat belum pilih mode:
            // tunjukkan hand gesture ke tombol mode
            if mode == .none {

                TouchGestureImage()
                    .frame(
                        width: Level1ExperimentControlMetrics.handWidth,
                        height: Level1ExperimentControlMetrics.handHeight
                    )
                    .rotationEffect(
                        .degrees(Level1ExperimentControlMetrics.handRotation)
                    )
                    .offset(
                        x: Level1ExperimentControlMetrics.handOffsetX,
                        y: Level1ExperimentControlMetrics.handOffsetY
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    private var instructionText: String {
        switch mode {
        case .none:
            return "Kamu bisa ganti bentuk dan tekstur yang kamu suka, lho!"

        case .texture:
            return "Pilih tekstur yang kamu suka!"

        case .shape:
            return "Pilih bentuk yang kamu suka!"
        }
    }

    private func previewModeButton(
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(
                    isSelected
                        ? .white
                        : .white.opacity(0.86)
                )
                .frame(width: 44, height: 44)
                .background(
                    isSelected
                        ? Color.blue
                        : Color.white.opacity(0.10),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview(
    "Experiment Flow",
    traits: .landscapeLeft
) {
    Level1ExperimentControlsPreviewState()
}

#endif
