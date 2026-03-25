//
//  MealSuggestionView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct MealSuggestionView: View {
    let notificationType: MealNotificationType
    let remainingCalories: Int
    let remainingProtein: Int
    let remainingCarbs: Int
    let remainingFat: Int
    let todayMeals: [String]
    let preferredProteins: [String]
    let todayActivities: [String]
    let hrvStatus: HRVStatus
    var coachStyle: CoachStyle = .supportive

    @Environment(\.dismiss) private var dismiss
    @State private var suggestion: MealSuggestion?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cachedAt: Date?

    @Environment(GroqService.self) private var groqService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Text(notificationType == .afternoon ? "Ak\u{015F}am \u{00D6}nerisi" : "Gece At\u{0131}\u{015F}t\u{0131}rmal\u{0131}\u{011F}\u{0131}")
                            .font(Theme.titleFont)
                            .fontWeight(.bold)
                        Spacer()
                        if let time = cachedAt {
                            Text(time.formatted(.dateTime.hour().minute()))
                                .font(Theme.microFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    // Remaining macros summary
                    HStack(spacing: 16) {
                        macroChip("Kalori", value: "\(remainingCalories)", unit: "kcal")
                        macroChip("Protein", value: "\(remainingProtein)", unit: "g")
                        macroChip("Karb", value: "\(remainingCarbs)", unit: "g")
                        macroChip("Ya\u{011F}", value: "\(remainingFat)", unit: "g")
                    }

                    Divider()

                    if isLoading {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("\u{00D6}neri haz\u{0131}rlan\u{0131}yor...")
                                    .font(Theme.bodyFont)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else if let suggestion {
                        // Suggestion title
                        Text(suggestion.title)
                            .font(Theme.headlineFont)

                        // Suggestion body
                        Text(suggestion.body)
                            .font(Theme.bodyFont)
                            .fixedSize(horizontal: false, vertical: true)

                        // Suggested meals
                        if !suggestion.meals.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(suggestion.meals, id: \.name) { meal in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(meal.name)
                                                .font(Theme.bodyFont)
                                                .fontWeight(.medium)
                                            Text(meal.portion)
                                                .font(Theme.captionFont)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(meal.calories) kcal")
                                                .font(Theme.bodyFont)
                                            Text("\(meal.protein)g protein")
                                                .font(Theme.captionFont)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                    .padding()
                                    .background(Theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        // Refresh button
                        Button {
                            Task { await generateSuggestion(force: true) }
                        } label: {
                            Label("Farkl\u{0131} \u{00D6}neri", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    } else if let error = errorMessage {
                        VStack(spacing: 8) {
                            Text(error)
                                .font(Theme.bodyFont)
                                .foregroundStyle(Theme.textSecondary)
                            Button("Tekrar Dene") {
                                Task { await generateSuggestion(force: true) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
                .padding()
            }
            .navigationTitle("\u{00D6}neri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            .task {
                await generateSuggestion(force: false)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func macroChip(_ label: String, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.bodyFont)
                .fontWeight(.semibold)
            Text("\(label)")
                .font(Theme.microFont)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func generateSuggestion(force: Bool) async {
        // Use cache if less than 2 hours old
        if !force, let cached = cachedAt,
           Date.now.timeIntervalSince(cached) < 7200 {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await groqService.generateMealSuggestion(
                notificationType: notificationType,
                remainingCalories: remainingCalories,
                remainingProtein: remainingProtein,
                remainingCarbs: remainingCarbs,
                remainingFat: remainingFat,
                todayMeals: todayMeals,
                preferredProteins: preferredProteins,
                todayActivities: todayActivities,
                hrvStatus: hrvStatus,
                coachStyle: coachStyle
            )
            suggestion = result
            cachedAt = .now
        } catch {
            errorMessage = "\u{00D6}neri olu\u{015F}turulamad\u{0131}. \u{0130}nternet ba\u{011F}lant\u{0131}n\u{0131} kontrol et."
        }

        isLoading = false
    }
}
