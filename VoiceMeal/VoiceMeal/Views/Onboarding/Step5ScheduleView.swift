//
//  Step5ScheduleView.swift
//  VoiceMeal
//

import SwiftUI

struct Step5ScheduleView: View {
    @Binding var weeklySchedule: [String]

    private let dayNames = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

    private struct Activity {
        let key: String
        let emoji: String
        let label: String
    }

    private let activities: [Activity] = [
        Activity(key: "weights", emoji: "🏋️", label: "Ağırlık"),
        Activity(key: "running", emoji: "🏃", label: "Koşu"),
        Activity(key: "cycling", emoji: "🚴", label: "Bisiklet"),
        Activity(key: "walking", emoji: "🚶", label: "Yürüyüş"),
        Activity(key: "rest", emoji: "😴", label: "Dinlenme"),
    ]

    private struct Template {
        let name: String
        let schedule: [String]
    }

    private let templates: [Template] = [
        Template(name: "Başlangıç", schedule: ["walking", "rest", "walking", "rest", "walking", "rest", "rest"]),
        Template(name: "Orta", schedule: ["weights", "rest", "running", "weights", "rest", "cycling", "rest"]),
        Template(name: "İleri", schedule: ["weights", "running", "weights", "cycling", "weights", "rest", "rest"]),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Haftalık Program")
                    .font(.title2)
                    .fontWeight(.bold)

                // Templates
                HStack(spacing: 12) {
                    ForEach(templates, id: \.name) { template in
                        Button {
                            weeklySchedule = template.schedule
                        } label: {
                            Text(template.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(weeklySchedule == template.schedule ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(weeklySchedule == template.schedule ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Per-day selection
                VStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dayNames[index])
                                .font(.headline)

                            HStack(spacing: 8) {
                                ForEach(activities, id: \.key) { activity in
                                    Button {
                                        weeklySchedule[index] = activity.key
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(activity.emoji)
                                                .font(.title3)
                                            Text(activity.label)
                                                .font(.caption2)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(weeklySchedule[index] == activity.key ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(weeklySchedule[index] == activity.key ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}
