import SwiftUI

struct Level2GestureLayer: View {
    let viewModel: Level2ViewModel

    var body: some View {
        switch viewModel.phase {
        case .spreadExploration:
            Level2SpreadGestureSurface(viewModel: viewModel)
        case .intensityExploration:
            Level2BrightnessGestureSurface(viewModel: viewModel)
        default:
            EmptyView()
        }
    }
}
