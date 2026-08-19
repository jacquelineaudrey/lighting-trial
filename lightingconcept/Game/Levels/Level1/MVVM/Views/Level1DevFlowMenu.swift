#if DEBUG

import SwiftUI

struct Level1DevFlowMenu: View {
    @ObservedObject var viewModel: Level1ViewModel

    var body: some View {
        Menu("Debug Level 1", systemImage: "slider.horizontal.3") {
            ForEach(Level1DevFlow.allCases) { flow in
                Button(flow.rawValue) {
                    viewModel.jumpToDevFlow(flow)
                }
            }
        }
        .labelStyle(.iconOnly)
        .font(.headline.bold())
        .foregroundStyle(.white)
        .frame(width: 52, height: 52)
        .background(Color.black.opacity(0.56), in: Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(0.8), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
        .accessibilityHint("Membuka pilihan perpindahan state pengembangan Level 1.")
    }
}

#endif
