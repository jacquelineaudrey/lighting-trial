//
//  L.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 28/09/26.
//

import ARKit
import Combine
import RealityKit
import SwiftUI

struct Level5ARContainerView:
    UIViewRepresentable {

    let viewModel:
        Level5ViewModel

    func makeCoordinator()
        -> Coordinator {

        Coordinator(
            viewModel:
                viewModel
        )
    }

    func makeUIView(
        context: Context
    ) -> ARView {

        let arView =
            ARView(
                frame: .zero
            )

        context.coordinator
            .configure(
                arView:
                    arView
            )

        return arView
    }

    func updateUIView(
        _ uiView: ARView,
        context: Context
    ) {
        context.coordinator
            .requestSceneSynchronization()
    }

    @MainActor
    final class Coordinator {

        private let viewModel:
            Level5ViewModel

        private let arCoordinator:
            ARSceneCoordinator

        private let guideController =
            Level5GuideController()

        private weak var arView:
            ARView?

        private var sceneUpdateSubscription:
            (any Cancellable)?

        init(
            viewModel:
                Level5ViewModel
        ) {

            self.viewModel =
                viewModel

            self.arCoordinator =
                ARSceneCoordinator(
                    viewModel:
                        viewModel
                            .arSceneViewModel,

                    gesturePolicy:
                        .full,

                    lessonECSMode:
                        .none,

                    telemetryDelegate:
                        viewModel
                )
        }

        func configure(
            arView:
                ARView
        ) {

            self.arView =
                arView

            Level5GuideSystem
                .registerSystem()

            arCoordinator
                .configure(
                    arView:
                        arView
                )

            guideController
                .setup(
                    on:
                        arView
                )

            sceneUpdateSubscription =
                arView.scene.subscribe(
                    to:
                        SceneEvents.Update.self
                ) { [weak self] _ in

                    guard let self else {
                        return
                    }

                    self.guideController
                        .sync(
                            text:
                                self.viewModel
                                    .guideText,

                            isVisible:
                                self.viewModel
                                    .showsGuide
                        )
                }
        }

        func requestSceneSynchronization() {

            arCoordinator
                .requestSceneSynchronization()

            guideController
                .sync(
                    text:
                        viewModel.guideText,

                    isVisible:
                        viewModel.showsGuide
                )
        }
    }
}
