//
//  HomeView.swift
//  VoiceMeal
//

import AVFoundation
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @StateObject var speechService = SpeechService()
    @Query(sort: \FoodEntry.date, order: .reverse) var allEntries: [FoodEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) var allWaterEntries: [WaterEntry]
    @Query var profiles: [UserProfile]
    @State var permissionGranted = false
    @State var isAnalyzing = false
    @State var errorMessage: String?
    @State var showSavedConfirmation = false
    @State var clarificationQuestion = ""
    @State var reviewMeals: [ParsedMeal] = []
    @State var showReviewCard = false
    @State var originalSpeechText = ""
    @State var fixingMealName: String?
    @State var showGoalInfo = false
    @State var showWeightBanner = false
    @State var showSettings = false
    @State var entryToEdit: FoodEntry?
    @State var entryToDelete: FoodEntry?
    @State var showDeleteAlert = false
    @State var showCorrected = false
    @State var correctionPickerEntries: [FoodEntry]?
    @Environment(GoalEngine.self) var goalEngine
    @State var healthKitService = HealthKitService()
    @State var waterGoalService = WaterGoalService()
    @State var tdeeWarningDismissed = false
    @State var showGoalUpdatedToast = false
    @State var entryToCorrect: FoodEntry?
    @State var correctionQuestion = ""

    @State var scrollToTopTrigger = false

    @State var showCamera = false
    @State var capturedImage: UIImage?
    @State var capturedImageData: Data?
    @State var showPhotoAnalysis = false
    @State var showPhotoLoading = false
    @State var pendingPhotoAnalysis = false
    @State var showCameraPermissionDenied = false
    @State var showNutritionCheck = false
    @State var showBarcodeScanner = false

    @Environment(GroqService.self) var groqService

    var todayEntries: [FoodEntry] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= startOfDay }
    }

    var todayWaterEntries: [WaterEntry] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allWaterEntries.filter { $0.date >= startOfDay }
    }

    var todayWaterMl: Int { todayWaterEntries.reduce(0) { $0 + $1.amountMl } }
    var isWaterTrackingEnabled: Bool { profiles.first?.isWaterTrackingEnabled ?? false }
    var eatenCalories: Int { todayEntries.reduce(0) { $0 + $1.calories } }
    var eatenProtein: Double { todayEntries.reduce(0.0) { $0 + $1.protein } }
    var eatenCarbs: Double { todayEntries.reduce(0.0) { $0 + $1.carbs } }
    var eatenFat: Double { todayEntries.reduce(0.0) { $0 + $1.fat } }
    var isListening: Bool { speechService.isRecording }

    var remainingCalories: Int {
        goalEngine.dailyCalorieTarget - eatenCalories
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // STICKY HEADER BAR
                HStack {
                    Text(L.record.localized)
                        .font(.headline.bold())
                        .foregroundStyle(.white)

                    Spacer()

                    if goalEngine.profile != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(Theme.orange)
                                .font(.caption)
                            Text("\(remainingCalories) kcal")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }

                    Button {
                        scrollToTopTrigger.toggle()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(
                    Theme.gradientTop.opacity(0.95)
                        .ignoresSafeArea(edges: .top)
                )
                .overlay(
                    Divider().opacity(0.2),
                    alignment: .bottom
                )

                // SCROLLABLE CONTENT
                ScrollViewReader { proxy in
                ScrollView {
            VStack(spacing: 24) {
                Color.clear.frame(height: 0).id("top")

                if showWeightBanner, let banner = goalEngine.weightUpdatedBanner {
                    HStack {
                        Text(banner)
                            .font(Theme.bodyFont)
                        Spacer()
                        Button {
                            showWeightBanner = false
                            goalEngine.dismissWeightBanner()
                        } label: {
                            Image(systemName: "xmark")
                                .font(Theme.captionFont)
                        }
                    }
                    .padding()
                    .background(Theme.green.opacity(0.15))
                    .themeCard()
                }

                if goalEngine.profile != nil {
                    dailyGoalCard

                    if shouldShowTdeeBanner {
                        TDEEWarningBanner(
                            hasWorkout: goalEngine.hasWorkoutToday,
                            currentGoal: goalEngine.dailyCalorieTarget,
                            updatedGoal: goalEngine.updatedEatingGoalIfAccepted,
                            onAccept: { applyTDEEUpdate() },
                            onDismiss: { dismissTdeeWarning() }
                        )
                    }

                    if showGoalUpdatedToast {
                        HStack {
                            Text("✅ \("goal_updated_toast".localized)")
                                .font(Theme.bodyFont)
                                .foregroundStyle(Theme.green)
                            Spacer()
                        }
                        .padding()
                        .background(Theme.green.opacity(0.15))
                        .themeCard()
                        .transition(.opacity)
                    }
                }

                mealEntrySection

                if showReviewCard && !reviewMeals.isEmpty {
                    mealReviewCard
                }

                errorSection

                mealListSection

                if goalEngine.profile != nil {
                    DailyInsightCard(
                        hrvStatus: healthKitService.hrvStatus,
                        todayHRV: healthKitService.todayHRV,
                        hrvBaseline: healthKitService.hrvBaseline,
                        sleep: healthKitService.lastNightSleep,
                        todayActivities: goalEngine.todayActivityNames,
                        consumed: eatenCalories,
                        dailyCalorieTarget: goalEngine.dailyCalorieTarget,
                        remainingCalories: goalEngine.dailyCalorieTarget - eatenCalories,
                        targetDeficit: Int(goalEngine.cappedDailyDeficit),
                        actualDeficit: Int(goalEngine.tdee) - eatenCalories,
                        deficitGap: Int(goalEngine.cappedDailyDeficit) - (Int(goalEngine.tdee) - eatenCalories),
                        proteinConsumed: eatenProtein,
                        proteinTarget: goalEngine.proteinTarget,
                        tdee: Int(goalEngine.tdee),
                        waterMl: isWaterTrackingEnabled ? todayWaterMl : 0,
                        waterGoalMl: isWaterTrackingEnabled ? waterGoalService.dailyGoalMl : 0,
                        coachStyle: profiles.first?.coachStyle ?? .supportive,
                        personalContext: profiles.first?.fullAIContext ?? "",
                        completedWorkouts: goalEngine.completedWorkouts
                    )

                    if isWaterTrackingEnabled {
                        WaterTrackingCard(
                            todayWaterMl: todayWaterMl,
                            goalMl: waterGoalService.dailyGoalMl,
                            todayEntries: todayWaterEntries,
                            onAdd: { ml, source in
                                addWater(ml: ml, source: source)
                            },
                            onDelete: { entry in
                                modelContext.delete(entry)
                                try? modelContext.save()
                                saveTodaySnapshot()
                            }
                        )
                    }
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .onChange(of: scrollToTopTrigger) { _, _ in
            withAnimation {
                proxy.scrollTo("top", anchor: .top)
            }
        }
                }
            }

            if showPhotoLoading {
                photoLoadingOverlay
            }
        }
        .task {
            permissionGranted = await speechService.requestPermissions()
            if healthKitService.isAvailable {
                await healthKitService.requestPermission()
                await refreshHealthKit()
            }
            saveTodaySnapshot()
            loadMorningTDEE()
            if let p = profiles.first {
                NotificationService.shared.reschedule(profile: p)
                await NotificationService.shared.checkAndRescheduleWeightReminder(profile: p)
            }
        }
        .onChange(of: speechService.isRecording) { oldValue, newValue in
            if oldValue && !newValue {
                if let speechError = speechService.lastError {
                    errorMessage = speechError
                } else if !speechService.transcript.isEmpty {
                    sendToGroq()
                }
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    await refreshHealthKit()
                    if SnapshotService.snapshotNeedsUpdate(for: .now, modelContext: modelContext) {
                        saveTodaySnapshot()
                    }
                    loadMorningTDEE()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task {
                saveYesterdaySnapshot()
                await refreshHealthKit()
                saveTodaySnapshot()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileUpdated)) { _ in
            saveTodaySnapshot()
        }
        .sheet(isPresented: $showGoalInfo) {
            goalInfoSheet
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $entryToEdit) { entry in
            EditFoodEntryView(entry: entry) {
                saveTodaySnapshot()
            }
        }
        .alert("delete_confirm".localized, isPresented: $showDeleteAlert) {
            Button(L.delete.localized, role: .destructive) {
                if let entry = entryToDelete {
                    modelContext.delete(entry)
                    try? modelContext.save()
                    saveTodaySnapshot()
                }
                entryToDelete = nil
            }
            Button(L.cancel.localized, role: .cancel) {
                entryToDelete = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            if capturedImageData != nil || capturedImage != nil {
                showPhotoLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showPhotoAnalysis = true
                    showPhotoLoading = false
                }
            } else {
                pendingPhotoAnalysis = true
            }
        }) {
            CameraPicker { image in
                capturedImage = image
                Task.detached(priority: .userInitiated) {
                    let data = GroqService.compressImage(image)
                    await MainActor.run {
                        if let data {
                            capturedImageData = data
                            if pendingPhotoAnalysis {
                                pendingPhotoAnalysis = false
                                showPhotoLoading = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showPhotoAnalysis = true
                                    showPhotoLoading = false
                                }
                            }
                        } else {
                            #if DEBUG
                            print("📷 [ERROR] Compression returned nil")
                            #endif
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoAnalysis) {
            if let image = capturedImage, let data = capturedImageData {
                PhotoAnalysisView(
                    image: image,
                    imageData: data,
                    onSave: { meals in
                        reviewMeals = meals
                        showReviewCard = true
                    },
                    onRetake: {
                        showCamera = true
                    }
                )
                .presentationBackground(Color(hex: "0A0A0F"))
            }
        }
        .alert("Kamera \u{0130}zni Gerekli", isPresented: $showCameraPermissionDenied) {
            Button("Ayarlar\u{0131} A\u{00E7}") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("\u{0130}ptal", role: .cancel) {}
        } message: {
            Text("Yemek foto\u{011F}raf\u{0131} \u{00E7}ekmek i\u{00E7}in kamera iznine ihtiyac\u{0131}m\u{0131}z var. Ayarlar'dan kamera iznini a\u{00E7}abilirsiniz.")
        }
        .sheet(isPresented: $showNutritionCheck) {
            nutritionCheckSheet
        }
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeResultView()
        }
    }

    // MARK: - HealthKit

    func refreshHealthKit() async {
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

        let activeEnergy = await healthKitService.fetchTodayActiveEnergy()
        waterGoalService.calculate(
            weightKg: profiles.first?.currentWeightKg ?? 70,
            activeEnergyKcal: activeEnergy,
            overrideMl: profiles.first?.waterGoalOverrideMl
        )

        let vo2 = await healthKitService.fetchLatestVO2Max()
        goalEngine.updateVO2Max(vo2)

        _ = await healthKitService.fetchTodayHRV()
        _ = await healthKitService.fetchHRVBaseline()
        _ = await healthKitService.fetchLastNightSleep()
        _ = await healthKitService.fetchLatestWeight()
        goalEngine.completedWorkouts = await healthKitService.fetchTodayWorkouts()
        goalEngine.syncWeight(
            healthWeight: healthKitService.latestWeight,
            healthWeightDate: healthKitService.latestWeightDate,
            profile: profiles.first
        )
        if goalEngine.weightUpdatedBanner != nil {
            showWeightBanner = true
        }
        if let p = profiles.first {
            Task {
                await NotificationService.shared.checkAndRescheduleWeightReminder(profile: p)
            }
        }
    }

    // MARK: - Snapshots

    func saveTodaySnapshot() {
        SnapshotService.saveSnapshot(
            date: .now,
            goalEngine: goalEngine,
            consumedCalories: eatenCalories,
            consumedProtein: eatenProtein,
            consumedCarbs: eatenCarbs,
            consumedFat: eatenFat,
            modelContext: modelContext,
            totalWaterMl: isWaterTrackingEnabled ? todayWaterMl : 0,
            waterGoalMl: isWaterTrackingEnabled ? waterGoalService.dailyGoalMl : 0
        )
        updateWidgetData()
    }

    func updateWidgetData() {
        let remaining = goalEngine.dailyCalorieTarget - eatenCalories
        let data = WidgetData(
            consumedCalories: eatenCalories,
            targetCalories: goalEngine.dailyCalorieTarget,
            remainingCalories: remaining,
            targetDeficit: Int(goalEngine.cappedDailyDeficit),
            actualDeficit: Int(goalEngine.tdee) - eatenCalories,
            waterConsumed: isWaterTrackingEnabled ? todayWaterMl : 0,
            waterGoal: isWaterTrackingEnabled ? waterGoalService.dailyGoalMl : 0,
            lastUpdated: Date()
        )
        WidgetDataStore.shared.save(data)
        FeedbackService.shared.addLog("Widget updated: \(eatenCalories)kcal eaten, \(remaining)kcal left")
    }

    func saveYesterdaySnapshot() {
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

    // MARK: - TDEE Warning

    var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    var isTdeeWarningDismissedToday: Bool {
        UserDefaults.standard.bool(forKey: "tdeeWarningDismissed_\(todayKey)")
    }

    var shouldShowTdeeBanner: Bool {
        guard goalEngine.isInBannerWindow,
              !tdeeWarningDismissed,
              !isTdeeWarningDismissedToday,
              healthKitService.todayActiveEnergy <= 300 else { return false }

        if goalEngine.hasWorkoutToday {
            return true
        }
        return goalEngine.tdeeDropWarning
    }

    func dismissTdeeWarning() {
        UserDefaults.standard.set(true, forKey: "tdeeWarningDismissed_\(todayKey)")
        tdeeWarningDismissed = true
    }

    func loadMorningTDEE() {
        if let snapshot = SnapshotService.fetchSnapshot(for: .now, modelContext: modelContext),
           snapshot.morningTDEE > 0 {
            goalEngine.todayMorningTDEE = snapshot.morningTDEE
        }
    }

    func applyTDEEUpdate() {
        if let snapshot = SnapshotService.fetchSnapshot(for: .now, modelContext: modelContext) {
            snapshot.dailyCalorieTarget = goalEngine.updatedEatingGoalIfAccepted
        }
        dismissTdeeWarning()
        withAnimation {
            showGoalUpdatedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showGoalUpdatedToast = false
            }
        }
    }

    // MARK: - Water

    func addWater(ml: Int, source: String) {
        let entry = WaterEntry(amountMl: ml, source: source)
        modelContext.insert(entry)
        try? modelContext.save()
        saveTodaySnapshot()
    }
}

#Preview {
    HomeView()
        .environment(GoalEngine())
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self, WaterEntry.self], inMemory: true)
}
