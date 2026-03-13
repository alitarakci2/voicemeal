//
//  ContentView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @State private var onboardingComplete = false
    @State private var selectedTab = 0
    @State private var goalEngine = GoalEngine()

    private var hasProfile: Bool {
        !profiles.isEmpty || onboardingComplete
    }

    var body: some View {
        if hasProfile {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Kayıt", systemImage: "mic")
                    }
                    .tag(0)

                PlanView()
                    .tabItem {
                        Label("Plan", systemImage: "calendar")
                    }
                    .tag(1)

                SettingsView()
                    .tabItem {
                        Label("Ayarlar", systemImage: "gearshape")
                    }
                    .tag(2)
            }
            .environment(goalEngine)
            .onAppear {
                goalEngine.update(with: profiles.first)
            }
            .onChange(of: profiles) {
                goalEngine.update(with: profiles.first)
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileUpdated)) { _ in
                if let profile = profiles.first {
                    goalEngine.updateProfile(profile)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMealSuggestion)) { _ in
                selectedTab = 0
            }
        } else {
            OnboardingContainerView(onboardingComplete: $onboardingComplete)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
