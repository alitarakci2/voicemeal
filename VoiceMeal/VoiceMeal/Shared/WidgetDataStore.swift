//
//  WidgetDataStore.swift
//  VoiceMeal
//

import Foundation
import WidgetKit

struct WidgetData: Codable {
    let consumedCalories: Int
    let targetCalories: Int
    let remainingCalories: Int
    let targetDeficit: Int
    let actualDeficit: Int
    let waterConsumed: Int
    let waterGoal: Int
    let lastUpdated: Date

    var remainingCaloriesClamped: Int {
        max(0, remainingCalories)
    }

    var waterPercent: Double {
        waterGoal > 0 ? Double(waterConsumed) / Double(waterGoal) : 0
    }

    var deficitPercent: Double {
        guard targetDeficit != 0 else { return 0 }
        return min(max(Double(actualDeficit) / Double(targetDeficit), 0), 1.0)
    }

    static let placeholder = WidgetData(
        consumedCalories: 1200,
        targetCalories: 2000,
        remainingCalories: 800,
        targetDeficit: 500,
        actualDeficit: 350,
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
