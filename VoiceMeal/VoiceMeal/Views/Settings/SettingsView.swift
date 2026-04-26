//
//  SettingsView.swift
//  VoiceMeal
//

import Sentry
import SwiftData
import SwiftUI

extension Notification.Name {
    static let profileUpdated = Notification.Name("ProfileUpdated")
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GroqService.self) private var groqService
    @Query private var profiles: [UserProfile]

    // Profile fields
    @State private var name = ""
    @State private var gender = "male"
    @State private var age = 25
    @State private var heightCm: Double = 170
    @State private var currentWeightKg: Double = 70

    // Coach Style
    @State private var selectedCoachStyle: CoachStyle = .supportive

    // Personal Context
    @State private var personalContext = ""

    // Food Habits
    @State private var cookingLocation: CookingLocation = .mostly_home
    @State private var portionSize: PortionSize = .medium
    @State private var oilUsage: OilUsage = .moderate
    @State private var proteinSource: ProteinSource = .mixed
    @State private var cuisinePreference: CuisinePreference = .turkish_home
    @State private var mealFrequency: MealFrequency = .two_meals

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
    @State private var debugToast: String = ""
    @State private var showWeightConflictAlert = false
    @State private var showResetAlert = false
    @State private var healthKitWeight: Double?
    @State private var healthKitWeightDate: Date?
    @State private var scrollProxy: ScrollViewProxy?

    @State private var healthKitService = HealthKitService()

    private var isEN: Bool { groqService.appLanguage == "en" }

    var body: some View {
        ZStack {
            AtmosphericBackground()

            VStack(spacing: 0) {
                // Sticky header with Save button
                HStack {
                    Text(L.settings.localized)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        handleSave()
                    } label: {
                        Text(L.save.localized)
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Theme.gradientTop.opacity(0.95))
                .overlay(Divider().opacity(0.2), alignment: .bottom)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 14) {
                            Color.clear.frame(height: 0).id("top")

                            // Section: Profile
                            profileSection

                            // Section: Coach Style
                            coachStyleSection

                            // Section: Food Profile
                            foodProfileSection

                            // Section: Personal Preferences
                            personalPreferencesSection

                            // Section: Notifications
                            notificationsSection

                            // Section: Language
                            languageSection



                            // Section: Tooltips
                            tooltipSection

                            // Section: App
                            appSection

                            #if DEBUG
                            debugSection
                            #endif
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                    .onAppear { scrollProxy = proxy }
                    .scrollDismissesKeyboard(.interactively)
                }
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
            } else if !debugToast.isEmpty {
                Text(debugToast)
                    .font(Theme.bodyFont)
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
        }
        .animation(.easeInOut, value: showSavedToast)
        .animation(.easeInOut, value: debugToast)
        .onChange(of: debugToast) { _, new in
            guard !new.isEmpty else { return }
            Task {
                try? await Task.sleep(for: .seconds(2))
                debugToast = ""
            }
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

    // MARK: - Profile Section

    private var profileSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(L.profile.localized, icon: "person.fill", iconColor: Theme.accent)

                // Name
                settingsRow(label: L.nameField.localized) {
                    TextField(L.nameField.localized, text: $name)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.white)
                }

                Divider().overlay(Theme.cardBorder)

                // Gender — custom picker
                genderPicker

                Divider().overlay(Theme.cardBorder)

                // Age
                settingsRow(label: L.age.localized) {
                    Stepper("\(age)", value: $age, in: 15...80)
                        .frame(width: 130)
                }

                Divider().overlay(Theme.cardBorder)

                // Height
                VStack(spacing: 8) {
                    HStack {
                        Text(L.height.localized)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(Int(heightCm)) cm")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Slider(value: $heightCm, in: 120...220, step: 1)
                        .tint(Theme.accent)
                }

                Divider().overlay(Theme.cardBorder)

                // Weight
                VStack(spacing: 8) {
                    HStack {
                        Text(L.weight.localized)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(String(format: "%.1f", currentWeightKg)) kg")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Slider(value: $currentWeightKg, in: 40...200, step: 0.1)
                        .tint(Theme.accent)
                }
            }
        }
    }

    // MARK: - Gender Picker

    private var genderPicker: some View {
        HStack(spacing: 0) {
            genderButton(value: "male", label: L.male.localized, icon: "person.fill")
            genderButton(value: "female", label: L.female.localized, icon: "person.fill")
        }
        .padding(3)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func genderButton(value: String, label: String, icon: String) -> some View {
        Button {
            gender = value
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.subheadline.weight(gender == value ? .semibold : .regular))
            }
            .foregroundStyle(gender == value ? Color.white : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                gender == value
                    ? AnyView(RoundedRectangle(cornerRadius: 8).fill(Theme.accent))
                    : AnyView(Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Coach Style Section

    private var coachStyleSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("coach_style".localized, icon: "brain.fill", iconColor: Theme.accent)

                ForEach(CoachStyle.allCases, id: \.self) { style in
                    Button {
                        selectedCoachStyle = style
                        FeedbackService.shared.addLog("Coach style changed: \(style.rawValue)")
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isEN ? style.displayNameEn : style.displayName)
                                    .font(Theme.bodyFont)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                Text(isEN ? style.descriptionEn : style.description)
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
                                : Color.white.opacity(0.04)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Food Profile Section

    private var foodProfileSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(L.foodProfile.localized, icon: "fork.knife", iconColor: Theme.warning)

                foodHabitRow(
                    label: L.cookingLabel.localized,
                    emoji: cookingLocation.emoji,
                    value: cookingLocation.label(groqService.appLanguage),
                    options: CookingLocation.allCases,
                    selected: $cookingLocation,
                    labelFn: { $0.label(groqService.appLanguage) },
                    emojiFn: { $0.emoji }
                )
                foodHabitRow(
                    label: L.portionLabel.localized,
                    emoji: portionSize.emoji,
                    value: portionSize.label(groqService.appLanguage),
                    options: PortionSize.allCases,
                    selected: $portionSize,
                    labelFn: { $0.label(groqService.appLanguage) },
                    emojiFn: { $0.emoji }
                )
                foodHabitRow(
                    label: L.oilUsage.localized,
                    emoji: oilUsage.emoji,
                    value: oilUsage.label(groqService.appLanguage),
                    options: OilUsage.allCases,
                    selected: $oilUsage,
                    labelFn: { $0.label(groqService.appLanguage) },
                    emojiFn: { $0.emoji }
                )
                foodHabitRow(
                    label: L.protein.localized,
                    emoji: proteinSource.emoji,
                    value: proteinSource.label(groqService.appLanguage),
                    options: ProteinSource.allCases,
                    selected: $proteinSource,
                    labelFn: { $0.label(groqService.appLanguage) },
                    emojiFn: { $0.emoji }
                )
                foodHabitRow(
                    label: L.cuisineLabel.localized,
                    emoji: cuisinePreference.emoji,
                    value: cuisinePreference.label(groqService.appLanguage),
                    options: CuisinePreference.allCases,
                    selected: $cuisinePreference,
                    labelFn: { $0.label(groqService.appLanguage) },
                    emojiFn: { $0.emoji }
                )
                foodHabitRow(
                    label: L.mealsPerDay.localized,
                    emoji: mealFrequency.emoji,
                    value: mealFrequency.label(groqService.appLanguage),
                    options: MealFrequency.allCases,
                    selected: $mealFrequency,
                    labelFn: { $0.label(groqService.appLanguage) },
                    emojiFn: { $0.emoji }
                )
            }
        }
    }

    private func foodHabitRow<T: RawRepresentable & Hashable>(
        label: String,
        emoji: String,
        value: String,
        options: [T],
        selected: Binding<T>,
        labelFn: @escaping (T) -> String,
        emojiFn: @escaping (T) -> String
    ) -> some View where T.RawValue == String {
        HStack {
            Text(emoji)
                .font(.body)
                .frame(width: 28)
            Text(label)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Menu {
                ForEach(options, id: \.rawValue) { option in
                    Button {
                        selected.wrappedValue = option
                    } label: {
                        HStack {
                            Text("\(emojiFn(option)) \(labelFn(option))")
                            if selected.wrappedValue == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(value)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.accent)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Personal Preferences Section

    private var personalPreferencesSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("personal_preferences".localized, icon: "text.bubble.fill", iconColor: Theme.blue)

                Text("tell_coach".localized)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)

                TextEditor(text: $personalContext)
                    .frame(minHeight: 100)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Theme.trackBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .font(Theme.bodyFont)
                    .foregroundStyle(.white)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(L.done.localized) {
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
                            }
                            .foregroundColor(Theme.accent)
                            .fontWeight(.semibold)
                        }
                    }

                Text("personal_context_example".localized)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(L.notifications.localized, icon: "bell.fill", iconColor: Theme.warning)

                Toggle(isOn: $weightReminderEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "scalemass.fill")
                            .foregroundStyle(Theme.warning)
                            .font(.system(size: 14))
                        Text("weight_reminder_enabled".localized)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                .tint(Theme.accent)

                if weightReminderEnabled {
                    Divider().overlay(Theme.cardBorder)

                    settingsRow(label: String(format: "weight_reminder_days".localized, weightReminderDays)) {
                        Stepper("\(weightReminderDays)", value: $weightReminderDays, in: 1...7)
                            .frame(width: 130)
                    }

                    Divider().overlay(Theme.cardBorder)

                    DatePicker(L.time.localized, selection: $weightReminderTime, displayedComponents: .hourAndMinute)
                        .tint(Theme.accent)
                }
            }
        }
    }

    // MARK: - Premium Section

    private var premiumSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Premium", icon: "star.fill", iconColor: .yellow)

                Toggle(isOn: $isWaterTrackingEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(Theme.blue)
                            .font(.system(size: 14))
                        Text(L.waterTracking.localized)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                .tint(Theme.accent)

                if isWaterTrackingEnabled {
                    Divider().overlay(Theme.cardBorder)

                    Toggle(L.autoCalculate.localized, isOn: $waterGoalAuto)
                        .tint(Theme.accent)
                }

                if isWaterTrackingEnabled && !waterGoalAuto {
                    Divider().overlay(Theme.cardBorder)

                    VStack(spacing: 8) {
                        HStack {
                            Text(L.waterGoal.localized)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text("\(Int(waterGoalManualMl)) ml")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.blue.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
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
    }

    // MARK: - Language Section

    private var languageSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(L.language.localized, icon: "globe", iconColor: Theme.green)

                languagePicker
            }
        }
    }

    private var languagePicker: some View {
        let options: [(label: String, value: String)] = [
            (L.systemDefault.localized, ""),
            ("Türkçe", "tr"),
            ("English", "en"),
        ]
        return HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button {
                    selectedLanguage = option.value
                    FeedbackService.shared.addLog("Language changed: \(option.value.isEmpty ? "system" : option.value)")
                    if option.value != previousLanguage {
                        applyLanguage(option.value)
                        previousLanguage = option.value
                    }
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(selectedLanguage == option.value ? .semibold : .regular))
                        .foregroundStyle(selectedLanguage == option.value ? Color.white : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedLanguage == option.value
                                ? AnyView(RoundedRectangle(cornerRadius: 8).fill(Theme.accent))
                                : AnyView(Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("🛠️ Debug", icon: "hammer.fill", iconColor: .orange)

                Button {
                    let sid = FeedbackService.shared.sessionID
                    SentrySDK.capture(message: "🧪 Test Event [\(sid)]")
                    debugToast = "Sentry event gönderildi: \(sid)"
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "ant.fill")
                            .foregroundColor(.orange)
                        Text("Test Sentry Event")
                            .font(Theme.bodyFont)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    SentrySDK.crash()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundColor(.red)
                        Text("Test Crash (kills app)")
                            .font(Theme.bodyFont)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(14)
                    .background(Theme.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                HStack {
                    Text("Session ID")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(FeedbackService.shared.sessionID)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                    Button {
                        UIPasteboard.general.string = FeedbackService.shared.sessionID
                        debugToast = "Kopyalandı!"
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    #endif

    // MARK: - Tooltip Section

    @ObservedObject private var tooltipManager = TooltipManager.shared

    private var tooltipSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("tooltips_label".localized, icon: "lightbulb.fill", iconColor: Theme.accent)

                Toggle(isOn: $tooltipManager.tooltipsEnabled) {
                    Text("tooltips_label".localized)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .tint(Theme.accent)

                Button {
                    tooltipManager.resetAll()
                    withAnimation { debugToast = "tooltips_reset_done".localized }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(Theme.accent)
                        Text("tooltips_reset".localized)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.accent.opacity(0.5))
                    }
                    .padding(14)
                    .background(Theme.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.accent.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(L.appSection.localized, icon: "info.circle.fill", iconColor: .gray)

                HStack {
                    Text(L.version.localized)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("1.0.0")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text(isEN
                     ? "💡 Tip: You can also shake your phone anywhere to send feedback."
                     : "💡 İpucu: Herhangi bir yerde telefonu sallayarak da geri bildirim gönderebilirsin.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showResetAlert = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(Theme.red)
                        Text(L.resetOnboarding.localized)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.red)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.red.opacity(0.5))
                    }
                    .padding(14)
                    .background(Theme.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Card Helpers

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func sectionHeader(_ title: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.bottom, 4)
    }

    private func settingsRow<Content: View>(label: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            trailing()
        }
    }

    // MARK: - Load / Save

    private func applyLanguage(_ lang: String) {
        if lang.isEmpty {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            UserDefaults.standard.removeObject(forKey: "appLanguage")
            UserDefaults(suiteName: "group.indio.VoiceMeal")?.removeObject(forKey: "appLanguage")
        } else {
            UserDefaults.standard.set([lang], forKey: "AppleLanguages")
            UserDefaults.standard.set(lang, forKey: "appLanguage")
            UserDefaults(suiteName: "group.indio.VoiceMeal")?.set(lang, forKey: "appLanguage")
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
        personalContext = p.personalContext
        cookingLocation = p.cookingLocation
        portionSize = p.portionSize
        oilUsage = p.oilUsage
        proteinSource = p.proteinSource
        cuisinePreference = p.cuisinePreference
        mealFrequency = p.mealFrequency
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
        p.personalContext = personalContext
        p.cookingLocation = cookingLocation
        p.portionSize = portionSize
        p.oilUsage = oilUsage
        p.proteinSource = proteinSource
        p.cuisinePreference = cuisinePreference
        p.mealFrequency = mealFrequency
        p.preferredLanguage = selectedLanguage
        p.updatedAt = .now

        try? modelContext.save()
        NotificationService.shared.reschedule(profile: p)
        NotificationCenter.default.post(name: .profileUpdated, object: nil)

        FeedbackService.shared.addLog("Settings saved: theme=voicemeal lang=\(selectedLanguage)")

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
