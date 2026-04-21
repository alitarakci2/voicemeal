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
        isComplete: Bool
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
    }

    var strengths: [String] {
        Self.decode(strengthsJSON)
    }

    var improvements: [String] {
        Self.decode(improvementsJSON)
    }

    var hasValidScore: Bool {
        score >= 1 && score <= 10 && daysOfData >= 3
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
