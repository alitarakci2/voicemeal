//
//  MealPlan.swift
//  VoiceMeal
//

import Foundation
import SwiftData

@Model
final class MealPlan {
    var id: UUID
    var date: Date
    var breakfastJSON: String
    var lunchJSON: String
    var dinnerJSON: String
    var selectedBreakfastJSON: String?
    var selectedLunchJSON: String?
    var selectedDinnerJSON: String?
    var generatedAt: Date
    var totalPlannedCalories: Int
    var totalPlannedProtein: Double

    // MARK: - Computed accessors

    var breakfastSuggestions: [MealPlanSuggestion] {
        get { Self.decode(breakfastJSON) }
        set { breakfastJSON = Self.encode(newValue) }
    }

    var lunchSuggestions: [MealPlanSuggestion] {
        get { Self.decode(lunchJSON) }
        set { lunchJSON = Self.encode(newValue) }
    }

    var dinnerSuggestions: [MealPlanSuggestion] {
        get { Self.decode(dinnerJSON) }
        set { dinnerJSON = Self.encode(newValue) }
    }

    var selectedBreakfast: MealPlanSuggestion? {
        get {
            guard let json = selectedBreakfastJSON else { return nil }
            return Self.decodeSingle(json)
        }
        set { selectedBreakfastJSON = newValue.map { Self.encodeSingle($0) } }
    }

    var selectedLunch: MealPlanSuggestion? {
        get {
            guard let json = selectedLunchJSON else { return nil }
            return Self.decodeSingle(json)
        }
        set { selectedLunchJSON = newValue.map { Self.encodeSingle($0) } }
    }

    var selectedDinner: MealPlanSuggestion? {
        get {
            guard let json = selectedDinnerJSON else { return nil }
            return Self.decodeSingle(json)
        }
        set { selectedDinnerJSON = newValue.map { Self.encodeSingle($0) } }
    }

    init(
        date: Date,
        breakfast: [MealPlanSuggestion],
        lunch: [MealPlanSuggestion],
        dinner: [MealPlanSuggestion]
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.breakfastJSON = Self.encode(breakfast)
        self.lunchJSON = Self.encode(lunch)
        self.dinnerJSON = Self.encode(dinner)
        self.generatedAt = .now

        let all = breakfast + lunch + dinner
        self.totalPlannedCalories = all.reduce(0) { $0 + $1.calories }
        self.totalPlannedProtein = all.reduce(0.0) { $0 + $1.protein }
    }

    // MARK: - JSON helpers

    private static func encode(_ items: [MealPlanSuggestion]) -> String {
        (try? String(data: JSONEncoder().encode(items), encoding: .utf8)) ?? "[]"
    }

    private static func decode(_ json: String) -> [MealPlanSuggestion] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([MealPlanSuggestion].self, from: data)) ?? []
    }

    private static func encodeSingle(_ item: MealPlanSuggestion) -> String {
        (try? String(data: JSONEncoder().encode(item), encoding: .utf8)) ?? "{}"
    }

    private static func decodeSingle(_ json: String) -> MealPlanSuggestion? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MealPlanSuggestion.self, from: data)
    }
}
