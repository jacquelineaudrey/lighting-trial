import SwiftUI

struct Level6PositionGuidance: View {
    let step: Level6PositionGuidanceStep
    let action: () -> Void

    var body: some View {
        switch step {
        case .overview:
            Level6GestureOverviewInstruction(action: action)
        case .planarMovement:
            Level6HoldGestureInstruction(action: action)
        case .height:
            Level6SideGestureInstruction(action: action)
        case .complete:
            EmptyView()
        }
    }
}

#Preview("All Gesture Instruction Steps") {
    TabView {
        Level6GestureOverviewInstruction(action: {})
        Level6HoldGestureInstruction(action: {})
        Level6SideGestureInstruction(action: {})
    }
    .tabViewStyle(.page)
    .background(Color.gray)
}
