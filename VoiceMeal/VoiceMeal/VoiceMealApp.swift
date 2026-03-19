//
//  VoiceMealApp.swift
//  VoiceMeal
//
//  Created by Ali Tarakçı on 11.03.2026.
//

import SwiftData
import SwiftUI

@main
struct VoiceMealApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    _ = await NotificationService.shared.requestPermission()
                }
        }
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self, WaterEntry.self, MealPlan.self])
    }
}
