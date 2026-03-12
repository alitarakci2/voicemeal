//
//  VoiceMealApp.swift
//  VoiceMeal
//
//  Created by Ali Tarakçı on 11.03.2026.
//

import SwiftUI
import SwiftData

@main
struct VoiceMealApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: FoodEntry.self)
    }
}
