//
//  OnboardingContainerView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var onboardingComplete: Bool

    @State private var step = 1
    private let totalSteps = 6

    // Step 1
    @State private var name = ""
    // Step 2
    @State private var gender = "male"
    @State private var age = 25
    @State private var heightCm = 175.0
    @State private var currentWeightKg = 80.0
    // Step 3
    @State private var goalWeightKg = 75.0
    @State private var goalDays = 90
    // Step 4
    @State private var intensityLevel = 0.5
    // Step 5
    @State private var weeklySchedule = ["walking", "rest", "walking", "rest", "walking", "rest", "rest"]

    private var canProceed: Bool {
        switch step {
        case 1: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: !gender.isEmpty
        default: true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(step), total: Double(totalSteps))
                .padding(.horizontal)
                .padding(.top, 8)

            Text("\(step) / \(totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            // Content
            Group {
                switch step {
                case 1:
                    Step1WelcomeView(name: $name)
                case 2:
                    Step2BodyView(gender: $gender, age: $age, heightCm: $heightCm, currentWeightKg: $currentWeightKg)
                case 3:
                    Step3GoalView(currentWeightKg: currentWeightKg, goalWeightKg: $goalWeightKg, goalDays: $goalDays)
                case 4:
                    Step4IntensityView(intensityLevel: $intensityLevel)
                case 5:
                    Step5ScheduleView(weeklySchedule: $weeklySchedule)
                case 6:
                    Step6SummaryView(
                        name: name, gender: gender, age: age, heightCm: heightCm,
                        currentWeightKg: currentWeightKg, goalWeightKg: goalWeightKg,
                        goalDays: goalDays, intensityLevel: intensityLevel,
                        weeklySchedule: weeklySchedule
                    )
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: step)

            // Navigation buttons
            HStack(spacing: 16) {
                if step > 1 {
                    Button {
                        step -= 1
                    } label: {
                        Text("Geri")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    if step < totalSteps {
                        step += 1
                    } else {
                        saveProfile()
                    }
                } label: {
                    Text(step == totalSteps ? "Başla" : "İleri")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            }
            .padding()
        }
    }

    private func saveProfile() {
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            gender: gender,
            age: age,
            heightCm: heightCm,
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            goalDays: goalDays,
            intensityLevel: intensityLevel,
            weeklySchedule: weeklySchedule
        )
        modelContext.insert(profile)
        onboardingComplete = true
    }
}
