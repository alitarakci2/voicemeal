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

            Text(L.welcome.localized)
                .font(Theme.largeTitleFont)

            Text("voice_intro".localized)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            TextField(L.enterName.localized, text: $name)
                .textFieldStyle(.roundedBorder)
                .font(Theme.titleFont)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}
