import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ARSceneViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isControlInspectorPresented = true

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                sceneCanvas
                    .inspector(isPresented: $isControlInspectorPresented) {
                        SceneControlPanel(viewModel: viewModel, isInspector: true)
                            .inspectorColumnWidth(min: 320, ideal: 380, max: 460)
                    }
                    .overlay(alignment: .topTrailing) {
                        if !isControlInspectorPresented {
                            Button("Show Controls", systemImage: "sidebar.right") {
                                isControlInspectorPresented = true
                            }
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .background(.thinMaterial, in: Circle())
                            .padding()
                        }
                    }
            } else {
                sceneCanvas
                    .overlay(alignment: .bottom) {
                        if viewModel.selectedConcept == nil {
                            SceneControlPanel(viewModel: viewModel)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 10)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: viewModel.selectedConcept)
            }
        }
        .overlay {
            if let concept = viewModel.selectedConcept {
                ShadowConceptOverlayView(concept: concept, tapLocation: viewModel.selectedConceptTapLocation) {
                    viewModel.selectedConcept = nil
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedConcept)
    }

    private var sceneCanvas: some View {
        ZStack(alignment: .top) {
            ARContainerView(viewModel: viewModel)
                .ignoresSafeArea()

            StatusBanner(
                text: viewModel.collisionWarning ?? viewModel.surfaceGuidanceText,
                isWarning: viewModel.collisionWarning != nil
            )
            .padding(.top, 12)
            .padding(.horizontal)
        }
    }
}

private struct StatusBanner: View {
    let text: String
    let isWarning: Bool

    var body: some View {
        Label(text, systemImage: isWarning ? "exclamationmark.triangle.fill" : "viewfinder")
            .font(.callout)
            .bold()
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel(text)
    }
}

private struct ShadowConceptOverlayView: View {
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
                Text("Tap to dismiss")
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
        .onTapGesture {
            onDismiss()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to dismiss")
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

#Preview("iPhone") {
    ContentView()
}

#Preview("iPad", traits: .fixedLayout(width: 1024, height: 768)) {
    ContentView()
}
