import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ARSceneViewModel()

    var body: some View {
        ZStack {
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            VStack {
                StatusBanner(text: viewModel.surfaceGuidanceText)
                    .padding(.top, 12)

                Spacer()

                SceneControlPanel(viewModel: viewModel)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .sheet(item: $viewModel.selectedConcept) { concept in
            ShadowConceptExplanationView(concept: concept)
                .presentationDetents([.height(180)])
        }
    }
}

private struct StatusBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
