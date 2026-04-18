//
//  PlanView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @Query private var allSnapshots: [DailySnapshot]
    @State private var planService = PlanService()
    @Environment(GoalEngine.self) private var goalEngine
    @State private var selectedPlan: DayPlan?
    @State private var showPastDays = false
    @State private var showFutureDays = false
    @State private var weeklyCardExpanded = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasAppeared = false

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

    private var yesterdayPlan: DayPlan? {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: -1, to: todayID) else { return nil }
        return dayPlans.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var todayPlan: DayPlan? {
        let calendar = Calendar.current
        return dayPlans.first { calendar.isDate($0.date, inSameDayAs: Date()) }
    }

    private var tomorrowPlan: DayPlan? {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: 1, to: todayID) else { return nil }
        return dayPlans.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var previousDays: [DayPlan] {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: -1, to: Date()) else { return [] }
        let cutoff = calendar.startOfDay(for: date)
        return dayPlans.filter { $0.date < cutoff }.sorted { $0.date > $1.date }
    }

    private var upcomingDays: [DayPlan] {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: 2, to: todayID) else { return [] }
        let cutoff = calendar.startOfDay(for: date)
        return dayPlans.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
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
        guard let mondayStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ),
        let sundayEnd = calendar.date(byAdding: .day, value: 6, to: mondayStart) else { return [] }
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
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Sticky header
                HStack {
                    Text("Plan")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        withAnimation { scrollProxy?.scrollTo("top", anchor: .top) }
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
                .overlay(Divider().opacity(0.2), alignment: .bottom)

                ScrollViewReader { proxy in
                ScrollView {
                LazyVStack(spacing: 10) {
                        Color.clear.frame(height: 0).id("top")

                        // Plan settings (collapsible)
                        planSettingsCard

                        // Weekly summary
                        weeklySummaryCard
                            .id("weeklyCard")
                            .padding(.bottom, 4)

                        // Collapsible previous days section
                        if !previousDays.isEmpty {
                            sectionHeader(
                                title: L.previousDays.localized + " (\(previousDays.count))",
                                dateRange: dateRangeText(previousDays.sorted { $0.date < $1.date }),
                                isExpanded: $showPastDays
                            )
                            if showPastDays {
                                ForEach(previousDays) { plan in
                                    DayRowView(plan: plan)
                                        .id(plan.date)
                                        .onTapGesture { selectedPlan = plan }
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }

                        // Yesterday
                        if let yesterday = yesterdayPlan {
                            DayRowView(plan: yesterday)
                                .id(yesterday.date)
                                .onTapGesture { selectedPlan = yesterday }
                        }

                        // Today — highlighted
                        if let today = todayPlan {
                            DayRowView(plan: today)
                                .id(today.date)
                                .onTapGesture { selectedPlan = today }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.accent, lineWidth: 1.5)
                                )
                        }

                        // Tomorrow
                        if let tomorrow = tomorrowPlan {
                            DayRowView(plan: tomorrow)
                                .id(tomorrow.date)
                                .onTapGesture { selectedPlan = tomorrow }
                        }

                        // Collapsible upcoming days section
                        if !upcomingDays.isEmpty {
                            sectionHeader(
                                title: L.nextDays.localized + " (\(upcomingDays.count))",
                                dateRange: dateRangeText(upcomingDays),
                                isExpanded: $showFutureDays
                            )
                            if showFutureDays {
                                ForEach(upcomingDays) { plan in
                                    DayRowView(plan: plan)
                                        .id(plan.date)
                                        .onTapGesture { selectedPlan = plan }
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onAppear {
                    if !hasAppeared {
                        hasAppeared = true
                        FeedbackService.shared.addLog("Plan tab opened")
                    }
                    scrollProxy = proxy
                    loadPlanSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("weeklyCard", anchor: .top)
                        }
                    }
                }
                } // ScrollViewReader
            } // VStack
        } // ZStack
        .onReceive(NotificationCenter.default.publisher(for: .profileUpdated)) { _ in
            planService.regeneratePlans()
            loadPlanSettings()
        }
        .sheet(item: $selectedPlan) { plan in
            DayDetailSheetView(plan: plan)
                .environmentObject(themeManager)
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

    // MARK: - Section Header

    private func sectionHeader(title: String, dateRange: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text(dateRange)
                    .font(Theme.microFont)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
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
            HStack(spacing: 12) {
                Text("\u{2699}\u{FE0F}")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.goal.localized)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text("\(String(format: "%.1f", goalWeightKg)) kg \u{00B7} \(String(format: "goal_duration".localized, goalDays)) \u{00B7} \(intensityLabel)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: showPlanSettings ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 4)
        }
        .tint(Theme.textSecondary)
        .padding(16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
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
        VStack(spacing: 0) {
            // Header (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { weeklyCardExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Text("\u{1F4CA}")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.thisWeek.localized)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text(String(format: L.daysWithDataFormat.localized, daysWithData))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: L.kcalDeficitFormat.localized, totalDeficitThisWeek))
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.accent)
                        Text(trendText)
                            .font(.caption)
                            .foregroundStyle(trendColor)
                    }
                    Image(systemName: weeklyCardExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if weeklyCardExpanded {
                Divider().overlay(Theme.cardBorder.opacity(0.3))

                // Column headers
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
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

                // Day rows with alternating backgrounds
                ForEach(Array(thisWeekDays.enumerated()), id: \.element.id) { index, day in
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
                            ForEach(0..<5, id: \.self) { _ in
                                Text("\u{2014}")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                    .font(Theme.captionFont)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 16)
                    .background(
                        day.status == .today
                            ? Theme.accent.opacity(0.08)
                            : (index % 2 == 0 ? Color.clear : Color.white.opacity(0.02))
                    )
                }

                Divider().overlay(Theme.cardBorder.opacity(0.3)).padding(.horizontal, 16)

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
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Day Row

struct DayRowView: View {
    let plan: DayPlan

    private var statusIcon: String {
        switch plan.status {
        case .completed: return "\u{2705}"
        case .exceeded: return "\u{26A0}\u{FE0F}"
        case .underate: return "\u{2B07}\u{FE0F}"
        case .missed: return "\u{274C}"
        case .today: return "\u{1F4CD}"
        case .planned: return "\u{1F4CB}"
        }
    }

    private var statusColor: Color {
        switch plan.status {
        case .completed: return Theme.green
        case .exceeded: return Theme.red
        case .underate: return Theme.orange
        case .missed: return Theme.textTertiary
        case .today: return Theme.accent
        case .planned: return Theme.textTertiary
        }
    }

    private var isToday: Bool { plan.status == .today }

    private var dateLabel: String {
        if isToday { return L.today.localized }
        return plan.date.formatted(.dateTime.day().month(.abbreviated))
    }

    private var dayAbbrev: String {
        let weekday = Calendar.current.component(.weekday, from: plan.date)
        let keys = ["", "day_sun_short", "day_mon_short", "day_tue_short", "day_wed_short", "day_thu_short", "day_fri_short", "day_sat_short"]
        return keys[weekday].localized
    }

    private var calorieProgress: Double {
        guard plan.targetCalories > 0 else { return 0 }
        return min(Double(plan.consumedCalories) / Double(plan.targetCalories), 1.0)
    }

    private var deficitText: String {
        switch plan.status {
        case .today:
            return L.ongoing.localized
        case .planned:
            let d = plan.snapshotTargetDeficit > 0 ? plan.snapshotTargetDeficit : plan.tdee - plan.targetCalories
            return String(format: L.deficitApproxFormat.localized, d)
        case .missed:
            return ""
        default:
            let d = plan.tdee - plan.consumedCalories
            return String(format: L.deficitValueFormat.localized, d)
        }
    }

    private var deficitColor: Color {
        let actual = plan.tdee - plan.consumedCalories
        let target = plan.snapshotTargetDeficit > 0 ? plan.snapshotTargetDeficit : plan.tdee - plan.targetCalories
        if actual <= 0 { return Theme.red }
        if target > 0 && actual >= Int(Double(target) * 0.80) { return Theme.green }
        return Theme.orange
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status circle + day abbreviation
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(statusIcon)
                        .font(.system(size: 18))
                }
                Text(dayAbbrev)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dateLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(plan.activities, id: \.self) { activity in
                            Text(activityEmoji(activity))
                                .font(.caption)
                        }
                    }
                }

                // Calorie progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(statusColor)
                            .frame(width: max(geo.size.width * calorieProgress, 2))
                    }
                }
                .frame(height: 4)

                // Numbers row
                HStack {
                    Text("\(plan.consumedCalories) / \(plan.targetCalories) kcal")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    if !deficitText.isEmpty {
                        Text(deficitText)
                            .font(.caption.bold())
                            .foregroundStyle(isToday ? Theme.accent : deficitColor)
                    }
                }
            }
        }
        .padding(14)
        .background(isToday ? Theme.accent.opacity(0.12) : Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isToday ? Theme.accent.opacity(0.5) : Color.white.opacity(0.06),
                    lineWidth: isToday ? 1.5 : 1
                )
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
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.status == .today ? L.today.localized : plan.date.formatted(.dateTime.day().month(.wide).year()))
                            .font(Theme.titleFont)
                            .foregroundStyle(.white)
                        HStack(spacing: 6) {
                            ForEach(plan.activities, id: \.self) { activity in
                                Text(GoalEngine.activityDisplayNames[activity] ?? activity)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Theme.accent.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        // Status banner
                        statusBanner

                        // Rings row: eating goal + deficit
                        if plan.status != .planned {
                            ringsCard
                        }

                        // Eating target card
                        eatingTargetCard

                        // Deficit card
                        if plan.status != .planned {
                            deficitCard
                        }

                        // Macro section
                        macroSection

                        // Food entries
                        foodEntriesCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.clear)
        .onAppear {
            FeedbackService.shared.addLog("Day detail opened: \(plan.date.formatted())")
        }
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

    // MARK: - Rings Card

    private var ringsCard: some View {
        let eatingProgress = plan.targetCalories > 0 ? min(Double(plan.consumedCalories) / Double(plan.targetCalories), 1.0) : 0
        let remaining = plan.targetCalories - plan.consumedCalories
        let eatingRingColor: Color = remaining < 0 ? Theme.red : Theme.accent

        let actualDeficit = plan.tdee - plan.consumedCalories
        let targetDeficit = plan.snapshotTargetDeficit > 0 ? plan.snapshotTargetDeficit : plan.tdee - plan.targetCalories
        let deficitProgress: Double = targetDeficit > 0 ? min(max(Double(actualDeficit) / Double(targetDeficit), 0), 1.0) : 0
        let deficitRingColor: Color = actualDeficit <= 0 ? Theme.red : (targetDeficit > 0 && actualDeficit >= Int(Double(targetDeficit) * 0.80) ? Theme.green : Theme.orange)

        return HStack(spacing: 12) {
            // Eating Goal ring
            detailRingCard(
                title: "eating_goal".localized,
                value: "\(plan.consumedCalories)",
                subtitle: "/ \(plan.targetCalories) kcal",
                progress: eatingProgress,
                ringColor: eatingRingColor
            )

            // Deficit ring
            detailRingCard(
                title: "calorie_deficit_label".localized,
                value: "\(actualDeficit)",
                subtitle: "/ \(targetDeficit) kcal",
                progress: deficitProgress,
                ringColor: deficitRingColor
            )
        }
    }

    private func detailRingCard(title: String, value: String, subtitle: String, progress: Double, ringColor: Color) -> some View {
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
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Food Entries Card

    @ViewBuilder
    private var foodEntriesCard: some View {
        if plan.status == .planned {
            VStack(alignment: .leading, spacing: 10) {
                Text("plan_for_today_label".localized)
                    .font(Theme.headlineFont)
                    .foregroundStyle(.white)
                Text("\(L.goal.localized): \(plan.targetCalories) kcal")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 6) {
                    MacroTotalPill("P", value: plan.targetProtein, color: Theme.blue)
                    MacroTotalPill("K", value: plan.targetCarbs, color: Theme.orange)
                    MacroTotalPill("Y", value: plan.targetFat, color: Theme.fatColor)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        } else if dayEntries.isEmpty {
            Text(L.noFoodLog.localized)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.foods.localized)
                    .font(Theme.headlineFont)
                    .foregroundStyle(.white)

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
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
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
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
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
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.trackBackground)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(deficitColor)
                            .frame(width: max(geo.size.width * deficitProgress, 3))
                    }
                }
                .frame(height: 6)

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
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var macroSection: some View {
        VStack(spacing: 8) {
            detailMacroRow(label: "pro_short".localized, value: Double(plan.consumedProtein), target: Double(plan.targetProtein), color: Theme.blue)
            detailMacroRow(label: "carb_short".localized, value: Double(plan.consumedCarbs), target: Double(plan.targetCarbs), color: Theme.orange)
            detailMacroRow(label: "fat_short".localized, value: Double(plan.consumedFat), target: Double(plan.targetFat), color: Theme.fatColor)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func detailMacroRow(label: String, value: Double, target: Double, color: Color) -> some View {
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
}

#Preview {
    PlanView()
        .environment(GoalEngine())
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
