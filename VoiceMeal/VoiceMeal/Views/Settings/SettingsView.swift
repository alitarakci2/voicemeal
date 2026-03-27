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
            Form {
                // Section: Profile
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

                // Section: Coach Style
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(CoachStyle.allCases, id: \.self) { style in
                            Button {
                                selectedCoachStyle = style
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(selectedLanguage == "en"
                                            ? style.displayNameEn
                                            : style.displayName)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                        Text(selectedLanguage == "en"
                                            ? style.descriptionEn
                                            : style.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedCoachStyle == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: "6C63FF"))
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(12)
                                .background(
                                    selectedCoachStyle == style
                                        ? Color(hex: "6C63FF").opacity(0.1)
                                        : Color(hex: "1C1C24")
                                )
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("coach_style".localized)
                }

                // Section: Notifications
                Section(L.notifications.localized) {
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
                }

                // Section: Premium
                Section {
                    Toggle(selectedLanguage == "en" ? "Water Tracking" : "Su Takibi", isOn: $isWaterTrackingEnabled)

                    if isWaterTrackingEnabled {
                        Toggle(L.autoCalculate.localized, isOn: $waterGoalAuto)
                    }

                    if isWaterTrackingEnabled && !waterGoalAuto {
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
                    } else if isWaterTrackingEnabled && waterGoalAuto {
                        Text(L.waterFormula.localized)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } header: {
                    Text(selectedLanguage == "en" ? "Premium" : "Premium")
                }

                // Save button
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                // Section: Language
                Section(L.language.localized) {
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

                // Section: App
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
