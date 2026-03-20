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
    @State private var parsedMeals: [ParsedMeal] = []
    @State private var clarificationQuestion: String?
    @State private var errorMessage: String?
    @State private var fullTranscript = ""
    @State private var showSavedConfirmation = false
    @State private var showGoalInfo = false
    @State private var showWeightBanner = false
    @State private var showSettings = false
    @State private var showMealSuggestion = false
    @State private var notificationSuggestionType: MealNotificationType?
    @State private var entryToEdit: FoodEntry?
    @State private var entryToDelete: FoodEntry?
    @State private var showDeleteAlert = false
    @State private var showCorrected = false
    @State private var correctionPickerEntries: [FoodEntry]?
    @Environment(GoalEngine.self) private var goalEngine
    @State private var healthKitService = HealthKitService()
    @State private var waterGoalService = WaterGoalService()

    // Camera state
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var capturedImageData: Data?
    @State private var showPhotoAnalysis = false
    @State private var showCameraPermissionDenied = false
    @State private var showNutritionCheck = false

    @Environment(GroqService.self) private var groqService

    private var todayEntries: [FoodEntry] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= startOfDay }
    }

    private var currentSuggestionType: MealNotificationType? {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 20 { return .evening }
        if hour >= 15 { return .afternoon }
        return nil
    }

    private var todayWaterEntries: [WaterEntry] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allWaterEntries.filter { $0.date >= startOfDay }
    }

    private var todayWaterMl: Int { todayWaterEntries.reduce(0) { $0 + $1.amountMl } }

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
                        waterMl: todayWaterMl,
                        waterGoalMl: waterGoalService.dailyGoalMl
                    )

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

                    // Meal suggestion button
                    if let suggestionType = currentSuggestionType {
                        Button {
                            showMealSuggestion = true
                        } label: {
                            Label(
                                suggestionType == .afternoon ? "Ak\u{015F}am \u{00D6}nerisi Al" : "Gece At\u{0131}\u{015F}t\u{0131}rmal\u{0131}\u{011F}\u{0131}",
                                systemImage: "lightbulb.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.orange)
                    }
                }

                // Input label
                Text("Ne yedin?")
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

                        Text("Sesle Kaydet")
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

                        Text("Foto\u{011F}rafla")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                // Status label
                if isAnalyzing {
                    ProgressView("Analiz ediliyor...")
                } else if showCorrected {
                    Text("D\u{00FC}zeltildi \u{2713}")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                } else if showSavedConfirmation {
                    Text("Kaydedildi \u{2713}")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.green)
                } else {
                    Text(speechService.isRecording ? "Dinliyorum..." : "Haz\u{0131}r")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(speechService.isRecording ? Theme.red : Theme.textSecondary)
                }

                // Transcript
                if !speechService.transcript.isEmpty {
                    Text(speechService.transcript)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .themeCard()
                }

                // Parsed results
                if !parsedMeals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(parsedMeals) { meal in
                            HStack {
                                Text(meal.name)
                                Spacer()
                                Text("\(Int(meal.calories)) kcal")
                                    .foregroundStyle(Theme.textSecondary)
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
                    .themeCard()
                }

                // Clarification question
                if let question = clarificationQuestion {
                    Text(question)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.orange)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.orange.opacity(0.1))
                        .themeCard()
                }

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.red)
                }

                // Today's meal list
                if !todayEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Bug\u{00FC}nk\u{00FC} Yemekler")
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
                            Text("Toplam")
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

                        Text("P: \(Int(eatenProtein))g  K: \(Int(eatenCarbs))g  Y: \(Int(eatenFat))g")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                    .themeCard()
                }

                // Correction picker
                if let entries = correctionPickerEntries {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hangi kayd\u{0131} d\u{00FC}zelteyim?")
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

                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(Theme.background)
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
        .onReceive(NotificationCenter.default.publisher(for: .openMealSuggestion)) { notification in
            if let typeRaw = notification.userInfo?["type"] as? String,
               let type = MealNotificationType(rawValue: typeRaw) {
                notificationSuggestionType = type
            } else {
                notificationSuggestionType = currentSuggestionType
            }
            showMealSuggestion = true
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
        .alert("Bu kayd\u{0131} silmek istedi\u{011F}ine emin misin?", isPresented: $showDeleteAlert) {
            Button("Sil", role: .destructive) {
                if let entry = entryToDelete {
                    modelContext.delete(entry)
                    try? modelContext.save()
                    saveTodaySnapshot()
                }
                entryToDelete = nil
            }
            Button("\u{0130}ptal", role: .cancel) {
                entryToDelete = nil
            }
        }
        .sheet(isPresented: $showMealSuggestion, onDismiss: {
            notificationSuggestionType = nil
        }) {
            if let type = notificationSuggestionType ?? currentSuggestionType {
                MealSuggestionView(
                    notificationType: type,
                    remainingCalories: goalEngine.dailyCalorieTarget - eatenCalories,
                    remainingProtein: goalEngine.proteinTarget - Int(eatenProtein),
                    remainingCarbs: goalEngine.carbTarget - Int(eatenCarbs),
                    remainingFat: goalEngine.fatTarget - Int(eatenFat),
                    todayMeals: todayEntries.map(\.name),
                    preferredProteins: profiles.first?.preferredProteins ?? [],
                    todayActivities: goalEngine.todayActivityNames,
                    hrvStatus: healthKitService.hrvStatus
                )
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                capturedImage = image
                Task.detached(priority: .userInitiated) {
                    let data = GroqService.compressImage(image)
                    await MainActor.run {
                        if let data {
                            capturedImageData = data
                            showPhotoAnalysis = true
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
                        saveEntries(from: meals)
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
    }

    // MARK: - Daily Goal Card

    private var dailyGoalCard: some View {
        let remaining = goalEngine.dailyCalorieTarget - eatenCalories
        let targetDeficit = Int(goalEngine.cappedDailyDeficit)
        let actualDeficit = Int(goalEngine.tdee) - eatenCalories
        let eatingPercent = goalEngine.dailyCalorieTarget > 0
            ? Int(Double(eatenCalories) / Double(goalEngine.dailyCalorieTarget) * 100) : 0
        let deficitPercent = targetDeficit > 0
            ? min(Int(Double(max(actualDeficit, 0)) / Double(targetDeficit) * 100), 999) : 0
        let deficitColor: Color = deficitPercent >= 80 ? Theme.green
            : deficitPercent >= 50 ? Theme.orange : Theme.red

        return VStack(alignment: .leading, spacing: 12) {
            // Header with today's activities
            HStack {
                let names = goalEngine.todayActivityNames
                    .compactMap { GoalEngine.activityDisplayNames[$0] }
                Text("\u{1F4C5} Bug\u{00FC}n: \(names.joined(separator: ", "))")
                    .font(Theme.bodyFont)
                    .fontWeight(.medium)

                Spacer()

                Button {
                    Task { await refreshHealthKit() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }

                Button {
                    showGoalInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Theme.textSecondary)
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Dual target: Yeme Hedefi + Kalori Açığı
            HStack(spacing: 0) {
                // Left: Yeme Hedefi
                VStack(spacing: 6) {
                    Text("Yeme Hedefi")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Text("Hedef")
                                .font(Theme.microFont)
                                .foregroundStyle(Theme.textTertiary)
                            Text("\(goalEngine.dailyCalorieTarget)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .allowsTightening(true)
                        }
                        VStack(spacing: 2) {
                            Text("Yenen")
                                .font(Theme.microFont)
                                .foregroundStyle(Theme.textTertiary)
                            Text("\(eatenCalories)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .allowsTightening(true)
                        }
                        VStack(spacing: 2) {
                            Text("Kalan")
                                .font(Theme.microFont)
                                .foregroundStyle(Theme.textTertiary)
                            Text("\(remaining)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(remaining < 0 ? Theme.red : Theme.textPrimary)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .allowsTightening(true)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(width: 1, height: 50)
                    .background(Theme.cardBorder)

                // Right: Kalori Açığı
                VStack(spacing: 6) {
                    Text("Kalori A\u{00E7}\u{0131}\u{011F}\u{0131}")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Text("Hedef")
                                .font(Theme.microFont)
                                .foregroundStyle(Theme.textTertiary)
                            Text("\(targetDeficit)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .allowsTightening(true)
                        }
                        VStack(spacing: 2) {
                            Text("Ger\u{00E7}ek")
                                .font(Theme.microFont)
                                .foregroundStyle(Theme.textTertiary)
                            Text("\(actualDeficit)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(actualDeficit < 0 ? Theme.red : Theme.textPrimary)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .allowsTightening(true)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Eating progress line
            if remaining < 0 {
                Text("\u{26A0}\u{FE0F} Yeme: %\(eatingPercent) a\u{015F}t\u{0131}n")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.red)
            } else {
                Text("\u{2705} Yeme: %\(eatingPercent) tamamland\u{0131}")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.green)
            }

            // Deficit progress line
            HStack(spacing: 4) {
                Text("\u{1F525} A\u{00E7}\u{0131}k: \(max(actualDeficit, 0)) / \(targetDeficit) kcal (%\(deficitPercent))")
                    .font(Theme.captionFont)
                    .foregroundStyle(deficitColor)
            }

            // Macro progress bars with warning emoji
            macroRow("Protein", eaten: Int(eatenProtein), target: goalEngine.proteinTarget, color: .blue, exceeded: Int(eatenProtein) > goalEngine.proteinTarget)
            macroRow("Karb", eaten: Int(eatenCarbs), target: goalEngine.carbTarget, color: .orange, exceeded: Int(eatenCarbs) > goalEngine.carbTarget)
            macroRow("Ya\u{011F}", eaten: Int(eatenFat), target: goalEngine.fatTarget, color: .yellow, exceeded: Int(eatenFat) > goalEngine.fatTarget)
        }
        .padding()
        .themeCard()
    }

    private func calorieStat(_ label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
            Text("\(value)")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func macroRow(_ name: String, eaten: Int, target: Int, color: Color, exceeded: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                let progress = target > 0 ? min(Double(eaten) / Double(target), 1.0) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.trackBackground)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)

            HStack(spacing: 2) {
                Text("\(eaten)g / \(target)g")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                if exceeded {
                    Text("\u{2B06}\u{FE0F}")
                        .font(Theme.microFont)
                }
            }
            .frame(width: 95, alignment: .trailing)
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
        return "Bug\u{00FC}n \u{015F}unlar\u{0131} yedim: \(foodList).\n\nBu yiyeceklerin toplam kalori, protein, karbonhidrat ve ya\u{011F} de\u{011F}erlerini hesaplar m\u{0131}s\u{0131}n?"
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
            .navigationTitle("Besin Do\u{011F}rulama")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") {
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
                        Label("Extrapolasyon aktif (%\(pct) g\u{00FC}n ge\u{00E7}ti)", systemImage: "iphone")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.blue)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if goalEngine.usingHealthKit {
                        Label("Apple Health verisi kullan\u{0131}l\u{0131}yor", systemImage: "iphone")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.green)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if healthKitService.dayFraction < 0.40 && healthKitService.isAvailable {
                        Label("Sabah erken \u{2014} hesaplanan TDEE kullan\u{0131}l\u{0131}yor", systemImage: "function")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if goalEngine.healthKitBurn > 0 {
                        Label("HealthKit verisi hen\u{00FC}z yetersiz, hesaplanan TDEE kullan\u{0131}l\u{0131}yor", systemImage: "hourglass")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label("Hesaplanan form\u{00FC}l: \(Int(goalEngine.tdee)) kcal", systemImage: "function")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if goalEngine.isCalorieClamped {
                        Label("Minimum sa\u{011F}l\u{0131}kl\u{0131} kalori hedefine ayarland\u{0131}", systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if goalEngine.isCapped, let reason = goalEngine.capReason {
                        Label("Hedef \u{00E7}ok agresif, g\u{00FC}venli s\u{0131}n\u{0131}ra ayarland\u{0131}", systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(reason)
                            .font(Theme.microFont)
                            .foregroundStyle(Theme.textSecondary)
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
                    infoRow(
                        goalEngine.projectedWeeklyLossKg > 0 ? "Tahmini Haftal\u{0131}k Kay\u{0131}p" : "Tahmini Haftal\u{0131}k Art\u{0131}\u{015F}",
                        value: "\(goalEngine.projectedWeeklyLossKg > 0 ? "-" : "+")\(String(format: "%.2f", abs(goalEngine.projectedWeeklyLossKg))) kg"
                    )

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
            totalWaterMl: todayWaterMl,
            waterGoalMl: waterGoalService.dailyGoalMl
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

    private func handleCameraTap() {
        #if targetEnvironment(simulator)
        errorMessage = "Kamera simülatörde kullanılamaz"
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

                // Handle water if detected
                if let waterMl = response.waterMl, waterMl > 0 {
                    addWater(ml: waterMl, source: "voice")
                }

                if response.isCorrection == true {
                    handleCorrection(response)
                } else if response.clarification_needed {
                    parsedMeals = response.meals
                    clarificationQuestion = response.clarification_question
                } else {
                    parsedMeals = response.meals
                    clarificationQuestion = nil
                    if !response.meals.isEmpty {
                        saveEntries(from: response.meals)
                    } else if response.waterMl != nil {
                        showSavedConfirmation = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            showSavedConfirmation = false
                        }
                    }
                }
            } catch {
                errorMessage = "Bir hata olu\u{015F}tu, tekrar deneyin"
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
                calories: Int(meal.calories),
                protein: meal.protein,
                carbs: meal.carbs,
                fat: meal.fat
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
