//
//  DailyLog.swift
//  VoiceMeal
//

import Foundation

struct DailyLog: Identifiable {
    let date: Date
    let entries: [FoodEntry]

    var id: Date { date }

    var totalCalories: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    var totalProtein: Double {
        entries.reduce(0) { $0 + $1.protein }
    }

    var totalCarbs: Double {
        entries.reduce(0) { $0 + $1.carbs }
    }

    var totalFat: Double {
        entries.reduce(0) { $0 + $1.fat }
    }

    static func groupByDay(_ entries: [FoodEntry]) -> [DailyLog] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        return grouped
            .map { DailyLog(date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }
}
