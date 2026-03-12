//
//  FoodEntry.swift
//  VoiceMeal
//

import Foundation
import SwiftData

@Model
final class FoodEntry {
    var id: UUID
    var name: String
    var amount: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var date: Date

    init(name: String, amount: String, calories: Int, protein: Double, carbs: Double, fat: Double, date: Date = .now) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.date = date
    }
}
