//
//  Step5ScheduleView.swift
//  VoiceMeal
//

import SwiftUI

struct Step5ScheduleView: View {
    @Binding var weeklySchedule: [[String]]
    var isObserveMode: Bool = false

    private enum ActivityLevel: String, CaseIterable {
        case sedentary, lightly, moderately, very

        var titleKey: String {
            switch self {
            case .sedentary:   return L.observeActivitySedentaryTitle
            case .lightly:     return L.observeActivityLightlyTitle
            case .moderately:  return L.observeActivityModeratelyTitle
            case .very:        return L.observeActivityVeryTitle
            }
        }

        var descKey: String {
            switch self {
            case .sedentary:   return L.observeActivitySedentaryDesc
            case .lightly:     return L.observeActivityLightlyDesc
            case .moderately:  return L.observeActivityModeratelyDesc
            case .very:        return L.observeActivityVeryDesc
            }
        }

        var schedule: [[String]] {
            switch self {
            case .sedentary:
                return [["rest"], ["rest"], ["rest"], ["rest"], ["rest"], ["rest"], ["rest"]]
            case .lightly:
                return [["walking"], ["rest"], ["walking"], ["rest"], ["rest"], ["walking"], ["rest"]]
            case .moderately:
                return [["weights"], ["walking"], ["running"], ["rest"], ["weights"], ["walking"], ["rest"]]
            case .very:
                return [["weights", "running"], ["running"], ["weights"], ["cycling", "walking"], ["weights"], ["running"], ["rest"]]
            }
        }
    }

    @State private var selectedLevel: ActivityLevel = .lightly

    private var dayNames: [String] {
        ["day_mon_short".localized, "day_tue_short".localized, "day_wed_short".localized,
         "day_thu_short".localized, "day_fri_short".localized, "day_sat_short".localized,
         "day_sun_short".localized]
    }

    private struct Activity {
        let key: String
        let emoji: String
        let label: String
    }

    private var activities: [Activity] {
        [
            Activity(key: "weights", emoji: "\u{1F3CB}\u{FE0F}", label: L.weights.localized),
            Activity(key: "running", emoji: "\u{1F3C3}", label: L.running.localized),
            Activity(key: "cycling", emoji: "\u{1F6B4}", label: L.cycling.localized),
            Activity(key: "walking", emoji: "\u{1F6B6}", label: L.walking.localized),
            Activity(key: "rest", emoji: "\u{1F634}", label: L.rest.localized),
        ]
    }

    private struct Template {
        let name: String
        let schedule: [[String]]
    }

    private var templates: [Template] {
        [
            Template(name: "template_beginner".localized, schedule: [["walking"], ["rest"], ["walking"], ["rest"], ["walking"], ["rest"], ["rest"]]),
            Template(name: L.medium.localized, schedule: [["weights"], ["rest"], ["running"], ["weights", "walking"], ["rest"], ["cycling"], ["rest"]]),
            Template(name: "template_advanced".localized, schedule: [["weights", "running"], ["running"], ["weights"], ["cycling", "walking"], ["weights"], ["rest"], ["rest"]]),
        ]
    }

    var body: some View {
        if isObserveMode {
            observeBody
        } else {
            goalBody
        }
    }

    private var observeBody: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(L.observeActivityTitle.localized)
                    .font(Theme.titleFont)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Button {
                            selectedLevel = level
                            weeklySchedule = level.schedule
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(level.titleKey.localized)
                                        .font(Theme.bodyFont)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    Text(level.descKey.localized)
                                        .font(Theme.captionFont)
                                        .foregroundStyle(Theme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: selectedLevel == level
                                    ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedLevel == level
                                        ? Theme.accent : Theme.textTertiary)
                                    .font(.system(size: 22))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selectedLevel == level
                                    ? Theme.accent.opacity(0.1)
                                    : Theme.cardBackground
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedLevel == level ? Theme.accent : Color.clear, lineWidth: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            weeklySchedule = selectedLevel.schedule
        }
    }

    private var goalBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("schedule_title".localized)
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
            dayActivities = ["rest"]
        } else {
            dayActivities.removeAll { $0 == "rest" }

            if dayActivities.contains(key) {
                dayActivities.removeAll { $0 == key }
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
