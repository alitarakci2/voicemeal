//
//  PlanView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct PlanView: View {
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @State private var planService = PlanService()
    @Environment(GoalEngine.self) private var goalEngine
    @State private var selectedPlan: DayPlan?
    @State private var showPastDays = false
    @State private var showFutureDays = false
    @State private var weeklyCardExpanded = false

    private var dayPlans: [DayPlan] {
        _ = planService.refreshID
        guard let profile = profiles.first else { return [] }
        return planService.generateDayPlans(profile: profile, entries: allEntries, goalEngine: goalEngine)
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }
        return dayPlans.filter { $0.date >= weekStart && $0.date <= today }
    }

    private func dayHasData(_ day: DayPlan) -> Bool {
        day.status != .missed && day.status != .planned
    }

    private var daysWithData: Int {
        thisWeekDays.filter { dayHasData($0) }.count
    }

    private var totalDeficitThisWeek: Int {
        thisWeekDays.filter { dayHasData($0) }.reduce(0) { $0 + ($1.tdee - $1.consumedCalories) }
    }

    private var weeklyEstimatedChangeKg: Double {
        thisWeekDays.filter { dayHasData($0) }.reduce(0.0) { $0 + $1.estimatedWeightChangeKg }
    }

    private var weeklyAvgCalories: Int {
        let days = thisWeekDays.filter { dayHasData($0) }
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { $0 + $1.consumedCalories } / days.count
    }

    private var weeklyAvgProtein: Double {
        let days = thisWeekDays.filter { dayHasData($0) }
        guard !days.isEmpty else { return 0 }
        return days.reduce(0.0) { $0 + $1.consumedProtein } / Double(days.count)
    }

    private var weeklyAvgCarbs: Double {
        let days = thisWeekDays.filter { dayHasData($0) }
        guard !days.isEmpty else { return 0 }
        return days.reduce(0.0) { $0 + $1.consumedCarbs } / Double(days.count)
    }

    private var weeklyAvgFat: Double {
        let days = thisWeekDays.filter { dayHasData($0) }
        guard !days.isEmpty else { return 0 }
        return days.reduce(0.0) { $0 + $1.consumedFat } / Double(days.count)
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EEE"
        let name = formatter.string(from: date)
        return String(name.prefix(3)).capitalized
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
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
