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
    @StateObject private var speechService = SpeechService()
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var allWaterEntries: [WaterEntry]
    @Query private var profiles: [UserProfile]
    @State private var permissionGranted = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showSavedConfirmation = false
    @State private var clarificationQuestion = ""
    @State private var pendingMeals: [ParsedMeal] = []
    @State private var showConfirmation = false
    @State private var originalSpeechText = ""
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

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                                .background(speechService.isRecording ? Theme.red : Theme.cardBackground)
                                .clipShape(Circle())
                                .overlay(
                                    Group {
                                        if speechService.isRecording {
                                            Circle()
                                                .stroke(Theme.red.opacity(0.4), lineWidth: 3)
                                                .scaleEffect(1.3)
                                                .opacity(0)
                                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: speechService.isRecording)
                                        } else {
                                            Circle()
                                                .stroke(Theme.cardBorder, lineWidth: 2)
                                        }
                                    }
                                )
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
                                .background(Theme.cardBackground)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Theme.cardBorder, lineWidth: 2)
                                )
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
                                .background(Theme.cardBackground)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Theme.cardBorder, lineWidth: 2)
                                )
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

                // Clarification question
                if !clarificationQuestion.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\u{1F916}")
                        Text(clarificationQuestion)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Confirmation card
                if showConfirmation {
                    confirmationCard
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
                            HStack(alignment: .top) {
                                FoodEntryRowView(entry: entry)

                                Button {
                                    entryToEdit = entry
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(Theme.captionFont)
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.plain)
                                Button {
                                    entryToDelete = entry
                                    showDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(Theme.captionFont)
                                        .foregroundStyle(Theme.red)
                                        .frame(width: 36, height: 36)
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
                        coachStyle: profiles.first?.coachStyle ?? .supportive
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
        .background(Theme.background.ignoresSafeArea())
        .toolbarBackground(Color.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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
                        pendingMeals = meals
                        showConfirmation = true
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

    // MARK: - Confirmation Card

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(groqService.appLanguage == "en" ? "Save these?" : "Bunlar\u{0131} kaydedelim mi?")
                .font(Theme.bodyFont)
                .fontWeight(.bold)
                .foregroundStyle(Theme.textPrimary)

            ForEach(pendingMeals) { meal in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(mealEmoji(for: meal.name) + " " + meal.name.capitalized)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(Int(meal.calories ?? 0)) kcal")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack(spacing: 8) {
                        if !meal.amount.isEmpty {
                            Text(meal.amount)
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if let p = meal.protein, p > 0 {
                            Text("P: \(Int(p))g")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if let c = meal.carbs, c > 0 {
                            Text("K: \(Int(c))g")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if let f = meal.fat, f > 0 {
                            Text("Y: \(Int(f))g")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }

            Divider().overlay(Theme.cardBorder)

            HStack {
                Text(groqService.appLanguage == "en" ? "Total" : "Toplam")
                    .font(Theme.bodyFont)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(pendingMeals.reduce(0) { $0 + Int($1.calories ?? 0) }) kcal")
                    .font(Theme.bodyFont)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.accent)
            }

            HStack(spacing: 12) {
                Button {
                    resetVoiceState()
                } label: {
                    Label(
                        groqService.appLanguage == "en" ? "Redo" : "Tekrar",
                        systemImage: "arrow.counterclockwise"
                    )
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    saveEntries(from: pendingMeals)
                    resetVoiceState()
                } label: {
                    Label(
                        groqService.appLanguage == "en" ? "Save" : "Kaydet",
                        systemImage: "checkmark"
                    )
                    .font(Theme.bodyFont)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func resetVoiceState() {
        clarificationQuestion = ""
        pendingMeals = []
        showConfirmation = false
        originalSpeechText = ""
    }

    // MARK: - Daily Goal Card

    private var dailyGoalCard: some View {
        let remaining = goalEngine.dailyCalorieTarget - eatenCalories
        let targetDeficit = Int(goalEngine.cappedDailyDeficit)
        let actualDeficit = Int(goalEngine.tdee) - eatenCalories
        let eatingProgress = goalEngine.dailyCalorieTarget > 0
            ? min(Double(eatenCalories) / Double(goalEngine.dailyCalorieTarget), 1.0) : 0
        let eatingPercent = Int(eatingProgress * 100)

        let deficitPercent = targetDeficit > 0
            ? min(Int(Double(max(actualDeficit, 0)) / Double(targetDeficit) * 100), 999) : 0

        return VStack(spacing: 20) {
            // Header
            HStack {
                let names = goalEngine.todayActivityNames
                    .compactMap { GoalEngine.activityDisplayNames[$0] }
                if !names.isEmpty {
                    Text(names.joined(separator: " \u{00B7} "))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        Task { await refreshHealthKit() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Button {
                        showGoalInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            // Large circular calorie gauge
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Theme.trackBackground, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(135))

                // Progress arc with gradient
                Circle()
                    .trim(from: 0, to: 0.75 * eatingProgress)
                    .stroke(
                        AngularGradient(
                            colors: remaining < 0
                                ? [Theme.red, Theme.orange]
                                : [Theme.orange, Color(hex: "FF6B2C"), Theme.red],
                            center: .center,
                            startAngle: .degrees(135),
                            endAngle: .degrees(405)
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))

                // Center text
                VStack(spacing: 2) {
                    Text(remaining < 0
                         ? ("eating_exceeded_short".localized)
                         : ("on_track_label".localized))
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(eatenCalories)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(goalEngine.dailyCalorieTarget) kcal")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 200, height: 200)
            .frame(maxWidth: .infinity)

            // Stats row below circle
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("remaining_label".localized)
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                    Text("\(remaining)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(remaining < 0 ? Theme.red : .white)
                    Text("kcal")
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Theme.cardBorder)
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("calorie_deficit_label".localized)
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                    Text("\(actualDeficit)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(actualDeficit < 0 ? Theme.red : Theme.green)
                    Text("/ \(targetDeficit)")
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Theme.cardBorder)
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("TDEE")
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                    Text("\(Int(goalEngine.tdee))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("kcal")
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }

            // Macro bars
            VStack(spacing: 10) {
                macroRow("protein_label".localized, eaten: Int(eatenProtein), target: goalEngine.proteinTarget, color: Theme.blue)
                macroRow("carb_label".localized, eaten: Int(eatenCarbs), target: goalEngine.carbTarget, color: Theme.orange)
                macroRow("fat_label".localized, eaten: Int(eatenFat), target: goalEngine.fatTarget, color: Theme.green)
            }
        }
        .padding(20)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func macroRow(_ name: String, eaten: Int, target: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(name)
                    .font(Theme.captionFont)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(eaten)g / \(target)g")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            }
            GeometryReader { geo in
                let progress = target > 0 ? min(Double(eaten) / Double(target), 1.0) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Theme.trackBackground)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: max(geo.size.width * progress, 4))
                }
            }
            .frame(height: 10)
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
            // If not in clarification mode, start fresh
            if clarificationQuestion.isEmpty {
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
                let response = try await groqService.parseMeals(transcript: transcript)

                // Handle water if detected and water tracking is enabled
                if isWaterTrackingEnabled, let waterMl = response.waterMl, waterMl > 0 {
                    addWater(ml: waterMl, source: "voice")
                }

                if response.isCorrection == true {
                    handleCorrection(response)
                } else if response.clarification_needed {
                    clarificationQuestion = response.clarification_question ?? ""
                } else if !response.meals.isEmpty {
                    pendingMeals = response.meals
                    showConfirmation = true
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
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self, WaterEntry.self], inMemory: true)
}
