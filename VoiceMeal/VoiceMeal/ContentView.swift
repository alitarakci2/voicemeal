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
        let black = UIColor.black

        // Tab bar - force black for ALL states
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = black
        tabAppearance.shadowColor = .clear

        // Normal icons/text
        let normalColor = UIColor(white: 0.45, alpha: 1)
        tabAppearance.stackedLayoutAppearance.normal.iconColor = normalColor
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        tabAppearance.compactInlineLayoutAppearance.normal.iconColor = normalColor
        tabAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        tabAppearance.inlineLayoutAppearance.normal.iconColor = normalColor
        tabAppearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]

        // Selected icons/text
        let accent = UIColor(Color(hex: "6C63FF"))
        tabAppearance.stackedLayoutAppearance.selected.iconColor = accent
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        tabAppearance.compactInlineLayoutAppearance.selected.iconColor = accent
        tabAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        tabAppearance.inlineLayoutAppearance.selected.iconColor = accent
        tabAppearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().barTintColor = black
        UITabBar.appearance().backgroundColor = black
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().unselectedItemTintColor = normalColor

        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = black
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // Segmented control
        UISegmentedControl.appearance().selectedSegmentTintColor = accent
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(white: 0.6, alpha: 1)], for: .normal)
        UISegmentedControl.appearance().backgroundColor = UIColor(Color(hex: "1C1C1E"))

    }

    var body: some View {
        Group {
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
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
