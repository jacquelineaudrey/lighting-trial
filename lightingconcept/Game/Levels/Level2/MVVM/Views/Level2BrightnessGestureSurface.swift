import SwiftUI

struct Level2BrightnessGestureSurface: View {
    let viewModel: Level2ViewModel

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Level2BrightnessEdgeGestureView(viewModel: viewModel, isLeadingEdge: true)
                    .frame(width: proxy.size.width * 0.42)

                Color.clear
                    .allowsHitTesting(false)
                    .frame(width: proxy.size.width * 0.16)

                Level2BrightnessEdgeGestureView(viewModel: viewModel, isLeadingEdge: false)
                    .frame(width: proxy.size.width * 0.42)
            }
        }
    }
}
