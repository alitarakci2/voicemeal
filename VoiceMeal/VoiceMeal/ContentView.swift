//
//  ContentView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @State private var onboardingComplete = false
    @State private var selectedTab = 0
    @State private var goalEngine = GoalEngine()
    @State private var groqService = GroqService()
    @State private var showFeedback = false
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundedAt: Date?
    private let watchService = WatchConnectivityService.shared

    private var todayEntries: [FoodEntry] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= startOfDay }
    }

    private func syncToWatch() {
        let entries = todayEntries
        let eaten = entries.reduce(0) { $0 + $1.calories }
        let protein = entries.reduce(0.0) { $0 + $1.protein }
        let carbs = entries.reduce(0.0) { $0 + $1.carbs }
        let fat = entries.reduce(0.0) { $0 + $1.fat }
        let realDeficit = Int(goalEngine.tdee) - eaten

        let meals = entries.map { e in
            (name: e.name, amount: e.amount, calories: e.calories, protein: e.protein, carbs: e.carbs, fat: e.fat)
        }

        watchService.sendDailyData(
            eatenCalories: eaten,
            goalCalories: goalEngine.dailyCalorieTarget,
            protein: protein,
            carbs: carbs,
            fat: fat,
            proteinTarget: Double(goalEngine.proteinTarget),
            carbTarget: Double(goalEngine.carbTarget),
            fatTarget: Double(goalEngine.fatTarget),
            deficit: realDeficit,
            targetDeficit: Int(goalEngine.cappedDailyDeficit),
            meals: meals
        )
    }

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
        let accent = UIColor(ThemeManager.shared.current.accent)
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
                .task {
                    _ = await NotificationService.shared.requestPermission()
                }
                .onChange(of: profiles) {
                    goalEngine.update(with: profiles.first)
                }
                .onReceive(NotificationCenter.default.publisher(for: .profileUpdated)) { _ in
                    if let profile = profiles.first {
                        goalEngine.updateProfile(profile)
                    }
                    syncToWatch()
                }
                .onChange(of: allEntries.count) {
                    syncToWatch()
                }
                .onChange(of: selectedTab) { _, newTab in
                    let tabNames = ["Record", "Plan", "Statistics", "Settings"]
                    let tabName = (0..<tabNames.count).contains(newTab) ? tabNames[newTab] : "Unknown"
                    FeedbackService.shared.currentTab = tabName
                    FeedbackService.shared.addLog("Tab changed: \(tabName)")
                }
                .onShake {
                    showFeedback = true
                    FeedbackService.shared.addLog("Shake detected - feedback opened")
                }
                .sheet(isPresented: $showFeedback) {
                    FeedbackSheet(
                        isPresented: $showFeedback,
                        appLanguage: groqService.appLanguage
                    )
                    .environmentObject(themeManager)
                }
            } else {
                OnboardingContainerView(onboardingComplete: $onboardingComplete)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                backgroundedAt = Date()
                FeedbackService.shared.addLog("App backgrounded")
            } else if newPhase == .active, let bgDate = backgroundedAt {
                if Date().timeIntervalSince(bgDate) > 300 {
                    selectedTab = 0
                }
                backgroundedAt = nil
                FeedbackService.shared.addLog("App foregrounded")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
