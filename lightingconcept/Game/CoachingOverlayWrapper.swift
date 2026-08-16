//
//  CoachingOverlayWrapper.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import SwiftUI
import ARKit

struct CoachingOverlayWrapper: UIViewRepresentable {
    let goal: ARCoachingOverlayView.Goal
    
    func makeUIView(context: Context) -> ARCoachingOverlayView {
        let overlay = ARCoachingOverlayView()
        overlay.goal = goal
        // In visionOS/iOS 18+ RealityView setups, you bind this to the active ARKitSession
        // If targeting iOS 17 with ARKitSession, automatic activation relies on the session running.
        overlay.activatesAutomatically = true
        return overlay
    }
    
    func updateUIView(_ uiView: ARCoachingOverlayView, context: Context) {
        uiView.goal = goal
    }
}
