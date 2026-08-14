import SwiftUI

struct Level2BrightnessGestureSurface: View {
    let viewModel: Level2ViewModel

    var body: some View {
        HStack(spacing: 0) {
            Level2BrightnessEdgeGestureView(viewModel: viewModel, isLeadingEdge: true)
                .frame(maxWidth: .infinity)

            Color.clear
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity)

            Color.clear
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity)

            Level2BrightnessEdgeGestureView(viewModel: viewModel, isLeadingEdge: false)
                .frame(maxWidth: .infinity)
        }
    }
}
