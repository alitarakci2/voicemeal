//
//  WaterGoalService.swift
//  VoiceMeal
//

import Foundation

@Observable
class WaterGoalService {
    var dailyGoalMl: Int = 2500
    var activeEnergyKcal: Double = 0

    /// Calculate smart water goal: weight × 33 + active energy bonus, capped at 5000ml
    func calculate(weightKg: Double, activeEnergyKcal: Double, overrideMl: Int?) {
        self.activeEnergyKcal = activeEnergyKcal

        if let override = overrideMl, override > 0 {
            dailyGoalMl = override
            return
        }

        let base = Int(weightKg * 33)
        // Add 500ml per 500kcal of active energy
        let bonus = Int((activeEnergyKcal / 500.0) * 500)
        dailyGoalMl = min(base + bonus, 5000)
    }
}
