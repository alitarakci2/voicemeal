//
//  MealPlanSuggestion.swift
//  VoiceMeal
//

import Foundation

struct MealPlanSuggestion: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let name: String
    let emoji: String
    let ingredients: [String]
    let prepNote: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let mealType: String // "breakfast" / "lunch" / "dinner"

    static func == (lhs: MealPlanSuggestion, rhs: MealPlanSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

struct DailyMealPlanResponse: Codable {
    let breakfast: [MealPlanSuggestion]
    let lunch: [MealPlanSuggestion]
    let dinner: [MealPlanSuggestion]
}
