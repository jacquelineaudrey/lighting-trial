////
////  lightingconceptApp.swift
////  lightingconcept
////
////  Created by Jacqueline on 30/07/26.
////
//
//import SwiftUI
//
//@main
//struct lightingconceptApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//    }
//}
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
<<<<<<< HEAD
        LidarPhysicsSystem.registerSystem()
    }

    var body: some SwiftUI.Scene {
=======
        ECSRegistration.registerAll()
    }

    var body: some Scene {
>>>>>>> Justin
        WindowGroup {
            MainMenuView()
        }
    }
}
