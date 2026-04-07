//
//  WatchSessionManager.swift
//  VoiceMealWatch Watch App
//
//  Watch side - receives daily data and meal list from iPhone
//

import Foundation
import WatchConnectivity

struct WatchMeal: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

@Observable
class WatchSessionManager: NSObject {
    // Daily summary
    var eatenCalories: Int = 0
    var goalCalories: Int = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var proteinTarget: Double = 0
    var carbTarget: Double = 0
    var fatTarget: Double = 0
    var deficit: Int = 0
    var lastUpdate: Date?

    // Meal list
    var meals: [WatchMeal] = []

    var remainingCalories: Int {
        goalCalories - eatenCalories
    }

    var calorieProgress: Double {
        guard goalCalories > 0 else { return 0 }
        return min(Double(eatenCalories) / Double(goalCalories), 1.0)
    }

    var hasData: Bool {
        lastUpdate != nil && goalCalories > 0
    }

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Receive data from iPhone

    private func processData(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.eatenCalories = data["eatenCalories"] as? Int ?? 0
            self.goalCalories = data["goalCalories"] as? Int ?? 0
            self.protein = data["protein"] as? Double ?? 0
            self.carbs = data["carbs"] as? Double ?? 0
            self.fat = data["fat"] as? Double ?? 0
            self.proteinTarget = data["proteinTarget"] as? Double ?? 0
            self.carbTarget = data["carbTarget"] as? Double ?? 0
            self.fatTarget = data["fatTarget"] as? Double ?? 0
            self.deficit = data["deficit"] as? Int ?? 0

            if let mealsData = data["meals"] as? [[String: Any]] {
                self.meals = mealsData.map { m in
                    WatchMeal(
                        name: m["name"] as? String ?? "",
                        amount: m["amount"] as? String ?? "",
                        calories: m["calories"] as? Int ?? 0,
                        protein: m["protein"] as? Double ?? 0,
                        carbs: m["carbs"] as? Double ?? 0,
                        fat: m["fat"] as? Double ?? 0
                    )
                }
            }

            if let lang = data["appLanguage"] as? String {
                UserDefaults.standard.set([lang], forKey: "AppleLanguages")
            }

            if let ts = data["timestamp"] as? TimeInterval {
                self.lastUpdate = Date(timeIntervalSince1970: ts)
            } else {
                self.lastUpdate = .now
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let context = session.receivedApplicationContext as? [String: Any], !context.isEmpty {
            processData(context)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        processData(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        processData(applicationContext)
    }
}
