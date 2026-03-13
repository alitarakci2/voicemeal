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
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $heightCm, in: 120...220, step: 1)

                    HStack {
                        Text("Kilo")
                        Spacer()
                        Text("\(String(format: "%.1f", currentWeightKg)) kg")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $currentWeightKg, in: 30...200, step: 0.1)
                }

                // Section 2: Goals
                Section("Hedef") {
                    HStack {
                        Text("Hedef Kilo")
                        Spacer()
                        Text("\(String(format: "%.1f", goalWeightKg)) kg")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $goalWeightKg, in: 30...200, step: 0.1)

                    Stepper("Hedef Süre: \(goalDays) gün", value: $goalDays, in: 14...365, step: 7)

                    // Weight loss warnings
                    if weeklyChange > 1.0 {
                        Label("Sa\u{011F}l\u{0131}ks\u{0131}z h\u{0131}z! S\u{00FC}reyi uzatman\u{0131} \u{00F6}neririz", systemImage: "light.beacon.max.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if weeklyChange > 0.75 {
                        Label("Agresif hedef \u{2014} dikkatli ilerle", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    // Weight gain warnings
                    if weeklyChange < -1.0 {
                        Label("\u{00C7}ok h\u{0131}zl\u{0131} kilo alma \u{2014} s\u{00FC}reyi uzatman\u{0131} \u{00F6}neririz", systemImage: "light.beacon.max.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if weeklyChange < -0.5 {
                        Label("H\u{0131}zl\u{0131} kilo alma hedefi \u{2014} dikkatli ilerle", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    // Safety cap info
                    if isDeficitCapped {
                        Label("Hedef \u{00E7}ok agresif, g\u{00FC}venli s\u{0131}n\u{0131}ra ayarlanacak", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // Section 3: Intensity
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Yoğunluk")
                            Spacer()
                            Text(intensityLabel)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $intensityLevel, in: 0...1, step: 0.1)

                        Text(intensityDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

                // Section 5: App
                Section("Uygulama") {
                    HStack {
                        Text("Versiyon")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
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
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.green)
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
        p.updatedAt = .now

        originalSchedule = weeklySchedule

        try? modelContext.save()
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
