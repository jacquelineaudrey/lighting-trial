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
    init() {
        LidarPhysicsSystem.registerSystem()
        ECSRegistration.registerAll()
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            MainMenuView()
        }
    }
}
