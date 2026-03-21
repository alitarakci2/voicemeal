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

    // Goal fields
    @State private var goalWeightKg: Double = 65
    @State private var goalDays = 90

    // Intensity
    @State private var intensityLevel: Double = 0.5

    // Water
    @State private var waterGoalAuto = true
    @State private var waterGoalManualMl: Double = 2500

    // Notifications
    @State private var notification1Enabled = true
    @State private var notification1Time = Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? .now
    @State private var notification2Enabled = true
    @State private var notification2Time = Calendar.current.date(from: DateComponents(hour: 21, minute: 30)) ?? .now
    @State private var weightReminderEnabled = true
    @State private var weightReminderDays: Int = 1
    @State private var weightReminderTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? .now
    @State private var preferredProteins: Set<String> = ["tavuk", "bal\u{0131}k", "dana", "yumurta", "baklagil", "s\u{00FC}t \u{00FC}r\u{00FC}nleri"]

    // Schedule
    @State private var weeklySchedule: [[String]] = Array(repeating: ["rest"], count: 7)
    @State private var originalSchedule: [[String]] = Array(repeating: ["rest"], count: 7)

    // Language
    @State private var selectedLanguage = ""
    @State private var showLanguageRestart = false

    // UI state
    @State private var showSavedToast = false
    @State private var showScheduleAlert = false
    @State private var showWeightConflictAlert = false
    @State private var showResetAlert = false
    @State private var healthKitWeight: Double?
    @State private var healthKitWeightDate: Date?

    @State private var healthKitService = HealthKitService()

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Profile
                Section(L.profile.localized) {
                    TextField(L.nameField.localized, text: $name)

                    Picker(L.gender.localized, selection: $gender) {
                        Text(L.male.localized).tag("male")
                        Text(L.female.localized).tag("female")
                    }

                    Stepper("\(L.age.localized): \(age)", value: $age, in: 15...80)

                    HStack {
                        Text(L.height.localized)
                        Spacer()
                        Text("\(Int(heightCm)) cm")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack {
                        Slider(value: $heightCm, in: 120...220, step: 1)
                            .tint(Theme.accent)
                        TextField("", value: $heightCm, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text(L.weight.localized)
                        Spacer()
                        Text("\(String(format: "%.2f", currentWeightKg)) kg")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack {
                        Slider(value: $currentWeightKg, in: 40...200, step: 0.05)
                            .tint(Theme.accent)
                        TextField("", value: $currentWeightKg, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // Section 2: Goals
                Section(L.goal.localized) {
                    HStack {
                        Text("target_weight".localized)
                        Spacer()
                        Text("\(String(format: "%.2f", goalWeightKg)) kg")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack {
                        Slider(value: $goalWeightKg, in: 30...200, step: 0.05)
                            .tint(Theme.accent)
                        TextField("", value: $goalWeightKg, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                    }

                    Stepper(String(format: "goal_duration".localized, goalDays), value: $goalDays, in: 14...365, step: 7)

                    // Weight loss warnings
                    if weeklyChange > 1.0 {
                        Label("unhealthy_pace".localized, systemImage: "light.beacon.max.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.red)
                    } else if weeklyChange > 0.75 {
                        Label("aggressive_goal".localized, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                    }
                    // Weight gain warnings
                    if weeklyChange < -1.0 {
                        Label(L.weightGainTooFast.localized, systemImage: "light.beacon.max.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.red)
                    } else if weeklyChange < -0.5 {
                        Label(L.weightGainFast.localized, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                    }

                    // Safety cap info
                    if isDeficitCapped {
                        Label(L.deficitCapped.localized, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                    }
                }

                // Section 3: Intensity
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L.intensity.localized)
                            Spacer()
                            Text(intensityLabel)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Slider(value: $intensityLevel, in: 0...1, step: 0.1)

                        Text(intensityDescription)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } header: {
                    Text(L.intensity.localized)
                } footer: {
                    Text(L.intensityFooter.localized)
                }

                // Section: Water Goal
                Section {
                    Toggle(L.autoCalculate.localized, isOn: $waterGoalAuto)

                    if !waterGoalAuto {
                        HStack {
                            Text(L.waterGoal.localized)
                            Spacer()
                            Text("\(Int(waterGoalManualMl)) ml")
                                .foregroundStyle(Theme.textSecondary)
                        }
                        HStack {
                            Slider(value: $waterGoalManualMl, in: 1000...5000, step: 100)
                                .tint(Theme.blue)
                            TextField("", value: $waterGoalManualMl, format: .number.precision(.fractionLength(0)))
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        Text(L.waterFormula.localized)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } header: {
                    Text("💧 \(L.waterGoal.localized)")
                }

                // Section 4: Weekly Schedule
                Section(L.weeklySchedule.localized) {
                    Step5ScheduleView(weeklySchedule: $weeklySchedule)
                        .listRowInsets(EdgeInsets())
                }

                // Section 6: Notifications
                Section(L.notifications.localized) {
                    Toggle(L.afternoonReminder.localized, isOn: $notification1Enabled)
                    if notification1Enabled {
                        DatePicker(L.time.localized, selection: $notification1Time, displayedComponents: .hourAndMinute)
                    }

                    Toggle(L.eveningReminder.localized, isOn: $notification2Enabled)
                    if notification2Enabled {
                        DatePicker(L.time.localized, selection: $notification2Time, displayedComponents: .hourAndMinute)
                    }

                    Toggle("weight_reminder_enabled".localized, isOn: $weightReminderEnabled)
                    if weightReminderEnabled {
                        Stepper(
                            String(format: "weight_reminder_days".localized, weightReminderDays),
                            value: $weightReminderDays,
                            in: 1...7
                        )
                        DatePicker(L.time.localized, selection: $weightReminderTime, displayedComponents: .hourAndMinute)
                        Text(String(format: "weight_reminder_explanation".localized, weightReminderDays))
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.preferredProteins.localized)
                            .font(Theme.bodyFont)
                        proteinChips
                    }
                }

                // Save button at bottom
                Section {
                    Button {
                        handleSave()
                    } label: {
                        Text(L.save.localized)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "6C63FF"))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaveDisabled)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                // Section: Language
                Section(L.language.localized) {
                    Picker(L.language.localized, selection: $selectedLanguage) {
                        Text(L.systemDefault.localized).tag("")
                        Text("Türkçe").tag("tr")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedLanguage) { _, newValue in
                        applyLanguage(newValue)
                    }
                }

                // Section 5: App
                Section(L.appSection.localized) {
                    HStack {
                        Text(L.version.localized)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label(L.resetOnboarding.localized, systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle(L.settings.localized)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.save.localized) {
                        handleSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaveDisabled)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L.done.localized) {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .foregroundColor(Color(hex: "6C63FF"))
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
            .alert(L.scheduleChange.localized, isPresented: $showScheduleAlert) {
                Button(L.save.localized, role: .destructive) {
                    performSave()
                }
                Button(L.cancel.localized, role: .cancel) {
                    weeklySchedule = originalSchedule
                }
            } message: {
                Text(L.scheduleChangeMessage.localized)
            }
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

    // MARK: - Weight change validation

    /// Positive = weight loss, negative = weight gain
    private var weeklyChange: Double {
        guard goalDays > 0 else { return 0 }
        return (currentWeightKg - goalWeightKg) / (Double(goalDays) / 7.0)
    }

    private var isSaveDisabled: Bool {
        weeklyChange > 1.5 || weeklyChange < -1.5
    }

    /// Preview whether the deficit will be safety-capped with current form values
    private var isDeficitCapped: Bool {
        guard goalDays > 0 else { return false }
        let weightDiff = currentWeightKg - goalWeightKg
        let rawDeficit = (weightDiff * 7700) / Double(goalDays)
        // Estimate TDEE with simple BMR * 1.5 for preview purposes
        let estimatedBMR: Double
        if gender == "male" {
            estimatedBMR = 10 * currentWeightKg + 6.25 * heightCm - 5 * Double(age) + 5
        } else {
            estimatedBMR = 10 * currentWeightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }
        let estimatedTDEE = estimatedBMR * 1.5
        let maxDeficit = estimatedTDEE * 0.35
        let maxSurplus = estimatedTDEE * 0.20
        return rawDeficit > maxDeficit || rawDeficit < -maxSurplus
    }

    // MARK: - Protein chips

    private static let allProteinKeys: [(key: String, labelKey: String)] = [
        ("tavuk", "protein_chicken"),
        ("balık", "protein_fish"),
        ("dana", "protein_beef"),
        ("yumurta", "protein_egg"),
        ("baklagil", "protein_legume"),
        ("süt ürünleri", "protein_dairy"),
    ]

    private var proteinChips: some View {
        let columns = [GridItem(.adaptive(minimum: 100))]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Self.allProteinKeys, id: \.key) { protein in
                let isSelected = preferredProteins.contains(protein.key)
                Button {
                    if isSelected {
                        preferredProteins.remove(protein.key)
                    } else {
                        preferredProteins.insert(protein.key)
                    }
                } label: {
                    Text(protein.labelKey.localized)
                        .font(Theme.captionFont)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? Theme.accent.opacity(0.2) : Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Intensity helpers

    private var intensityLabel: String {
        switch intensityLevel {
        case ...0.3: return L.intensityLight.localized
        case 0.3...0.7: return L.intensityModerate.localized
        default: return L.intensityIntense.localized
        }
    }

    private var intensityDescription: String {
        switch intensityLevel {
        case ...0.3: return L.intensityLightDesc.localized
        case 0.3...0.7: return L.intensityModerateDesc.localized
        default: return L.intensityIntenseDesc.localized
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
        goalWeightKg = p.goalWeightKg
        goalDays = p.goalDays
        intensityLevel = p.intensityLevel
        weeklySchedule = p.weeklySchedule
        originalSchedule = p.weeklySchedule
        selectedLanguage = p.preferredLanguage
        if let override = p.waterGoalOverrideMl {
            waterGoalAuto = false
            waterGoalManualMl = Double(override)
        } else {
            waterGoalAuto = true
        }
        notification1Enabled = p.notification1Enabled
        notification2Enabled = p.notification2Enabled
        notification1Time = Calendar.current.date(from: DateComponents(hour: p.notification1Hour, minute: p.notification1Minute)) ?? .now
        notification2Time = Calendar.current.date(from: DateComponents(hour: p.notification2Hour, minute: p.notification2Minute)) ?? .now
        weightReminderEnabled = p.weightReminderEnabled
        weightReminderDays = p.weightReminderDays
        weightReminderTime = Calendar.current.date(from: DateComponents(hour: p.weightReminderHour, minute: 0)) ?? .now
        preferredProteins = Set(p.preferredProteins)
    }

    private func handleSave() {
        // Check schedule change
        if weeklySchedule != originalSchedule {
            showScheduleAlert = true
            return
        }

        // Check HealthKit weight conflict
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
        p.goalWeightKg = goalWeightKg
        p.goalDays = goalDays
        p.intensityLevel = intensityLevel
        p.weeklySchedule = weeklySchedule
        p.notification1Enabled = notification1Enabled
        p.notification1Hour = Calendar.current.component(.hour, from: notification1Time)
        p.notification1Minute = Calendar.current.component(.minute, from: notification1Time)
        p.notification2Enabled = notification2Enabled
        p.notification2Hour = Calendar.current.component(.hour, from: notification2Time)
        p.notification2Minute = Calendar.current.component(.minute, from: notification2Time)
        p.weightReminderEnabled = weightReminderEnabled
        p.weightReminderDays = weightReminderDays
        p.weightReminderHour = Calendar.current.component(.hour, from: weightReminderTime)
        p.preferredProteins = Array(preferredProteins)
        p.waterGoalOverrideMl = waterGoalAuto ? nil : Int(waterGoalManualMl)
        p.preferredLanguage = selectedLanguage
        p.updatedAt = .now

        originalSchedule = weeklySchedule

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
