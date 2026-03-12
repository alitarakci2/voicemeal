//
//  ContentView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @State private var onboardingComplete = false

    private var hasProfile: Bool {
        !profiles.isEmpty || onboardingComplete
    }

    var body: some View {
        if hasProfile {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Kayıt", systemImage: "mic")
                    }

                PlanView()
                    .tabItem {
                        Label("Plan", systemImage: "calendar")
                    }
            }
        } else {
            OnboardingContainerView(onboardingComplete: $onboardingComplete)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FoodEntry.self, UserProfile.self], inMemory: true)
}
