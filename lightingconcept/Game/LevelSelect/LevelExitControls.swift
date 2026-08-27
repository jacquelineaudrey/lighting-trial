//
//  LevelExitControls.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI

// MARK: - Tombol ikon bulat bergaya glass (dipakai untuk kembali & ulangi langkah)

/// Tombol ikon bulat generik dengan latar `.thinMaterial` ("glass"), dipakai
/// di layar level AR untuk aksi navigasi ringkas (kembali, ulangi langkah, dst)
/// yang tidak butuh label teks.
///
/// Mengikuti HIG: ukuran tap target 52x52pt — di atas minimum HIG 44x44pt,
/// dibesarkan sedikit karena target penggunanya anak-anak.
struct LevelGlassIconButton: View {
    let systemImage: String
    var iconColor: Color = Color.black
    var isDisabled = false
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 48, height: 48)
                .background(.thinMaterial, in: Circle())
                .shadow(radius: 3, y: 1)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Tombol kembali (back) khas layar level AR

/// Tombol "kembali" custom untuk layar level AR (Level 1, Level 4, dst).
///
/// Kenapa custom, bukan back button sistem bawaan `NavigationStack`?
/// Layar level pakai `.navigationBarBackButtonHidden(true)` karena kamera AR
/// full-screen tidak boleh ketiban navigation bar sistem. Tombol ini gantinya
/// — sekaligus jadi tempat memicu konfirmasi keluar (`LevelExitConfirmation`)
/// yang tidak dimiliki back button bawaan.
///
/// Mengikuti HIG: ikon "chevron.left" (pola standar tombol kembali di iOS),
/// ditaruh di pojok kiri-atas (leading edge, area yang biasa dipakai navigasi
/// mundur), dengan latar `.thinMaterial` supaya tetap kebaca di atas video AR
/// apa pun warnanya.
struct LevelBackButton: View {
    let action: () -> Void

    var body: some View {
        LevelGlassIconButton(
            systemImage: "chevron.left",
            accessibilityLabel: "Kembali ke menu",
            action: action
        )
    }
}

// MARK: - Tombol ulangi langkah (repeat/undo) khas layar level AR

/// Tombol "ulangi langkah" (undo satu state) untuk layar level AR.
/// Sama gayanya dengan `LevelBackButton` — ikon bulat glass tanpa teks —
/// supaya kedua tombol navigasi di layar level terasa konsisten.
struct LevelRepeatStepButton: View {
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        LevelGlassIconButton(
            systemImage: "arrow.uturn.backward",
            isDisabled: isDisabled,
            accessibilityLabel: "Ulangi langkah sebelumnya",
            action: action
        )
    }
}

// MARK: - Konfirmasi keluar level (bahasa anak-anak, positif & seru)

/// Alert konfirmasi sebelum keluar dari level yang sedang dimainkan.
///
/// SENGAJA memakai bahasa yang ceria dan tidak menyinggung — TIDAK ada kata
/// "hilang", "kalah", "gagal", "sayang", atau kalimat negatif lain yang bisa
/// bikin anak merasa rugi/sedih. Progress diberitahukan lewat framing
/// positif: "mulai petualangan baru" yang seru, bukan "kehilangan progress".
struct LevelExitConfirmation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    if isPresented {
                        Button(action: dismissConfirmation) {
                            Color.black.opacity(0.4)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Tutup konfirmasi kembali ke menu")
                        .transition(.opacity)

                        ExitLevelDialog(
                            onStayTapped: dismissConfirmation,
                            onExitTapped: confirmExit
                        )
                        .transition(dialogTransition)
                        .accessibilityAddTraits(.isModal)
                    }
                }
                .ignoresSafeArea()
                .animation(overlayAnimation, value: isPresented)
            }
    }

    private var overlayAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.14)
            : .easeOut(duration: 0.22)
    }

    private var dialogTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .offset(y: 28).combined(with: .opacity),
            removal: .offset(y: 12).combined(with: .opacity)
        )
    }

    private func dismissConfirmation() {
        isPresented = false
    }

    private func confirmExit() {
        isPresented = false
        onConfirm()
    }
}

extension View {
    /// Menempelkan alert konfirmasi keluar level dengan bahasa ramah anak.
    func levelExitConfirmation(isPresented: Binding<Bool>, onConfirm: @escaping () -> Void) -> some View {
        modifier(LevelExitConfirmation(isPresented: isPresented, onConfirm: onConfirm))
    }
}
