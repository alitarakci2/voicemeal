//
//  HomeView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speechService = SpeechService()
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @State private var permissionGranted = false
    @State private var isAnalyzing = false
    @State private var parsedMeals: [ParsedMeal] = []
    @State private var clarificationQuestion: String?
    @State private var errorMessage: String?
    @State private var fullTranscript = ""
    @State private var showSavedConfirmation = false
    @State private var showGoalInfo = false
    @State private var showWeightBanner = false
    @State private var showSettings = false
    @State private var goalEngine = GoalEngine()
    @State private var healthKitService = HealthKitService()

    private let groqService = GroqService()

    private var todayEntries: [FoodEntry] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= startOfDay }
    }

    private var eatenCalories: Int { todayEntries.reduce(0) { $0 + $1.calories } }
    private var eatenProtein: Double { todayEntries.reduce(0.0) { $0 + $1.protein } }
    private var eatenCarbs: Double { todayEntries.reduce(0.0) { $0 + $1.carbs } }
    private var eatenFat: Double { todayEntries.reduce(0.0) { $0 + $1.fat } }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Weight update banner
                if showWeightBanner, let banner = goalEngine.weightUpdatedBanner {
                    HStack {
                        Text(banner)
                            .font(.subheadline)
                        Spacer()
                        Button {
                            showWeightBanner = false
                            goalEngine.dismissWeightBanner()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Daily goal card
                if goalEngine.profile != nil {
                    dailyGoalCard

                    DailyInsightCard(
                        hrvStatus: healthKitService.hrvStatus,
                        todayHRV: healthKitService.todayHRV,
                        hrvBaseline: healthKitService.hrvBaseline,
                        sleep: healthKitService.lastNightSleep,
                        todayActivities: goalEngine.todayActivityNames,
                        remainingCalories: goalEngine.dailyCalorieTarget - eatenCalories,
                        calorieDeficit: Int(goalEngine.tdee) - eatenCalories,
                        intensityLevel: goalEngine.profile?.intensityLevel ?? 0.5
                    )
                }

                // Mic button
                Button {
                    handleMicTap()
                } label: {
                    Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 120)
                        .background(speechService.isRecording ? Color.red : Color.gray)
                        .clipShape(Circle())
                        .shadow(color: speechService.isRecording ? .red.opacity(0.4) : .clear, radius: 16)
                }
                .disabled(isAnalyzing)

                // Status label
                if isAnalyzing {
                    ProgressView("Analiz ediliyor...")
                } else if showSavedConfirmation {
                    Text("Kaydedildi \u{2713}")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    Text(speechService.isRecording ? "Dinliyorum..." : "Hazır")
                        .font(.headline)
                        .foregroundStyle(speechService.isRecording ? .red : .secondary)
                }

                // Transcript
                if !speechService.transcript.isEmpty {
                    Text(speechService.transcript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Parsed results
                if !parsedMeals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(parsedMeals) { meal in
                            HStack {
                                Text(meal.name)
                                Spacer()
                                Text("\(Int(meal.calories)) kcal")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        HStack {
                            Text("Toplam")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(Int(parsedMeals.reduce(0) { $0 + $1.calories })) kcal")
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Clarification question
                if let question = clarificationQuestion {
                    Text(question)
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                // Today's meal list
                if !todayEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bugünkü Yemekler")
                            .font(.headline)

                        ForEach(todayEntries, id: \.id) { entry in
                            HStack {
                                Text(entry.name)
                                Spacer()
                                Text("\(entry.calories) kcal")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .task {
            permissionGranted = await speechService.requestPermissions()
            if healthKitService.isAvailable {
                await healthKitService.requestPermission()
                await refreshHealthKit()
            }
            saveTodaySnapshot()
        }
        .onChange(of: speechService.isRecording) { oldValue, newValue in
            if oldValue && !newValue && !speechService.transcript.isEmpty {
                sendToGroq()
            }
        }
        .onChange(of: profiles) {
            goalEngine.update(with: profiles.first)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    await refreshHealthKit()
                    if SnapshotService.snapshotNeedsUpdate(for: .now, modelContext: modelContext) {
                        saveTodaySnapshot()
                    }
                }
            }
        }
        .onAppear {
            goalEngine.update(with: profiles.first)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task {
                saveYesterdaySnapshot()
                await refreshHealthKit()
                saveTodaySnapshot()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileUpdated)) { _ in
            if let profile = profiles.first {
                goalEngine.updateProfile(profile)
            }
            saveTodaySnapshot()
        }
        .sheet(isPresented: $showGoalInfo) {
            goalInfoSheet
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Daily Goal Card

    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with today's activities
            HStack {
                let names = goalEngine.todayActivityNames
                    .compactMap { GoalEngine.activityDisplayNames[$0] }
                Text("📅 Bugün: \(names.joined(separator: ", "))")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button {
                    Task { await refreshHealthKit() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showGoalInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
            }

            // Calorie summary
            let remaining = goalEngine.dailyCalorieTarget - eatenCalories
            HStack {
                calorieStat("Hedef", value: goalEngine.dailyCalorieTarget)
                calorieStat("Yenen", value: eatenCalories)
                VStack(spacing: 2) {
                    Text("Kalan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(remaining)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(remaining < 0 ? .red : .primary)
                }
                .frame(maxWidth: .infinity)
                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Daily deficit
            let deficit = Int(goalEngine.tdee) - eatenCalories
            HStack {
                if deficit > 0 {
                    Text("\u{1F525} \(deficit) kcal a\u{00E7}\u{0131}k")
                        .foregroundStyle(.green)
                } else {
                    Text("\u{26A0}\u{FE0F} \(abs(deficit)) kcal fazla")
                        .foregroundStyle(.red)
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)

            // Macro progress bars
            macroRow("Protein", eaten: Int(eatenProtein), target: goalEngine.proteinTarget, color: .blue)
            macroRow("Karb", eaten: Int(eatenCarbs), target: goalEngine.carbTarget, color: .orange)
            macroRow("Yağ", eaten: Int(eatenFat), target: goalEngine.fatTarget, color: .yellow)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func calorieStat(_ label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
    }

    private func macroRow(_ name: String, eaten: Int, target: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.caption)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                let progress = target > 0 ? min(Double(eaten) / Double(target), 1.0) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)

            Text("\(eaten)g / \(target)g")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
    }

    // MARK: - Goal Info Sheet

    private var goalInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // TDEE source indicator
                    if goalEngine.isUsingExtrapolatedTDEE {
                        let pct = Int(healthKitService.dayFraction * 100)
                        Label("Extrapolasyon aktif (%\(pct) g\u{00FC}n ge\u{00E7}ti)", systemImage: "iphone")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if goalEngine.usingHealthKit {
                        Label("Apple Health verisi kullan\u{0131}l\u{0131}yor", systemImage: "iphone")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if healthKitService.dayFraction < 0.40 && healthKitService.isAvailable {
                        Label("Sabah erken \u{2014} hesaplanan TDEE kullan\u{0131}l\u{0131}yor", systemImage: "function")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if goalEngine.healthKitBurn > 0 {
                        Label("HealthKit verisi hen\u{00FC}z yetersiz, hesaplanan TDEE kullan\u{0131}l\u{0131}yor", systemImage: "hourglass")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label("Hesaplanan form\u{00FC}l: \(Int(goalEngine.tdee)) kcal", systemImage: "function")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if goalEngine.isCalorieClamped {
                        Label("Minimum sa\u{011F}l\u{0131}kl\u{0131} kalori hedefine ayarland\u{0131}", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if goalEngine.isCapped, let reason = goalEngine.capReason {
                        Label("Hedef \u{00E7}ok agresif, g\u{00FC}venli s\u{0131}n\u{0131}ra ayarland\u{0131}", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    infoRow("TDEE", value: "\(Int(goalEngine.tdee)) kcal (g\u{00FC}ven: \(goalEngine.tdeeConfidence))")
                    if goalEngine.usingHealthKit || goalEngine.isUsingExtrapolatedTDEE {
                        infoRow("Hesaplanan TDEE", value: "\(Int(goalEngine.calculatedTDEE)) kcal")
                    }
                    if goalEngine.healthKitBurn > 0 && !goalEngine.usingHealthKit && !goalEngine.isUsingExtrapolatedTDEE {
                        infoRow("HealthKit Yak\u{0131}m", value: "\(Int(goalEngine.healthKitBurn)) kcal")
                        infoRow("BMR E\u{015F}i\u{011F}i", value: "\(Int(goalEngine.bmr)) kcal")
                    }
                    if goalEngine.isCapped {
                        infoRow("Ham A\u{00E7}\u{0131}k", value: "\(Int(goalEngine.rawDailyDeficit)) kcal")
                        infoRow("Uygulan A\u{00E7}\u{0131}k", value: "\(Int(goalEngine.cappedDailyDeficit)) kcal")
                    } else {
                        infoRow("G\u{00FC}nl\u{00FC}k A\u{00E7}\u{0131}k", value: "\(Int(goalEngine.deficit)) kcal")
                    }
                    infoRow("G\u{00FC}nl\u{00FC}k Hedef", value: "\(goalEngine.dailyCalorieTarget) kcal")
                    infoRow("Tahmini Haftal\u{0131}k De\u{011F}i\u{015F}im", value: "\(String(format: "%+.2f", goalEngine.projectedWeeklyLossKg)) kg")

                    Divider()

                    // VO2Max
                    if let vo2 = goalEngine.vo2Max {
                        infoRow("VO2 Max", value: "\(String(format: "%.1f", vo2)) ml/kg/min")
                        infoRow("Fitness", value: goalEngine.vo2MaxLevel)
                    } else {
                        infoRow("VO2 Max", value: "Veri yok")
                    }

                    // Weight from Health
                    if let w = goalEngine.latestWeightFromHealth {
                        let dateStr = goalEngine.latestWeightDate?.formatted(.dateTime.day().month(.abbreviated)) ?? ""
                        infoRow("Kilo (Health)", value: "\(String(format: "%.1f", w)) kg \u{2014} \(dateStr)")
                    }

                    Divider()

                    infoRow("BMR", value: "\(Int(goalEngine.bmr)) kcal")
                    infoRow("Aktivite \u{00C7}arpan\u{0131}", value: "\(String(format: "%.2f", goalEngine.activityMultiplier))x")
                    if goalEngine.vo2Max != nil {
                        infoRow("VO2 Ayar\u{0131}", value: "\(String(format: "%+.2f", goalEngine.vo2MaxAdjustment))")
                    }
                    infoRow("Protein Hedefi", value: "\(goalEngine.proteinTarget)g")
                    infoRow("Karb Hedefi", value: "\(goalEngine.carbTarget)g")
                    infoRow("Ya\u{011F} Hedefi", value: "\(goalEngine.fatTarget)g")
                }
                .padding()
            }
            .navigationTitle("Hedef Detaylar\u{0131}")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { showGoalInfo = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - HealthKit

    private func refreshHealthKit() async {
        guard healthKitService.isAvailable else { return }

        let extrapolated = await healthKitService.fetchTodayBurnExtrapolated(bmr: goalEngine.bmr, calculatedTDEE: goalEngine.calculatedTDEE)
        goalEngine.isEarlyMorning = healthKitService.dayFraction < 0.40
        if extrapolated > 0 {
            goalEngine.updateExtrapolatedBurn(extrapolated)
        } else {
            let burn = healthKitService.todayTotalBurn
            goalEngine.updateHealthKitBurn(burn)
            goalEngine.isUsingExtrapolatedTDEE = false
        }

        let vo2 = await healthKitService.fetchLatestVO2Max()
        goalEngine.updateVO2Max(vo2)

        _ = await healthKitService.fetchTodayHRV()
        _ = await healthKitService.fetchHRVBaseline()
        _ = await healthKitService.fetchLastNightSleep()
        _ = await healthKitService.fetchLatestWeight()
        goalEngine.syncWeight(
            healthWeight: healthKitService.latestWeight,
            healthWeightDate: healthKitService.latestWeightDate,
            profile: profiles.first
        )
        if goalEngine.weightUpdatedBanner != nil {
            showWeightBanner = true
        }
    }

    // MARK: - Snapshots

    private func saveTodaySnapshot() {
        SnapshotService.saveSnapshot(
            date: .now,
            goalEngine: goalEngine,
            consumedCalories: eatenCalories,
            consumedProtein: eatenProtein,
            consumedCarbs: eatenCarbs,
            consumedFat: eatenFat,
            modelContext: modelContext
        )
    }

    private func saveYesterdaySnapshot() {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) else { return }
        let startOfYesterday = Calendar.current.startOfDay(for: yesterday)
        let startOfToday = Calendar.current.startOfDay(for: .now)

        let yesterdayEntries = allEntries.filter { $0.date >= startOfYesterday && $0.date < startOfToday }
        let cal = yesterdayEntries.reduce(0) { $0 + $1.calories }
        let pro = yesterdayEntries.reduce(0.0) { $0 + $1.protein }
        let carb = yesterdayEntries.reduce(0.0) { $0 + $1.carbs }
        let fat = yesterdayEntries.reduce(0.0) { $0 + $1.fat }

        SnapshotService.saveSnapshot(
            date: yesterday,
            goalEngine: goalEngine,
            consumedCalories: cal,
            consumedProtein: pro,
            consumedCarbs: carb,
            consumedFat: fat,
            modelContext: modelContext
        )
    }

    // MARK: - Actions

    private func handleMicTap() {
        if speechService.isRecording {
            speechService.stopListening()
        } else {
            guard permissionGranted else { return }
            errorMessage = nil
            showSavedConfirmation = false
            if clarificationQuestion == nil {
                parsedMeals = []
                fullTranscript = ""
            }
            clarificationQuestion = nil
            do {
                try speechService.startListening()
            } catch {
                errorMessage = "Mikrofon başlatılamadı"
            }
        }
    }

    private func sendToGroq() {
        let newText = speechService.transcript
        if fullTranscript.isEmpty {
            fullTranscript = newText
        } else {
            fullTranscript += " " + newText
        }

        isAnalyzing = true
        errorMessage = nil

        Task {
            do {
                let response = try await groqService.parseMeals(transcript: fullTranscript)
                parsedMeals = response.meals
                if response.clarification_needed {
                    clarificationQuestion = response.clarification_question
                } else {
                    clarificationQuestion = nil
                    saveEntries(from: response.meals)
                }
            } catch {
                errorMessage = "Bir hata oluştu, tekrar deneyin"
            }
            isAnalyzing = false
        }
    }

    private func saveEntries(from meals: [ParsedMeal]) {
        for meal in meals {
            let entry = FoodEntry(
                name: meal.name,
                amount: meal.amount,
                calories: Int(meal.calories),
                protein: meal.protein,
                carbs: meal.carbs,
                fat: meal.fat
            )
            modelContext.insert(entry)
        }
        showSavedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSavedConfirmation = false
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
