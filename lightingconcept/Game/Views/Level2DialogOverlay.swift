import SwiftUI

struct Level2DialogOverlay: View {
    let line: DialogLine
    let buttonTitle: String
    let replayNarration: () -> Void
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🦉")
                .font(.largeTitle.scaled(by: 1.6))
                .accessibilityHidden(true)

            Text(line.characterName)
                .font(.headline)
                .foregroundStyle(.blue)

            Text(line.text)
                .font(.title3)
                .bold()
                .multilineTextAlignment(.center)

            Level2ReplayNarrationButton(action: replayNarration)

            Button(buttonTitle, action: action)
                .font(.title3)
                .bold()
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
    }
}
