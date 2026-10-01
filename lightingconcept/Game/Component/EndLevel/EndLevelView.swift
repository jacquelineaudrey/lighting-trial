//
//  EndLevelView.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 17/08/26.
//

import SwiftUI

struct EndLevelView: View {
    let data: EndLevelModel
    let onBack: () -> Void
    let onNext: (() -> Void)?
    let backTitle: String
    let nextTitle: String?
    let nextSystemImage: String?

    init(
        data: EndLevelModel,
        onBack: @escaping () -> Void,
        onNext: (() -> Void)? = nil,
        backTitle: String = "Pilih Level",
        nextTitle: String? = nil,
        nextSystemImage: String? = nil
    ) {
        self.data = data
        self.onBack = onBack
        self.onNext = onNext
        self.backTitle = backTitle
        self.nextTitle = nextTitle
        self.nextSystemImage = nextSystemImage
    }

    var body: some View {
        GeometryReader { proxy in
            let designSize = CGSize(width: 1000, height: 820)
            let availableWidth = max(proxy.size.width - 40, 1)
            let availableHeight = max(proxy.size.height - 32, 1)
            let scale = min(
                availableWidth / designSize.width,
                availableHeight / designSize.height,
                1
            )

            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()

                ZStack {
                    Image("containerWood")
                        .resizable()
                        .scaledToFit()
                        .frame(width: designSize.width, height: designSize.height)

                    ZStack {
                        Image("ribbonBlue")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 400)

                        Text("LEVEL \(data.levelNumber)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(y: -7)
                    }
                    .offset(y: -180)

                    Text(data.message)
                        .font(.system(size: 28, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 24)
                        .frame(width: 600, height: 138)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(hex: "C98928"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color(hex: "7E520E"), lineWidth: 2)
                        )
                        .offset(y: 60)

                    HStack {
                        LevelActionButton(
                            title: backTitle,
                            role: backButtonRole,
                            action: onBack
                        )

                        Spacer()

                        LevelActionButton(
                            title: nextTitle ?? (onNext == nil ? "Selesai" : "Selanjutnya"),
                            action: finishLevel
                        )
                    }
                    .frame(width: 580)
                    .offset(y: 210)

                    Image(data.mascotImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 250)
                        .offset(x: 390, y: 165)
                }
                .frame(width: designSize.width, height: designSize.height)
                .scaleEffect(scale)
                .offset(y: -32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func finishLevel() {
        if let onNext {
            onNext()
        } else {
            onBack()
        }
    }

    private var isMenuBackButton: Bool {
        backTitle.localizedCaseInsensitiveContains("menu")
    }

//    private var backSystemImage: String {
//        isMenuBackButton ? "house.fill" : "square.grid.2x2"
//    }

    private var backButtonRole: LevelActionButton.Role {
        isMenuBackButton ? .menu : .secondary
    }
}

/// Shared responsive entry point for every level completion screen.
/// It keeps level flows independent from the base card's sizing implementation.
struct ResponsiveEndLevelView: View {
    let data: EndLevelModel
    let onBack: () -> Void
    let onNext: (() -> Void)?
    let backTitle: String
    let nextTitle: String?
    let nextSystemImage: String?

    init(
        data: EndLevelModel,
        onBack: @escaping () -> Void,
        onNext: (() -> Void)? = nil,
        backTitle: String = "Pilih Level",
        nextTitle: String? = nil,
        nextSystemImage: String? = nil
    ) {
        self.data = data
        self.onBack = onBack
        self.onNext = onNext
        self.backTitle = backTitle
        self.nextTitle = nextTitle
        self.nextSystemImage = nextSystemImage
    }

    var body: some View {
        EndLevelView(
            data: data,
            onBack: onBack,
            onNext: onNext,
            backTitle: backTitle,
            nextTitle: nextTitle,
            nextSystemImage: nextSystemImage
        )
    }
}

#Preview(traits: .landscapeLeft) {
    EndLevelView(data: EndLevelModel(
        id: 1,
        levelNumber: 1,
        message: "Kamu hebat!\nSekarang kamu bisa ke level berikutnya!",
        mascotImageName: "lumiIdle"
    ), onBack: { }, onNext: { })
}
