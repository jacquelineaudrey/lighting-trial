//
//  Level4ViewModel.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 13/08/26.
//

import Foundation
import Combine
import RealityKit

enum Level4Phase: Equatable {
    case onboarding, scanningSurface, positioning, transitionTrivia, exploring, closing, review, completed
}

enum HoldRole: Equatable {
    case none, light, object
}

@MainActor
final class Level4ViewModel: ObservableObject {

    let arSceneViewModel = ARSceneViewModel()
    
    let onboardingDialog = Level4Content.onboardingDialog
    let transitionDialog = Level4Content.transitionDialog
    let closingDialog = Level4Content.closingDialog
    let reviewPoints = Level4Content.learningReviewPoints

    @Published private(set) var phase: Level4Phase = .onboarding
    @Published private(set) var onboardingIndex = 0
    @Published private(set) var transitionIndex = 0
    @Published private(set) var closingIndex = 0

    @Published private(set) var activeHoldRole: HoldRole = .none
    @Published private(set) var hasPositionedOnce = false

    private let progressStore: GameProgressStore
    weak var rootAnchor: AnchorEntity? // Must be accessible by Level4ARView
    private var hasPlacedScene = false

    init(progressStore: GameProgressStore? = nil) {
        self.progressStore = progressStore ?? GameProgressStore.shared
        
        arSceneViewModel.directManipulationRotatesOnly = true
        arSceneViewModel.usesRealisticEnvironmentLighting = false
        arSceneViewModel.updateSelectedObject { object in
            object.type = .cube
            object.importedModel = nil
        }
    }

    func setupLevel(in anchor: AnchorEntity) {
        self.rootAnchor = anchor
    }

    func startScanning() {
        if phase == .onboarding && isLastOnboardingLine {
            phase = .scanningSurface
        }
    }
    
    func placeSceneIfNeeded() {
        guard !hasPlacedScene else { return }
        hasPlacedScene = true
        
        arSceneViewModel.isObjectPlaced = true
        finishScanning()
    }

    // MARK: - Phase Progression
    
    var currentOnboardingLine: DialogLine { onboardingDialog[onboardingIndex] }
    var isLastOnboardingLine: Bool { onboardingIndex == onboardingDialog.count - 1 }

    func advanceOnboarding() {
        if isLastOnboardingLine { phase = .scanningSurface } else { onboardingIndex += 1 }
    }

    func finishScanning() {
        guard phase == .scanningSurface else { return }
        phase = .positioning
    }

    // MARK: - Native ECS Hold Mechanics
    
    func setHold(role: HoldRole, isHeld: Bool) {
        guard phase == .positioning || phase == .exploring else { return }
        
        if isHeld {
            activeHoldRole = role
            arSceneViewModel.interactionMode = role == .light ? .moveLight : .moveObject
        } else {
            activeHoldRole = .none
            hasPositionedOnce = true
        }
    }
    
    func syncHoldStatesToECS(rootAnchor: AnchorEntity) {
        if let lightEntity = SceneObjectSystem.entityWithObjectID(arSceneViewModel.selectedLightID, in: rootAnchor) {
            var comp = lightEntity.components[HoldInteractionComponent.self] ?? HoldInteractionComponent(lockYAxis: false)
            comp.isHeld = activeHoldRole == .light
            lightEntity.components.set(comp)
        }
        
        if let objectEntity = SceneObjectSystem.entityWithObjectID(arSceneViewModel.selectedObjectID, in: rootAnchor) {
            var comp = objectEntity.components[HoldInteractionComponent.self] ?? HoldInteractionComponent(lockYAxis: true)
            comp.isHeld = activeHoldRole == .object
            objectEntity.components.set(comp)
        }
    }
    
    func syncPositionsFromECS(scene: RealityKit.Scene) {
        guard activeHoldRole != .none else { return }
        // Future sync logic here if needed
    }

    // MARK: - Transition & Closing
    
    func proceedToTransitionTrivia() {
        guard phase == .positioning, hasPositionedOnce else { return }
        phase = .transitionTrivia; transitionIndex = 0
    }

    var currentTransitionLine: DialogLine { transitionDialog[transitionIndex] }
    var isLastTransitionLine: Bool { transitionIndex == transitionDialog.count - 1 }
    func advanceTransition() { if isLastTransitionLine { phase = .exploring } else { transitionIndex += 1 } }

    func finishExploring() { guard phase == .exploring else { return }; phase = .closing; closingIndex = 0 }
    
    var currentClosingLine: DialogLine { closingDialog[closingIndex] }
    var isLastClosingLine: Bool { closingIndex == closingDialog.count - 1 }
    func advanceClosing() { if isLastClosingLine { phase = .review } else { closingIndex += 1 } }

    func finishReview() { guard phase == .review else { return }; phase = .completed; progressStore.markLevelCompleted(Level4Content.levelID) }
}
