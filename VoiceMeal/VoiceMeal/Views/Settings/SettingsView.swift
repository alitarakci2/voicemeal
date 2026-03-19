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

    // Notifications
    @State private var notification1Enabled = true
    @State private var notification1Time = Calendar.current.date(from: DateComponents(hour: 16, minute: 0)) ?? .now
    @State private var notification2Enabled = true
    @State private var notification2Time = Calendar.current.date(from: DateComponents(hour: 21, minute: 30)) ?? .now
    @State private var preferredProteins: Set<String> = ["tavuk", "bal\u{0131}k", "dana", "yumurta", "baklagil", "s\u{00FC}t \u{00FC}r\u{00FC}nleri"]

    // Schedule
    @State private var weeklySchedule: [[String]] = Array(repeating: ["rest"], count: 7)
    @State private var originalSchedule: [[String]] = Array(repeating: ["rest"], count: 7)

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
                Section("Profil") {
                    TextField("Ad", text: $name)

                    Picker("Cinsiyet", selection: $gender) {
                        Text("Erkek").tag("male")
                        Text("Kadın").tag("female")
                    }

                    Stepper("Yaş: \(age)", value: $age, in: 15...80)

                    HStack {
                        Text("Boy")
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
                        Text("Kilo")
                        Spacer()
                        Text("\(String(format: "%.1f", currentWeightKg)) kg")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack {
                        Slider(value: $currentWeightKg, in: 40...200, step: 0.1)
                            .tint(Theme.accent)
                        TextField("", value: $currentWeightKg, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // Section 2: Goals
                Section("Hedef") {
                    HStack {
                        Text("Hedef Kilo")
                        Spacer()
                        Text("\(String(format: "%.1f", goalWeightKg)) kg")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack {
                        Slider(value: $goalWeightKg, in: 30...200, step: 0.1)
                            .tint(Theme.accent)
                        TextField("", value: $goalWeightKg, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                    }

                    Stepper("Hedef Süre: \(goalDays) gün", value: $goalDays, in: 14...365, step: 7)

                    // Weight loss warnings
                    if weeklyChange > 1.0 {
                        Label("Sa\u{011F}l\u{0131}ks\u{0131}z h\u{0131}z! S\u{00FC}reyi uzatman\u{0131} \u{00F6}neririz", systemImage: "light.beacon.max.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.red)
                    } else if weeklyChange > 0.75 {
                        Label("Agresif hedef \u{2014} dikkatli ilerle", systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                    }
                    // Weight gain warnings
                    if weeklyChange < -1.0 {
                        Label("\u{00C7}ok h\u{0131}zl\u{0131} kilo alma \u{2014} s\u{00FC}reyi uzatman\u{0131} \u{00F6}neririz", systemImage: "light.beacon.max.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.red)
                    } else if weeklyChange < -0.5 {
                        Label("H\u{0131}zl\u{0131} kilo alma hedefi \u{2014} dikkatli ilerle", systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                    }

                    // Safety cap info
                    if isDeficitCapped {
                        Label("Hedef \u{00E7}ok agresif, g\u{00FC}venli s\u{0131}n\u{0131}ra ayarlanacak", systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                    }
                }

                // Section 3: Intensity
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Yoğunluk")
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
                    Text("Yoğunluk")
                } footer: {
                    Text("Yüksek yoğunluk daha hızlı sonuç verir ama sürdürülebilirliği düşer.")
                }

                // Section 4: Weekly Schedule
                Section("Haftalık Program") {
                    Step5ScheduleView(weeklySchedule: $weeklySchedule)
                        .listRowInsets(EdgeInsets())
                }

                // Section 6: Notifications
                Section("Bildirimler") {
                    Toggle("\u{00D6}\u{011F}le/Ak\u{015F}am Hat\u{0131}rlatmas\u{0131}", isOn: $notification1Enabled)
                    if notification1Enabled {
                        DatePicker("Saat", selection: $notification1Time, displayedComponents: .hourAndMinute)
                    }

                    Toggle("Gece Kapan\u{0131}\u{015F} Hat\u{0131}rlatmas\u{0131}", isOn: $notification2Enabled)
                    if notification2Enabled {
                        DatePicker("Saat", selection: $notification2Time, displayedComponents: .hourAndMinute)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tercih Etti\u{011F}in Protein Kaynaklar\u{0131}")
                            .font(Theme.bodyFont)
                        proteinChips
                    }
                }

                // Section 5: App
                Section("Uygulama") {
                    HStack {
                        Text("Versiyon")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Onboarding'i S\u{0131}f\u{0131}rla", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        handleSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaveDisabled)
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text("Kaydedildi")
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
            .alert("Program Değişikliği", isPresented: $showScheduleAlert) {
                Button("Kaydet", role: .destructive) {
                    performSave()
                }
                Button("İptal", role: .cancel) {
                    weeklySchedule = originalSchedule
                }
            } message: {
                Text("Haftalık programı değiştirdiniz. Bu, günlük kalori hedeflerinizi etkileyecek. Kaydetmek istiyor musunuz?")
            }
            .alert("Kilo Çakışması", isPresented: $showWeightConflictAlert) {
                Button("Elle girilen kilom (\(String(format: "%.1f", currentWeightKg)) kg)") {
                    performSave()
                }
                Button("HealthKit (\(String(format: "%.1f", healthKitWeight ?? 0)) kg)") {
                    currentWeightKg = healthKitWeight ?? currentWeightKg
                    performSave()
                }
                Button("İptal", role: .cancel) {}
            } message: {
                if let hkDate = healthKitWeightDate {
                    Text("HealthKit'ten farklı bir kilo verisi var (\(hkDate.formatted(.dateTime.day().month(.abbreviated)))). Hangisini kullanmak istersiniz?")
                } else {
                    Text("HealthKit'ten farklı bir kilo verisi var. Hangisini kullanmak istersiniz?")
                }
            }
            .alert("S\u{0131}f\u{0131}rla?", isPresented: $showResetAlert) {
                Button("S\u{0131}f\u{0131}rla", role: .destructive) {
                    resetOnboarding()
                }
                Button("\u{0130}ptal", role: .cancel) {}
            } message: {
                Text("T\u{00FC}m profil bilgilerin silinecek ve kurulum yeniden ba\u{015F}layacak.")
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

    private static let allProteins: [(key: String, label: String)] = [
        ("tavuk", "Tavuk"),
        ("bal\u{0131}k", "Bal\u{0131}k/Somon"),
        ("dana", "Dana/K\u{0131}yma"),
        ("yumurta", "Yumurta"),
        ("baklagil", "Baklagil"),
        ("s\u{00FC}t \u{00FC}r\u{00FC}nleri", "S\u{00FC}t \u{00DC}r\u{00FC}nleri"),
    ]

    private var proteinChips: some View {
        let columns = [GridItem(.adaptive(minimum: 100))]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Self.allProteins, id: \.key) { protein in
                let isSelected = preferredProteins.contains(protein.key)
                Button {
                    if isSelected {
                        preferredProteins.remove(protein.key)
                    } else {
                        preferredProteins.insert(protein.key)
                    }
                } label: {
                    Text(protein.label)
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
        case ...0.3: return "Hafif"
        case 0.3...0.7: return "Orta"
        default: return "Yoğun"
        }
    }

    private var intensityDescription: String {
        switch intensityLevel {
        case ...0.3: return "Günlük açık ~%10 — yavaş ve sürdürülebilir"
        case 0.3...0.7: return "Günlük açık ~%20 — dengeli ilerleme"
        default: return "Günlük açık ~%28 — hızlı ama zorlayıcı"
        }
    }

    // MARK: - Load / Save

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
        notification1Enabled = p.notification1Enabled
        notification2Enabled = p.notification2Enabled
        notification1Time = Calendar.current.date(from: DateComponents(hour: p.notification1Hour, minute: p.notification1Minute)) ?? .now
        notification2Time = Calendar.current.date(from: DateComponents(hour: p.notification2Hour, minute: p.notification2Minute)) ?? .now
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

        print("[Settings] BEFORE save - startWeight: \(p.programStartWeightKg)")

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
        p.preferredProteins = Array(preferredProteins)
        p.updatedAt = .now

        originalSchedule = weeklySchedule

        try? modelContext.save()
        print("[Settings] AFTER save - startWeight: \(p.programStartWeightKg)")
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
