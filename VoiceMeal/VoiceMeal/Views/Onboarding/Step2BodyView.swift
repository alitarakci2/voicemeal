//
//  Step2BodyView.swift
//  VoiceMeal
//

import SwiftUI

struct Step2BodyView: View {
    @Binding var gender: String
    @Binding var age: Int
    @Binding var heightCm: Double
    @Binding var currentWeightKg: Double

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Vücut Bilgilerin")
                    .font(Theme.titleFont)

                // Gender
                HStack(spacing: 16) {
                    genderCard(label: "Erkek", value: "male", icon: "figure.stand")
                    genderCard(label: "Kadın", value: "female", icon: "figure.stand.dress")
                }

                // Age
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yaş: \(age)")
                        .font(Theme.headlineFont)
                    Picker("Yaş", selection: $age) {
                        ForEach(15...80, id: \.self) { y in
                            Text("\(y)").tag(y)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                // Height
                VStack(alignment: .leading, spacing: 8) {
                    Text("Boy: \(Int(heightCm)) cm")
                        .font(Theme.headlineFont)
                    Slider(value: $heightCm, in: 140...220, step: 1)
                }

                // Weight
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kilo: \(String(format: "%.1f", currentWeightKg)) kg")
                        .font(Theme.headlineFont)
                    Slider(value: $currentWeightKg, in: 40...200, step: 0.5)
                }
            }
            .padding()
        }
    }

    private func genderCard(label: String, value: String, icon: String) -> some View {
        Button {
            gender = value
        } label: {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                Text(label)
                    .font(Theme.headlineFont)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(gender == value ? Theme.accent.opacity(0.15) : Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(gender == value ? Theme.accent : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
