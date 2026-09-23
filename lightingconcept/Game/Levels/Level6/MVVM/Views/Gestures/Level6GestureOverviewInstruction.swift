import SwiftUI

struct Level6GestureOverviewInstruction: View {
    let action: () -> Void

    var body: some View {
        Level2FreeExploreInstructionsOverlay(action: action)
    }
}

#Preview("Gesture Flow 1 — Two-Finger Overview") {
    Level6GestureOverviewInstruction(action: {})
        .background(Color.gray)
}
