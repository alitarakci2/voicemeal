//
//  NutritionReportService.swift
//  VoiceMeal
//

import Foundation
import SwiftData

// Legacy alias kept to minimize churn in any untouched call sites.
typealias NutritionReportWeekKind = ReportPeriodKind

enum NutritionReportError: LocalizedError {
    case insufficientData
    case cooldownActive(secondsRemaining: Int)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .insufficientData: return "Not enough data for a report."
        case .cooldownActive(let s): return "Cooldown: \(s)s remaining."
        case .generationFailed(let m): return m
        }
    }
}

struct NutritionReportContext {
    let report: NutritionReport?
    let period: ReportPeriod
    let kind: ReportPeriodKind
    let periodStart: Date
    let periodEnd: Date
    let daysOfData: Int
    /// Only meaningful for `.program`.
    let programDay: Int
    let programTotalDays: Int
}

enum NutritionReportService {
    static let cooldownSeconds: TimeInterval = 4 * 60 * 60

    // MARK: - Minimum-days policy (per period)

    static let minimumDaysForWeek = 3
    static let minimumDaysForMonth = 7

    static var minimumDaysForProgram: Int {
        #if DEBUG
        return 1
        #else
        return 3
        #endif
    }

    static func minimumDays(for period: ReportPeriod) -> Int {
        switch period {
        case .week:    return minimumDaysForWeek
        case .month:   return minimumDaysForMonth
        case .program: return minimumDaysForProgram
        }
    }

    // MARK: - Week boundaries (Monday-Sunday)

    static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let startOfDay = cal.startOfDay(for: date)
        var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)
        components.weekday = 2
        return cal.date(from: components) ?? startOfDay
    }

    static func weekEnd(for date: Date, calendar: Calendar = .current) -> Date {
        let start = weekStart(for: date, calendar: calendar)
        let sundayStart = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return calendar.date(byAdding: .second, value: 86399, to: sundayStart) ?? sundayStart
    }

    static func isMonday(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.weekday, from: date) == 2
    }

    // MARK: - Calendar month boundaries

    static func calendarMonthStart(for date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month], from: startOfDay)
        return calendar.date(from: components) ?? startOfDay
    }

    static func calendarMonthEnd(for date: Date, calendar: Calendar = .current) -> Date {
        let start = calendarMonthStart(for: date, calendar: calendar)
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: start),
              let end = calendar.date(byAdding: .second, value: -1, to: nextMonth) else {
            return start
        }
        return end
    }

    static func isFirstOfMonth(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.day, from: date) == 1
    }

    // MARK: - Context resolution

    /// Generic entry point — dispatches to period-specific resolvers.
    static func resolveContext(
        for period: ReportPeriod,
        today: Date,
        profile: UserProfile?,
        allEntries: [FoodEntry],
        existingReports: [NutritionReport],
        language: String
    ) -> NutritionReportContext {
        switch period {
        case .week:    return resolveWeekContext(today: today, allEntries: allEntries, existingReports: existingReports, language: language)
        case .month:   return resolveMonthContext(today: today, allEntries: allEntries, existingReports: existingReports, language: language)
        case .program: return resolveProgramContext(today: today, profile: profile, allEntries: allEntries, existingReports: existingReports, language: language)
        }
    }

    /// Back-compat overload — old call sites that didn't specify a period default to `.week`.
    static func resolveContext(
        today: Date,
        allEntries: [FoodEntry],
        existingReports: [NutritionReport],
        language: String
    ) -> NutritionReportContext {
        resolveWeekContext(today: today, allEntries: allEntries, existingReports: existingReports, language: language)
    }

    static func resolveWeekContext(
        today: Date,
        allEntries: [FoodEntry],
        existingReports: [NutritionReport],
        language: String
    ) -> NutritionReportContext {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: today)
        let todayEntryCount = allEntries.filter { $0.date >= startOfToday }.count

        let currentWeekStart = weekStart(for: today)
        let lastWeekStart = cal.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart

        let kind: ReportPeriodKind
        let targetStart: Date
        if isMonday(today) && todayEntryCount == 0 {
            targetStart = lastWeekStart
            kind = .previous
        } else if isMonday(today) && todayEntryCount > 0 {
            targetStart = currentWeekStart
            kind = .inProgress
        } else {
            targetStart = currentWeekStart
            kind = .current
        }

        let targetEnd = weekEnd(for: targetStart)
        let daysOfData = countDaysOfData(entries: allEntries, start: targetStart, end: targetEnd)
        let existing = findExistingReport(reports: existingReports, period: .week, start: targetStart, language: language)

        return NutritionReportContext(
            report: existing,
            period: .week,
            kind: kind,
            periodStart: targetStart,
            periodEnd: targetEnd,
            daysOfData: daysOfData,
            programDay: 0,
            programTotalDays: 0
        )
    }

    static func resolveMonthContext(
        today: Date,
        allEntries: [FoodEntry],
        existingReports: [NutritionReport],
        language: String
    ) -> NutritionReportContext {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: today)
        let todayEntryCount = allEntries.filter { $0.date >= startOfToday }.count

        let currentMonthStart = calendarMonthStart(for: today)
        let lastMonthStart = cal.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart

        let kind: ReportPeriodKind
        let targetStart: Date
        if isFirstOfMonth(today) && todayEntryCount == 0 {
            targetStart = lastMonthStart
            kind = .previous
        } else if isFirstOfMonth(today) && todayEntryCount > 0 {
            targetStart = currentMonthStart
            kind = .inProgress
        } else {
            targetStart = currentMonthStart
            kind = .current
        }

        let targetEnd = calendarMonthEnd(for: targetStart)
        let daysOfData = countDaysOfData(entries: allEntries, start: targetStart, end: targetEnd)
        let existing = findExistingReport(reports: existingReports, period: .month, start: targetStart, language: language)

        return NutritionReportContext(
            report: existing,
            period: .month,
            kind: kind,
            periodStart: targetStart,
            periodEnd: targetEnd,
            daysOfData: daysOfData,
            programDay: 0,
            programTotalDays: 0
        )
    }

    static func resolveProgramContext(
        today: Date,
        profile: UserProfile?,
        allEntries: [FoodEntry],
        existingReports: [NutritionReport],
        language: String
    ) -> NutritionReportContext {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: today)

        guard let profile, profile.goalDays > 0 else {
            return NutritionReportContext(
                report: nil,
                period: .program,
                kind: .programNotStarted,
                periodStart: startOfToday,
                periodEnd: startOfToday,
                daysOfData: 0,
                programDay: 0,
                programTotalDays: 0
            )
        }

        let programStart = cal.startOfDay(for: profile.effectiveProgramStart)
        let totalDays = profile.goalDays
        let elapsed = (cal.dateComponents([.day], from: programStart, to: startOfToday).day ?? 0) + 1
        let programDay = max(1, min(totalDays, elapsed))

        let programEnd: Date = {
            guard let endDay = cal.date(byAdding: .day, value: totalDays - 1, to: programStart),
                  let eod = cal.date(byAdding: .second, value: 86399, to: endDay) else {
                return startOfToday
            }
            return eod
        }()

        let kind: ReportPeriodKind
        if elapsed > totalDays {
            kind = .programCompleted
        } else {
            kind = .current
        }

        let windowEnd = min(startOfToday.addingTimeInterval(86399), programEnd)
        let daysOfData = countDaysOfData(entries: allEntries, start: programStart, end: windowEnd)
        let existing = findExistingReport(reports: existingReports, period: .program, start: programStart, language: language)

        return NutritionReportContext(
            report: existing,
            period: .program,
            kind: kind,
            periodStart: programStart,
            periodEnd: programEnd,
            daysOfData: daysOfData,
            programDay: programDay,
            programTotalDays: totalDays
        )
    }

    static func countDaysOfData(entries: [FoodEntry], start: Date, end: Date) -> Int {
        let cal = Calendar.current
        let daysWithFood = Set(
            entries
                .filter { $0.date >= start && $0.date <= end }
                .map { cal.startOfDay(for: $0.date) }
        )
        return daysWithFood.count
    }

    private static func findExistingReport(
        reports: [NutritionReport],
        period: ReportPeriod,
        start: Date,
        language: String
    ) -> NutritionReport? {
        let cal = Calendar.current
        // Filter out reports generated with an older prompt version — history stays in DB,
        // but the UI and cooldown treat them as absent so a fresh report regenerates.
        return reports.first { r in
            r.periodType == period
                && cal.isDate(r.effectivePeriodStart, inSameDayAs: start)
                && r.language == language
                && r.promptVersion >= GroqService.nutritionReportPromptVersion
        }
    }

    // MARK: - Cooldown

    static func cooldownRemaining(for report: NutritionReport, now: Date = .now) -> Int {
        let elapsed = now.timeIntervalSince(report.generatedAt)
        let remaining = cooldownSeconds - elapsed
        return remaining > 0 ? Int(remaining) : 0
    }

    // MARK: - Payload for Groq

    /// Builds a compact JSON payload for the AI. Week uses per-entry detail; month/program
    /// aggregate by day to keep token cost bounded for longer windows.
    static func buildPayload(
        entries: [FoodEntry],
        period: ReportPeriod,
        periodStart: Date,
        periodEnd: Date,
        programTotalDays: Int = 0
    ) -> String {
        switch period {
        case .week:
            return buildWeeklyEntryPayload(entries: entries, periodStart: periodStart, periodEnd: periodEnd)
        case .month, .program:
            return buildDailyAggregatePayload(
                entries: entries,
                periodStart: periodStart,
                periodEnd: periodEnd,
                totalDays: period == .program ? max(1, programTotalDays) : nil
            )
        }
    }

    /// Back-compat overload — defaults to week semantics.
    static func buildPayload(entries: [FoodEntry], weekStart: Date, weekEnd: Date) -> String {
        buildWeeklyEntryPayload(entries: entries, periodStart: weekStart, periodEnd: weekEnd)
    }

    private static func buildWeeklyEntryPayload(entries: [FoodEntry], periodStart: Date, periodEnd: Date) -> String {
        let cal = Calendar.current
        let filtered = entries
            .filter { $0.date >= periodStart && $0.date <= periodEnd }
            .sorted { $0.date < $1.date }
        let items: [[String: Any]] = filtered.map { e in
            let dayIndex = cal.dateComponents([.day], from: periodStart, to: cal.startOfDay(for: e.date)).day ?? 0
            return [
                "d": max(0, min(6, dayIndex)),
                "n": e.name,
                "c": e.calories,
                "p": Int(e.protein.rounded()),
                "cb": Int(e.carbs.rounded()),
                "f": Int(e.fat.rounded())
            ]
        }
        let root: [String: Any] = [
            "days": 7,
            "entries": items
        ]
        return serialize(root)
    }

    private static func buildDailyAggregatePayload(
        entries: [FoodEntry],
        periodStart: Date,
        periodEnd: Date,
        totalDays: Int?
    ) -> String {
        let cal = Calendar.current
        let filtered = entries
            .filter { $0.date >= periodStart && $0.date <= periodEnd }
        var byDay: [Int: (c: Double, p: Double, cb: Double, f: Double, n: Int)] = [:]
        for e in filtered {
            let dayIndex = cal.dateComponents([.day], from: periodStart, to: cal.startOfDay(for: e.date)).day ?? 0
            var bucket = byDay[dayIndex] ?? (0, 0, 0, 0, 0)
            bucket.c += Double(e.calories)
            bucket.p += e.protein
            bucket.cb += e.carbs
            bucket.f += e.fat
            bucket.n += 1
            byDay[dayIndex] = bucket
        }
        let days: [[String: Any]] = byDay.keys.sorted().map { d in
            let b = byDay[d] ?? (0, 0, 0, 0, 0)
            return [
                "d": d,
                "c": Int(b.c.rounded()),
                "p": Int(b.p.rounded()),
                "cb": Int(b.cb.rounded()),
                "f": Int(b.f.rounded()),
                "m": b.n
            ]
        }
        var root: [String: Any] = ["days": days]
        if let totalDays {
            root["totalDays"] = totalDays
        } else {
            let spanDays = (cal.dateComponents([.day], from: periodStart, to: periodEnd).day ?? 0) + 1
            root["totalDays"] = max(1, spanDays)
        }
        return serialize(root)
    }

    private static func serialize(_ root: [String: Any]) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "{}"
    }

    // MARK: - Filename helpers

    static func weekLabel(for weekStart: Date, calendar: Calendar = .current) -> String {
        let year = calendar.component(.yearForWeekOfYear, from: weekStart)
        let week = calendar.component(.weekOfYear, from: weekStart)
        return String(format: "%04d-W%02d", year, week)
    }

    static func monthLabel(for monthStart: Date, calendar: Calendar = .current) -> String {
        let year = calendar.component(.year, from: monthStart)
        let month = calendar.component(.month, from: monthStart)
        return String(format: "%04d-%02d", year, month)
    }

    static func shareFilename(for period: ReportPeriod, periodStart: Date, programDay: Int = 0) -> String {
        switch period {
        case .week:
            return "voicemeal-beslenme-karnesi-\(weekLabel(for: periodStart)).png"
        case .month:
            return "voicemeal-beslenme-karnesi-\(monthLabel(for: periodStart)).png"
        case .program:
            return "voicemeal-beslenme-karnesi-program-day-\(max(1, programDay)).png"
        }
    }

    /// Back-compat — week-only filename helper.
    static func shareFilename(for weekStart: Date) -> String {
        shareFilename(for: .week, periodStart: weekStart)
    }

    // MARK: - Persistence

    static func upsert(
        payload: NutritionReportPayload,
        period: ReportPeriod,
        periodStart: Date,
        periodEnd: Date,
        gapKind: CalorieGapKind,
        language: String,
        daysOfData: Int,
        isComplete: Bool,
        programDay: Int,
        programTotalDays: Int,
        in context: ModelContext,
        existingReports: [NutritionReport]
    ) -> NutritionReport {
        let gapKindRaw = gapKindRawValue(gapKind)
        let cal = Calendar.current
        // Reuse only same-version rows; older-version rows remain as history and a new row is inserted.
        if let existing = existingReports.first(where: { r in
            r.periodType == period
                && cal.isDate(r.effectivePeriodStart, inSameDayAs: periodStart)
                && r.language == language
                && r.promptVersion >= GroqService.nutritionReportPromptVersion
        }) {
            existing.score = payload.score
            existing.summary = payload.summary
            existing.strengthsJSON = encodeList(payload.strengths)
            existing.improvementsJSON = encodeList(payload.improvements)
            existing.microInsights = payload.microInsights
            existing.weeklyPattern = payload.weeklyPattern
            existing.gapKindRaw = gapKindRaw
            existing.generatedAt = .now
            existing.daysOfData = daysOfData
            existing.isComplete = isComplete
            existing.periodTypeRaw = period.rawValue
            existing.periodStartDate = periodStart
            existing.periodEndDate = periodEnd
            if period == .week {
                existing.weekStartDate = periodStart
                existing.weekEndDate = periodEnd
            }
            existing.programDay = programDay
            existing.programTotalDays = programTotalDays
            existing.promptVersion = GroqService.nutritionReportPromptVersion
            try? context.save()
            return existing
        } else {
            let report = NutritionReport(
                weekStartDate: period == .week ? periodStart : .distantPast,
                weekEndDate: period == .week ? periodEnd : .distantPast,
                score: payload.score,
                summary: payload.summary,
                strengths: payload.strengths,
                improvements: payload.improvements,
                microInsights: payload.microInsights,
                weeklyPattern: payload.weeklyPattern,
                gapKindRaw: gapKindRaw,
                language: language,
                daysOfData: daysOfData,
                isComplete: isComplete,
                periodType: period,
                periodStartDate: periodStart,
                periodEndDate: periodEnd,
                programDay: programDay,
                programTotalDays: programTotalDays
            )
            report.promptVersion = GroqService.nutritionReportPromptVersion
            context.insert(report)
            try? context.save()
            return report
        }
    }

    static func gapKindRawValue(_ kind: CalorieGapKind) -> String {
        switch kind {
        case .deficit: return "deficit"
        case .surplus: return "surplus"
        case .maintain: return "maintain"
        case .observe: return "observe"
        }
    }

    static func gapKind(from raw: String) -> CalorieGapKind {
        switch raw {
        case "surplus": return .surplus
        case "maintain": return .maintain
        case "observe": return .observe
        default: return .deficit
        }
    }

    private static func encodeList(_ list: [String]) -> String {
        guard let data = try? JSONEncoder().encode(list),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }
}
