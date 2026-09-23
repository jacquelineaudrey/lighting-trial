import SwiftUI

struct Level6SideGestureInstruction: View {
    let action: () -> Void

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                ZStack {
                    Level6VerticalGestureAsset(
                        horizontalPosition: 0.12,
                        size: proxy.size
                    )
                    Level6VerticalGestureAsset(
                        horizontalPosition: 0.94,
                        size: proxy.size
                    )
                    Level6BottomGestureInstruction(
                        text: "Naik turun (kiri: terang & kanan: tinggi). Dua jari (lebar cahaya)."
                    )
                }
            }

        }
        .contentShape(.rect)
        .onTapGesture(perform: action)
    }
}

private struct Level6VerticalGestureAsset: View {
    let horizontalPosition: CGFloat
    let size: CGSize

    var body: some View {
        Level2GestureAssetImage(
            prompt: .verticalSlide,
            showsPulse: false
        )
        .frame(
            width: min(size.width * 0.18, 210),
            height: min(size.height * 0.28, 230)
        )
        .position(
            x: size.width * horizontalPosition,
            y: size.height * 0.47
        )
    }
}

#Preview("Gesture Flow 3 — Left and Right Controls") {
    Level6SideGestureInstruction(action: {})
        .background(Color.gray)
}
