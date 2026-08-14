import SwiftUI

/// Shared sandbox-style interaction overlay for educational shadow labels.
/// Any 3D marker named `Label: ...` is handled by ARSceneCoordinator; tapping
/// it sets `selectedConcept`, and this view presents the same spotlight
/// explanation used by the Sandbox.
struct ShadowConceptOverlayView: View {
    let concept: ShadowConcept
    let tapLocation: CGPoint
    let onDismiss: () -> Void

    private let holeRadius: CGFloat = 50

    var body: some View {
        ZStack {
            SpotlightCutoutShape(holeCenter: tapLocation, holeRadius: holeRadius)
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                .frame(width: holeRadius * 2, height: holeRadius * 2)
                .position(tapLocation)

            VStack(alignment: .leading, spacing: 16) {
                Text(concept.rawValue)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(concept.explanation)
                    .font(.body)
                    .foregroundStyle(.white)
                Text("Ketuk untuk menutup")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Ketuk untuk menutup")
    }
}

private struct SpotlightCutoutShape: Shape {
    var holeCenter: CGPoint
    var holeRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(holeCenter.x, holeCenter.y) }
        set {
            holeCenter.x = newValue.first
            holeCenter.y = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addEllipse(in: CGRect(
            x: holeCenter.x - holeRadius,
            y: holeCenter.y - holeRadius,
            width: holeRadius * 2,
            height: holeRadius * 2
        ))
        return path
    }
}
