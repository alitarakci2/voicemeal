//
//  WidgetDataStore.swift
//  VoiceMeal
//

import Foundation
import WidgetKit

struct WidgetMealEntry: Codable, Hashable {
    let name: String
    let calories: Int
    let date: Date
}

struct WidgetData: Codable {
    let consumedCalories: Int
    let targetCalories: Int
    let remainingCalories: Int
    let targetDeficit: Int
    let actualDeficit: Int
    let proteinEaten: Double
    let proteinTarget: Double
    let lastMeals: [WidgetMealEntry]
    let theme: String
    let waterConsumed: Int
    let waterGoal: Int
    let lastUpdated: Date
    var isObserveMode: Bool = false

    enum CodingKeys: String, CodingKey {
        case consumedCalories, targetCalories, remainingCalories, targetDeficit, actualDeficit
        case proteinEaten, proteinTarget, lastMeals, theme, waterConsumed, waterGoal, lastUpdated
        case isObserveMode
    }

    init(
        consumedCalories: Int,
        targetCalories: Int,
        remainingCalories: Int,
        targetDeficit: Int,
        actualDeficit: Int,
        proteinEaten: Double,
        proteinTarget: Double,
        lastMeals: [WidgetMealEntry],
        theme: String,
        waterConsumed: Int,
        waterGoal: Int,
        lastUpdated: Date,
        isObserveMode: Bool = false
    ) {
        self.consumedCalories = consumedCalories
        self.targetCalories = targetCalories
        self.remainingCalories = remainingCalories
        self.targetDeficit = targetDeficit
        self.actualDeficit = actualDeficit
        self.proteinEaten = proteinEaten
        self.proteinTarget = proteinTarget
        self.lastMeals = lastMeals
        self.theme = theme
        self.waterConsumed = waterConsumed
        self.waterGoal = waterGoal
        self.lastUpdated = lastUpdated
        self.isObserveMode = isObserveMode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        consumedCalories = try c.decode(Int.self, forKey: .consumedCalories)
        targetCalories = try c.decode(Int.self, forKey: .targetCalories)
        remainingCalories = try c.decode(Int.self, forKey: .remainingCalories)
        targetDeficit = try c.decode(Int.self, forKey: .targetDeficit)
        actualDeficit = try c.decode(Int.self, forKey: .actualDeficit)
        proteinEaten = try c.decode(Double.self, forKey: .proteinEaten)
        proteinTarget = try c.decode(Double.self, forKey: .proteinTarget)
        lastMeals = try c.decode([WidgetMealEntry].self, forKey: .lastMeals)
        theme = try c.decode(String.self, forKey: .theme)
        waterConsumed = try c.decode(Int.self, forKey: .waterConsumed)
        waterGoal = try c.decode(Int.self, forKey: .waterGoal)
        lastUpdated = try c.decode(Date.self, forKey: .lastUpdated)
        isObserveMode = try c.decodeIfPresent(Bool.self, forKey: .isObserveMode) ?? false
    }

    var remainingCaloriesClamped: Int {
        max(0, remainingCalories)
    }

    var waterPercent: Double {
        waterGoal > 0 ? Double(waterConsumed) / Double(waterGoal) : 0
    }

    var caloriePercent: Double {
        targetCalories > 0 ? min(max(Double(consumedCalories) / Double(targetCalories), 0), 1.0) : 0
    }

    var proteinPercent: Double {
        proteinTarget > 0 ? min(max(proteinEaten / proteinTarget, 0), 1.0) : 0
    }

    var deficitPercent: Double {
        guard targetDeficit != 0 else { return 0 }
        return min(max(Double(actualDeficit) / Double(targetDeficit), 0), 1.0)
    }

    var lastMeal: WidgetMealEntry? { lastMeals.first }

    static let placeholder = WidgetData(
        consumedCalories: 1200,
        targetCalories: 2000,
        remainingCalories: 800,
        targetDeficit: 500,
        actualDeficit: 350,
        proteinEaten: 85,
        proteinTarget: 110,
        lastMeals: [
            WidgetMealEntry(name: "Tavuk salata", calories: 420, date: Date().addingTimeInterval(-3600)),
            WidgetMealEntry(name: "Yulaf", calories: 310, date: Date().addingTimeInterval(-10800)),
            WidgetMealEntry(name: "Kahvaltı", calories: 470, date: Date().addingTimeInterval(-21600))
        ],
        theme: "purple",
        waterConsumed: 1500,
        waterGoal: 2500,
        lastUpdated: Date()
    )
}

class WidgetDataStore {
    static let shared = WidgetDataStore()
    private let suiteName = "group.indio.VoiceMeal"
    private let key = "widgetData"

    func save(_ data: WidgetData) {
        let defaults = UserDefaults(suiteName: suiteName)
        let encoded = try? JSONEncoder().encode(data)
        defaults?.set(encoded, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func load() -> WidgetData? {
        let defaults = UserDefaults(suiteName: suiteName)
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }
}
