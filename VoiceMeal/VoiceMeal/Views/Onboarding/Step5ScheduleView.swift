//
//  Step5ScheduleView.swift
//  VoiceMeal
//

import SwiftUI

struct Step5ScheduleView: View {
    @Binding var weeklySchedule: [[String]]

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
        let schedule: [[String]]
    }

    private let templates: [Template] = [
        Template(name: "Başlangıç", schedule: [["walking"], ["rest"], ["walking"], ["rest"], ["walking"], ["rest"], ["rest"]]),
        Template(name: "Orta", schedule: [["weights"], ["rest"], ["running"], ["weights", "walking"], ["rest"], ["cycling"], ["rest"]]),
        Template(name: "İleri", schedule: [["weights", "running"], ["running"], ["weights"], ["cycling", "walking"], ["weights"], ["rest"], ["rest"]]),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Haftalık Program")
                    .font(Theme.titleFont)

                // Templates
                HStack(spacing: 12) {
                    ForEach(templates, id: \.name) { template in
                        Button {
                            weeklySchedule = template.schedule
                        } label: {
                            Text(template.name)
                                .font(Theme.bodyFont)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(weeklySchedule == template.schedule ? Theme.accent.opacity(0.15) : Theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(weeklySchedule == template.schedule ? Theme.accent : Color.clear, lineWidth: 2)
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
                                .font(Theme.headlineFont)

                            HStack(spacing: 8) {
                                ForEach(activities, id: \.key) { activity in
                                    let isSelected = weeklySchedule[index].contains(activity.key)
                                    Button {
                                        toggleActivity(activity.key, forDay: index)
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(activity.emoji)
                                                .font(Theme.titleFont)
                                            Text(activity.label)
                                                .font(Theme.microFont)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Theme.accent.opacity(0.2) : Theme.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
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

    private func toggleActivity(_ key: String, forDay index: Int) {
        var dayActivities = weeklySchedule[index]

        if key == "rest" {
            // Rest clears everything else
            dayActivities = ["rest"]
        } else {
            // Remove rest if selecting an activity
            dayActivities.removeAll { $0 == "rest" }

            if dayActivities.contains(key) {
                dayActivities.removeAll { $0 == key }
                // If nothing left, default to rest
                if dayActivities.isEmpty {
                    dayActivities = ["rest"]
                }
            } else {
                dayActivities.append(key)
            }
        }

        weeklySchedule[index] = dayActivities
    }
}
