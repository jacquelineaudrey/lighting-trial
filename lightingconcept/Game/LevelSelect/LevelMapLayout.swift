//
//  LevelMapLayout.swift
//  lightingconcept
//

import SwiftUI

enum LevelMapLayout {
    static let canvasSize = CGSize(width: 1_210, height: 834)
    static let previousOpenArtworkHeight: CGFloat = 259
    static let openArtworkSize = CGSize(width: 355, height: 355)
    static let openPositionOffset = CGSize(
        width: 0,
        height: (previousOpenArtworkHeight - openArtworkSize.height) * 0.5
    )
    static func lockedArtworkSize(for levelID: Int) -> CGSize {
        switch levelID {
        case 3, 4, 5:
            CGSize(width: 201, height: 169)
        default:
            CGSize(width: 201, height: 168)
        }
    }
    static let lockedPositionOffset = openPositionOffset
    static let buttonTouchSize = CGSize(width: 225, height: 194)
    static let backButtonCenter = CGPoint(x: 31, y: 54)

    static func scale(toFill containerSize: CGSize) -> CGFloat {
        max(containerSize.width / canvasSize.width,
            containerSize.height / canvasSize.height)
    }

    static func position(for levelID: Int, isOpen: Bool) -> CGPoint {
        let basePosition: CGPoint = switch levelID {
        case 1: CGPoint(x: 370, y: 570)
        case 2: CGPoint(x: 405, y: 365)
        case 3: CGPoint(x: 700, y: 555)
        case 4: CGPoint(x: 605, y: 250)
        case 5: CGPoint(x: 895, y: 400)
        case 6: CGPoint(x: 850, y: 190)
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
