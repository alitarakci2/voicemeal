//
//  Step4IntensityView.swift
//  VoiceMeal
//

import SwiftUI

struct Step4IntensityView: View {
    @Binding var intensityLevel: Double

    private struct IntensityOption {
        let label: String
        let emoji: String
        let value: Double
        let subtitle: String
        let detail: String
        let color: Color
    }

    private let options: [IntensityOption] = [
        IntensityOption(label: "Kolay", emoji: "🟢", value: 0.2,
                        subtitle: "Stressiz, sürdürülebilir", detail: "~%10 kalori açığı", color: .green),
        IntensityOption(label: "Orta", emoji: "🟡", value: 0.5,
                        subtitle: "Dengeli ilerleme", detail: "~%20 kalori açığı", color: .yellow),
        IntensityOption(label: "Agresif", emoji: "🔴", value: 0.8,
                        subtitle: "Hızlı sonuç, disiplin gerektirir", detail: "~%25-30 kalori açığı", color: .red),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("Yoğunluk")
                .font(.title2)
                .fontWeight(.bold)

            Text("Kalori açığını ne kadar agresif tutmak istiyorsun?")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                ForEach(options, id: \.value) { option in
                    Button {
                        intensityLevel = option.value
                    } label: {
                        HStack(spacing: 16) {
                            Text(option.emoji)
                                .font(.system(size: 32))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.label)
                                    .font(.headline)
                                Text(option.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(option.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if intensityLevel == option.value {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(option.color)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(intensityLevel == option.value ? option.color.opacity(0.1) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(intensityLevel == option.value ? option.color : Color.clear, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding()
    }
}
