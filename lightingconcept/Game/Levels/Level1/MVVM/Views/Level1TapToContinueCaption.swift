import SwiftUI

struct LevelTapToContinueCaption: View {
    var body: some View {
        Label("Ketuk dimana saja untuk lanjut", systemImage: "hand.tap.fill")
            .font(.headline.bold())
            .foregroundStyle(Color(hex: "21415D"))
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(Color.white.opacity(0.94), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color(hex: "9FA60C").opacity(0.55), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
            .accessibilityLabel("Ketuk dimana saja untuk lanjut")
    }
}
