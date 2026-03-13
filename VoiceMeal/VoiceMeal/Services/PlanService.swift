//
//  PlanService.swift
//  VoiceMeal
//

import Foundation

@Observable
class PlanService {

    var refreshID = UUID()

    func regeneratePlans() {
        refreshID = UUID()
    }

    func generateDayPlans(profile: UserProfile, entries: [FoodEntry]) -> [DayPlan] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        guard let startDate = calendar.date(byAdding: .day, value: -30, to: today),
              let endDate = calendar.date(byAdding: .day, value: 7, to: today) else {
            return []
        }

        let entriesByDay = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        var plans: [DayPlan] = []
        var current = startDate

        while current <= endDate {
            let dayEntries = entriesByDay[current] ?? []
            let activities = activitiesForDate(current, profile: profile)

            let target = calculateTargets(profile: profile, activities: activities)

            let consumedCal = dayEntries.reduce(0) { $0 + $1.calories }
            let consumedP = dayEntries.reduce(0.0) { $0 + $1.protein }
            let consumedC = dayEntries.reduce(0.0) { $0 + $1.carbs }
            let consumedF = dayEntries.reduce(0.0) { $0 + $1.fat }

            let status: DayStatus
            if calendar.isDate(current, inSameDayAs: today) {
                status = .today
            } else if current > today {
                status = .planned
            } else if dayEntries.isEmpty {
                status = .missed
            } else if consumedCal > Int(Double(target.calories) * 1.1) {
                status = .exceeded
            } else if consumedCal < Int(Double(target.calories) * 0.85) {
                status = .underate
            } else {
                status = .completed
            }

            let plan = DayPlan(
                date: current,
                activities: activities,
                tdee: target.tdee,
                targetCalories: target.calories,
                targetProtein: target.protein,
                targetCarbs: target.carbs,
                targetFat: target.fat,
                consumedCalories: current > today ? 0 : consumedCal,
                consumedProtein: current > today ? 0 : consumedP,
                consumedCarbs: current > today ? 0 : consumedC,
                consumedFat: current > today ? 0 : consumedF,
                status: status
            )
            plans.append(plan)

            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return plans
    }

    private func activitiesForDate(_ date: Date, profile: UserProfile) -> [String] {
        let schedule = profile.weeklySchedule
        guard schedule.count == 7 else { return ["rest"] }

        let weekday = Calendar.current.component(.weekday, from: date)
        let index: Int
        switch weekday {
        case 1: index = 6   // Sunday
        case 2: index = 0   // Monday
        case 3: index = 1
        case 4: index = 2
        case 5: index = 3
        case 6: index = 4
        case 7: index = 5   // Saturday
        default: index = 0
        }
        let activities = schedule[index]
        return activities.isEmpty ? ["rest"] : activities
    }

    // NOTE: Historical accuracy requires a DailySnapshot model to store
    // per-day weight/profile values at the time. Currently all days use
    // today's profile values. Planned for a future sprint.
    private func calculateTargets(profile: UserProfile, activities: [String]) -> (tdee: Int, calories: Int, protein: Int, carbs: Int, fat: Int) {
        let bmr: Double
        if profile.gender == "male" {
            bmr = 10 * profile.currentWeightKg + 6.25 * profile.heightCm - 5 * Double(profile.age) + 5
        } else {
            bmr = 10 * profile.currentWeightKg + 6.25 * profile.heightCm - 5 * Double(profile.age) - 161
        }

        let multiplier: Double
        if activities == ["rest"] {
            multiplier = 1.2
        } else {
            let multipliers: [String: Double] = [
                "walking": 1.375,
                "weights": 1.55,
                "cycling": 1.55,
                "running": 1.725,
            ]
            let highest = activities.compactMap { multipliers[$0] }.max() ?? 1.2
            let bonus = activities.filter({ $0 != "rest" }).count > 1 ? 0.1 : 0.0
            multiplier = highest + bonus
        }

        let tdee = bmr * multiplier

        let rawDeficit: Double
        if profile.goalDays > 0 {
            let weightDiff = profile.currentWeightKg - profile.goalWeightKg
            rawDeficit = (weightDiff * 7700) / Double(profile.goalDays)
        } else {
            rawDeficit = 0
        }
        let maxDeficit = tdee * 0.35
        let maxSurplus = tdee * 0.20
        let deficit = max(-maxSurplus, min(maxDeficit, rawDeficit))

        let minimumCalorie = bmr * 0.85
        let rawCalories = tdee - deficit
        let calories: Int
        if deficit > 0 {
            calories = Int(max(rawCalories, minimumCalorie))
        } else {
            calories = Int(rawCalories)
        }

        let protein = Int(2.0 * profile.currentWeightKg)
        let fat = Int(Double(calories) * 0.25 / 9.0)
        let proteinCal = Double(protein) * 4.0
        let fatCal = Double(fat) * 9.0
        let carbs = max(0, Int((Double(calories) - proteinCal - fatCal) / 4.0))

        return (Int(tdee), calories, protein, carbs, fat)
    }
}
