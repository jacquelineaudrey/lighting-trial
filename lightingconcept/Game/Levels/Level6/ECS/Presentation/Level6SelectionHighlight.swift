import RealityKit
import SwiftUI

@MainActor
enum Level6SelectionHighlight {
    static let entityName = "Level 6 Light Selection Highlight"

    static func makeEntity() -> Entity {
        let highlight = Entity()
        highlight.name = entityName

        let redMaterial = UnlitMaterial(color: .red)
        for index in 0..<20 {
            let angle = Float(index) / 20 * 2 * .pi
            let dot = ModelEntity(
                mesh: .generateSphere(radius: 0.0045),
                materials: [redMaterial]
            )
            dot.position = SIMD3<Float>(
                cos(angle) * 0.052,
                sin(angle) * 0.052,
                0.002
            )
            highlight.addChild(dot)
        }

        var glow = PointLightComponent()
        glow.color = .white
        glow.intensity = 260
        glow.attenuationRadius = 0.24
        highlight.components.set(glow)
        return highlight
    }
}

private struct Level6SelectionHighlightPreview: View {
    private let dotCount = 20

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)

            Circle()
                .fill(.yellow)
                .frame(width: 108, height: 108)
                .shadow(color: .yellow.opacity(0.8), radius: 24)

            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(.red)
                    .frame(width: 14, height: 14)
                    .offset(y: -156)
                    .rotationEffect(.degrees(Double(index) / Double(dotCount) * 360))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

#Preview("Selected Lamp Decoration") {
    Level6SelectionHighlightPreview()
        .frame(width: 500, height: 420)
}
