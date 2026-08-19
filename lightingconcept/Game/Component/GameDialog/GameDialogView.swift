//
//  GameDialogView.swift
//  lightingconcept
//
//  Reusable game dialog matching the ExitLevelDialog visual style.
//

import SwiftUI

struct GameDialogView: View {
    let title: String
    let message: String
    let primaryTitle: String
    let secondaryTitle: String?
    var isLoading = false
    var loadingMessage: String?
    var primaryAction: () -> Void = {}
    var secondaryAction: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 35)
                .fill(Color(hex: "EFEBCF"))
                .overlay(
                    RoundedRectangle(cornerRadius: 35)
                        .stroke(Color(hex: "D6CF91"), lineWidth: 2)
                )
                .frame(width: 330, height: secondaryTitle == nil ? 214 : 252)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 17))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "313131"))

                Text(isLoading ? (loadingMessage ?? message) : message)
                    .font(.system(size: 17))
                    .fontWeight(.regular)
                    .foregroundColor(Color(hex: "313131"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 286, height: 86, alignment: .topLeading)
            .padding(.top, 24)

            if isLoading {
                ProgressView()
                    .tint(Color(hex: "9FA60C"))
                    .scaleEffect(1.25)
                    .padding(.top, 128)
            } else {
                VStack(spacing: 12) {
                    Button(action: primaryAction) {
                        Text(primaryTitle)
                            .font(.system(size: 17))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 292, height: 48)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "9FA60C"))
                            )
                    }

                    if let secondaryTitle {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                                .font(.system(size: 17))
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "C0392B"))
                                .frame(width: 292, height: 48)
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: "C0392B"), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.top, secondaryTitle == nil ? 130 : 123)
            }
        }
    }
}

struct GameDialogOverlay: ViewModifier {
    let isPresented: Bool
    let title: String
    let message: String
    let primaryTitle: String
    let secondaryTitle: String?
    var isLoading = false
    var loadingMessage: String?
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()
                    .transition(.opacity)

                GameDialogView(
                    title: title,
                    message: message,
                    primaryTitle: primaryTitle,
                    secondaryTitle: secondaryTitle,
                    isLoading: isLoading,
                    loadingMessage: loadingMessage,
                    primaryAction: primaryAction,
                    secondaryAction: secondaryAction
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPresented)
        .animation(.easeInOut(duration: 0.18), value: isLoading)
    }
}

extension View {
    func gameDialog(
        isPresented: Bool,
        title: String,
        message: String,
        primaryTitle: String,
        secondaryTitle: String? = nil,
        isLoading: Bool = false,
        loadingMessage: String? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            GameDialogOverlay(
                isPresented: isPresented,
                title: title,
                message: message,
                primaryTitle: primaryTitle,
                secondaryTitle: secondaryTitle,
                isLoading: isLoading,
                loadingMessage: loadingMessage,
                primaryAction: primaryAction,
                secondaryAction: secondaryAction
            )
        )
    }
}

#Preview("Freeze Confirmation", traits: .landscapeLeft) {
    Color.gray.opacity(0.4)
        .ignoresSafeArea()
        .gameDialog(
            isPresented: true,
            title: "Scene akan di-freeze",
            message: "Pastikan layarmu menangkap objek.",
            primaryTitle: "Iya, lanjut",
            secondaryTitle: "Sebentar aku arahkan lagi",
            primaryAction: {},
            secondaryAction: {}
        )
}

#Preview("Loading", traits: .landscapeLeft) {
    Color.gray.opacity(0.4)
        .ignoresSafeArea()
        .gameDialog(
            isPresented: true,
            title: "Menyiapkan scene",
            message: "Pastikan layarmu menangkap objek.",
            primaryTitle: "Iya, lanjut",
            secondaryTitle: "Sebentar aku arahkan lagi",
            isLoading: true,
            loadingMessage: "Sebentar ya, gambarnya sedang disiapkan.",
            primaryAction: {},
            secondaryAction: {}
        )
}

#Preview("Info Message", traits: .landscapeLeft) {
    Color.gray.opacity(0.4)
        .ignoresSafeArea()
        .gameDialog(
            isPresented: true,
            title: "Foto Gambar",
            message: "Keren! Gambarmu sudah tersimpan.",
            primaryTitle: "OK",
            primaryAction: {}
        )
}
