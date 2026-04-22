//
//  NutritionReport.swift
//  VoiceMeal
//

import Foundation
import SwiftData

@Model
final class NutritionReport {
    var id: UUID
    var weekStartDate: Date
    var weekEndDate: Date
    var score: Int
    var summary: String
    var strengthsJSON: String
    var improvementsJSON: String
    var microInsights: String
    var weeklyPattern: String
    var gapKindRaw: String
    var language: String
    var generatedAt: Date
    var daysOfData: Int
    var isComplete: Bool
    // Period-aware fields (introduced in v2; legacy week-only rows migrated via NutritionReportMigrator).
    var periodTypeRaw: String = ReportPeriod.week.rawValue
    var periodStartDate: Date = Date.distantPast
    var periodEndDate: Date = Date.distantPast
    // Optional program context — only populated when periodType == .program.
    var programDay: Int = 0
    var programTotalDays: Int = 0
    // Prompt version this report was generated with. Mismatch with GroqService.nutritionReportPromptVersion
    // means the report is served from the old prompt shape — service layer filters it out on resolve.
    var promptVersion: Int = 0

    init(
        weekStartDate: Date,
        weekEndDate: Date,
        score: Int,
        summary: String,
        strengths: [String],
        improvements: [String],
        microInsights: String,
        weeklyPattern: String,
        gapKindRaw: String,
        language: String,
        daysOfData: Int,
        isComplete: Bool,
        periodType: ReportPeriod = .week,
        periodStartDate: Date? = nil,
        periodEndDate: Date? = nil,
        programDay: Int = 0,
        programTotalDays: Int = 0
    ) {
        self.id = UUID()
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.score = score
        self.summary = summary
        self.strengthsJSON = Self.encode(strengths)
        self.improvementsJSON = Self.encode(improvements)
        self.microInsights = microInsights
        self.weeklyPattern = weeklyPattern
        self.gapKindRaw = gapKindRaw
        self.language = language
        self.generatedAt = .now
        self.daysOfData = daysOfData
        self.isComplete = isComplete
        self.periodTypeRaw = periodType.rawValue
        self.periodStartDate = periodStartDate ?? weekStartDate
        self.periodEndDate = periodEndDate ?? weekEndDate
        self.programDay = programDay
        self.programTotalDays = programTotalDays
    }

    var strengths: [String] {
        Self.decode(strengthsJSON)
    }

    var improvements: [String] {
        Self.decode(improvementsJSON)
    }

    var hasValidScore: Bool {
        score >= 1 && score <= 10 && daysOfData >= minimumDaysForValidScore
    }

    var periodType: ReportPeriod {
        ReportPeriod(rawValue: periodTypeRaw) ?? .week
    }

    /// Effective period start — falls back to `weekStartDate` for legacy rows not yet migrated.
    var effectivePeriodStart: Date {
        periodStartDate == .distantPast ? weekStartDate : periodStartDate
    }

    var effectivePeriodEnd: Date {
        periodEndDate == .distantPast ? weekEndDate : periodEndDate
    }

    private var minimumDaysForValidScore: Int {
        switch periodType {
        case .week:    return 3
        case .month:   return 7
        case .program:
            #if DEBUG
            return 1
            #else
            return 3
            #endif
        }
    }

    private static func encode(_ list: [String]) -> String {
        guard let data = try? JSONEncoder().encode(list),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }

    private static func decode(_ s: String) -> [String] {
        guard let data = s.data(using: .utf8),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return list
    }
}
