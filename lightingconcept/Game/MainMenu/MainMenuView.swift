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

#if DEBUG
    @State private var devLevel: DevLevel?
#endif

    @StateObject private var lockAlertViewModel = LockAlertViewModel()
    @State private var showSimulationLockAlert = false

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

#if DEBUG
                        DevLevelMenu { level in
                            devLevel = level
                        }
                        .position(x: 86, y: 64)
#endif
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
#if DEBUG
            .navigationDestination(item: $devLevel) { level in
                switch level {
                case .one:
                    Level1FlowView()
                case .two:
                    Level2FlowView()
                case .three:
                    Level3FlowView()
                case .six:
                    Level6FlowView()
                }
            }
#endif
            .overlay {
                if showSimulationLockAlert {
                    ZStack {
                        InstantDimmingBackdrop {
                            showSimulationLockAlert = false
                        }

                        LockAlertView(data: lockAlertViewModel.alerts[0]) {
                            showSimulationLockAlert = false
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }

    private func openLevelSelect() {
        showLevelSelect = true
    }

    private func openSandbox() {
        guard progressStore.isSandboxUnlocked else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSimulationLockAlert = true
            }
            return
        }
        showSandbox = true
    }

    private func openAudioSettings() {
        showsAudioSettings = true
    }

    private func closeAudioSettings() {
        showsAudioSettings = false
    }
}

#if DEBUG
private enum DevLevel: Int, CaseIterable, Hashable, Identifiable {
    case one = 1
    case two = 2
    case three = 3
    case six = 6

    var id: Self { self }
}

private struct DevLevelMenu: View {
    let openLevel: (DevLevel) -> Void

    var body: some View {
        Menu {
            ForEach(DevLevel.allCases) { level in
                Button {
                    openLevel(level)
                } label: {
                    Text(verbatim: "Level \(level.rawValue)")
                }
            }
        } label: {
            Label {
                Text(verbatim: "DEV")
                    .fontWeight(.bold)
            } icon: {
                Image(systemName: "wrench.and.screwdriver.fill")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.orange, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .accessibilityLabel("Developer level picker")
        .accessibilityHint("Opens any implemented level without checking progress.")
    }
}
#endif

private struct InstantDimmingBackdrop: View {
    let action: () -> Void

    var body: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .transaction { transaction in
                transaction.animation = nil
            }
            .onTapGesture(perform: action)
    }
}

#Preview(traits: .landscapeLeft) {
    MainMenuView()
}
