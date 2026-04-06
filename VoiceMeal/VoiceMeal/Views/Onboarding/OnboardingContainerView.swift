//
//  OnboardingContainerView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var onboardingComplete: Bool

    @State private var step = 0 // 0 = HealthKit intro
    private let totalSteps = 7

    // Step 1 (Welcome)
    @State private var name = ""
    // Step 2 (Body)
    @State private var gender = "male"
    @State private var age = 25
    @State private var heightCm = 175.0
    @State private var currentWeightKg = 80.0
    // Step 3 (Goal)
    @State private var goalWeightKg = 75.0
    @State private var goalDays = 90
    // Step 4 (Intensity)
    @State private var intensityLevel = 0.5
    // Step 5 (Schedule)
    @State private var weeklySchedule: [[String]] = [["walking"], ["rest"], ["walking"], ["rest"], ["walking"], ["rest"], ["rest"]]
    // Step 6 (Coach Style)
    @State private var selectedCoachStyle: CoachStyle = .supportive

    // HealthKit
    @State private var healthKitService = HealthKitService()
    @State private var healthKitLoaded = false
    @State private var showHealthKitBanner = false

    private var canProceed: Bool {
        switch step {
        case 0: true
        case 1: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: !gender.isEmpty
        default: true
        }
    }

    // Steps 0 through totalSteps-1, progress starts from step 1
    private var displayStep: Int {
        max(1, step)
    }

    private var displayTotal: Int {
        totalSteps - 1 // Don't count HealthKit intro in progress
    }

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 {
                // Progress bar (don't show on HealthKit intro)
                ProgressView(value: Double(displayStep), total: Double(displayTotal))
                    .tint(Theme.accent)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Text("\(displayStep) / \(displayTotal)")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
            }

            // HealthKit banner
            if showHealthKitBanner {
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("healthkit_imported".localized)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Theme.green.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Content
            Group {
                switch step {
                case 0:
                    healthKitIntroView
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
                    coachStyleView
                case 7:
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
                if step > 0 {
                    Button {
                        step -= 1
                    } label: {
                        Text(L.back.localized)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    if step == 0 {
                        requestHealthKitAndProceed()
                    } else if step < totalSteps {
                        step += 1
                    } else {
                        saveProfile()
                    }
                } label: {
                    Text(step == totalSteps ? L.start.localized : L.next.localized)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canProceed)
            }
            .padding()
        }
        .background(Theme.background)
    }

    // MARK: - HealthKit Intro

    private var healthKitIntroView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)

            Text("healthkit_intro_title".localized)
                .font(Theme.largeTitleFont)
                .multilineTextAlignment(.center)

            Text("healthkit_intro_body".localized)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                healthKitFeatureRow(icon: "scalemass", text: "healthkit_feature_weight".localized)
                healthKitFeatureRow(icon: "ruler", text: "healthkit_feature_height".localized)
                healthKitFeatureRow(icon: "person", text: "healthkit_feature_profile".localized)
                healthKitFeatureRow(icon: "flame", text: "healthkit_feature_calories".localized)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    private func healthKitFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text(text)
                .font(Theme.bodyFont)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Coach Style

    private var coachStyleView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("coach_style".localized)
                    .font(Theme.titleFont)

                Text("coach_style_intro".localized)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    ForEach(CoachStyle.allCases, id: \.self) { style in
                        Button {
                            selectedCoachStyle = style
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(style.displayName)
                                        .font(Theme.bodyFont)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                    Text(style.description)
                                        .font(Theme.captionFont)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: selectedCoachStyle == style
                                    ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedCoachStyle == style
                                        ? Theme.accent : Theme.textTertiary)
                                    .font(.system(size: 22))
                            }
                            .padding(14)
                            .background(
                                selectedCoachStyle == style
                                    ? Theme.accent.opacity(0.1)
                                    : Theme.cardBackground
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - HealthKit

    private func requestHealthKitAndProceed() {
        step = 1
        guard !healthKitLoaded else { return }
        healthKitLoaded = true
        Task {
            await loadFromHealthKit()
        }
    }

    private func loadFromHealthKit() async {
        guard healthKitService.isAvailable else { return }
        let granted = await healthKitService.requestPermission()
        guard granted else { return }

        var imported = false

        if let hkGender = healthKitService.fetchBiologicalSex() {
            gender = hkGender
            imported = true
        }

        if let hkAge = healthKitService.fetchAge() {
            age = hkAge
            imported = true
        }

        if let hkHeight = await healthKitService.fetchLatestHeight() {
            let rounded = hkHeight.rounded()
            if rounded >= 140 && rounded <= 220 {
                heightCm = rounded
                imported = true
            }
        }

        if let hkWeight = await healthKitService.fetchLatestWeight() {
            if hkWeight >= 40 && hkWeight <= 200 {
                currentWeightKg = (hkWeight * 10).rounded() / 10
                imported = true
            }
        }

        if imported {
            withAnimation {
                showHealthKitBanner = true
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation {
                showHealthKitBanner = false
            }
        }
    }

    // MARK: - Save

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
        profile.programStartWeightKg = currentWeightKg
        profile.coachStyleRaw = selectedCoachStyle.rawValue
        modelContext.insert(profile)
        onboardingComplete = true
    }
}
