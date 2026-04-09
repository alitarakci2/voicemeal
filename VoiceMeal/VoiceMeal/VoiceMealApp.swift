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
    init() {
        _ = WatchConnectivityService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ThemeManager.shared)
        }
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self, WaterEntry.self])
    }
}
