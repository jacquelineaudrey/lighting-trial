//
//  lightingconceptApp.swift
//  lightingconcept
//
//  Created by Jacqueline on 30/07/26.
//

import SwiftUI

@main
struct lightingconceptApp: App {
    init() {
        ECSRegistration.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            MainMenuView()
        }
    }
}
