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

    @State private var heightText = ""
    @State private var weightText = ""
    @FocusState private var heightFocused: Bool
    @FocusState private var weightFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("body_metrics".localized)
                    .font(Theme.titleFont)

                // Gender
                HStack(spacing: 16) {
                    genderCard(label: L.male.localized, value: "male", icon: "figure.stand")
                    genderCard(label: L.female.localized, value: "female", icon: "figure.stand.dress")
                }

                // Age
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(L.age.localized): \(age)")
                        .font(Theme.headlineFont)
                    Picker(L.age.localized, selection: $age) {
                        ForEach(15...80, id: \.self) { y in
                            Text("\(y)").tag(y)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                // Height
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(L.height.localized): \(Int(heightCm)) cm")
                        .font(Theme.headlineFont)
                    HStack {
                        Slider(value: $heightCm, in: 140...220, step: 1)
                            .tint(Theme.accent)
                            .onChange(of: heightCm) { _, newVal in
                                if !heightFocused {
                                    heightText = "\(Int(newVal))"
                                }
                            }
                        TextField("", text: $heightText)
                            .keyboardType(.numberPad)
                            .frame(width: 64)
                            .padding(8)
                            .background(Color(hex: "2A2A38"))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .focused($heightFocused)
                            .onChange(of: heightFocused) { _, focused in
                                if !focused {
                                    validateHeight()
                                }
                            }
                    }
                }

                // Weight
                VStack(alignment: .leading, spacing: 8) {
                    Text("\("current_weight_label".localized): \(String(format: "%.1f", currentWeightKg)) kg")
                        .font(Theme.headlineFont)
                    HStack {
                        Slider(value: $currentWeightKg, in: 40...200, step: 0.1)
                            .tint(Theme.accent)
                            .onChange(of: currentWeightKg) { _, newVal in
                                if !weightFocused {
                                    weightText = String(format: "%.1f", newVal)
                                }
                            }
                        TextField("", text: $weightText)
                            .keyboardType(.decimalPad)
                            .frame(width: 64)
                            .padding(8)
                            .background(Color(hex: "2A2A38"))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .focused($weightFocused)
                            .onChange(of: weightFocused) { _, focused in
                                if !focused {
                                    validateWeight()
                                }
                            }
                    }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            heightText = "\(Int(heightCm))"
            weightText = String(format: "%.1f", currentWeightKg)
        }
    }

    // MARK: - Validation

    private func validateHeight() {
        if let val = Double(heightText) {
            let clamped = min(220, max(140, val)).rounded()
            heightCm = clamped
            heightText = "\(Int(clamped))"
        } else {
            heightText = "\(Int(heightCm))"
        }
    }

    private func validateWeight() {
        let cleaned = weightText.replacingOccurrences(of: ",", with: ".")
        if let val = Double(cleaned) {
            let clamped = min(200, max(40, val))
            currentWeightKg = (clamped * 10).rounded() / 10
            weightText = String(format: "%.1f", currentWeightKg)
        } else {
            weightText = String(format: "%.1f", currentWeightKg)
        }
    }

    // MARK: - UI

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
