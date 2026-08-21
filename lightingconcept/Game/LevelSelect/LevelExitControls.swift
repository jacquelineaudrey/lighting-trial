//
//  LevelExitControls.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI

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
/// apa pun warnanya. Ukuran tap target 52x52pt — di atas minimum HIG 44x44pt,
/// dibesarkan sedikit karena target penggunanya anak-anak (konsisten dengan
/// `ThumbNavButton` 96pt di `Level1FlowView` untuk kontrol yang lebih sering
/// dipakai; back button ini aksi jarang-dipakai jadi tidak perlu sebesar itu).
struct LevelBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
                .background(.thinMaterial, in: Circle())
                .shadow(radius: 3, y: 1)
        }
        .accessibilityLabel("Kembali ke menu")
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
