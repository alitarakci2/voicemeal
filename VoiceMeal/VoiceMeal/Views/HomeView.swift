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
                // Daily goal card
                if goalEngine.profile != nil {
                    dailyGoalCard
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
                Task { await refreshHealthKit() }
            }
        }
        .onAppear {
            goalEngine.update(with: profiles.first)
        }
        .sheet(isPresented: $showGoalInfo) {
            goalInfoSheet
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
                    // HealthKit vs calculated indicator
                    if goalEngine.usingHealthKit {
                        Label("Apple Health verisi kullanılıyor: \(Int(goalEngine.tdee)) kcal", systemImage: "iphone")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if goalEngine.healthKitBurn > 0 {
                        Label("HealthKit verisi henüz yetersiz, hesaplanan TDEE kullanılıyor", systemImage: "hourglass")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label("Hesaplanan TDEE kullanılıyor: \(Int(goalEngine.tdee)) kcal", systemImage: "function")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if goalEngine.isCalorieClamped {
                        Label("Minimum sağlıklı kalori hedefine ayarlandı", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()

                    infoRow("TDEE", value: "\(Int(goalEngine.tdee)) kcal")
                    if goalEngine.usingHealthKit {
                        infoRow("Hesaplanan TDEE", value: "\(Int(goalEngine.calculatedTDEE)) kcal")
                    }
                    if goalEngine.healthKitBurn > 0 && !goalEngine.usingHealthKit {
                        infoRow("HealthKit Yakım", value: "\(Int(goalEngine.healthKitBurn)) kcal")
                        infoRow("BMR Eşiği", value: "\(Int(goalEngine.bmr)) kcal")
                    }
                    infoRow("Kalori Açığı", value: "\(Int(goalEngine.deficit)) kcal")
                    infoRow("Günlük Hedef", value: "\(goalEngine.dailyCalorieTarget) kcal")
                    infoRow("Tahmini Haftalık Kayıp", value: "\(String(format: "%.2f", goalEngine.projectedWeeklyLossKg)) kg")

                    Divider()

                    infoRow("BMR", value: "\(Int(goalEngine.bmr)) kcal")
                    infoRow("Aktivite Çarpanı", value: "\(String(format: "%.2f", goalEngine.activityMultiplier))x")
                    infoRow("Protein Hedefi", value: "\(goalEngine.proteinTarget)g")
                    infoRow("Karb Hedefi", value: "\(goalEngine.carbTarget)g")
                    infoRow("Yağ Hedefi", value: "\(goalEngine.fatTarget)g")
                }
                .padding()
            }
            .navigationTitle("Hedef Detayları")
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
        let burn = await healthKitService.fetchTodayTotalBurn()
        goalEngine.updateHealthKitBurn(burn)
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
        .modelContainer(for: [FoodEntry.self, UserProfile.self], inMemory: true)
}
