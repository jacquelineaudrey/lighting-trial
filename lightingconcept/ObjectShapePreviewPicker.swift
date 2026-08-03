import SwiftUI

struct ObjectShapePreviewPicker: View {
    @Binding var selection: LearningObjectType
    var showsSelection = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Choose Shape")
                    .font(.headline)
                Text("Tap a preview to apply it to the active object.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(LearningObjectType.allCases) { type in
                        Button {
                            selection = type
                        } label: {
                            VStack(spacing: 4) {
                                Canvas { context, size in
                                    Self.draw(type, in: size, context: &context)
                                }
                                .frame(width: 62, height: 54)

                                Text(type.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .top)
                            }
                            .frame(width: 100)
                            .padding(.vertical, 7)
                            .background(
                                isSelected(type) ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected(type) ? Color.accentColor : .clear, lineWidth: 2)
                            }
                            .overlay(alignment: .topTrailing) {
                                if isSelected(type) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                        .background(.background, in: Circle())
                                        .padding(6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Choose \(type.rawValue)")
                        .accessibilityValue(isSelected(type) ? "Selected" : "Not selected")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func isSelected(_ type: LearningObjectType) -> Bool {
        showsSelection && selection == type
    }

    private static func draw(
        _ type: LearningObjectType,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let stroke = GraphicsContext.Shading.color(.primary)
        let fill = GraphicsContext.Shading.color(.accentColor.opacity(0.28))
        let width = size.width
        let height = size.height

        func render(_ path: Path) {
            context.fill(path, with: fill)
            context.stroke(path, with: stroke, lineWidth: 1.5)
        }

        switch type {
        case .sphere:
            let rect = CGRect(x: 11, y: 5, width: width - 22, height: height - 10)
            render(Path(ellipseIn: rect))
            var curve = Path()
            curve.addEllipse(in: CGRect(x: rect.midX - 7, y: rect.minY, width: 14, height: rect.height))
            context.stroke(curve, with: stroke, lineWidth: 1)

        case .cylinder:
            let top = CGRect(x: 11, y: 5, width: width - 22, height: 14)
            var body = Path()
            body.move(to: CGPoint(x: top.minX, y: top.midY))
            body.addLine(to: CGPoint(x: top.minX, y: height - 11))
            body.addQuadCurve(
                to: CGPoint(x: top.maxX, y: height - 11),
                control: CGPoint(x: top.midX, y: height)
            )
            body.addLine(to: CGPoint(x: top.maxX, y: top.midY))
            body.closeSubpath()
            render(body)
            render(Path(ellipseIn: top))

        case .cone:
            var cone = Path()
            cone.move(to: CGPoint(x: width / 2, y: 4))
            cone.addLine(to: CGPoint(x: 10, y: height - 11))
            cone.addQuadCurve(
                to: CGPoint(x: width - 10, y: height - 11),
                control: CGPoint(x: width / 2, y: height)
            )
            cone.closeSubpath()
            render(cone)

        case .hemisphere:
            var dome = Path()
            dome.move(to: CGPoint(x: 8, y: height - 13))
            dome.addCurve(
                to: CGPoint(x: width - 8, y: height - 13),
                control1: CGPoint(x: 13, y: 4),
                control2: CGPoint(x: width - 13, y: 4)
            )
            dome.addQuadCurve(
                to: CGPoint(x: 8, y: height - 13),
                control: CGPoint(x: width / 2, y: height - 2)
            )
            render(dome)

        case .squarePyramid, .triangularPyramid:
            let apex = CGPoint(x: width / 2, y: 4)
            let left = CGPoint(x: 8, y: height - 12)
            let right = CGPoint(x: width - 8, y: height - 12)
            let back = CGPoint(x: width / 2, y: height - 2)
            var pyramid = Path()
            pyramid.move(to: apex)
            pyramid.addLine(to: left)
            pyramid.addLine(to: back)
            pyramid.addLine(to: right)
            pyramid.closeSubpath()
            pyramid.move(to: apex)
            pyramid.addLine(to: back)
            if type == .squarePyramid {
                pyramid.move(to: left)
                pyramid.addLine(to: right)
            }
            render(pyramid)

        case .cube, .cuboid:
            let isCuboid = type == .cuboid
            let horizontalInset: CGFloat = isCuboid ? 5 : 11
            let topHeight: CGFloat = 12
            let frontTop: CGFloat = 17
            let frontBottom: CGFloat = height - 5
            let depth: CGFloat = 10
            var box = Path()
            box.move(to: CGPoint(x: horizontalInset, y: frontTop))
            box.addLine(to: CGPoint(x: width - horizontalInset - depth, y: frontTop))
            box.addLine(to: CGPoint(x: width - horizontalInset, y: frontTop - topHeight))
            box.addLine(to: CGPoint(x: horizontalInset + depth, y: frontTop - topHeight))
            box.closeSubpath()
            box.move(to: CGPoint(x: horizontalInset, y: frontTop))
            box.addLine(to: CGPoint(x: horizontalInset, y: frontBottom))
            box.addLine(to: CGPoint(x: width - horizontalInset - depth, y: frontBottom))
            box.addLine(to: CGPoint(x: width - horizontalInset - depth, y: frontTop))
            box.move(to: CGPoint(x: width - horizontalInset - depth, y: frontBottom))
            box.addLine(to: CGPoint(x: width - horizontalInset, y: frontBottom - topHeight))
            box.addLine(to: CGPoint(x: width - horizontalInset, y: frontTop - topHeight))
            render(box)
        }
    }
}

#Preview {
    @Previewable @State var selection = LearningObjectType.cube
    ObjectShapePreviewPicker(selection: $selection)
        .padding()
}
