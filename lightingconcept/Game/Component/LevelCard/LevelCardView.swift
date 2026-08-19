//
//  LevelCard.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 16/08/26.
//

import SwiftUI

struct LevelCardView: View {
    let level: Level
    var onBack: () -> Void = {}
    var onStart: () -> Void = {}

    var body: some View {
        ZStack {
            Image("container")

            VStack(spacing: 50) {

                ZStack {
                    Image("ribbonRed")
                    Text("LEVEL \(level.levelNumber)")
                        .font(.system(size: 36))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(x: 0, y: -7)
                }

                Text(level.title)
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "313131"))
                    .multilineTextAlignment(.center)

                Text(level.subtitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "313131"))
                    .frame(width: 350, height: 130)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color(hex: "D6CF91").opacity(0.25))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color(hex: "D6CF91"), lineWidth: 2)
                    )

                Button(action: onStart) {
                    ZStack {
                        Image("button")
                        Text("MULAI")
                            .font(.system(size: 36))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .offset(x: 0, y: -3)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onBack) {
                Image(systemName: "multiply")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: "21415D"))
                    .frame(width: 56, height: 56)
                    .background(Color(hex: "FFF4C7"), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color(hex: "D6A83E"), lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel("Kembali")
            .accessibilityHint("Menutup kartu level dan kembali ke peta.")
            .padding(.top, 38)
            .padding(.trailing, 38)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    LevelCardView(level: Level(id: 1, levelNumber: 1, title: "Bentuk dan\nTekstur", subtitle: "Yuk, lihat perbedaan\nbayangannya!"), onStart: {
        print("Tapped MULAI")
    })
}
