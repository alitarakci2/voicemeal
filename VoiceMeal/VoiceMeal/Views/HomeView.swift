//
//  HomeView.swift
//  VoiceMeal
//

import AVFoundation
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var speechService = SpeechService()
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var allWaterEntries: [WaterEntry]
    @Query private var profiles: [UserProfile]
    @State private var permissionGranted = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showSavedConfirmation = false
    @State private var clarificationQuestion = ""
    @State private var reviewMeals: [ParsedMeal] = []
    @State private var showReviewCard = false
    @State private var originalSpeechText = ""
    @State private var fixingMealName: String?
    @State private var showGoalInfo = false
    @State private var showWeightBanner = false
    @State private var showSettings = false
    @State private var entryToEdit: FoodEntry?
    @State private var entryToDelete: FoodEntry?
    @State private var showDeleteAlert = false
    @State private var showCorrected = false
    @State private var correctionPickerEntries: [FoodEntry]?
    @Environment(GoalEngine.self) private var goalEngine
    @State private var healthKitService = HealthKitService()
    @State private var waterGoalService = WaterGoalService()
    @State private var tdeeWarningDismissed = false
    @State private var showGoalUpdatedToast = false
    @State private var entryToCorrect: FoodEntry?
    @State private var correctionQuestion = ""

    // Scroll state
    @State private var scrollProxy: ScrollViewProxy?

    // Camera state
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var capturedImageData: Data?
    @State private var showPhotoAnalysis = false
    @State private var pendingPhotoAnalysis = false
    @State private var showCameraPermissionDenied = false
    @State private var showNutritionCheck = false
    @State private var showBarcodeScanner = false

    @Environment(GroqService.self) private var groqService

    private var todayEntries: [FoodEntry] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= startOfDay }
    }

    private var todayWaterEntries: [WaterEntry] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allWaterEntries.filter { $0.date >= startOfDay }
    }

    private var todayWaterMl: Int { todayWaterEntries.reduce(0) { $0 + $1.amountMl } }

    private var isWaterTrackingEnabled: Bool { profiles.first?.isWaterTrackingEnabled ?? false }

    private var eatenCalories: Int { todayEntries.reduce(0) { $0 + $1.calories } }
    private var eatenProtein: Double { todayEntries.reduce(0.0) { $0 + $1.protein } }
    private var eatenCarbs: Double { todayEntries.reduce(0.0) { $0 + $1.carbs } }
    private var eatenFat: Double { todayEntries.reduce(0.0) { $0 + $1.fat } }

    private var isListening: Bool { speechService.isRecording }

    private var remainingCalories: Int {
        goalEngine.dailyCalorieTarget - eatenCalories
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Full screen gradient
            themeManager.current.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // STICKY HEADER BAR
                HStack {
                    Text(groqService.appLanguage == "en" ? "Record" : "Kayıt")
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
                        withAnimation {
                            scrollProxy?.scrollTo("top", anchor: .top)
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(themeManager.current.accent)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(
                    themeManager.current.gradientTop.opacity(0.95)
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
                // Weight update banner
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

                // Daily goal card
                if goalEngine.profile != nil {
                    dailyGoalCard

                    // TDEE evening banner
                    if shouldShowTdeeBanner {
                        TDEEWarningBanner(
                            hasWorkout: goalEngine.hasWorkoutToday,
                            currentGoal: goalEngine.dailyCalorieTarget,
                            updatedGoal: goalEngine.updatedEatingGoalIfAccepted,
                            onAccept: {
                                applyTDEEUpdate()
                            },
                            onDismiss: {
                                dismissTdeeWarning()
                            }
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

                // Input label
                Text(L.whatDidYouEat.localized)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)

                // Dual buttons: Mic + Camera
                HStack(spacing: 24) {
                    // Mic button
                    VStack(spacing: 8) {
                        Button {
                            handleMicTap()
                        } label: {
                            Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(speechService.isRecording ? Theme.red : themeManager.current.cardBackground)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(speechService.isRecording ? Theme.red.opacity(0.4) : themeManager.current.cardBorder.opacity(0.6), lineWidth: 2)
                                )
                                .shadow(color: speechService.isRecording ? Theme.red.opacity(0.5) : themeManager.current.accent.opacity(0.25), radius: 12, y: 2)
                        }
                        .disabled(isAnalyzing)
                        .sensoryFeedback(.impact, trigger: speechService.isRecording)

                        Text("voice_record".localized)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    // Camera button
                    VStack(spacing: 8) {
                        Button {
                            handleCameraTap()
                        } label: {
                            Image(systemName: "camera")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(themeManager.current.cardBackground)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(themeManager.current.cardBorder.opacity(0.6), lineWidth: 2)
                                )
                                .shadow(color: themeManager.current.accent.opacity(0.25), radius: 12, y: 2)
                        }
                        .disabled(isAnalyzing)

                        Text("photo_record".localized)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    // Barcode button
                    VStack(spacing: 8) {
                        Button {
                            showBarcodeScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(themeManager.current.cardBackground)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(themeManager.current.cardBorder.opacity(0.6), lineWidth: 2)
                                )
                                .shadow(color: themeManager.current.accent.opacity(0.25), radius: 12, y: 2)
                        }
                        .disabled(isAnalyzing)

                        Text("barcode_record".localized)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                // Status label
                if isAnalyzing {
                    ProgressView(L.analyzing.localized)
                } else if showCorrected {
                    Text("corrected_confirmation".localized)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                } else if showSavedConfirmation {
                    Text("saved_confirmation".localized)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.green)
                } else {
                    Text(speechService.isRecording ? "listening".localized : L.ready.localized)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(speechService.isRecording ? Theme.red : Theme.textSecondary)
                }

                // Per-item correction prompt (for saved entries)
                if !correctionQuestion.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\u{270F}\u{FE0F}")
                        Text(correctionQuestion)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Review card — shows parsed meals for review/fix/save
                if showReviewCard && !reviewMeals.isEmpty {
                    mealReviewCard
                }

                // Error
                if let error = errorMessage {
                    VStack(spacing: 4) {
                        Text("\u{26A0}\u{FE0F} Hata")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.red)
                        Text(error)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Today's meal list
                if !todayEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("today_foods".localized)
                                .font(Theme.headlineFont)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Button {
                                showNutritionCheck = true
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .font(Theme.bodyFont)
                                    .foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 8)

                        ForEach(todayEntries, id: \.id) { entry in
                            HStack(alignment: .center, spacing: 4) {
                                FoodEntryRowView(entry: entry)

                                Button {
                                    startVoiceCorrection(for: entry)
                                } label: {
                                    Text("fix_entry".localized)
                                        .font(.caption)
                                        .foregroundStyle(Theme.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.accent.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                Button {
                                    entryToEdit = entry
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                                Button {
                                    entryToDelete = entry
                                    showDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.red)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                            if entry.id != todayEntries.last?.id {
                                Divider()
                                    .overlay(Theme.cardBorder.opacity(0.5))
                                    .padding(.leading)
                            }
                        }

                        // Total row
                        Divider()
                            .overlay(Theme.cardBorder)
                            .padding(.horizontal)

                        HStack {
                            Text(L.total.localized)
                                .font(Theme.bodyFont)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(eatenCalories) kcal")
                                .font(Theme.bodyFont)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)

                        HStack(spacing: 6) {
                            Spacer()
                            MacroTotalPill("P", value: Int(eatenProtein), color: Theme.blue)
                            MacroTotalPill("K", value: Int(eatenCarbs), color: Theme.orange)
                            MacroTotalPill("Y", value: Int(eatenFat), color: Color(hex: "FF6B9D"))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    .themeCard()
                }

                // Correction picker
                if let entries = correctionPickerEntries {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("which_entry_correct".localized)
                            .font(Theme.bodyFont)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.orange)
                        ForEach(entries, id: \.id) { entry in
                            Button {
                                entryToEdit = entry
                                correctionPickerEntries = nil
                            } label: {
                                HStack {
                                    Text(entry.name)
                                    Spacer()
                                    Text("\(entry.calories) kcal")
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Theme.orange.opacity(0.1))
                    .themeCard()
                }

                // Daily insight card
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
                        intensityLevel: goalEngine.profile?.intensityLevel ?? 0.5,
                        waterMl: isWaterTrackingEnabled ? todayWaterMl : 0,
                        waterGoalMl: isWaterTrackingEnabled ? waterGoalService.dailyGoalMl : 0,
                        coachStyle: profiles.first?.coachStyle ?? .supportive,
                        personalContext: profiles.first?.personalContext ?? ""
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
        } // ScrollView
        .onAppear { scrollProxy = proxy }
                } // ScrollViewReader
            } // VStack (sticky header + scroll)
        } // ZStack
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
            if capturedImageData != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showPhotoAnalysis = true
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
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showPhotoAnalysis = true
                                }
                            }
                        } else {
                            print("📷 [ERROR] Compression returned nil")
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

    // MARK: - Meal Review Card

    private var mealReviewCard: some View {
        let isEN = groqService.appLanguage == "en"
        return VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEN ? "Review your meals" : "Yemekleri kontrol et")
                    .font(Theme.bodyFont)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { resetVoiceState() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.textTertiary)
                        .opacity(isListening ? 0.4 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(isListening)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().overlay(Theme.cardBorder.opacity(0.3)).padding(.horizontal)

            // Meal list
            ForEach(Array(reviewMeals.enumerated()), id: \.offset) { index, meal in
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(mealEmoji(for: meal.name))
                            .font(.title3)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(meal.name.capitalized)
                                .font(Theme.bodyFont)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.textPrimary)

                            if !meal.amount.isEmpty {
                                Text(meal.amount)
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            HStack(spacing: 6) {
                                Text("\(Int(meal.calories ?? 0)) kcal")
                                    .font(Theme.captionFont)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                Text("P:\(Int(meal.protein ?? 0))g")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.blue.opacity(0.8))
                                Text("K:\(Int(meal.carbs ?? 0))g")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.orange.opacity(0.8))
                                Text("Y:\(Int(meal.fat ?? 0))g")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.green.opacity(0.8))
                            }
                        }

                        Spacer()

                        // Fix button
                        Button { startFixingReviewMeal(meal) } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 10))
                                Text(isEN ? "Fix" : "Düzelt")
                                    .font(.caption)
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .opacity(isListening ? 0.4 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .disabled(isListening)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if index < reviewMeals.count - 1 {
                        Divider().overlay(Theme.cardBorder.opacity(0.2)).padding(.horizontal, 16)
                    }
                }
            }

            // Clarification inside review card
            if !clarificationQuestion.isEmpty {
                Divider().overlay(Theme.cardBorder.opacity(0.3)).padding(.horizontal)
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{1F916}")
                    Text(clarificationQuestion)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Text(isEN ? "Tap mic to answer" : "Cevaplamak i\u{00E7}in mikrofona bas")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            // Fix-mode prompt
            if let fixing = fixingMealName {
                Divider().overlay(Theme.cardBorder.opacity(0.3)).padding(.horizontal)
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{270F}\u{FE0F}")
                    Text(isEN
                        ? "Tell me about \(fixing) — amount, brand, or correct values"
                        : "\(fixing) hakk\u{0131}nda s\u{00F6}yle — miktar, marka veya de\u{011F}erleri d\u{00FC}zelt")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            // Listening indicator
            if isListening {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.red)
                        .frame(width: 8, height: 8)
                    Text(isEN ? "Listening..." : "Dinliyorum...")
                        .font(.caption)
                        .foregroundStyle(Theme.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            Divider().overlay(Theme.cardBorder.opacity(0.3)).padding(.horizontal)

            // Total + Save
            VStack(spacing: 8) {
                HStack {
                    Text(isEN ? "Total" : "Toplam")
                        .font(Theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(reviewMeals.reduce(0) { $0 + Int($1.calories ?? 0) }) kcal")
                        .font(Theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accent)
                }

                Button {
                    saveEntries(from: reviewMeals)
                    resetVoiceState()
                } label: {
                    Label(isEN ? "Save All" : "Kaydet", systemImage: "checkmark")
                        .font(Theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isListening ? Theme.accent.opacity(0.4) : Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isListening)
            }
            .padding(16)
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func startVoiceCorrection(for entry: FoodEntry) {
        resetVoiceState()
        entryToCorrect = entry
        correctionQuestion = String(format: "what_to_change".localized, entry.name)
        errorMessage = nil
        showSavedConfirmation = false
        do {
            try speechService.startListening()
        } catch {
            errorMessage = speechService.lastError ?? "mic_error".localized
        }
    }

    private func startFixingReviewMeal(_ meal: ParsedMeal) {
        fixingMealName = meal.name
        errorMessage = nil
        do {
            try speechService.startListening()
        } catch {
            errorMessage = speechService.lastError ?? "mic_error".localized
            fixingMealName = nil
        }
    }

    private func resetVoiceState() {
        clarificationQuestion = ""
        correctionQuestion = ""
        entryToCorrect = nil
        fixingMealName = nil
        reviewMeals = []
        showReviewCard = false
        originalSpeechText = ""
    }

    // MARK: - Daily Goal Card

    private var dailyGoalCard: some View {
        let remaining = goalEngine.dailyCalorieTarget - eatenCalories
        let targetDeficit = Int(goalEngine.cappedDailyDeficit)
        let actualDeficit = Int(goalEngine.tdee) - eatenCalories
        let eatingProgress = goalEngine.dailyCalorieTarget > 0
            ? min(Double(eatenCalories) / Double(goalEngine.dailyCalorieTarget), 1.0) : 0
        let deficitProgress = targetDeficit > 0
            ? min(max(Double(actualDeficit) / Double(targetDeficit), 0), 1.0) : 0

        return VStack(spacing: 16) {
            // Header row: date + activity + buttons
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    let names = goalEngine.todayActivityNames
                        .compactMap { GoalEngine.activityDisplayNames[$0] }
                    if !names.isEmpty {
                        Text(names.joined(separator: " · "))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer()
                HStack(spacing: 14) {
                    Button { Task { await refreshHealthKit() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Button { showGoalInfo = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            // 2x2 Metric ring grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                // Eating Goal ring
                metricRingCard(
                    title: "eating_goal".localized,
                    value: "\(eatenCalories)",
                    subtitle: "/ \(goalEngine.dailyCalorieTarget) kcal",
                    progress: eatingProgress,
                    ringColor: remaining < 0 ? Theme.red : themeManager.current.accent
                )

                // Deficit ring
                metricRingCard(
                    title: "calorie_deficit_label".localized,
                    value: "\(actualDeficit)",
                    subtitle: "/ \(targetDeficit) kcal",
                    progress: deficitProgress,
                    ringColor: actualDeficit < 0 ? Theme.red : Theme.green
                )

                // Remaining
                metricStatCard(
                    title: "remaining_label".localized,
                    value: "\(remaining)",
                    unit: "kcal",
                    color: remaining < 0 ? Theme.red : Theme.green
                )

                // TDEE
                metricStatCard(
                    title: "TDEE",
                    value: "\(Int(goalEngine.tdee))",
                    unit: "kcal",
                    color: .white
                )
            }

            // Macro progress rows
            VStack(spacing: 8) {
                macroProgressRow(label: "pro_short".localized, value: eatenProtein, target: Double(goalEngine.proteinTarget), color: Theme.blue)
                macroProgressRow(label: "carb_short".localized, value: eatenCarbs, target: Double(goalEngine.carbTarget), color: Theme.orange)
                macroProgressRow(label: "fat_short".localized, value: eatenFat, target: Double(goalEngine.fatTarget), color: Color(hex: "FF6B9D"))
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(themeManager.current.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(themeManager.current.cardBorder.opacity(0.5), lineWidth: 1)
        )
    }

    private func metricRingCard(title: String, value: String, subtitle: String, progress: Double, ringColor: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            ZStack {
                Circle()
                    .stroke(Theme.trackBackground, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 70, height: 70)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func metricStatCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func macroProgressRow(label: String, value: Double, target: Double, color: Color) -> some View {
        let progress = target > 0 ? min(value / target, 1.0) : 0
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 16, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.trackBackground)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(geo.size.width * progress, 3))
                }
            }
            .frame(height: 6)

            Text("\(Int(value))/\(Int(target))g")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 60, alignment: .trailing)
        }
    }

    // MARK: - Nutrition Check Sheet

    private func generateNutritionCheckText(entries: [FoodEntry]) -> String {
        var lines: [String] = []
        for entry in entries {
            if !entry.amount.isEmpty {
                lines.append("\(entry.amount) \(entry.name)")
            } else {
                lines.append(entry.name)
            }
        }
        let foodList = lines.joined(separator: ", ")
        return String(format: "nutrition_check_prompt".localized, foodList)
    }

    private var nutritionCheckSheet: some View {
        let text = generateNutritionCheckText(entries: todayEntries)
        return NavigationStack {
            ScrollView {
                Text(text)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.background)
            .navigationTitle("nutrition_check".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.close.localized) {
                        showNutritionCheck = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
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
                        Label(String(format: "extrapolation_active_format".localized, pct), systemImage: "iphone")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.blue)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if goalEngine.usingHealthKit {
                        Label("using_apple_health".localized, systemImage: "iphone")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.green)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if healthKitService.dayFraction < 0.40 && healthKitService.isAvailable {
                        Label("early_morning_tdee".localized, systemImage: "function")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if goalEngine.healthKitBurn > 0 {
                        Label("healthkit_insufficient".localized, systemImage: "hourglass")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label(String(format: "calculated_formula_format".localized, Int(goalEngine.tdee)), systemImage: "function")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if goalEngine.isCalorieClamped {
                        Label("min_healthy_calorie".localized, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if goalEngine.isCapped, let reason = goalEngine.capReason {
                        Label("goal_too_aggressive".localized, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(reason)
                            .font(Theme.microFont)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Divider()

                    infoRow("tdee_label".localized, value: "\(Int(goalEngine.tdee)) kcal (\("confidence_label".localized): \(goalEngine.tdeeConfidence))")
                    if goalEngine.usingHealthKit || goalEngine.isUsingExtrapolatedTDEE {
                        infoRow("calculated_tdee".localized, value: "\(Int(goalEngine.calculatedTDEE)) kcal")
                    }
                    if goalEngine.healthKitBurn > 0 && !goalEngine.usingHealthKit && !goalEngine.isUsingExtrapolatedTDEE {
                        infoRow("healthkit_burn".localized, value: "\(Int(goalEngine.healthKitBurn)) kcal")
                        infoRow("bmr_threshold".localized, value: "\(Int(goalEngine.bmr)) kcal")
                    }
                    if goalEngine.isCapped {
                        infoRow("raw_deficit".localized, value: "\(Int(goalEngine.rawDailyDeficit)) kcal")
                        infoRow("applied_deficit".localized, value: "\(Int(goalEngine.cappedDailyDeficit)) kcal")
                    } else {
                        infoRow("daily_deficit".localized, value: "\(Int(goalEngine.deficit)) kcal")
                    }
                    infoRow("daily_target_label".localized, value: "\(goalEngine.dailyCalorieTarget) kcal")
                    infoRow(
                        goalEngine.projectedWeeklyLossKg > 0 ? "estimated_weekly_loss".localized : "estimated_weekly_gain".localized,
                        value: "\(goalEngine.projectedWeeklyLossKg > 0 ? "-" : "+")\(String(format: "%.2f", abs(goalEngine.projectedWeeklyLossKg))) kg"
                    )

                    Divider()

                    // VO2Max
                    if let vo2 = goalEngine.vo2Max {
                        infoRow("vo2_max".localized, value: "\(String(format: "%.1f", vo2)) ml/kg/min")
                        infoRow("fitness_label".localized, value: goalEngine.vo2MaxLevel)
                    } else {
                        infoRow("vo2_max".localized, value: "no_data".localized)
                    }

                    // Weight from Health
                    if let w = goalEngine.latestWeightFromHealth {
                        let dateStr = goalEngine.latestWeightDate?.formatted(.dateTime.day().month(.abbreviated)) ?? ""
                        infoRow("weight_health".localized, value: "\(String(format: "%.1f", w)) kg \u{2014} \(dateStr)")
                    }

                    Divider()

                    infoRow("bmr_label".localized, value: "\(Int(goalEngine.bmr)) kcal")
                    infoRow("activity_multiplier".localized, value: "\(String(format: "%.2f", goalEngine.activityMultiplier))x")
                    if goalEngine.vo2Max != nil {
                        infoRow("vo2_adjustment".localized, value: "\(String(format: "%+.2f", goalEngine.vo2MaxAdjustment))")
                    }
                    infoRow("protein_target".localized, value: "\(goalEngine.proteinTarget)g")
                    infoRow("carb_target".localized, value: "\(goalEngine.carbTarget)g")
                    infoRow("fat_target".localized, value: "\(goalEngine.fatTarget)g")
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("goal_details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.close.localized) { showGoalInfo = false }
                }
            }
        }
        .presentationBackground(Theme.background)
        .presentationDetents([.medium, .large])
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.bodyFont)
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

    private func saveTodaySnapshot() {
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

    private func updateWidgetData() {
        let data = WidgetData(
            consumedCalories: eatenCalories,
            targetCalories: goalEngine.dailyCalorieTarget,
            remainingCalories: goalEngine.dailyCalorieTarget - eatenCalories,
            targetDeficit: Int(goalEngine.cappedDailyDeficit),
            actualDeficit: Int(goalEngine.tdee) - eatenCalories,
            waterConsumed: isWaterTrackingEnabled ? todayWaterMl : 0,
            waterGoal: isWaterTrackingEnabled ? waterGoalService.dailyGoalMl : 0,
            lastUpdated: Date()
        )
        WidgetDataStore.shared.save(data)
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

    // MARK: - TDEE Warning

    private var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private var isTdeeWarningDismissedToday: Bool {
        UserDefaults.standard.bool(forKey: "tdeeWarningDismissed_\(todayKey)")
    }

    private var shouldShowTdeeBanner: Bool {
        guard goalEngine.isInBannerWindow,
              !tdeeWarningDismissed,
              !isTdeeWarningDismissedToday,
              healthKitService.todayActiveEnergy <= 300 else { return false }

        if goalEngine.hasWorkoutToday {
            return true
        }
        return goalEngine.tdeeDropWarning
    }

    private func dismissTdeeWarning() {
        UserDefaults.standard.set(true, forKey: "tdeeWarningDismissed_\(todayKey)")
        tdeeWarningDismissed = true
    }

    private func loadMorningTDEE() {
        if let snapshot = SnapshotService.fetchSnapshot(for: .now, modelContext: modelContext),
           snapshot.morningTDEE > 0 {
            goalEngine.todayMorningTDEE = snapshot.morningTDEE
        }
    }

    private func applyTDEEUpdate() {
        // Update today's snapshot with new target
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

    // MARK: - Actions

    private func handleCameraTap() {
        #if targetEnvironment(simulator)
        errorMessage = "camera_simulator_error".localized
        #else
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        showCameraPermissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionDenied = true
        @unknown default:
            showCameraPermissionDenied = true
        }
        #endif
    }

    private func handleMicTap() {
        if speechService.isRecording {
            speechService.stopListening()
        } else {
            guard permissionGranted else { return }
            errorMessage = nil
            showSavedConfirmation = false
            // Preserve state if in clarification, correction, or fix mode
            let preserveState = !clarificationQuestion.isEmpty
                || !correctionQuestion.isEmpty
                || fixingMealName != nil
            if !preserveState {
                resetVoiceState()
            }
            do {
                try speechService.startListening()
            } catch {
                errorMessage = speechService.lastError ?? "mic_error".localized
                print("❌ [HomeView] Mic start error: \(error)")
            }
        }
    }

    private func sendToGroq() {
        let newText = speechService.transcript

        // Fix mode for review meals (not yet saved)
        if let mealName = fixingMealName,
           let mealIndex = reviewMeals.firstIndex(where: { $0.name == mealName }) {
            let meal = reviewMeals[mealIndex]
            let lang = groqService.appLanguage
            let fixTranscript: String
            if lang == "en" {
                fixTranscript = """
                Current meal: \(meal.name), \(meal.amount), \(Int(meal.calories ?? 0)) kcal, \
                P:\(Int(meal.protein ?? 0))g C:\(Int(meal.carbs ?? 0))g F:\(Int(meal.fat ?? 0))g. \
                User correction: "\(newText)". \
                Update values based on what user said. Verify consistency: \
                protein×4 + carbs×4 + fat×9 ≈ calories (adjust carbs if needed). \
                Return updated meal in meals array. clarification_needed: false.
                """
            } else {
                fixTranscript = """
                Mevcut yemek: \(meal.name), \(meal.amount), \(Int(meal.calories ?? 0)) kcal, \
                P:\(Int(meal.protein ?? 0))g K:\(Int(meal.carbs ?? 0))g Y:\(Int(meal.fat ?? 0))g. \
                Kullanıcı düzeltmesi: "\(newText)". \
                Söylenene göre değerleri güncelle. Tutarlılık kontrolü: \
                protein×4 + karb×4 + yağ×9 ≈ kalori (gerekirse karbı ayarla). \
                Güncel yemeği meals dizisinde döndür. clarification_needed: false.
                """
            }

            isAnalyzing = true
            errorMessage = nil

            Task {
                do {
                    let response = try await groqService.parseMeals(transcript: fixTranscript, personalContext: profiles.first?.personalContext ?? "")
                    if let updatedMeal = response.meals.first {
                        reviewMeals[mealIndex] = updatedMeal
                    }
                } catch {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "mic_error".localized
                }
                fixingMealName = nil
                isAnalyzing = false
            }
            return
        }

        // Per-item correction mode for saved entries
        if let entry = entryToCorrect {
            let lang = groqService.appLanguage
            let correctionTranscript: String
            if lang == "en" {
                correctionTranscript = """
                Previously saved: \(entry.name), \(entry.amount), \(entry.calories) kcal, \
                P:\(Int(entry.protein))g C:\(Int(entry.carbs))g F:\(Int(entry.fat))g. \
                User wants to change: "\(newText)". \
                Update only the changed fields. Set isCorrection: true, targetFoodName: "\(entry.name)".
                """
            } else {
                correctionTranscript = """
                Daha önce kaydedilen: \(entry.name), \(entry.amount), \(entry.calories) kcal, \
                P:\(Int(entry.protein))g K:\(Int(entry.carbs))g Y:\(Int(entry.fat))g. \
                Kullanıcı düzeltmek istiyor: "\(newText)". \
                Sadece değişen alanları güncelle. isCorrection: true, targetFoodName: "\(entry.name)" yap.
                """
            }

            isAnalyzing = true
            errorMessage = nil
            correctionQuestion = ""

            Task {
                do {
                    let response = try await groqService.parseMeals(transcript: correctionTranscript, personalContext: profiles.first?.personalContext ?? "")
                    applyCorrection(to: entry, from: response)
                    entryToCorrect = nil
                } catch {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "mic_error".localized
                    entryToCorrect = nil
                }
                isAnalyzing = false
            }
            return
        }

        // If clarifying, combine original + answer
        let transcript: String
        if !clarificationQuestion.isEmpty && !originalSpeechText.isEmpty {
            transcript = originalSpeechText + ". " + newText
            clarificationQuestion = ""
        } else {
            originalSpeechText = newText
            transcript = newText
        }

        isAnalyzing = true
        errorMessage = nil

        Task {
            do {
                let response = try await groqService.parseMeals(transcript: transcript, personalContext: profiles.first?.personalContext ?? "")

                // Handle water if detected and water tracking is enabled
                if isWaterTrackingEnabled, let waterMl = response.waterMl, waterMl > 0 {
                    addWater(ml: waterMl, source: "voice")
                }

                print("🏠 [HomeView] entering meal result handler")
                print("🏠 [HomeView] clarification_needed: \(response.clarification_needed)")
                print("🏠 [HomeView] clarification_question: \(response.clarification_question ?? "nil")")
                print("🏠 [HomeView] isCorrection: \(response.isCorrection ?? false)")
                print("🏠 [HomeView] meals count: \(response.meals.count)")
                print("🏠 [HomeView] showReviewCard before: \(showReviewCard)")
                print("🏠 [HomeView] reviewMeals count before: \(reviewMeals.count)")

                if response.isCorrection == true {
                    print("🏠 [HomeView] → branch: correction")
                    handleCorrection(response)
                } else if response.clarification_needed {
                    print("🏠 [HomeView] → branch: clarification (NOT saving)")
                    // Store meals and show review card with clarification inside it
                    reviewMeals = response.meals
                    clarificationQuestion = response.clarification_question ?? ""
                    showReviewCard = true
                    print("🏠 [HomeView] reviewMeals count after: \(reviewMeals.count)")
                } else if !response.meals.isEmpty {
                    print("🏠 [HomeView] → branch: confirmation card")
                    reviewMeals = response.meals
                    showReviewCard = true
                } else if response.waterMl != nil {
                    showSavedConfirmation = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showSavedConfirmation = false
                    }
                }
            } catch {
                print("❌ [HomeView] Groq error: \(error)")
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Bir hata olu\u{015F}tu, tekrar deneyin"
            }
            isAnalyzing = false
        }
    }

    private func handleCorrection(_ response: MealParseResponse) {
        guard let targetName = response.targetFoodName else {
            errorMessage = "D\u{00FC}zeltilecek yemek belirlenemedi"
            return
        }

        let matches = todayEntries.filter {
            $0.name.localizedCaseInsensitiveContains(targetName)
        }

        if matches.count == 1, let entry = matches.first {
            applyCorrection(to: entry, from: response)
        } else if matches.count > 1 {
            correctionPickerEntries = matches
        } else {
            // No match found — show picker with all entries
            correctionPickerEntries = todayEntries
        }
    }

    private func applyCorrection(to entry: FoodEntry, from response: MealParseResponse) {
        // Safety fallback: if amount changed but macros missing, scale proportionally
        if let newAmount = response.correctedAmount,
           response.correctedCalories == nil {
            let ratio = parseAmountRatio(old: entry.amount, new: newAmount)
            if let ratio, ratio > 0, ratio != 1.0 {
                entry.calories = Int(Double(entry.calories) * ratio)
                entry.protein = entry.protein * ratio
                entry.carbs = entry.carbs * ratio
                entry.fat = entry.fat * ratio
                entry.amount = newAmount
            } else {
                entry.amount = newAmount
            }
        } else {
            if let cal = response.correctedCalories { entry.calories = cal }
            if let pro = response.correctedProtein { entry.protein = pro }
            if let carb = response.correctedCarbs { entry.carbs = carb }
            if let fat = response.correctedFat { entry.fat = fat }
            if let amount = response.correctedAmount { entry.amount = amount }
        }
        try? modelContext.save()
        saveTodaySnapshot()

        showCorrected = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCorrected = false
        }
    }

    private func parseAmountRatio(old: String, new: String) -> Double? {
        func extractNumber(_ s: String) -> Double? {
            let digits = s.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Double(digits)
        }
        guard let oldNum = extractNumber(old), oldNum > 0,
              let newNum = extractNumber(new) else {
            return nil
        }
        return newNum / oldNum
    }

    private func addWater(ml: Int, source: String) {
        let entry = WaterEntry(amountMl: ml, source: source)
        modelContext.insert(entry)
        try? modelContext.save()
        saveTodaySnapshot()
    }

    private func saveEntries(from meals: [ParsedMeal]) {
        for meal in meals {
            let entry = FoodEntry(
                name: meal.name,
                amount: meal.amount,
                calories: Int(meal.calories ?? 0),
                protein: meal.protein ?? 0,
                carbs: meal.carbs ?? 0,
                fat: meal.fat ?? 0
            )
            modelContext.insert(entry)
        }
        saveTodaySnapshot()
        showSavedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSavedConfirmation = false
        }
    }
}

#Preview {
    HomeView()
        .environment(GoalEngine())
        .environmentObject(ThemeManager())
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self, WaterEntry.self], inMemory: true)
}
