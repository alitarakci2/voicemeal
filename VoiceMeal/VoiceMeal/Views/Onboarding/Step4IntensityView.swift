//
//  Step4IntensityView.swift
//  VoiceMeal
//

import SwiftUI

struct Step4IntensityView: View {
    @Binding var intensityLevel: Double

    private struct IntensityOption {
        let labelKey: String
        let emoji: String
        let value: Double
        let subtitleKey: String
        let detailKey: String
        let color: Color
    }

    private var options: [IntensityOption] {
        [
            IntensityOption(labelKey: L.easy.localized, emoji: "\u{1F7E2}", value: 0.2,
                            subtitleKey: "intensity_easy_sub".localized, detailKey: "intensity_easy_detail".localized, color: .green),
            IntensityOption(labelKey: L.medium.localized, emoji: "\u{1F7E1}", value: 0.5,
                            subtitleKey: "intensity_medium_sub".localized, detailKey: "intensity_medium_detail".localized, color: .yellow),
            IntensityOption(labelKey: L.aggressive.localized, emoji: "\u{1F534}", value: 0.8,
                            subtitleKey: "intensity_aggressive_sub".localized, detailKey: "intensity_aggressive_detail".localized, color: .red),
        ]
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("intensity_title".localized)
                .font(Theme.titleFont)

            Text("intensity_question".localized)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
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
                                Text(option.labelKey)
                                    .font(Theme.headlineFont)
                                Text(option.subtitleKey)
                                    .font(Theme.bodyFont)
                                    .foregroundStyle(Theme.textSecondary)
                                Text(option.detailKey)
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            Spacer()

                            if intensityLevel == option.value {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(Theme.titleFont)
                                    .foregroundStyle(option.color)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(intensityLevel == option.value ? option.color.opacity(0.1) : Theme.cardBackground)
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
