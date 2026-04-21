//
//  NutritionReportService.swift
//  VoiceMeal
//

import Foundation
import SwiftData

enum NutritionReportWeekKind {
    case thisWeek
    case lastWeek
    case inProgress
}

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
    let weekKind: NutritionReportWeekKind
    let weekStart: Date
    let weekEnd: Date
    let daysOfData: Int
}

enum NutritionReportService {
    static let cooldownSeconds: TimeInterval = 4 * 60 * 60

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

    static func isSundayEndOfDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return calendar.component(.weekday, from: date) == 1 && hour >= 20
    }

    // MARK: - Context resolution

    static func resolveContext(
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

        let kind: NutritionReportWeekKind
        let targetStart: Date
        if isMonday(today) && todayEntryCount == 0 {
            targetStart = lastWeekStart
            kind = .lastWeek
        } else if isMonday(today) && todayEntryCount > 0 {
            targetStart = currentWeekStart
            kind = .inProgress
        } else {
            targetStart = currentWeekStart
            kind = .thisWeek
        }

        let targetEnd = weekEnd(for: targetStart)
        let daysOfData = countDaysOfData(entries: allEntries, weekStart: targetStart, weekEnd: targetEnd)
        let existing = existingReports.first { report in
            Calendar.current.isDate(report.weekStartDate, inSameDayAs: targetStart)
                && report.language == language
        }

        return NutritionReportContext(
            report: existing,
            weekKind: kind,
            weekStart: targetStart,
            weekEnd: targetEnd,
            daysOfData: daysOfData
        )
    }

    static func countDaysOfData(entries: [FoodEntry], weekStart: Date, weekEnd: Date) -> Int {
        let cal = Calendar.current
        let daysWithFood = Set(
            entries
                .filter { $0.date >= weekStart && $0.date <= weekEnd }
                .map { cal.startOfDay(for: $0.date) }
        )
        return daysWithFood.count
    }

    // MARK: - Cooldown

    static func cooldownRemaining(for report: NutritionReport, now: Date = .now) -> Int {
        let elapsed = now.timeIntervalSince(report.generatedAt)
        let remaining = cooldownSeconds - elapsed
        return remaining > 0 ? Int(remaining) : 0
    }

    // MARK: - Payload for Groq

    static func buildPayload(entries: [FoodEntry], weekStart: Date, weekEnd: Date) -> String {
        let cal = Calendar.current
        let filtered = entries
            .filter { $0.date >= weekStart && $0.date <= weekEnd }
            .sorted { $0.date < $1.date }
        let items: [[String: Any]] = filtered.map { e in
            let dayIndex = cal.dateComponents([.day], from: weekStart, to: cal.startOfDay(for: e.date)).day ?? 0
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

    static func shareFilename(for weekStart: Date) -> String {
        "voicemeal-beslenme-karnesi-\(weekLabel(for: weekStart)).png"
    }

    // MARK: - Persistence

    static func upsert(
        payload: NutritionReportPayload,
        weekStart: Date,
        weekEnd: Date,
        gapKind: CalorieGapKind,
        language: String,
        daysOfData: Int,
        isComplete: Bool,
        in context: ModelContext,
        existingReports: [NutritionReport]
    ) -> NutritionReport {
        let gapKindRaw = gapKindRawValue(gapKind)
        let cal = Calendar.current
        if let existing = existingReports.first(where: {
            cal.isDate($0.weekStartDate, inSameDayAs: weekStart) && $0.language == language
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
            existing.weekEndDate = weekEnd
            try? context.save()
            return existing
        } else {
            let report = NutritionReport(
                weekStartDate: weekStart,
                weekEndDate: weekEnd,
                score: payload.score,
                summary: payload.summary,
                strengths: payload.strengths,
                improvements: payload.improvements,
                microInsights: payload.microInsights,
                weeklyPattern: payload.weeklyPattern,
                gapKindRaw: gapKindRaw,
                language: language,
                daysOfData: daysOfData,
                isComplete: isComplete
            )
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
        }
    }

    static func gapKind(from raw: String) -> CalorieGapKind {
        switch raw {
        case "surplus": return .surplus
        case "maintain": return .maintain
        default: return .deficit
        }
    }

    private static func encodeList(_ list: [String]) -> String {
        guard let data = try? JSONEncoder().encode(list),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }
}
