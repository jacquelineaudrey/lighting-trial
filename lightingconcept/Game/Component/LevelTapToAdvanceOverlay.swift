import SwiftUI

/// Area lanjut yang konsisten untuk dialog level dan aman dari double tap.
struct LevelTapToAdvanceOverlay: View {
    var isEnabled = true
    var showsCaption = true
    let action: () -> Void

    @State private var isDebouncing = false

    var body: some View {
        ZStack {
            Button(action: advance) {
                Color.clear
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled || isDebouncing)
            .accessibilityLabel("Ketuk dimana saja untuk lanjut")
            .accessibilityHint("Melanjutkan permainan ke langkah berikutnya.")

            if isEnabled && showsCaption {
                VStack {
                    Spacer()
                    LevelTapToContinueCaption()
                        .padding(.bottom, 28)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
    }

    private func advance() {
        guard isEnabled, !isDebouncing else { return }
        isDebouncing = true
        action()

        Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            isDebouncing = false
        }
    }
}
