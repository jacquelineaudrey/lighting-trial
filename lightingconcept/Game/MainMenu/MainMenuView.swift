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

    @StateObject private var lockAlertViewModel = LockAlertViewModel()
    @State private var showSimulationLockAlert = false

    var body: some View {
        NavigationStack {
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
                }
                .frame(width: MainMenuLayout.canvasSize.width,
                       height: MainMenuLayout.canvasSize.height)
                .scaleEffect(scale)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .ignoresSafeArea()
            .navigationDestination(isPresented: $showLevelSelect) {
                LevelSelectView()
            }
            .navigationDestination(isPresented: $showSandbox) {
                ContentView()
            }
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
}

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

#Preview {
    MainMenuView()
}
