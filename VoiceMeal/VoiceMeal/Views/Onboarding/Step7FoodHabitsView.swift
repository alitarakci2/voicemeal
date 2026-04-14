//
//  Step7FoodHabitsView.swift
//  VoiceMeal
//

import SwiftUI

struct Step7FoodHabitsView: View {
    @Binding var cookingLocation: CookingLocation
    @Binding var portionSize: PortionSize
    @Binding var oilUsage: OilUsage
    @Binding var proteinSource: ProteinSource
    @Binding var cuisinePreference: CuisinePreference
    @Binding var mealFrequency: MealFrequency
    var appLanguage: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("🍽️")
                        .font(.system(size: 50))
                    Text(appLanguage == "en"
                         ? "Your Food Habits"
                         : "Yemek Alışkanlıkların")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text(appLanguage == "en"
                         ? "Help your AI coach make better estimates"
                         : "AI koçunun daha iyi tahmin yapmasına yardım et")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Q1: Cooking location
                FoodHabitQuestion(
                    question: appLanguage == "en"
                        ? "Where do you usually eat?"
                        : "Genellikle nerede yemek yiyorsun?",
                    options: CookingLocation.allCases,
                    selected: cookingLocation,
                    onSelect: { cookingLocation = $0 },
                    label: { $0.label(appLanguage) },
                    emoji: { $0.emoji }
                )

                // Q2: Portion size
                FoodHabitQuestion(
                    question: appLanguage == "en"
                        ? "How large are your portions?"
                        : "Porsiyon büyüklüğün nasıl?",
                    options: PortionSize.allCases,
                    selected: portionSize,
                    onSelect: { portionSize = $0 },
                    label: { $0.label(appLanguage) },
                    emoji: { $0.emoji }
                )

                // Q3: Oil usage
                FoodHabitQuestion(
                    question: appLanguage == "en"
                        ? "How much oil/fat in your cooking?"
                        : "Yemeklerinde ne kadar yağ kullanılır?",
                    options: OilUsage.allCases,
                    selected: oilUsage,
                    onSelect: { oilUsage = $0 },
                    label: { $0.label(appLanguage) },
                    emoji: { $0.emoji }
                )

                // Q4: Protein source
                FoodHabitQuestion(
                    question: appLanguage == "en"
                        ? "Main protein source?"
                        : "Ana protein kaynağın nedir?",
                    options: ProteinSource.allCases,
                    selected: proteinSource,
                    onSelect: { proteinSource = $0 },
                    label: { $0.label(appLanguage) },
                    emoji: { $0.emoji }
                )

                // Q5: Cuisine
                FoodHabitQuestion(
                    question: appLanguage == "en"
                        ? "Preferred cuisine style?"
                        : "Hangi mutfağı çok yersin?",
                    options: CuisinePreference.allCases,
                    selected: cuisinePreference,
                    onSelect: { cuisinePreference = $0 },
                    label: { $0.label(appLanguage) },
                    emoji: { $0.emoji }
                )

                // Q6: Meal frequency
                FoodHabitQuestion(
                    question: appLanguage == "en"
                        ? "How many meals per day?"
                        : "Günde kaç öğün yersin?",
                    options: MealFrequency.allCases,
                    selected: mealFrequency,
                    onSelect: { mealFrequency = $0 },
                    label: { $0.label(appLanguage) },
                    emoji: { $0.emoji }
                )

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Reusable question section

struct FoodHabitQuestion<T: RawRepresentable & Hashable>: View
where T.RawValue == String {
    let question: String
    let options: [T]
    let selected: T
    let onSelect: (T) -> Void
    let label: (T) -> String
    let emoji: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question)
                .font(.subheadline.bold())
                .foregroundColor(.white)

            VStack(spacing: 8) {
                ForEach(options, id: \.rawValue) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        HStack(spacing: 12) {
                            Text(emoji(option))
                                .font(.title3)
                                .frame(width: 32)

                            Text(label(option))
                                .font(.subheadline)
                                .foregroundColor(.white)

                            Spacer()

                            if selected == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.accent)
                                    .font(.title3)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(Color.white.opacity(0.2))
                                    .font(.title3)
                            }
                        }
                        .padding(14)
                        .background(
                            selected == option
                                ? Theme.accent.opacity(0.12)
                                : Theme.cardBackground
                        )
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    selected == option
                                        ? Theme.accent.opacity(0.4)
                                        : Color.white.opacity(0.06),
                                    lineWidth: selected == option ? 1.5 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
