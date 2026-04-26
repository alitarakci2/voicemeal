//
//  HomeView+MealListSection.swift
//  VoiceMeal
//

import SwiftUI

extension HomeView {

    var mealListSection: some View {
        Group {
            if !todayEntries.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("today_foods".localized)
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Button {
                            showNutritionCheck = true
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(Theme.bodyFont)
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 8)

                    ForEach(todayEntries, id: \.id) { entry in
                        HStack(alignment: .center, spacing: 4) {
                            FoodEntryRowView(entry: entry)

                            Button {
                                startVoiceCorrection(for: entry)
                            } label: {
                                Text("fix_entry".localized)
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.accent.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            Button {
                                entryToEdit = entry
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            Button {
                                entryToDelete = entry
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.red)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        if entry.id != todayEntries.last?.id {
                            Divider()
                                .overlay(Theme.cardBorder.opacity(0.5))
                                .padding(.leading)
                        }
                    }

                    Divider()
                        .overlay(Theme.cardBorder)
                        .padding(.horizontal)

                    HStack {
                        Text(L.total.localized)
                            .font(Theme.bodyFont)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(eatenCalories) kcal")
                            .font(Theme.bodyFont)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    HStack(spacing: 6) {
                        Spacer()
                        MacroTotalPill("P", value: Int(eatenProtein), color: Theme.blue)
                        MacroTotalPill("K", value: Int(eatenCarbs), color: Theme.macroCarb)
                        MacroTotalPill("Y", value: Int(eatenFat), color: Theme.fatColor)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .themeCard()
            }

            if let entries = correctionPickerEntries {
                VStack(alignment: .leading, spacing: 8) {
                    Text("which_entry_correct".localized)
                        .font(Theme.bodyFont)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.warning)
                    ForEach(entries, id: \.id) { entry in
                        Button {
                            entryToEdit = entry
                            correctionPickerEntries = nil
                        } label: {
                            HStack {
                                Text(entry.name)
                                Spacer()
                                Text("\(entry.calories) kcal")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Theme.warning.opacity(0.1))
                .themeCard()
            }
        }
    }
}
