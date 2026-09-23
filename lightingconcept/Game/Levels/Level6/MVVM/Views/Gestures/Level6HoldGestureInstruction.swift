import SwiftUI

struct Level6HoldGestureInstruction: View {
    let action: () -> Void

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                ZStack {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 92, weight: .semibold))
                        .foregroundStyle(.white)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.46), lineWidth: 2)
                                .frame(width: 150, height: 150)
                        }
                        .position(
                            x: proxy.size.width * 0.50,
                            y: proxy.size.height * 0.46
                        )

                    Level6BottomGestureInstruction(
                        text: "Tekan dan tahan layar, lalu gerakkan perangkat. Cahaya akan mengikuti gerakanmu."
                    )
                }
            }

        }
        .contentShape(.rect)
        .onTapGesture(perform: action)
    }
}

#Preview("Gesture Flow 2 — Hold and Move") {
    Level6HoldGestureInstruction(action: {})
        .background(Color.gray)
}
