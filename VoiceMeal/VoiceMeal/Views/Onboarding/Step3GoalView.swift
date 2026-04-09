//
//  Step3GoalView.swift
//  VoiceMeal
//

import SwiftUI

struct Step3GoalView: View {
    let currentWeightKg: Double
    @Binding var goalWeightKg: Double
    @Binding var goalDays: Int

    @State private var goalWeightText = ""
    @FocusState private var goalWeightFocused: Bool

    private let presetDays = [30, 60, 90, 120]

    private var weeklyLoss: Double {
        guard goalDays > 0 else { return 0 }
        let totalLoss = currentWeightKg - goalWeightKg
        let weeks = Double(goalDays) / 7.0
        return totalLoss / weeks
    }

    private var isAggressive: Bool {
        weeklyLoss > 1.0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("weight_goal_title".localized)
                    .font(Theme.titleFont)

                // Goal weight
                VStack(alignment: .leading, spacing: 8) {
                    Text("\("goal_weight_label".localized): \(String(format: "%.1f", goalWeightKg)) kg")
                        .font(Theme.headlineFont)
                    HStack {
                        Slider(value: $goalWeightKg, in: 40...200, step: 0.1)
                            .tint(Theme.accent)
                            .onChange(of: goalWeightKg) { _, newVal in
                                if !goalWeightFocused {
                                    goalWeightText = String(format: "%.1f", newVal)
                                }
                            }
                        TextField("", text: $goalWeightText)
                            .keyboardType(.decimalPad)
                            .frame(width: 64)
                            .padding(8)
                            .background(Theme.trackBackground)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .focused($goalWeightFocused)
                            .onChange(of: goalWeightFocused) { _, focused in
                                if !focused {
                                    validateGoalWeight()
                                }
                            }
                    }
                }

                // Duration
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.duration.localized)
                        .font(Theme.headlineFont)
                    HStack(spacing: 12) {
                        ForEach(presetDays, id: \.self) { days in
                            Button {
                                goalDays = days
                            } label: {
                                Text("\(days) \("day_suffix".localized)")
                                    .font(Theme.bodyFont)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(goalDays == days ? Theme.accent.opacity(0.15) : Theme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(goalDays == days ? Theme.accent : Color.clear, lineWidth: 2)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Custom stepper
                    Stepper(String(format: "custom_duration".localized, goalDays), value: $goalDays, in: 14...365, step: 7)
                        .font(Theme.bodyFont)
                        .padding(.top, 4)
                }

                // Summary
                VStack(spacing: 12) {
                    if currentWeightKg > goalWeightKg {
                        Text(String(format: "weekly_loss".localized, String(format: "%.2f", weeklyLoss)))
                            .font(Theme.headlineFont)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if isAggressive {
                            Label("too_aggressive".localized, systemImage: "exclamationmark.triangle.fill")
                                .font(Theme.bodyFont)
                                .foregroundStyle(Theme.orange)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else if currentWeightKg < goalWeightKg {
                        Text(String(format: "weekly_gain".localized, String(format: "%.2f", abs(weeklyLoss))))
                            .font(Theme.headlineFont)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("maintain_weight".localized)
                            .font(Theme.headlineFont)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            goalWeightText = String(format: "%.1f", goalWeightKg)
        }
    }

    private func validateGoalWeight() {
        let cleaned = goalWeightText.replacingOccurrences(of: ",", with: ".")
        if let val = Double(cleaned) {
            let clamped = min(200, max(40, val))
            goalWeightKg = (clamped * 10).rounded() / 10
            goalWeightText = String(format: "%.1f", goalWeightKg)
        } else {
            goalWeightText = String(format: "%.1f", goalWeightKg)
        }
    }
}
