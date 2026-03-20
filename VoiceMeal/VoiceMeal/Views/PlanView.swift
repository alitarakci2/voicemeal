//
//  PlanView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct PlanView: View {
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @Query private var allSnapshots: [DailySnapshot]
    @State private var planService = PlanService()
    @Environment(GoalEngine.self) private var goalEngine
    @State private var selectedPlan: DayPlan?
    @State private var showPastDays = false
    @State private var showFutureDays = false
    @State private var weeklyCardExpanded = false

    private var dayPlans: [DayPlan] {
        _ = planService.refreshID
        guard let profile = profiles.first else { return [] }
        return planService.generateDayPlans(profile: profile, entries: allEntries, snapshots: allSnapshots, goalEngine: goalEngine)
    }

    private var todayID: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private var pastDays: [DayPlan] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -3, to: todayID)!
        return dayPlans.filter { $0.date < cutoff }
    }

    private var visibleDays: [DayPlan] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -3, to: todayID)!
        let end = calendar.date(byAdding: .day, value: 3, to: todayID)!
        return dayPlans.filter { $0.date >= start && $0.date <= end }
    }

    private var futureDays: [DayPlan] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 3, to: todayID)!
        return dayPlans.filter { $0.date > cutoff }
    }

    private func dateRangeText(_ days: [DayPlan]) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        let f = first.date.formatted(.dateTime.day().month(.abbreviated))
        let l = last.date.formatted(.dateTime.day().month(.abbreviated))
        return first.date == last.date ? f : "\(f) - \(l)"
    }

    // MARK: - Weekly Helpers

    private var thisWeekDays: [DayPlan] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let mondayStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        )!
        let sundayEnd = calendar.date(byAdding: .day, value: 6, to: mondayStart)!
        return dayPlans.filter { $0.date >= mondayStart && $0.date <= sundayEnd }
    }

    private func dayHasData(_ day: DayPlan) -> Bool {
        day.status != .missed && day.status != .planned
    }

    private func deficitColor(actual: Int, target: Int) -> Color {
        if actual <= 0 {
            return Theme.red
        } else if target > 0 && actual >= Int(Double(target) * 0.80) {
            return Theme.green
        } else {
            return Theme.orange
        }
    }

    // Completed past days only (excludes today's partial data)
    private var completedWeekDays: [DayPlan] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return thisWeekDays.filter { day in
            let dayStart = Calendar.current.startOfDay(for: day.date)
            return dayHasData(day) && dayStart < todayStart
        }
    }

    private var daysWithData: Int {
        completedWeekDays.count
    }

    private var totalDeficitThisWeek: Int {
        completedWeekDays.reduce(0) { $0 + ($1.tdee - $1.consumedCalories) }
    }

    private var weeklyEstimatedChangeKg: Double {
        completedWeekDays.reduce(0.0) { $0 + $1.estimatedWeightChangeKg }
    }

    private var weeklyAvgDeficit: Int {
        guard !completedWeekDays.isEmpty else { return 0 }
        return completedWeekDays.reduce(0) { $0 + ($1.tdee - $1.consumedCalories) } / completedWeekDays.count
    }

    private var weeklyAvgCalories: Int {
        guard !completedWeekDays.isEmpty else { return 0 }
        return completedWeekDays.reduce(0) { $0 + $1.consumedCalories } / completedWeekDays.count
    }

    private var weeklyAvgProtein: Double {
        guard !completedWeekDays.isEmpty else { return 0 }
        return completedWeekDays.reduce(0.0) { $0 + $1.consumedProtein } / Double(completedWeekDays.count)
    }

    private var weeklyAvgCarbs: Double {
        guard !completedWeekDays.isEmpty else { return 0 }
        return completedWeekDays.reduce(0.0) { $0 + $1.consumedCarbs } / Double(completedWeekDays.count)
    }

    private var weeklyAvgFat: Double {
        guard !completedWeekDays.isEmpty else { return 0 }
        return completedWeekDays.reduce(0.0) { $0 + $1.consumedFat } / Double(completedWeekDays.count)
    }

    private var trendText: String {
        let change = weeklyEstimatedChangeKg
        if change < -0.05 { return "\u{2193} Kilo veriyor" }
        if change > 0.05 { return "\u{2191} Dikkat" }
        return "\u{2192} Sabit"
    }

    private var trendColor: Color {
        let change = weeklyEstimatedChangeKg
        if change < -0.05 { return Theme.green }
        if change > 0.05 { return Theme.orange }
        return Theme.textSecondary
    }

    private func shortDayName(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1: return "Paz"
        case 2: return "Pzt"
        case 3: return "Sal"
        case 4: return "\u{00C7}ar"
        case 5: return "Per"
        case 6: return "Cum"
        case 7: return "Cmt"
        default: return "?"
        }
    }

    private func statusEmoji(_ day: DayPlan) -> String {
        switch day.status {
        case .completed: return "\u{2705}"
        case .exceeded: return "\u{26A0}\u{FE0F}"
        case .underate: return "\u{2B07}\u{FE0F}"
        case .missed: return "\u{274C}"
        case .today: return "\u{1F4CD}"
        case .planned: return "\u{1F4CB}"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Weekly summary
                        weeklySummaryCard
                            .id("weeklyCard")
                            .padding(.bottom, 4)

                        // Collapsible past section
                        if !pastDays.isEmpty {
                            DisclosureGroup(isExpanded: $showPastDays) {
                                ForEach(pastDays) { plan in
                                    DayRowView(plan: plan)
                                        .id(plan.date)
                                        .onTapGesture { selectedPlan = plan }
                                }
                            } label: {
                                HStack {
                                    Text("\u{25B6} \u{00D6}nceki g\u{00FC}nler")
                                        .font(Theme.captionFont)
                                        .foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    Text(dateRangeText(pastDays))
                                        .font(Theme.microFont)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                .padding(.vertical, 8)
                            }
                            .tint(Theme.textSecondary)
                        }

                        // Always visible: 3 days before + today + 3 days after
                        ForEach(visibleDays) { plan in
                            DayRowView(plan: plan)
                                .id(plan.date)
                                .onTapGesture { selectedPlan = plan }
                        }

                        // Collapsible future section
                        if !futureDays.isEmpty {
                            DisclosureGroup(isExpanded: $showFutureDays) {
                                ForEach(futureDays) { plan in
                                    DayRowView(plan: plan)
                                        .id(plan.date)
                                        .onTapGesture { selectedPlan = plan }
                                }
                            } label: {
                                HStack {
                                    Text("\u{25B6} Sonraki g\u{00FC}nler")
                                        .font(Theme.captionFont)
                                        .foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    Text(dateRangeText(futureDays))
                                        .font(Theme.microFont)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                .padding(.vertical, 8)
                            }
                            .tint(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Theme.background)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("weeklyCard", anchor: .top)
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
        }
    }

    private var weeklySummaryCard: some View {
        DisclosureGroup(isExpanded: $weeklyCardExpanded) {
            VStack(spacing: 0) {
                Divider()
                    .overlay(Theme.cardBorder)
                    .padding(.vertical, 8)

                // Header row
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 40, alignment: .leading)
                    Text("Kal")
                        .frame(maxWidth: .infinity)
                    Text("Açık")
                        .frame(maxWidth: .infinity)
                    Text("Pro")
                        .frame(maxWidth: .infinity)
                    Text("Kar")
                        .frame(maxWidth: .infinity)
                    Text("Ya\u{011F}")
                        .frame(maxWidth: .infinity)
                }
                .font(Theme.microFont)
                .foregroundStyle(Theme.textTertiary)
                .padding(.bottom, 6)

                // Day rows
                ForEach(thisWeekDays) { day in
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            HStack(spacing: 3) {
                                Text(statusEmoji(day))
                                    .font(.system(size: 10))
                                Text(shortDayName(day.date))
                                    .font(Theme.microFont)
                                    .foregroundStyle(day.status == .today ? Theme.accent : Theme.textSecondary)
                            }
                            .frame(width: 40, alignment: .leading)

                            if dayHasData(day) || day.status == .today {
                                Text("\(day.consumedCalories)")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Theme.textPrimary)
                                let deficit = day.tdee - day.consumedCalories
                                let targetDeficit = day.tdee - day.targetCalories
                                Text("\(deficit)")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(deficitColor(actual: deficit, target: targetDeficit))
                                Text("\(Int(day.consumedProtein))g")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Theme.textSecondary)
                                Text("\(Int(day.consumedCarbs))g")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Theme.textSecondary)
                                Text("\(Int(day.consumedFat))g")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Theme.textSecondary)
                            } else {
                                Text("\u{2014}")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Theme.textTertiary)
                                Text("\u{2014}")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Theme.textTertiary)
                                Text("\u{2014}")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Theme.textTertiary)
                                Text("\u{2014}")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Theme.textTertiary)
                                Text("\u{2014}")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .font(Theme.captionFont)
                        .padding(.vertical, 6)

                        Divider()
                            .overlay(Theme.cardBorder.opacity(0.5))
                    }
                }

                // Average row
                HStack(spacing: 0) {
                    Text("Ort")
                        .frame(width: 40, alignment: .leading)
                        .fontWeight(.bold)
                    Text("\(weeklyAvgCalories)")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(weeklyAvgDeficit)")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .foregroundStyle(weeklyAvgDeficit > 0 ? Theme.green : Theme.red)
                    Text("\(Int(weeklyAvgProtein))g")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(Int(weeklyAvgCarbs))g")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(Int(weeklyAvgFat))g")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textSecondary)
                }
                .font(Theme.captionFont)
                .padding(.vertical, 8)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\u{1F4CA} Bu Hafta")
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(daysWithData)/7 g\u{00FC}nde veri")
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\u{1F525} \(totalDeficitThisWeek) kcal a\u{00E7}\u{0131}k")
                        .font(Theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.orange)
                    Text(trendText)
                        .font(Theme.microFont)
                        .foregroundStyle(trendColor)
                }
            }
            .padding(.vertical, 4)
        }
        .tint(Theme.textSecondary)
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Day Row

struct DayRowView: View {
    let plan: DayPlan

    private var statusIcon: String {
        switch plan.status {
        case .completed: return "checkmark.circle.fill"
        case .exceeded: return "xmark.circle.fill"
        case .underate: return "exclamationmark.triangle.fill"
        case .missed: return "minus.circle.fill"
        case .today: return "location.fill"
        case .planned: return "doc.text"
        }
    }

    private var statusColor: Color {
        switch plan.status {
        case .completed: return Theme.green
        case .exceeded: return Theme.red
        case .underate: return Theme.orange
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
                    let plannedDeficit = plan.snapshotTargetDeficit > 0 ? plan.snapshotTargetDeficit : plan.tdee - plan.targetCalories
                    Text("~\(plannedDeficit) a\u{00E7}\u{0131}k")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)

                case .missed:
                    Text("0 / \(plan.targetCalories) kcal")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()

                default:
                    let actualDeficit = plan.tdee - plan.consumedCalories
                    let targetDeficit = plan.snapshotTargetDeficit > 0 ? plan.snapshotTargetDeficit : plan.tdee - plan.targetCalories
                    Text("\(plan.consumedCalories) / \(plan.targetCalories) kcal")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(actualDeficit) a\u{00E7}\u{0131}k")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(deficitRowColor(actual: actualDeficit, target: targetDeficit))
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

    private func deficitRowColor(actual: Int, target: Int) -> Color {
        if actual <= 0 {
            return Theme.red
        } else if target > 0 && actual >= Int(Double(target) * 0.80) {
            return Theme.green
        } else {
            return Theme.orange
        }
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

                    // Section 1: Yeme Hedefi
                    eatingTargetCard

                    // Section 2: Kalori Açığı
                    if plan.status != .planned {
                        deficitCard
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
                            HStack(alignment: .top, spacing: 8) {
                                Text(foodEmoji(entry.name))
                                    .font(.title3)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.name)
                                        .font(Theme.bodyFont)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Theme.textPrimary)

                                    if !entry.amount.isEmpty {
                                        Text("\(entry.amount)  \u{2022}  \(entry.calories) kcal")
                                            .font(Theme.captionFont)
                                            .foregroundStyle(Theme.textSecondary)
                                    } else {
                                        Text("\(entry.calories) kcal")
                                            .font(Theme.captionFont)
                                            .foregroundStyle(Theme.textSecondary)
                                    }

                                    Text("P: \(Int(entry.protein))g  K: \(Int(entry.carbs))g  Y: \(Int(entry.fat))g")
                                        .font(Theme.microFont)
                                        .foregroundStyle(Theme.textTertiary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 6)

                            if entry.id != dayEntries.last?.id {
                                Divider()
                                    .overlay(Theme.cardBorder.opacity(0.5))
                            }
                        }

                        // Total row
                        Divider()
                            .overlay(Theme.cardBorder)
                            .padding(.top, 4)

                        HStack {
                            Text("Toplam")
                                .font(Theme.bodyFont)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(plan.consumedCalories) kcal")
                                .font(Theme.bodyFont)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.top, 2)

                        let totalP = dayEntries.reduce(0.0) { $0 + $1.protein }
                        let totalC = dayEntries.reduce(0.0) { $0 + $1.carbs }
                        let totalF = dayEntries.reduce(0.0) { $0 + $1.fat }
                        Text("P: \(Int(totalP))g  K: \(Int(totalC))g  Y: \(Int(totalF))g")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
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

    private func foodEmoji(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("tavuk") || lower.contains("chicken") { return "\u{1F357}" }
        if lower.contains("et") || lower.contains("dana") || lower.contains("k\u{0131}yma") || lower.contains("biftek") || lower.contains("kuzu") { return "\u{1F969}" }
        if lower.contains("bal\u{0131}k") || lower.contains("somon") || lower.contains("ton") { return "\u{1F41F}" }
        if lower.contains("yumurta") { return "\u{1F95A}" }
        if lower.contains("s\u{00FC}t") || lower.contains("yo\u{011F}urt") || lower.contains("kefir") || lower.contains("peynir") { return "\u{1F95B}" }
        if lower.contains("ekmek") || lower.contains("tost") { return "\u{1F35E}" }
        if lower.contains("pirin\u{00E7}") || lower.contains("bulgur") || lower.contains("makarna") || lower.contains("noodle") { return "\u{1F35A}" }
        if lower.contains("salata") || lower.contains("sebze") || lower.contains("brokoli") || lower.contains("biber") || lower.contains("\u{0131}spanak") { return "\u{1F966}" }
        if lower.contains("ya\u{011F}") || lower.contains("zeytinya\u{011F}\u{0131}") { return "\u{1FAD2}" }
        if lower.contains("meyve") || lower.contains("elma") || lower.contains("muz") || lower.contains("portakal") { return "\u{1F34E}" }
        if lower.contains("kahve") || lower.contains("coffee") { return "\u{2615}" }
        if lower.contains("\u{00E7}ay") || lower.contains("tea") { return "\u{1FAD6}" }
        if lower.contains("su") || lower.contains("water") { return "\u{1F4A7}" }
        if lower.contains("patates") || lower.contains("k\u{0131}zartma") { return "\u{1F35F}" }
        if lower.contains("pizza") { return "\u{1F355}" }
        if lower.contains("hamburger") || lower.contains("burger") { return "\u{1F354}" }
        if lower.contains("pilav") { return "\u{1F35A}" }
        if lower.contains("corba") || lower.contains("\u{00E7}orba") { return "\u{1F372}" }
        return "\u{1F37D}\u{FE0F}"
    }

    private var isPastOlderThan7Days: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfDay(for: .now))!
        return plan.date < sevenDaysAgo
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch plan.status {
        case .completed:
            Label("Kalori a\u{00E7}\u{0131}\u{011F}\u{0131} hedefine ula\u{015F}t\u{0131}n", systemImage: "checkmark.circle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.green)
        case .exceeded:
            Label("Kalori fazlas\u{0131} \u{2014} a\u{00E7}\u{0131}k veremadin", systemImage: "xmark.circle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.red)
        case .underate:
            Label("A\u{00E7}\u{0131}k hedefinin gerisinde kald\u{0131}n", systemImage: "exclamationmark.triangle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.orange)
        case .missed:
            Label("Bu g\u{00FC}n i\u{00E7}in kay\u{0131}t yok", systemImage: "xmark.circle.fill")
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

    // MARK: - Yeme Hedefi Card

    private var eatingTargetCard: some View {
        let diff = plan.consumedCalories - plan.targetCalories
        let progress = plan.targetCalories > 0 ? min(Double(plan.consumedCalories) / Double(plan.targetCalories), 1.0) : 0
        let progressColor: Color = diff > 0 ? Theme.orange : Theme.green

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\u{1F3AF} Yeme Hedefi")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if plan.status != .planned {
                    Text("%\(plan.caloriePercentage)")
                        .font(Theme.captionFont)
                        .fontWeight(.bold)
                        .foregroundStyle(progressColor)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.trackBackground)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressColor)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 12)

            HStack {
                Text("Hedef: \(plan.targetCalories)")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Yenen: \(plan.consumedCalories)")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textPrimary)
            }

            if plan.status != .planned {
                if diff > 0 {
                    Label("Hedefi \(diff) kcal a\u{015F}t\u{0131}n", systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.orange)
                } else if diff == 0 {
                    Label("Hedefe tam ula\u{015F}t\u{0131}n", systemImage: "checkmark.circle.fill")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.green)
                } else {
                    Label("\(abs(diff)) kcal kalori kald\u{0131}", systemImage: "checkmark.circle.fill")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.green)
                }
            }
        }
        .padding()
        .themeCard()
    }

    // MARK: - Kalori Açığı Card

    private var deficitCard: some View {
        let actualDeficit = plan.tdee - plan.consumedCalories
        let targetDeficit = plan.snapshotTargetDeficit > 0 ? plan.snapshotTargetDeficit : plan.tdee - plan.targetCalories
        let deficitGap = targetDeficit - actualDeficit
        let deficitProgress: Double = targetDeficit > 0 ? min(max(Double(actualDeficit) / Double(targetDeficit), 0), 1.0) : 0
        let deficitPercent = targetDeficit > 0 ? Int(deficitProgress * 100) : 0

        let deficitColor: Color
        if actualDeficit <= 0 {
            deficitColor = Theme.red
        } else if targetDeficit > 0 && actualDeficit >= Int(Double(targetDeficit) * 0.80) {
            deficitColor = Theme.green
        } else {
            deficitColor = Theme.orange
        }

        return VStack(alignment: .leading, spacing: 10) {
            Text("\u{1F525} Kalori A\u{00E7}\u{0131}\u{011F}\u{0131}")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Yak\u{0131}m (TDEE):")
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(plan.tdee) kcal")
                        .foregroundStyle(Theme.textPrimary)
                }
                HStack {
                    Text("Yenen:")
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(plan.consumedCalories) kcal")
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .font(Theme.captionFont)

            Divider()
                .overlay(Theme.cardBorder)

            // Deficit progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Ger\u{00E7}ek a\u{00E7}\u{0131}k: \(actualDeficit) kcal")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(deficitColor)
                    Spacer()
                    Text("Hedef: \(targetDeficit) kcal")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.trackBackground)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(deficitColor)
                            .frame(width: geo.size.width * deficitProgress)
                    }
                }
                .frame(height: 12)

                if actualDeficit <= 0 {
                    Label("A\u{00E7}\u{0131}k yok \u{2014} \(abs(actualDeficit)) kcal fazla", systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.red)
                } else if deficitGap > 0 {
                    Label("Hedef a\u{00E7}\u{0131}\u{011F}\u{0131}n \(deficitGap) kcal gerisinde (%\(deficitPercent))", systemImage: "arrow.down.right")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(deficitColor)
                } else {
                    Label("Hedef a\u{00E7}\u{0131}\u{011F}\u{0131} tutturuldu (%\(deficitPercent))", systemImage: "checkmark.circle.fill")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.green)
                }
            }
        }
        .padding()
        .themeCard()
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
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
