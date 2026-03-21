//
//  Step6SummaryView.swift
//  VoiceMeal
//

import SwiftUI

struct Step6SummaryView: View {
    let name: String
    let gender: String
    let age: Int
    let heightCm: Double
    let currentWeightKg: Double
    let goalWeightKg: Double
    let goalDays: Int
    let intensityLevel: Double
    let weeklySchedule: [[String]]

    private var dayNames: [String] {
        ["day_mon_short".localized, "day_tue_short".localized, "day_wed_short".localized,
         "day_thu_short".localized, "day_fri_short".localized, "day_sat_short".localized,
         "day_sun_short".localized]
    }

    private var activityLabels: [String: String] {
        [
            "weights": "\u{1F3CB}\u{FE0F} \(L.weights.localized)",
            "running": "\u{1F3C3} \(L.running.localized)",
            "cycling": "\u{1F6B4} \(L.cycling.localized)",
            "walking": "\u{1F6B6} \(L.walking.localized)",
            "rest": "\u{1F634} \(L.rest.localized)",
        ]
    }

    private var intensityLabel: String {
        switch intensityLevel {
        case 0.2: "\u{1F7E2} \(L.easy.localized)"
        case 0.5: "\u{1F7E1} \(L.medium.localized)"
        case 0.8: "\u{1F534} \(L.aggressive.localized)"
        default: L.medium.localized
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(L.summary.localized)
                    .font(Theme.titleFont)

                VStack(alignment: .leading, spacing: 12) {
                    summaryRow(L.enterName.localized, value: name)
                    summaryRow(L.gender.localized, value: gender == "male" ? L.male.localized : L.female.localized)
                    summaryRow(L.age.localized, value: "\(age)")
                    summaryRow(L.height.localized, value: "\(Int(heightCm)) cm")
                    summaryRow("current_weight_label".localized, value: "\(String(format: "%.2f", currentWeightKg)) kg")
                    summaryRow("goal_weight_label".localized, value: "\(String(format: "%.2f", goalWeightKg)) kg")
                    summaryRow(L.duration.localized, value: "\(goalDays) \("day_suffix".localized)")
                    summaryRow(L.intensity.localized, value: intensityLabel)

                    Divider()

                    Text("schedule_title".localized)
                        .font(Theme.headlineFont)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<7, id: \.self) { index in
                            HStack(alignment: .top) {
                                Text(dayNames[index])
                                    .font(Theme.bodyFont)
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 30, alignment: .leading)

                                let labels = weeklySchedule[index].compactMap { activityLabels[$0] }
                                Text(labels.joined(separator: ", "))
                                    .font(Theme.bodyFont)
                            }
                        }
                    }
                }
                .padding()
                .themeCard()
            }
            .padding()
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
