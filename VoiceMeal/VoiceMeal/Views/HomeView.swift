//
//  HomeView.swift
//  VoiceMeal
//

import AVFoundation
import Sentry
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
    @SceneStorage("voice.clarificationQuestion") var clarificationQuestion = ""
    @SceneStorage("voice.reviewMealsJSON") private var reviewMealsJSON: String = ""
    @SceneStorage("voice.showReviewCard") var showReviewCard = false
    @SceneStorage("voice.originalSpeechText") var originalSpeechText = ""
    @SceneStorage("voice.reviewSavedAt") private var reviewSavedAtRaw: Double = 0

    var reviewMeals: [ParsedMeal] {
        get {
            guard !reviewMealsJSON.isEmpty,
                  let data = reviewMealsJSON.data(using: .utf8),
                  let meals = try? JSONDecoder().decode([ParsedMeal].self, from: data) else {
                return []
            }
            return meals
        }
        nonmutating set {
            if newValue.isEmpty {
                reviewMealsJSON = ""
                reviewSavedAtRaw = 0
            } else if let data = try? JSONEncoder().encode(newValue), data.count < 1_000_000,
                      let json = String(data: data, encoding: .utf8) {
                reviewMealsJSON = json
                reviewSavedAtRaw = Date().timeIntervalSince1970
            }
        }
    }
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
    @State var showPermissionAlert = false
    @State var showRetryButton = false
    @State var manuallyEditedMealNames: Set<String> = []
    @State var voiceReportSession: VoiceSession?
    @State var sessionBackgroundedAt: Date?
    @State var problematicSessionToReport: VoiceSession?
    @State var showProblematicPrompt = false
    @State var showReportThanksToast = false
    @EnvironmentObject var themeManager: ThemeManager

    @State var scrollToTopTrigger = false
    @State var voiceScrollTrigger = false
    @State var pendingVoiceStart = false
    @State var recordingStartedAt: Date?

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
                            gapKind: CalorieGapKind.from(signedTargetDeficit: Int(goalEngine.cappedDailyDeficit)),
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
                    .id("voiceSection")

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
                        completedWorkouts: goalEngine.completedWorkouts,
                        isObserveMode: profiles.first?.isObserveMode ?? false
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
        .onChange(of: voiceScrollTrigger) { _, _ in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                proxy.scrollTo("voiceSection", anchor: .top)
            }
        }
                }
            }

            if showPhotoLoading {
                photoLoadingOverlay
            }
        }
        .task {
            if reviewSavedAtRaw > 0 {
                let saved = Date(timeIntervalSince1970: reviewSavedAtRaw)
                if !Calendar.current.isDateInToday(saved) {
                    reviewMealsJSON = ""
                    clarificationQuestion = ""
                    showReviewCard = false
                    originalSpeechText = ""
                    reviewSavedAtRaw = 0
                }
            }
            speechService.onMaxDurationReached = {
                errorMessage = L.maxRecordingDurationReached.localized
                FeedbackService.shared.addLog("Voice recording auto-stopped: max duration reached")
                FeedbackService.shared.logVoiceEvent(icon: "⏰", message: "Max duration reached — auto stop")
            }
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
        .onChange(of: errorMessage) { _, newValue in
            guard let current = newValue else { return }
            Task {
                try? await Task.sleep(for: .seconds(5))
                if errorMessage == current {
                    errorMessage = nil
                }
            }
        }
        .onChange(of: speechService.isRecording) { oldValue, newValue in
            if oldValue && !newValue {
                if let startedAt = recordingStartedAt {
                    if Date().timeIntervalSince(startedAt) <= 2.0 {
                        FeedbackService.shared.addLog("auto_record_cancelled")
                    }
                    recordingStartedAt = nil
                }
                if let speechError = speechService.lastError {
                    errorMessage = speechError
                    FeedbackService.shared.logVoiceEvent(
                        icon: "❌",
                        message: "Speech error: \(speechError)"
                    )
                } else if !speechService.transcript.isEmpty {
                    FeedbackService.shared.logVoiceEvent(
                        icon: "⏹",
                        message: "Record stopped",
                        data: ["chars": "\(speechService.transcript.count)"]
                    )
                    sendToGroq()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await refreshHealthKit()
                    if SnapshotService.snapshotNeedsUpdate(for: .now, modelContext: modelContext) {
                        saveTodaySnapshot()
                    }
                    loadMorningTDEE()
                }
                // Abandonment check: if we backgrounded mid-review and stayed >= 60s away
                if let bgAt = sessionBackgroundedAt {
                    let elapsed = Date().timeIntervalSince(bgAt)
                    if elapsed >= 60, FeedbackService.shared.currentVoiceSession != nil {
                        FeedbackService.shared.logVoiceEvent(
                            icon: "⏳",
                            message: "Abandoned after \(Int(elapsed))s background"
                        )
                        FeedbackService.shared.endVoiceSession(reason: .abandoned)
                    }
                    sessionBackgroundedAt = nil
                }
            } else if newPhase == .background {
                if speechService.isRecording {
                    speechService.cancelListening()
                    FeedbackService.shared.addLog("Voice cancelled due to background transition")
                    FeedbackService.shared.logVoiceEvent(icon: "❌", message: "Cancelled: app backgrounded")
                    FeedbackService.shared.endVoiceSession(reason: .cancelled)
                } else if FeedbackService.shared.currentVoiceSession != nil && showReviewCard {
                    // Arm the abandonment timer — finalized on foreground if >= 60s elapsed
                    sessionBackgroundedAt = Date()
                }
            }
        }
        .sensoryFeedback(.success, trigger: showSavedConfirmation) { _, newValue in newValue }
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
        .onReceive(NotificationCenter.default.publisher(for: .foodEntrySaved)) { _ in
            saveTodaySnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetDeepLinkRecord)) { _ in
            pendingVoiceStart = true
        }
        .onChange(of: pendingVoiceStart) { _, shouldStart in
            guard shouldStart else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                let deadline = Date().addingTimeInterval(1.5)
                while !permissionGranted && Date() < deadline {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                guard permissionGranted else {
                    errorMessage = "mic_permission_denied".localized
                    FeedbackService.shared.addLog("auto_record_blocked: no mic permission")
                    pendingVoiceStart = false
                    return
                }
                FeedbackService.shared.addLog("auto_record_started")
                recordingStartedAt = Date()
                handleMicTap()
                pendingVoiceStart = false
            }
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
        .sheet(item: $voiceReportSession) { session in
            FeedbackSheet(
                isPresented: Binding(
                    get: { voiceReportSession != nil },
                    set: { if !$0 { voiceReportSession = nil } }
                ),
                appLanguage: groqService.appLanguage,
                voiceSession: session
            )
            .environmentObject(themeManager)
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
        .alert(L.permissionRequiredTitle.localized, isPresented: $showPermissionAlert) {
            Button(L.openSettings.localized) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L.cancel.localized, role: .cancel) {}
        } message: {
            Text(L.permissionRequiredMessage.localized)
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
        .modifier(
            VoiceReportPromptModifier(
                appLanguage: groqService.appLanguage,
                showPrompt: $showProblematicPrompt,
                session: $problematicSessionToReport,
                showThanksToast: $showReportThanksToast
            )
        )
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
        let descriptor = FetchDescriptor<UserProfile>()
        let freshProfiles = (try? modelContext.fetch(descriptor)) ?? []
        let isObserve = freshProfiles.first?.isObserveMode ?? profiles.first?.isObserveMode ?? false

        let remaining = goalEngine.dailyCalorieTarget - eatenCalories
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let todayEntriesSorted = allEntries
            .filter { $0.date >= startOfDay }
            .sorted { $0.date > $1.date }
        let recentMeals = todayEntriesSorted.prefix(3).map {
            WidgetMealEntry(name: $0.name, calories: $0.calories, date: $0.date)
        }

        let data = WidgetData(
            consumedCalories: eatenCalories,
            targetCalories: goalEngine.dailyCalorieTarget,
            remainingCalories: remaining,
            targetDeficit: Int(goalEngine.cappedDailyDeficit),
            actualDeficit: Int(goalEngine.tdee) - eatenCalories,
            proteinEaten: eatenProtein,
            proteinTarget: Double(goalEngine.proteinTarget),
            lastMeals: Array(recentMeals),
            theme: ThemeManager.shared.current.rawValue,
            waterConsumed: isWaterTrackingEnabled ? todayWaterMl : 0,
            waterGoal: isWaterTrackingEnabled ? waterGoalService.dailyGoalMl : 0,
            lastUpdated: Date(),
            isObserveMode: isObserve
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
        if profiles.first?.isObserveMode == true { return false }
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
