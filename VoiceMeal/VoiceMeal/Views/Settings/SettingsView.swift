//
//  SettingsView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

extension Notification.Name {
    static let profileUpdated = Notification.Name("ProfileUpdated")
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    // Profile fields
    @State private var name = ""
    @State private var gender = "male"
    @State private var age = 25
    @State private var heightCm: Double = 170
    @State private var currentWeightKg: Double = 70

    // Coach Style
    @State private var selectedCoachStyle: CoachStyle = .supportive

    // Notifications
    @State private var weightReminderEnabled = true
    @State private var weightReminderDays: Int = 1
    @State private var weightReminderTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? .now

    // Premium
    @State private var isWaterTrackingEnabled = false
    @State private var waterGoalAuto = true
    @State private var waterGoalManualMl: Double = 2500

    // Language
    @State private var selectedLanguage = ""
    @State private var previousLanguage = ""
    @State private var showLanguageRestart = false

    // UI state
    @State private var showSavedToast = false
    @State private var showWeightConflictAlert = false
    @State private var showResetAlert = false
    @State private var healthKitWeight: Double?
    @State private var healthKitWeightDate: Date?

    @State private var healthKitService = HealthKitService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                        // Section: Profile
                        settingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader(L.profile.localized)

                            VStack(spacing: 12) {
                                settingsRow(label: L.nameField.localized) {
                                    TextField(L.nameField.localized, text: $name)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(.white)
                                }

                                Divider().overlay(Color(hex: "2C2C2E"))

                                settingsRow(label: L.gender.localized) {
                                    Picker("", selection: $gender) {
                                        Text(L.male.localized).tag("male")
                                        Text(L.female.localized).tag("female")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 160)
                                }

                                Divider().overlay(Color(hex: "2C2C2E"))

                                settingsRow(label: L.age.localized) {
                                    Stepper("\(age)", value: $age, in: 15...80)
                                        .frame(width: 130)
                                }

                                Divider().overlay(Color(hex: "2C2C2E"))

                                VStack(spacing: 6) {
                                    settingsRow(label: L.height.localized) {
                                        Text("\(Int(heightCm)) cm")
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Slider(value: $heightCm, in: 120...220, step: 1)
                                        .tint(Theme.accent)
                                }

                                Divider().overlay(Color(hex: "2C2C2E"))

                                VStack(spacing: 6) {
                                    settingsRow(label: L.weight.localized) {
                                        Text("\(String(format: "%.1f", currentWeightKg)) kg")
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Slider(value: $currentWeightKg, in: 40...200, step: 0.1)
                                        .tint(Theme.accent)
                                }
                            }
                        }
                    }

                    // Section: Coach Style
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("coach_style".localized)

                            ForEach(CoachStyle.allCases, id: \.self) { style in
                                Button {
                                    selectedCoachStyle = style
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(selectedLanguage == "en"
                                                ? style.displayNameEn
                                                : style.displayName)
                                                .font(Theme.bodyFont)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.white)
                                            Text(selectedLanguage == "en"
                                                ? style.descriptionEn
                                                : style.description)
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
                                            : Color(hex: "2C2C2E").opacity(0.5)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Section: Notifications
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(L.notifications.localized)

                            Toggle("weight_reminder_enabled".localized, isOn: $weightReminderEnabled)
                                .tint(Theme.accent)

                            if weightReminderEnabled {
                                Divider().overlay(Color(hex: "2C2C2E"))

                                settingsRow(label: "weight_reminder_days".localized) {
                                    Stepper("\(weightReminderDays)", value: $weightReminderDays, in: 1...7)
                                        .frame(width: 130)
                                }

                                Divider().overlay(Color(hex: "2C2C2E"))

                                DatePicker(L.time.localized, selection: $weightReminderTime, displayedComponents: .hourAndMinute)
                                    .tint(Theme.accent)
                            }
                        }
                    }

                    // Section: Premium
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Premium")

                            Toggle(selectedLanguage == "en" ? "Water Tracking" : "Su Takibi", isOn: $isWaterTrackingEnabled)
                                .tint(Theme.accent)

                            if isWaterTrackingEnabled {
                                Divider().overlay(Color(hex: "2C2C2E"))

                                Toggle(L.autoCalculate.localized, isOn: $waterGoalAuto)
                                    .tint(Theme.accent)
                            }

                            if isWaterTrackingEnabled && !waterGoalAuto {
                                Divider().overlay(Color(hex: "2C2C2E"))

                                VStack(spacing: 6) {
                                    settingsRow(label: L.waterGoal.localized) {
                                        Text("\(Int(waterGoalManualMl)) ml")
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Slider(value: $waterGoalManualMl, in: 1000...5000, step: 100)
                                        .tint(Theme.blue)
                                }
                            } else if isWaterTrackingEnabled && waterGoalAuto {
                                Text(L.waterFormula.localized)
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }

                    // Save button
                    Button {
                        handleSave()
                    } label: {
                        Text(L.save.localized)
                            .font(Theme.headlineFont)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    // Section: Language
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(L.language.localized)

                            Picker(L.language.localized, selection: $selectedLanguage) {
                                Text(L.systemDefault.localized).tag("")
                                Text("Turkce").tag("tr")
                                Text("English").tag("en")
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedLanguage) { _, newValue in
                                if newValue != previousLanguage {
                                    applyLanguage(newValue)
                                    previousLanguage = newValue
                                }
                            }
                        }
                    }

                    // Section: App
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(L.appSection.localized)

                            settingsRow(label: L.version.localized) {
                                Text("1.0.0")
                                    .foregroundStyle(Theme.textTertiary)
                            }

                            Divider().overlay(Color(hex: "2C2C2E"))

                            Button {
                                showResetAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text(L.resetOnboarding.localized)
                                }
                                .foregroundStyle(Theme.red)
                                .font(Theme.bodyFont)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(Theme.background)
            .navigationTitle(L.settings.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L.done.localized) {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .foregroundColor(Theme.accent)
                    .fontWeight(.semibold)
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text(L.savedToast.localized)
                        .font(Theme.bodyFont)
                        .fontWeight(.medium)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.green)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
            .animation(.easeInOut, value: showSavedToast)
            .alert(L.weightConflict.localized, isPresented: $showWeightConflictAlert) {
                Button("\("manual_weight".localized) (\(String(format: "%.2f", currentWeightKg)) kg)") {
                    performSave()
                }
                Button("HealthKit (\(String(format: "%.2f", healthKitWeight ?? 0)) kg)") {
                    currentWeightKg = healthKitWeight ?? currentWeightKg
                    performSave()
                }
                Button(L.cancel.localized, role: .cancel) {}
            } message: {
                if let hkDate = healthKitWeightDate {
                    Text(String(format: L.weightConflictMessage.localized, hkDate.formatted(.dateTime.day().month(.abbreviated))))
                } else {
                    Text(L.weightConflictMessageAlt.localized)
                }
            }
            .alert(L.resetConfirm.localized, isPresented: $showResetAlert) {
                Button(L.resetConfirm.localized, role: .destructive) {
                    resetOnboarding()
                }
                Button(L.cancel.localized, role: .cancel) {}
            } message: {
                Text(L.resetConfirmMessage.localized)
            }
            .alert(L.language.localized, isPresented: $showLanguageRestart) {
                Button("OK") {}
            } message: {
                Text(L.languageRestart.localized)
            }
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
            .onAppear {
                loadProfile()
            }
            .task {
                if healthKitService.isAvailable {
                    await healthKitService.requestPermission()
                    _ = await healthKitService.fetchLatestWeight()
                    healthKitWeight = healthKitService.latestWeight
                    healthKitWeightDate = healthKitService.latestWeightDate
                }
            }
        }
    }

    // MARK: - Card Helpers

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.headlineFont)
            .foregroundStyle(.white)
    }

    private func settingsRow<Content: View>(label: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(Theme.bodyFont)
                .foregroundStyle(.white)
            Spacer()
            trailing()
        }
    }

    // MARK: - Load / Save

    private func applyLanguage(_ lang: String) {
        if lang.isEmpty {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([lang], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
        showLanguageRestart = true
    }

    private func loadProfile() {
        guard let p = profiles.first else { return }
        name = p.name
        gender = p.gender
        age = p.age
        heightCm = p.heightCm
        currentWeightKg = p.currentWeightKg
        selectedLanguage = p.preferredLanguage
        previousLanguage = p.preferredLanguage
        isWaterTrackingEnabled = p.isWaterTrackingEnabled
        if let override = p.waterGoalOverrideMl {
            waterGoalAuto = false
            waterGoalManualMl = Double(override)
        } else {
            waterGoalAuto = true
        }
        weightReminderEnabled = p.weightReminderEnabled
        weightReminderDays = p.weightReminderDays
        weightReminderTime = Calendar.current.date(from: DateComponents(hour: p.weightReminderHour, minute: 0)) ?? .now
        selectedCoachStyle = p.coachStyle
    }

    private func handleSave() {
        if let hkWeight = healthKitWeight,
           abs(hkWeight - currentWeightKg) > 0.5 {
            showWeightConflictAlert = true
            return
        }
        performSave()
    }

    private func resetOnboarding() {
        for profile in profiles {
            modelContext.delete(profile)
        }
    }

    private func performSave() {
        guard let p = profiles.first else { return }

        p.name = name
        p.gender = gender
        p.age = age
        p.heightCm = heightCm
        p.currentWeightKg = currentWeightKg
        p.notification1Enabled = false
        p.notification2Enabled = false
        p.weightReminderEnabled = weightReminderEnabled
        p.weightReminderDays = weightReminderDays
        p.weightReminderHour = Calendar.current.component(.hour, from: weightReminderTime)
        p.isWaterTrackingEnabled = isWaterTrackingEnabled
        p.waterGoalOverrideMl = waterGoalAuto ? nil : Int(waterGoalManualMl)
        p.coachStyle = selectedCoachStyle
        p.preferredLanguage = selectedLanguage
        p.updatedAt = .now

        try? modelContext.save()
        NotificationService.shared.reschedule(profile: p)
        NotificationCenter.default.post(name: .profileUpdated, object: nil)

        showSavedToast = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSavedToast = false
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
