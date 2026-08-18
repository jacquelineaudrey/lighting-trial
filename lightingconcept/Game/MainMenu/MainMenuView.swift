//
//  MainMenuView.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI

@MainActor
/// Layar pembuka: pilih "Mulai Belajar" atau "Coba Simulasi".
/// Simulasi terkunci sampai semua level Belajar selesai.
struct MainMenuView: View {
    @State private var progressStore = GameProgressStore.shared
    @State private var showLevelSelect = false
    @State private var showSandbox = false
    @State private var showsAudioSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { proxy in
                    let scale = MainMenuLayout.scale(toFill: proxy.size)

                    ZStack(alignment: .topLeading) {
                        Image(
                            progressStore.isSandboxUnlocked
                                ? ImageResource.HomeScreen.homeScreen
                                : ImageResource.HomeScreen.homeScreenLock
                        )
                            .resizable()
                            .frame(width: MainMenuLayout.canvasSize.width,
                                   height: MainMenuLayout.canvasSize.height)
                            .accessibilityHidden(true)

                        MainMenuButton(
                            title: "Mulai Belajar",
                            isLocked: false,
                            action: openLevelSelect
                        )
                        .frame(width: MainMenuLayout.buttonSize.width,
                               height: MainMenuLayout.buttonSize.height)
                        .position(MainMenuLayout.learnButtonCenter)

                        MainMenuButton(
                            title: "Coba Simulasi",
                            isLocked: !progressStore.isSandboxUnlocked,
                            action: openSandbox
                        )
                        .frame(width: MainMenuLayout.buttonSize.width,
                               height: MainMenuLayout.buttonSize.height)
                        .position(MainMenuLayout.sandboxButtonCenter)

                        MainMenuSettingsButton(action: openAudioSettings)
                            .frame(width: MainMenuLayout.settingsButtonSize.width,
                                   height: MainMenuLayout.settingsButtonSize.height)
                            .position(MainMenuLayout.settingsButtonCenter)
                    }
                    .frame(width: MainMenuLayout.canvasSize.width,
                           height: MainMenuLayout.canvasSize.height)
                    .scaleEffect(scale)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                .accessibilityHidden(showsAudioSettings)

                if showsAudioSettings {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)

                    AudioSettingsView(dismiss: closeAudioSettings)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showsAudioSettings)
            .ignoresSafeArea()
            .navigationDestination(isPresented: $showLevelSelect) {
                LevelSelectView()
            }
            .navigationDestination(isPresented: $showSandbox) {
                ContentView()
            }
        }
    }

    private func openLevelSelect() {
        showLevelSelect = true
    }

    private func openSandbox() {
        guard progressStore.isSandboxUnlocked else { return }
        showSandbox = true
    }

    private func openAudioSettings() {
        showsAudioSettings = true
    }

    private func closeAudioSettings() {
        showsAudioSettings = false
    }
}

#Preview {
    MainMenuView()
}
