#if DEBUG

import SwiftUI

struct DeveloperPhaseMenu: View {
    let levelTitle: String
    let phases: [String]
    let onSelect: (Int) -> Void

    var body: some View {
        Menu(levelTitle, systemImage: "wrench.and.screwdriver.fill") {
            ForEach(phases.indices, id: \.self) { index in
                Button(phases[index]) {
                    onSelect(index)
                }
            }
        }
        .labelStyle(.iconOnly)
        .font(.headline.bold())
        .foregroundStyle(.white)
        .frame(width: 52, height: 52)
        .background(Color.orange.opacity(0.92), in: Circle())
        .overlay {
            Circle().stroke(.white.opacity(0.9), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
        .accessibilityLabel("\(levelTitle) phase picker")
        .accessibilityHint("Jumps directly to a phase for development testing.")
    }
}

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
