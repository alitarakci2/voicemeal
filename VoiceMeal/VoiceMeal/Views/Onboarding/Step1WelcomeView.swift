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
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sesini kullanarak yemeklerini takip et")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Adın", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}
