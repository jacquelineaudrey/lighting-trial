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
                        SceneControlPanel(viewModel: viewModel)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                    }
            }
        }
        .sheet(item: $viewModel.selectedConcept) { concept in
            ShadowConceptExplanationView(concept: concept)
                .presentationDetents([.height(180)])
        }
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

private struct ShadowConceptExplanationView: View {
    let concept: ShadowConcept

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(concept.rawValue)
                .font(.headline)
            Text(concept.explanation)
                .font(.body)
            Spacer()
        }
    }
}

#Preview("iPhone") {
    ContentView()
}

#Preview("iPad", traits: .fixedLayout(width: 1024, height: 768)) {
    ContentView()
}
