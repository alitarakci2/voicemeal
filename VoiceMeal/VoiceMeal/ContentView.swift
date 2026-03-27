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
    @State private var groqService = GroqService()

    private var hasProfile: Bool {
        !profiles.isEmpty || onboardingComplete
    }

    init() {
        // Tab bar styling - pure black background
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.black
        tabBarAppearance.shadowColor = UIColor(white: 0.15, alpha: 1)

        // Normal state
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.45, alpha: 1)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(white: 0.45, alpha: 1)
        ]

        // Selected state
        let accentColor = UIColor(Color(hex: "6C63FF"))
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = accentColor
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: accentColor
        ]

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Navigation bar styling
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor.black
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // Segmented control styling
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color(hex: "6C63FF"))
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(white: 0.6, alpha: 1)], for: .normal)
        UISegmentedControl.appearance().backgroundColor = UIColor(Color(hex: "1C1C1E"))
    }

    var body: some View {
        if hasProfile {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("tab_record".localized, systemImage: "mic")
                    }
                    .tag(0)

                PlanView()
                    .tabItem {
                        Label("tab_plan".localized, systemImage: "calendar")
                    }
                    .tag(1)

                StatisticsView()
                    .tabItem {
                        Label("tab_statistics".localized, systemImage: "chart.bar.fill")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("tab_settings".localized, systemImage: "gearshape")
                    }
                    .tag(3)
            }
            .tint(Theme.accent)
            .environment(goalEngine)
            .environment(groqService)
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
        } else {
            OnboardingContainerView(onboardingComplete: $onboardingComplete)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
