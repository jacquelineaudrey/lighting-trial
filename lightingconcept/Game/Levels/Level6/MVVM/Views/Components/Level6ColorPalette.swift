import SwiftUI

// MARK: - Color Palette

struct Level6ColorPalette: View {
    let selectedColor: Level6LightColor
    let selectColor: (Level6LightColor) -> Void
    let close: () -> Void

    private let contentWidth: CGFloat = 360

    private let columns = Array(
        repeating: GridItem(.fixed(40), spacing: 14),
        count: 5
    )

    private let paletteColors: [Level6LightColor] = [
        .black,
        .blue,
        .green,
        .yellow,
        .red,
        .lightBlue,
        .purple,
        .orange,
        .pink,
        .white
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.black.opacity(0.14))
                .frame(width: 60, height: 8)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Header
            HStack {
                Text("Warna Cahaya")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.72))
                        .frame(width: 44, height: 44)
                        .background(
                            Color.primary.opacity(0.10),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tutup pilihan warna")
            }
            .frame(width: contentWidth)

            // Preview dan grid warna
            HStack(alignment: .center, spacing: 0) {

                // MARK: Selected Color Preview
                RoundedRectangle(cornerRadius: 24)
                    .fill(selectedColor.color)
                    .frame(width: 82, height: 82)

                Spacer(minLength: 16)

                // MARK: Color Grid
                LazyVGrid(
                    columns: columns,
                    alignment: .center,
                    spacing: 20
                ) {
                    ForEach(paletteColors) { color in
                        Button {
                            withAnimation(
                                .spring(
                                    response: 0.25,
                                    dampingFraction: 0.72
                                )
                            ) {
                                selectColor(color)
                            }
                        } label: {
                            Level6ColorCircle(
                                color: color.color,
                                isSelected: color == selectedColor
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.displayName)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(width: contentWidth)
            .padding(.top, 30)
            .padding(.bottom, 64)
        }
        .padding(.horizontal, 20)
        .background(.thickMaterial)
        .clipShape(Level6ColorPickerBubbleShape())
        .shadow(
            color: .black.opacity(0.1),
            radius: 14,
            x: 0,
            y: 16
        )
    }
}

// MARK: - Color Circle

private struct Level6ColorCircle: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 32, height: 32)
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .padding(5)
                }
            }
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .animation(
                .spring(
                    response: 0.25,
                    dampingFraction: 0.72
                ),
                value: isSelected
            )
    }
}

// MARK: - Bubble Shape

private struct Level6ColorPickerBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let cornerRadius: CGFloat = 48
        let pointerWidth: CGFloat = 48
        let pointerHeight: CGFloat = 24

        let bottom = rect.maxY - pointerHeight
        let centerX = rect.minX + 110

        path.move(
            to: CGPoint(
                x: rect.minX + cornerRadius,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX - cornerRadius,
                y: rect.minY
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX,
                y: rect.minY + cornerRadius
            ),
            control: CGPoint(
                x: rect.maxX,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX,
                y: bottom - cornerRadius
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX - cornerRadius,
                y: bottom
            ),
            control: CGPoint(
                x: rect.maxX,
                y: bottom
            )
        )

        path.addLine(
            to: CGPoint(
                x: centerX + pointerWidth / 2,
                y: bottom
            )
        )

        path.addLine(
            to: CGPoint(
                x: centerX,
                y: rect.maxY
            )
        )

        path.addLine(
            to: CGPoint(
                x: centerX - pointerWidth / 2,
                y: bottom
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.minX + cornerRadius,
                y: bottom
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX,
                y: bottom - cornerRadius
            ),
            control: CGPoint(
                x: rect.minX,
                y: bottom
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY + cornerRadius
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + cornerRadius,
                y: rect.minY
            ),
            control: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Interactive Preview

private struct Level6ColorPalettePreview: View {
    @State private var selectedColor: Level6LightColor = .yellow
    @State private var isOpen = true

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background terang agar shadow panel terlihat
            LinearGradient(
                colors: [
                    Color.white,
                    Color(
                        red: 0.87,
                        green: 0.89,
                        blue: 0.93
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Palette dan button disusun secara vertikal.
            // Palette berada di atas button.
            VStack(alignment: .leading, spacing: 14) {
                if isOpen {
                    Level6ColorPalette(
                        selectedColor: selectedColor,
                        selectColor: { color in
                            withAnimation(
                                .spring(
                                    response: 0.25,
                                    dampingFraction: 0.75
                                )
                            ) {
                                selectedColor = color
                            }
                        },
                        close: {
                            withAnimation(
                                .spring(
                                    response: 0.38,
                                    dampingFraction: 0.86
                                )
                            ) {
                                isOpen = false
                            }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion:
                                .scale(
                                    scale: 0.88,
                                    anchor: .bottom
                                )
                                .combined(with: .opacity),

                            removal:
                                .scale(
                                    scale: 0.88,
                                    anchor: .bottom
                                )
                                .combined(with: .opacity)
                        )
                    )
                }

                // Button tetap selalu ditampilkan
                Level6ColorButton {
                    withAnimation(
                        .spring(
                            response: 0.38,
                            dampingFraction: 0.86
                        )
                    ) {
                        isOpen.toggle()
                    }
                }
                .transition(.opacity)
            }
            .padding(.leading, 24)
            .padding(.bottom, 24)
        }
        .animation(
            .spring(
                response: 0.38,
                dampingFraction: 0.86
            ),
            value: isOpen
        )
    }
}

// MARK: - iPad Canvas Preview

#Preview("Color Picker Apple Style - iPad") {
    Level6ColorPalettePreview()
        .previewDevice(
            PreviewDevice(
                rawValue: "iPad Pro 11-inch (M4)"
            )
        )
        .previewInterfaceOrientation(.landscapeLeft)
}
