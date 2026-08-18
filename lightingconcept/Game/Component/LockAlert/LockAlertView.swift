//
//  LockAlertView.swift
//  lightingconcept
//
//  Created by Rayhan Nanda on 18/08/26.
//

import SwiftUI

struct LockAlertView: View {
    let data: LockAlertData
    var onBackTapped: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 35)
                .fill(Color(hex: "EFEBCF"))
                .overlay(
                    RoundedRectangle(cornerRadius: 35)
                        .stroke(Color(hex: "D6CF91"), lineWidth: 2)
                )
                .frame(width: 355, height: 184)

            VStack(alignment: .leading, spacing: 10) {
                Text(data.title)
                    .font(.system(size: 17))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "313131"))

                Text(data.subtitle)
                    .font(.system(size: 17))
                    .fontWeight(.regular)
                    .foregroundColor(Color(hex: "313131"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 311, alignment: .topLeading)
            .padding(.top, 24)
            .padding(.horizontal, 22)

            Button(action: onBackTapped) {
                Text("Kembali")
                    .font(.system(size: 17))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 327, height: 48)
                    .background(
                        Capsule()
                            .fill(Color(hex: "9FA60C"))
                    )
            }
            .padding(.top, 120) // distance from dialog top to button — adjust as needed
        }
    }
}

#Preview(traits: .landscapeLeft) {
    LockAlertView(data: LockAlertData(
        id: 1,
        title: "Simulasi belum terbuka!",
        subtitle: "Ayo kita mulai belajar dulu untuk membuka bagian ini!"
    ))
}
