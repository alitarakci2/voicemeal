//
//  WatchConnectivityService.swift
//  VoiceMeal
//
//  iPhone side - sends daily data and meal list to Apple Watch
//

import Foundation
import WatchConnectivity

class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendDailyData(
        eatenCalories: Int,
        goalCalories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        proteinTarget: Double,
        carbTarget: Double,
        fatTarget: Double,
        deficit: Int,
        meals: [(name: String, amount: String, calories: Int, protein: Double, carbs: Double, fat: Double)] = []
    ) {
        var data: [String: Any] = [
            "eatenCalories": eatenCalories,
            "goalCalories": goalCalories,
            "protein": protein,
            "carbs": carbs,
            "fat": fat,
            "proteinTarget": proteinTarget,
            "carbTarget": carbTarget,
            "fatTarget": fatTarget,
            "deficit": deficit,
            "timestamp": Date().timeIntervalSince1970,
            "appLanguage": UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? "tr"
        ]

        let mealsData: [[String: Any]] = meals.map { m in
            [
                "name": m.name,
                "amount": m.amount,
                "calories": m.calories,
                "protein": m.protein,
                "carbs": m.carbs,
                "fat": m.fat
            ]
        }
        data["meals"] = mealsData

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(data, replyHandler: nil)
        }
        try? WCSession.default.updateApplicationContext(data)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
