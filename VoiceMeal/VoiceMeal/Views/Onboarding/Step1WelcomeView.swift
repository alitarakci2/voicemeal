//
//  Step1WelcomeView.swift
//  VoiceMeal
//

import SwiftUI

struct Step1WelcomeView: View {
    @Binding var name: String

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            Text("Hoş Geldin!")
                .font(Theme.largeTitleFont)

            Text("Sesini kullanarak yemeklerini takip et")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            TextField("Adın", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(Theme.titleFont)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}
