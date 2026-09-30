//
//  Level5GuideController.swift
//  lightingconcept
//
//  Created by Justin Hartanto Widjaja on 28/09/26.
//

import ARKit
import Combine
import RealityKit

@MainActor
final class Level5GuideController {

    private weak var arView:
        ARView?

    private var anchor:
        AnchorEntity?

    private var guide:
        Entity?

    private var speechCloud:
        Entity?

    private var displayedText:
        String?

    private var needsPlacement =
        true

    private var cameraSubscription:
        AnyCancellable?

    func setup(
        on arView:
            ARView
    ) {

        guard self.arView == nil
        else {
            return
        }

        self.arView =
            arView

        let anchor =
            AnchorEntity(
                world: .zero
            )

        anchor.name =
            "Level 5 Guide Root Anchor"

        let guide =
            Entity()

        guide.name =
            "Level 5 Guide — Lumi & Bayo"

        guide.components.set(
            Level5GuideComponent(
                basePosition:
                    .zero
            )
        )

        guide.isEnabled =
            false

        if let lumi =
            CharacterGuideFactory
                .makeCharacter(
                    asset:
                        .lumiIdle,

                    width:
                        0.30,

                    height:
                        0.44
                ) {

            lumi.name =
                "Lumi Character"

            lumi.position =
                SIMD3<Float>(
                    -0.19,
                    0,
                    0
                )

            guide.addChild(
                lumi
            )
        }

        if let bayo =
            CharacterGuideFactory
                .makeCharacter(
                    asset:
                        .bayoIdle,

                    width:
                        0.30,

                    height:
                        0.44
                ) {

            bayo.name =
                "Bayo Character"

            bayo.position =
                SIMD3<Float>(
                    0.19,
                    0,
                    0
                )

            guide.addChild(
                bayo
            )
        }

        anchor.addChild(
            guide
        )

        arView.scene.addAnchor(
            anchor
        )

        self.anchor =
            anchor

        self.guide =
            guide

        cameraSubscription =
            AnyCancellable(
                arView.scene.subscribe(
                    to:
                        SceneEvents.Update.self
                ) { [weak self, weak arView] _ in

                    guard let self else {
                        return
                    }

                    guard self.needsPlacement
                    else {

                        self.cameraSubscription?
                            .cancel()

                        self.cameraSubscription =
                            nil

                        return
                    }

                    guard let transform =
                        arView?
                            .session
                            .currentFrame?
                            .camera
                            .transform
                    else {
                        return
                    }

                    self.placeIfNeeded(
                        cameraTransform:
                            transform
                    )
                }
            )
    }

    func sync(
        text:
            String,

        isVisible:
            Bool
    ) {

        guard let guide
        else {
            return
        }

        guide.isEnabled =
            isVisible
            && !needsPlacement

        guard isVisible
        else {
            return
        }

        guard displayedText != text
        else {
            return
        }

        displayedText =
            text

        rebuildSpeechCloud(
            text:
                text,

            on:
                guide
        )
    }

    private func placeIfNeeded(
        cameraTransform:
            simd_float4x4
    ) {

        guard needsPlacement,
              let guide
        else {
            return
        }

        let cameraPosition =
            SIMD3<Float>(
                cameraTransform
                    .columns.3.x,

                cameraTransform
                    .columns.3.y,

                cameraTransform
                    .columns.3.z
            )

        let forward3D =
            -SIMD3<Float>(
                cameraTransform
                    .columns.2.x,

                0,

                cameraTransform
                    .columns.2.z
            )

        let length =
            simd_length(
                forward3D
            )

        guard length > 0.0001
        else {
            return
        }

        let forward =
            forward3D / length

        let right =
            SIMD3<Float>(
                -forward.z,
                0,
                forward.x
            )

        let position =
            cameraPosition
            + forward * 1.15
            + right * 0.44
            + SIMD3<Float>(
                0,
                -0.42,
                0
            )

        guide.position =
            position

        guide.components.set(
            Level5GuideComponent(
                basePosition:
                    position
            )
        )

        needsPlacement =
            false

        guide.isEnabled =
            true
    }

    private func rebuildSpeechCloud(
        text:
            String,

        on guide:
            Entity
    ) {

        speechCloud?
            .removeFromParent()

        let cloud =
            CharacterGuideFactory
                .makeSpeechCloud(
                    text:
                        text,

                    width:
                        0.90,

                    height:
                        0.36,

                    fontSize:
                        0.035,

                    textHorizontalInset:
                        0.10,

                    textVerticalInset:
                        0.09
                )

        cloud.name =
            "Level 5 Speech Cloud"

        cloud.position =
            SIMD3<Float>(
                0,
                0.39,
                0
            )

        guide.addChild(
            cloud
        )

        speechCloud =
            cloud
    }
}
