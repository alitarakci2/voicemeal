//
//  OnboardingContainerView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var onboardingComplete: Bool

    @State private var step = 0 // 0 = HealthKit intro
    private let totalSteps = 9

    // Step 2 (Welcome)
    @State private var name = ""
    // Step 3 (Body)
    @State private var gender = "male"
    @State private var age = 25
    @State private var heightCm = 175.0
    @State private var currentWeightKg = 80.0
    // Step 4 (Mode select)
    @State private var selectedMode: TrackingMode = .goal
    // Step 5 (Goal)
    @State private var goalWeightKg = 75.0
    @State private var goalDays = 90
    // Step 6 (Schedule)
    @State private var weeklySchedule: [[String]] = [["walking"], ["rest"], ["walking"], ["rest"], ["walking"], ["rest"], ["rest"]]
    // Step 7 (Coach Style)
    @State private var selectedCoachStyle: CoachStyle = .supportive
    // Step 8 (Food Habits)
    @State private var cookingLocation: CookingLocation = .mostly_home
    @State private var portionSize: PortionSize = .medium
    @State private var oilUsage: OilUsage = .moderate
    @State private var proteinSource: ProteinSource = .mixed
    @State private var cuisinePreference: CuisinePreference = .turkish_home
    @State private var mealFrequency: MealFrequency = .two_meals

    // HealthKit
    @State private var healthKitService = HealthKitService()
    @State private var healthKitLoaded = false
    @State private var showHealthKitBanner = false

    private var appLanguage: String {
        UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
    }

    private var canProceed: Bool {
        switch step {
        case 0, 1: true
        case 2: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 3: !gender.isEmpty
        default: true
        }
    }

    private var displayStep: Int {
        max(1, step - 1)
    }

    private var displayTotal: Int {
        totalSteps - 2
    }

    private var estimatedDailyTarget: Int {
        let bmr: Double
        if gender == "male" {
            bmr = 10 * currentWeightKg + 6.25 * heightCm - 5 * Double(age) + 5
        } else {
            bmr = 10 * currentWeightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }
        let tdee = bmr * 1.5
        let weightDiff = currentWeightKg - goalWeightKg
        let rawDeficit = goalDays > 0 ? (weightDiff * 7700) / Double(goalDays) : 0
        let cappedDeficit = min(rawDeficit, tdee * 0.35)
        return max(Int(tdee - cappedDeficit), gender == "male" ? 1500 : 1200)
    }

    var body: some View {
        VStack(spacing: 0) {
            if step > 1 && step < totalSteps {
                ProgressView(value: Double(displayStep), total: Double(displayTotal))
                    .tint(Theme.accent)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Text("\(displayStep) / \(displayTotal)")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
            }

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

            Group {
                switch step {
                case 0:
                    healthKitIntroView
                case 1:
                    StepAppTourView(appLanguage: appLanguage) {
                        step = 2
                    }
                case 2:
                    Step1WelcomeView(name: $name)
                case 3:
                    Step2BodyView(gender: $gender, age: $age, heightCm: $heightCm, currentWeightKg: $currentWeightKg)
                case 4:
                    Step3ModeSelectView(selectedMode: $selectedMode)
                case 5:
                    Step3GoalView(currentWeightKg: currentWeightKg, goalWeightKg: $goalWeightKg, goalDays: $goalDays)
                case 6:
                    Step5ScheduleView(weeklySchedule: $weeklySchedule)
                case 7:
                    coachStyleView
                case 8:
                    Step7FoodHabitsView(
                        cookingLocation: $cookingLocation,
                        portionSize: $portionSize,
                        oilUsage: $oilUsage,
                        proteinSource: $proteinSource,
                        cuisinePreference: $cuisinePreference,
                        mealFrequency: $mealFrequency,
                        appLanguage: appLanguage
                    )
                case 9:
                    StepReadyView(
                        appLanguage: appLanguage,
                        userName: name.trimmingCharacters(in: .whitespaces),
                        dailyTarget: estimatedDailyTarget
                    ) {
                        saveProfile()
                    }
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: step)

            if step != 1 && step != totalSteps {
                HStack(spacing: 16) {
                    if step > 0 {
                        Button {
                            if step == 2 {
                                step = 0
                            } else if step == 6 && selectedMode == .observe {
                                // Schedule → ModeSelect (skip Goal)
                                step = 4
                            } else {
                                step -= 1
                            }
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
                        } else if step == 4 && selectedMode == .observe {
                            // ModeSelect → Schedule (skip Goal)
                            step = 6
                        } else if step < totalSteps {
                            step += 1
                        }
                    } label: {
                        Text(step == totalSteps - 1 ? L.next.localized : L.next.localized)
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
            intensityLevel: 0.2,
            weeklySchedule: weeklySchedule
        )
        profile.programStartWeightKg = currentWeightKg
        profile.trackingMode = selectedMode
        if selectedMode == .goal {
            profile.programStartDate = .now
        }
        profile.coachStyleRaw = selectedCoachStyle.rawValue
        profile.cookingLocation = cookingLocation
        profile.portionSize = portionSize
        profile.oilUsage = oilUsage
        profile.proteinSource = proteinSource
        profile.cuisinePreference = cuisinePreference
        profile.mealFrequency = mealFrequency
        modelContext.insert(profile)
        onboardingComplete = true
    }
}
