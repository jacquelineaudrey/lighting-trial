import SwiftUI

struct Level6TouchIndicator: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.7), lineWidth: 1.5)
                .frame(width: 44, height: 44)
            Circle()
                .fill(.red)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle().stroke(.white, lineWidth: 2)
                }
        }
    }
}

struct Level6HeightControl: View {
    let heightPercentage: Int

    var body: some View {
        let sliderHeight: CGFloat = 190
        let fillRatio = min(max(CGFloat(heightPercentage) / 100, 0), 1)

        VStack(spacing: 10) {
            Image(systemName: "arrow.up.to.line")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(.white.opacity(0.50))
                    .frame(width: 15, height: sliderHeight)
                Capsule()
                    .fill(Color(hex: "9FA60C"))
                    .frame(width: 15, height: max(18, sliderHeight * fillRatio))
                    .animation(.easeOut(duration: 0.12), value: heightPercentage)
            }

            Image(systemName: "arrow.down.to.line")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(.black.opacity(0.12), in: Capsule())
    }
}

struct Level6BottomGestureInstruction: View {
    let text: String

    var body: some View {
        VStack {
            Spacer()
            highlightedText(text, highlightedWords: [])
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 34)
                .frame(minHeight: 66)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 34)
        }
    }
}

#Preview("Touch Indicator") {
    Level6TouchIndicator()
        .padding(60)
        .background(Color.gray)
}

#Preview("Height Control") {
    Level6HeightControl(heightPercentage: 62)
        .padding(40)
        .background(Color.gray)
}
