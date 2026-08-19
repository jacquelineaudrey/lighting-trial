//
//  ExitlevelDialog.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 18/08/26.
//

import SwiftUI

struct ExitLevelDialog: View {
    var onStayTapped: () -> Void = {}
    var onExitTapped: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 35)
                .fill(Color(hex: "EFEBCF"))
                .overlay(
                    RoundedRectangle(cornerRadius: 35)
                        .stroke(Color(hex: "D6CF91"), lineWidth: 2)
                )
                .frame(width: 300, height: 240)

            VStack(alignment: .leading, spacing: 8) {
                Text("Kembali ke menu?")
                    .font(.system(size: 17))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "313131"))

                Text("Kamu bisa bermain lagi kapan saja.")
                    .font(.system(size: 17))
                    .fontWeight(.regular)
                    .foregroundColor(Color(hex: "313131"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 256, height: 76, alignment: .topLeading)
            .padding(.top, 24)

            VStack(spacing: 12) {
                Button(action: onStayTapped) {
                    Text("Tetap Main")
                        .font(.system(size: 17))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 272, height: 52)
                        .background(
                            Capsule()
                                .fill(Color(hex: "9FA60C"))
                        )
                }

                Button(action: onExitTapped) {
                    Label("Kembali ke Menu", systemImage: "house.fill")
                        .font(.system(size: 17))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "9FA60C"))
                        .frame(width: 272, height: 52)
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "9FA60C"), lineWidth: 2)
                        )
                }
            }
            .padding(.top, 115) // distance from dialog top to button group — adjust as needed
        }
    }
}

#Preview(traits: .landscapeLeft) {
    ExitLevelDialog()
}
