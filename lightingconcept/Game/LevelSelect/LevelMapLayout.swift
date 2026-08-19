//
//  LevelMapLayout.swift
//  lightingconcept
//

import SwiftUI

enum LevelMapLayout {
    static let canvasSize = CGSize(width: 1_210, height: 834)
    static let previousOpenArtworkHeight: CGFloat = 259
    static let openArtworkSize = CGSize(width: 300, height: 300)
    static let openPositionOffset = CGSize(
        width: 0,
        height: (previousOpenArtworkHeight - openArtworkSize.height) * 0.5
    )
    static let lockedArtworkOriginalSize = CGSize(width: 325, height: 274)
    static let lockedArtworkSize = CGSize(
        width: lockedArtworkOriginalSize.width * 0.5,
        height: lockedArtworkOriginalSize.height * 0.5
    )
    static let lockedPositionOffset = openPositionOffset
    static let buttonTouchSize = CGSize(width: 225, height: 194)
    static let backButtonCenter = CGPoint(x: 31, y: 54)

    static func scale(toFill containerSize: CGSize) -> CGFloat {
        max(containerSize.width / canvasSize.width,
            containerSize.height / canvasSize.height)
    }

    static func position(for levelID: Int, isOpen: Bool) -> CGPoint {
        let basePosition: CGPoint = switch levelID {
        case 1: CGPoint(x: 384, y: 522)
        case 2: CGPoint(x: 422, y: 323)
        case 3: CGPoint(x: 726, y: 513)
        case 4: CGPoint(x: 625, y: 197)
        case 5: CGPoint(x: 924, y: 348)
        case 6: CGPoint(x: 854, y: 155)
        default: .zero
        }

        let positionOffset = isOpen ? openPositionOffset : lockedPositionOffset
        return CGPoint(
            x: basePosition.x + positionOffset.width,
            y: basePosition.y + positionOffset.height
        )
    }

    static func artwork(for levelID: Int, isOpen: Bool) -> ImageResource {
        switch (levelID, isOpen) {
        case (1, true): .Levels.one
        case (1, false): .Levels.oneLock
        case (2, true): .Levels.two
        case (2, false): .Levels.twoLock
        case (3, true): .Levels.three
        case (3, false): .Levels.threeLock
        case (4, true): .Levels.four
        case (4, false): .Levels.fourLock
        case (5, true): .Levels.five
        case (5, false): .Levels.fiveLock
        case (6, true): .Levels.six
        default: .Levels.sixLock
        }
    }
}
