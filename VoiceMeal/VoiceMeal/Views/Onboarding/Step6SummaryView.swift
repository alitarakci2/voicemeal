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

    private let dayNames = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

    private let activityLabels: [String: String] = [
        "weights": "🏋️ Ağırlık",
        "running": "🏃 Koşu",
        "cycling": "🚴 Bisiklet",
        "walking": "🚶 Yürüyüş",
        "rest": "😴 Dinlenme",
    ]

    private var intensityLabel: String {
        switch intensityLevel {
        case 0.2: "🟢 Kolay"
        case 0.5: "🟡 Orta"
        case 0.8: "🔴 Agresif"
        default: "Özel"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Özet")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 12) {
                    summaryRow("İsim", value: name)
                    summaryRow("Cinsiyet", value: gender == "male" ? "Erkek" : "Kadın")
                    summaryRow("Yaş", value: "\(age)")
                    summaryRow("Boy", value: "\(Int(heightCm)) cm")
                    summaryRow("Mevcut Kilo", value: "\(String(format: "%.1f", currentWeightKg)) kg")
                    summaryRow("Hedef Kilo", value: "\(String(format: "%.1f", goalWeightKg)) kg")
                    summaryRow("Süre", value: "\(goalDays) gün")
                    summaryRow("Yoğunluk", value: intensityLabel)

                    Divider()

                    Text("Haftalık Program")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<7, id: \.self) { index in
                            HStack(alignment: .top) {
                                Text(dayNames[index])
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .leading)

                                let labels = weeklySchedule[index].compactMap { activityLabels[$0] }
                                Text(labels.joined(separator: ", "))
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
