//
//  PlanView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @Query private var allSnapshots: [DailySnapshot]
    @State private var planService = PlanService()
    @Environment(GoalEngine.self) private var goalEngine
    @State private var selectedPlan: DayPlan?
    @State private var showPastDays = false
    @State private var showFutureDays = false
    @State private var weeklyCardExpanded = false

    // Plan settings
    @State private var showPlanSettings = false
    @State private var weeklySchedule: [[String]] = Array(repeating: ["rest"], count: 7)
    @State private var originalSchedule: [[String]] = Array(repeating: ["rest"], count: 7)
    @State private var goalWeightKg: Double = 65
    @State private var goalDays = 90
    @State private var intensityLevel: Double = 0.5
    @State private var showSavedToast = false
    @State private var settingsLoaded = false

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
        if change < -0.05 { return "\u{2193} \(L.trendLosing.localized)" }
        if change > 0.05 { return "\u{2191} \(L.trendWarning.localized)" }
        return "\u{2192} \(L.trendStable.localized)"
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
        case 1: return "day_sun_short".localized
        case 2: return "day_mon_short".localized
        case 3: return "day_tue_short".localized
        case 4: return "day_wed_short".localized
        case 5: return "day_thu_short".localized
        case 6: return "day_fri_short".localized
        case 7: return "day_sat_short".localized
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

    // MARK: - Goal validation

    private var weeklyChange: Double {
        guard let p = profiles.first, goalDays > 0 else { return 0 }
        return (p.currentWeightKg - goalWeightKg) / (Double(goalDays) / 7.0)
    }

    private var isSaveDisabled: Bool {
        weeklyChange > 1.5 || weeklyChange < -1.5
    }

    private var isDeficitCapped: Bool {
        guard let p = profiles.first, goalDays > 0 else { return false }
        let weightDiff = p.currentWeightKg - goalWeightKg
        let rawDeficit = (weightDiff * 7700) / Double(goalDays)
        let estimatedBMR: Double
        if p.gender == "male" {
            estimatedBMR = 10 * p.currentWeightKg + 6.25 * p.heightCm - 5 * Double(p.age) + 5
        } else {
            estimatedBMR = 10 * p.currentWeightKg + 6.25 * p.heightCm - 5 * Double(p.age) - 161
        }
        let estimatedTDEE = estimatedBMR * 1.5
        let maxDeficit = estimatedTDEE * 0.35
        let maxSurplus = estimatedTDEE * 0.20
        return rawDeficit > maxDeficit || rawDeficit < -maxSurplus
    }

    private var intensityLabel: String {
        switch intensityLevel {
        case ...0.3: return L.intensityLight.localized
        case 0.3...0.7: return L.intensityModerate.localized
        default: return L.intensityIntense.localized
        }
    }

    private var intensityDescription: String {
        switch intensityLevel {
        case ...0.3: return L.intensityLightDesc.localized
        case 0.3...0.7: return L.intensityModerateDesc.localized
        default: return L.intensityIntenseDesc.localized
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                        // Title
                        Text("Plan")
                            .font(Theme.titleFont)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)

                        // Plan settings (collapsible)
                        planSettingsCard

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
                                    Text("\u{25B6} \(L.previousDays.localized)")
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
                                    Text("\u{25B6} \(L.nextDays.localized)")
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
                .onAppear {
                    loadPlanSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("weeklyCard", anchor: .top)
                        }
                    }
                }
                .background(Theme.background)
            }
        .onReceive(NotificationCenter.default.publisher(for: .profileUpdated)) { _ in
            planService.regeneratePlans()
            loadPlanSettings()
        }
        .sheet(item: $selectedPlan) { plan in
            DayDetailSheetView(plan: plan)
        }
        .overlay(alignment: .bottom) {
            if showSavedToast {
                Text(L.savedToast.localized)
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

    // MARK: - Plan Settings Card

    private var planSettingsCard: some View {
        DisclosureGroup(isExpanded: $showPlanSettings) {
            VStack(spacing: 16) {
                Divider()
                    .overlay(Theme.cardBorder)

                // Goal Weight
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("target_weight".localized)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(String(format: "%.1f", goalWeightKg)) kg")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Slider(value: $goalWeightKg, in: 30...200, step: 0.5)
                        .tint(Theme.accent)

                    Stepper(String(format: "goal_duration".localized, goalDays), value: $goalDays, in: 14...365, step: 7)
                        .font(Theme.captionFont)

                    // Warnings
                    if weeklyChange > 1.0 {
                        Label("unhealthy_pace".localized, systemImage: "light.beacon.max.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.red)
                    } else if weeklyChange > 0.75 {
                        Label("aggressive_goal".localized, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                    }
                    if weeklyChange < -1.0 {
                        Label(L.weightGainTooFast.localized, systemImage: "light.beacon.max.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.red)
                    } else if weeklyChange < -0.5 {
                        Label(L.weightGainFast.localized, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                    }
                    if isDeficitCapped {
                        Label(L.deficitCapped.localized, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.orange)
                    }
                }

                Divider()
                    .overlay(Theme.cardBorder)

                // Intensity
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L.intensity.localized)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(intensityLabel)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Slider(value: $intensityLevel, in: 0...1, step: 0.1)
                        .tint(Theme.accent)
                    Text(intensityDescription)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }

                Divider()
                    .overlay(Theme.cardBorder)

                // Weekly Schedule
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.weeklySchedule.localized)
                        .font(Theme.bodyFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textPrimary)

                    Step5ScheduleView(weeklySchedule: $weeklySchedule)
                }

                // Save button
                Button {
                    savePlanSettings()
                } label: {
                    Text(L.save.localized)
                        .font(Theme.bodyFont)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isSaveDisabled)
            }
            .padding(.top, 8)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\u{2699}\u{FE0F} \(L.goal.localized)")
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.textPrimary)
                    Text(String(format: "goal_duration".localized, goalDays) + " \u{00B7} \(intensityLabel)")
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .tint(Theme.textSecondary)
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Plan Settings Load / Save

    private func loadPlanSettings() {
        guard let p = profiles.first else { return }
        goalWeightKg = p.goalWeightKg
        goalDays = p.goalDays
        intensityLevel = p.intensityLevel
        weeklySchedule = p.weeklySchedule
        originalSchedule = p.weeklySchedule
        settingsLoaded = true
    }

    private func savePlanSettings() {
        guard let p = profiles.first else { return }
        p.goalWeightKg = goalWeightKg
        p.goalDays = goalDays
        p.intensityLevel = intensityLevel
        p.weeklySchedule = weeklySchedule
        p.updatedAt = .now

        originalSchedule = weeklySchedule

        try? modelContext.save()
        NotificationCenter.default.post(name: .profileUpdated, object: nil)
        planService.regeneratePlans()

        showSavedToast = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSavedToast = false
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
                    Text(L.calShort.localized)
                        .frame(maxWidth: .infinity)
                    Text(L.deficitShort.localized)
                        .frame(maxWidth: .infinity)
                    Text(L.proShort.localized)
                        .frame(maxWidth: .infinity)
                    Text(L.carbShort.localized)
                        .frame(maxWidth: .infinity)
                    Text(L.fatShort.localized)
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
                    Text(L.average.localized)
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
                    Text("\u{1F4CA} \(L.thisWeek.localized)")
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.textPrimary)
                    Text(String(format: L.daysWithDataFormat.localized, daysWithData))
                        .font(Theme.microFont)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\u{1F525} \(String(format: L.kcalDeficitFormat.localized, totalDeficitThisWeek))")
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
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
            return L.today.localized
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
                    Text(L.ongoing.localized)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.blue)

                case .planned:
                    Text(String(format: L.targetKcalFormat.localized, plan.targetCalories))
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    let plannedDeficit = plan.snapshotTargetDeficit > 0 ? plan.snapshotTargetDeficit : plan.tdee - plan.targetCalories
                    Text(String(format: L.deficitApproxFormat.localized, plannedDeficit))
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
                    Text(String(format: L.deficitValueFormat.localized, actualDeficit))
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(deficitRowColor(actual: actualDeficit, target: targetDeficit))
                }
            }
        }
        .padding()
        .frame(minHeight: 72)
        .background(plan.status == .today ? Theme.accent.opacity(0.1) : Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            plan.status == .today
                ? RoundedRectangle(cornerRadius: 20).stroke(Theme.accent.opacity(0.4), lineWidth: 2)
                : nil
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
                        Text(plan.status == .today ? L.today.localized : plan.date.formatted(.dateTime.day().month(.wide).year()))
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

                    // Section 1: Eating Target
                    eatingTargetCard

                    // Section 2: Calorie Deficit
                    if plan.status != .planned {
                        deficitCard
                    }

                    macroSection

                    // Food entries
                    if plan.status == .planned {
                        Text("plan_for_today_label".localized)
                            .font(Theme.headlineFont)
                            .padding(.top, 4)
                        Text("\(L.goal.localized): \(plan.targetCalories) kcal")
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 6) {
                            MacroTotalPill("P", value: plan.targetProtein, color: Theme.blue)
                            MacroTotalPill("K", value: plan.targetCarbs, color: Theme.orange)
                            MacroTotalPill("Y", value: plan.targetFat, color: Theme.fatColor)
                        }
                    } else if dayEntries.isEmpty {
                        Text(L.noFoodLog.localized)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 4)
                    } else {
                        Text(L.foods.localized)
                            .font(Theme.headlineFont)
                            .padding(.top, 4)
                        ForEach(dayEntries, id: \.id) { entry in
                            FoodEntryRowView(entry: entry)

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
                            Text(L.total.localized)
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
                        HStack(spacing: 6) {
                            Spacer()
                            MacroTotalPill("P", value: Int(totalP), color: Theme.blue)
                            MacroTotalPill("K", value: Int(totalC), color: Theme.orange)
                            MacroTotalPill("Y", value: Int(totalF), color: Theme.fatColor)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(L.dayDetail.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.close.localized) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.background)
    }

    private var isPastOlderThan7Days: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfDay(for: .now))!
        return plan.date < sevenDaysAgo
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch plan.status {
        case .completed:
            Label("goal_reached_status".localized, systemImage: "checkmark.circle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.green)
        case .exceeded:
            Label("calorie_surplus_status".localized, systemImage: "xmark.circle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.red)
        case .underate:
            Label("behind_deficit_status".localized, systemImage: "exclamationmark.triangle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.orange)
        case .missed:
            Label("no_log_status".localized, systemImage: "xmark.circle.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textTertiary)
        case .today:
            Label("in_progress_status".localized, systemImage: "location.fill")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.blue)
        case .planned:
            Label("planned_status".localized, systemImage: "doc.text")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
        }

        if isPastOlderThan7Days {
            Text("goal_note_old_text".localized)
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
                Text("\u{1F3AF} \("eating_goal_card".localized)")
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
                Text("\(L.goal.localized): \(plan.targetCalories)")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(L.eaten.localized): \(plan.consumedCalories)")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textPrimary)
            }

            if plan.status != .planned {
                if diff > 0 {
                    Label(String(format: "exceeded_by".localized, diff), systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.orange)
                } else if diff == 0 {
                    Label("goal_reached_exact".localized, systemImage: "checkmark.circle.fill")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.green)
                } else {
                    Label(String(format: "calories_left".localized, abs(diff)), systemImage: "checkmark.circle.fill")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.green)
                }
            }
        }
        .padding()
        .themeCard()
    }

    // MARK: - Kalori Acigi Card

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
            Text("\u{1F525} \("calorie_deficit_card".localized)")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L.burnTdee.localized)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(plan.tdee) kcal")
                        .foregroundStyle(Theme.textPrimary)
                }
                HStack {
                    Text("\(L.eaten.localized):")
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
                    Text("\(L.realDeficit.localized): \(actualDeficit) kcal")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(deficitColor)
                    Spacer()
                    Text("\(L.goal.localized): \(targetDeficit) kcal")
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
                    Label(String(format: "no_deficit_surplus".localized, abs(actualDeficit)), systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.red)
                } else if deficitGap > 0 {
                    Label(String(format: "deficit_behind_by".localized, deficitGap, deficitPercent), systemImage: "arrow.down.right")
                        .font(Theme.captionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(deficitColor)
                } else {
                    Label(String(format: "deficit_goal_reached".localized, deficitPercent), systemImage: "checkmark.circle.fill")
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
            macroBar("protein_label".localized, eaten: Int(plan.consumedProtein), target: plan.targetProtein, color: .blue)
            macroBar("carb_label".localized, eaten: Int(plan.consumedCarbs), target: plan.targetCarbs, color: .orange)
            macroBar("fat_label".localized, eaten: Int(plan.consumedFat), target: plan.targetFat, color: .yellow)
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
