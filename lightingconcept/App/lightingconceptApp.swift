//
//  lightingconceptApp.swift
//  lightingconcept
//
//  Created by Jacqueline on 30/07/26.
//

import SwiftUI
import RealityKit

@main
struct lightingconceptApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        LidarPhysicsSystem.registerSystem()
        ECSRegistration.registerAll()
        Level2ECSRegistration.registerAll()
        Level3ECSRegistration.registerAll()
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            MainMenuView()
                .onAppear(perform: BackgroundMusicPlayer.shared.play)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhase(newPhase)
                }
        }
    }

    private func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            BackgroundMusicPlayer.shared.play()
        case .inactive, .background:
            BackgroundMusicPlayer.shared.pause()
        @unknown default:
            break
        }
    }
}
