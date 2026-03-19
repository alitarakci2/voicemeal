//
//  PlanView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct PlanView: View {
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @Query private var mealPlans: [MealPlan]
    @State private var planService = PlanService()
    @Environment(GoalEngine.self) private var goalEngine
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPlan: DayPlan?
    @State private var healthKitService = HealthKitService()

    // Meal plan state
    @State private var isGeneratingMealPlan = false
    @State private var mealPlanError: String?
    @State private var selectedMealDetail: MealPlanSuggestion?
    @State private var showSavedToast = false
    @State private var savedMealType: String?

    private let groqService = GroqService()

    private var dayPlans: [DayPlan] {
        _ = planService.refreshID
        guard let profile = profiles.first else { return [] }
        return planService.generateDayPlans(profile: profile, entries: allEntries, goalEngine: goalEngine)
    }

    private var todayID: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private var todayMealPlan: MealPlan? {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return mealPlans.first { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }
    }

    private var weeklyStats: (totalDeficit: Int, estimatedChangeKg: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else {
            return (0, 0)
        }
        let weekPlans = dayPlans.filter { $0.date >= weekStart && $0.date <= today && $0.status != .planned }
        let totalDeficit = weekPlans.reduce(0) { $0 + ($1.tdee - $1.consumedCalories) }
        let estimatedChange = weekPlans.reduce(0.0) { $0 + $1.estimatedWeightChangeKg }
        return (totalDeficit, estimatedChange)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Meal plan section
                        mealPlanSection
                            .padding(.bottom, 8)

                        // Weekly summary
                        weeklySummaryCard
                            .padding(.bottom, 4)

                        ForEach(dayPlans) { plan in
                            DayRowView(plan: plan)
                                .id(plan.date)
                                .onTapGesture {
                                    selectedPlan = plan
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Theme.background)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(todayID, anchor: .center)
                        }
                    }
                }
            }
            .navigationTitle("Plan")
            .onReceive(NotificationCenter.default.publisher(for: .profileUpdated)) { _ in
                planService.regeneratePlans()
            }
            .sheet(item: $selectedPlan) { plan in
                DayDetailSheetView(plan: plan)
            }
            .sheet(item: $selectedMealDetail) { suggestion in
                MealDetailSheet(suggestion: suggestion) {
                    saveMealAsFoodEntry(suggestion)
                }
            }
            .task {
                if todayMealPlan == nil {
                    await generateMealPlan()
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    let label = mealTypeLabel(savedMealType)
                    Text("\(label) eklendi \u{2713}")
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
        }
    }

    // MARK: - Meal Plan Section

    private var mealPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("\u{1F4C5} Bug\u{00FC}n\u{00FC}n \u{00D6}\u{011F}\u{00FC}n Plan\u{0131}")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    Task { await generateMealPlan() }
                } label: {
                    Label("Yeniden \u{00DC}ret", systemImage: "arrow.clockwise")
                        .font(Theme.captionFont)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .disabled(isGeneratingMealPlan)
            }

            if isGeneratingMealPlan {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("\u{00D6}\u{011F}\u{00FC}n plan\u{0131} haz\u{0131}rlan\u{0131}yor...")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let plan = todayMealPlan {
                mealSection("Kahvalt\u{0131}", suggestions: plan.breakfastSuggestions, selected: plan.selectedBreakfast, mealType: "breakfast")
                mealSection("\u{00D6}\u{011F}le Yeme\u{011F}i", suggestions: plan.lunchSuggestions, selected: plan.selectedLunch, mealType: "lunch")
                mealSection("Ak\u{015F}am Yeme\u{011F}i", suggestions: plan.dinnerSuggestions, selected: plan.selectedDinner, mealType: "dinner")
            } else if let error = mealPlanError {
                VStack(spacing: 8) {
                    Text(error)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)
                    Button("Tekrar Dene") {
                        Task { await generateMealPlan() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                Text("Y\u{00FC}kleniyor...")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding()
        .themeCard()
    }

    private func mealSection(_ title: String, suggestions: [MealPlanSuggestion], selected: MealPlanSuggestion?, mealType: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(Theme.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textPrimary)
                if selected != nil {
                    Text("\u{2705}")
                        .font(Theme.captionFont)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions) { suggestion in
                        MealSuggestionCardView(
                            suggestion: suggestion,
                            isSelected: selected?.id == suggestion.id,
                            isDimmed: selected != nil && selected?.id != suggestion.id,
                            onSelect: {
                                selectMeal(suggestion, mealType: mealType)
                            },
                            onTap: {
                                selectedMealDetail = suggestion
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func generateMealPlan() async {
        guard let profile = profiles.first else { return }

        isGeneratingMealPlan = true
        mealPlanError = nil

        do {
            // Fetch HRV for context
            if healthKitService.isAvailable {
                await healthKitService.requestPermission()
                _ = await healthKitService.fetchTodayHRV()
                _ = await healthKitService.fetchHRVBaseline()
            }

            let frequentFoods = FrequentFoodService.getFrequentFoods(entries: allEntries)

            let response = try await groqService.generateDailyMealPlan(
                dailyCalorieTarget: goalEngine.dailyCalorieTarget,
                proteinTarget: goalEngine.proteinTarget,
                carbTarget: goalEngine.carbTarget,
                fatTarget: goalEngine.fatTarget,
                favoriteFoods: profile.favoriteFoods,
                frequentFoods: frequentFoods,
                todayActivities: goalEngine.todayActivityNames,
                hrvStatus: healthKitService.hrvStatus
            )

            // Delete old plan for today if exists
            if let existing = todayMealPlan {
                modelContext.delete(existing)
            }

            let plan = MealPlan(
                date: .now,
                breakfast: response.breakfast,
                lunch: response.lunch,
                dinner: response.dinner
            )
            modelContext.insert(plan)
            try? modelContext.save()
        } catch {
            mealPlanError = "\u{00D6}\u{011F}\u{00FC}n plan\u{0131} olu\u{015F}turulamad\u{0131}. \u{0130}nternet ba\u{011F}lant\u{0131}n\u{0131} kontrol et."
        }

        isGeneratingMealPlan = false
    }

    private func selectMeal(_ suggestion: MealPlanSuggestion, mealType: String) {
        guard let plan = todayMealPlan else { return }

        switch mealType {
        case "breakfast": plan.selectedBreakfast = suggestion
        case "lunch": plan.selectedLunch = suggestion
        case "dinner": plan.selectedDinner = suggestion
        default: break
        }
        try? modelContext.save()

        savedMealType = mealType
        showSavedToast = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSavedToast = false
        }
    }

    private func saveMealAsFoodEntry(_ suggestion: MealPlanSuggestion) {
        let entry = FoodEntry(
            name: suggestion.name,
            amount: suggestion.ingredients.joined(separator: ", "),
            calories: suggestion.calories,
            protein: suggestion.protein,
            carbs: suggestion.carbs,
            fat: suggestion.fat
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func mealTypeLabel(_ type: String?) -> String {
        switch type {
        case "breakfast": return "Kahvalt\u{0131}"
        case "lunch": return "\u{00D6}\u{011F}le"
        case "dinner": return "Ak\u{015F}am"
        default: return "\u{00D6}\u{011F}\u{00FC}n"
        }
    }

    // MARK: - Weekly Summary

    private var weeklySummaryCard: some View {
        let stats = weeklyStats
        return VStack(alignment: .leading, spacing: 6) {
            Text("\u{1F4CA} Bu Hafta")
                .font(Theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textPrimary)
            HStack {
                Text("Toplam a\u{00E7}\u{0131}k: \(stats.totalDeficit) kcal")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Tahmini: \u{2248} \(String(format: "%+.2f", stats.estimatedChangeKg)) kg")
                    .font(Theme.captionFont)
                    .fontWeight(.medium)
                    .foregroundStyle(stats.estimatedChangeKg <= 0 ? Theme.green : Theme.orange)
            }
        }
        .padding()
        .themeCard()
    }
}

// MARK: - Day Row

struct DayRowView: View {
    let plan: DayPlan

    private var statusIcon: String {
        switch plan.status {
        case .completed: return "checkmark.circle.fill"
        case .exceeded: return "exclamationmark.triangle.fill"
        case .underate: return "arrow.down.circle.fill"
        case .missed: return "xmark.circle.fill"
        case .today: return "location.fill"
        case .planned: return "doc.text"
        }
    }

    private var statusColor: Color {
        switch plan.status {
        case .completed: return Theme.green
        case .exceeded: return Theme.orange
        case .underate: return Theme.blue
        case .missed: return Theme.textTertiary
        case .today: return Theme.blue
        case .planned: return Theme.textTertiary
        }
    }

    private var dateLabel: String {
        if plan.status == .today {
            return "Bug\u{00FC}n"
        }
        return plan.date.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(statusColor)

                Text(dateLabel)
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    ForEach(plan.activities, id: \.self) { activity in
                        Text(activityEmoji(activity))
                            .font(Theme.captionFont)
                    }
                }
            }

            HStack {
                switch plan.status {
                case .today:
                    Text("\(plan.consumedCalories) / \(plan.targetCalories) kcal")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("devam ediyor...")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.blue)

                case .planned:
                    Text("Hedef: \(plan.targetCalories) kcal")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    let plannedDeficit = plan.tdee - plan.targetCalories
                    Text("~\(plannedDeficit) a\u{00E7}\u{0131}k")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)

                case .missed:
                    Text("0 / \(plan.targetCalories) kcal")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()

                default:
                    Text("\(plan.consumedCalories) / \(plan.targetCalories) kcal")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    let weightChange = plan.estimatedWeightChangeKg
                    Text("\u{2248} \(String(format: "%+.2f", weightChange)) kg")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(weightChange <= 0 ? Theme.green : Theme.orange)
                }
            }
        }
        .padding()
        .frame(minHeight: 72)
        .background(plan.status == .today ? Theme.accent.opacity(0.1) : Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(plan.status == .today ? Theme.accent.opacity(0.4) : Theme.cardBorder, lineWidth: plan.status == .today ? 2 : 1)
        )
    }

    private func activityEmoji(_ activity: String) -> String {
        switch activity {
        case "weights": return "\u{1F3CB}\u{FE0F}"
        case "running": return "\u{1F3C3}"
        case "cycling": return "\u{1F6B4}"
        case "walking": return "\u{1F6B6}"
        case "rest": return "\u{1F4A4}"
        default: return "\u{2753}"
        }
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheetView: View {
    let plan: DayPlan
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    private var dayEntries: [FoodEntry] {
        let calendar = Calendar.current
        return allEntries.filter { calendar.isDate($0.date, inSameDayAs: plan.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Date + activities
                    HStack {
                        Text(plan.status == .today ? "Bug\u{00FC}n" : plan.date.formatted(.dateTime.day().month(.wide).year()))
                            .font(Theme.titleFont)
                            .fontWeight(.bold)
                        Spacer()
                        ForEach(plan.activities, id: \.self) { activity in
                            Text(GoalEngine.activityDisplayNames[activity] ?? activity)
                                .font(Theme.captionFont)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.cardBackground)
                                .clipShape(Capsule())
                        }
                    }

                    // Status banner
                    statusBanner

                    // Calorie + macro progress
                    calorieSection

                    // Daily deficit (past and today only)
                    if plan.status != .planned {
                        let deficit = plan.tdee - plan.consumedCalories
                        HStack {
                            if deficit > 0 {
                                Text("\u{1F525} \(deficit) kcal a\u{00E7}\u{0131}k")
                                    .foregroundStyle(Theme.green)
                            } else {
                                Text("\u{26A0}\u{FE0F} \(abs(deficit)) kcal fazla")
                                    .foregroundStyle(Theme.red)
                            }
                        }
                        .font(Theme.bodyFont)
                        .fontWeight(.medium)
                    }

                    macroSection

                    // Food entries
                    if plan.status == .planned {
                        Text("Bu g\u{00FC}n i\u{00E7}in plan")
                            .font(Theme.headlineFont)
                            .padding(.top, 4)
                        Text("Hedef: \(plan.targetCalories) kcal")
                            .foregroundStyle(Theme.textSecondary)
                        Text("P: \(plan.targetProtein)g  K: \(plan.targetCarbs)g  Y: \(plan.targetFat)g")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textSecondary)
                    } else if dayEntries.isEmpty {
                        Text("Yemek kayd\u{0131} yok")
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 4)
                    } else {
                        Text("Yemekler")
                            .font(Theme.headlineFont)
                            .padding(.top, 4)
                        ForEach(dayEntries, id: \.id) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.name)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(entry.calories) kcal")
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Text("P: \(Int(entry.protein))g  K: \(Int(entry.carbs))g  Y: \(Int(entry.fat))g")
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("G\u{00FC}n Detay\u{0131}")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isPastOlderThan7Days: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfDay(for: .now))!
        return plan.date < sevenDaysAgo
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch plan.status {
        case .completed:
            Label("Hedefe ula\u{015F}\u{0131}ld\u{0131}", systemImage: "checkmark.circle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.green)
        case .exceeded:
            Label("Hedef a\u{015F}\u{0131}ld\u{0131}", systemImage: "exclamationmark.triangle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.orange)
        case .underate:
            Label("Hedefin alt\u{0131}nda kald\u{0131}n \u{2014} \u{00E7}ok az yedin", systemImage: "arrow.down.circle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.blue)
        case .missed:
            Label("Ka\u{00E7}\u{0131}r\u{0131}ld\u{0131}", systemImage: "xmark.circle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textTertiary)
        case .today:
            Label("Devam ediyor", systemImage: "location.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.blue)
        case .planned:
            Label("Planland\u{0131}", systemImage: "doc.text")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
        }

        if isPastOlderThan7Days {
            Text("* Hedef, mevcut profil de\u{011F}erleriyle hesaplanm\u{0131}\u{015F}t\u{0131}r")
                .font(Theme.microFont)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var calorieSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kalori")
                .font(Theme.bodyFont)
                .fontWeight(.medium)

            let progress = plan.targetCalories > 0 ? min(Double(plan.consumedCalories) / Double(plan.targetCalories), 1.0) : 0

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.trackBackground)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(plan.status == .exceeded ? Theme.orange : plan.status == .underate ? Theme.blue : Theme.green)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 12)

            HStack {
                Text("\(plan.consumedCalories) / \(plan.targetCalories) kcal")
                    .font(Theme.captionFont)
                Spacer()
                if plan.status != .planned {
                    Text("%\(plan.caloriePercentage)")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private var macroSection: some View {
        VStack(spacing: 8) {
            macroBar("Protein", eaten: Int(plan.consumedProtein), target: plan.targetProtein, color: .blue)
            macroBar("Karb", eaten: Int(plan.consumedCarbs), target: plan.targetCarbs, color: .orange)
            macroBar("Ya\u{011F}", eaten: Int(plan.consumedFat), target: plan.targetFat, color: .yellow)
        }
    }

    private func macroBar(_ name: String, eaten: Int, target: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(Theme.captionFont)
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

            Text("\(eaten)g / \(target)g")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

#Preview {
    PlanView()
        .environment(GoalEngine())
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self, MealPlan.self], inMemory: true)
}
