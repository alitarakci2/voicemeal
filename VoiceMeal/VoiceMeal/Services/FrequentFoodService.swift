//
//  FrequentFoodService.swift
//  VoiceMeal
//

import Foundation

struct FrequentFoodService {
    /// Returns top 10 most frequent food names from the last 30 days
    static func getFrequentFoods(entries: [FoodEntry]) -> [String] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let recentEntries = entries.filter { $0.date >= thirtyDaysAgo }

        let counts = Dictionary(
            recentEntries.map { ($0.name.lowercased(), 1) },
            uniquingKeysWith: +
        )

        return counts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
    }
}
