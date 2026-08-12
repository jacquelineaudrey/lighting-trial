import SwiftUI
import RealityKit

@main
struct lightingconceptApp: App {
    init() {
        LidarPhysicsSystem.registerSystem()
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            MainMenuView()
        }
    }
}
