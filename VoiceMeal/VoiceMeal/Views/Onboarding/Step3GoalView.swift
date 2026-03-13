//
//  Step3GoalView.swift
//  VoiceMeal
//

import SwiftUI

struct Step3GoalView: View {
    let currentWeightKg: Double
    @Binding var goalWeightKg: Double
    @Binding var goalDays: Int

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
                Text("Hedefin")
                    .font(Theme.titleFont)

                // Goal weight
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hedef Kilo: \(String(format: "%.1f", goalWeightKg)) kg")
                        .font(Theme.headlineFont)
                    Slider(value: $goalWeightKg, in: 40...200, step: 0.5)
                }

                // Duration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Süre")
                        .font(Theme.headlineFont)
                    HStack(spacing: 12) {
                        ForEach(presetDays, id: \.self) { days in
                            Button {
                                goalDays = days
                            } label: {
                                Text("\(days) gün")
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
                    Stepper("Özel: \(goalDays) gün", value: $goalDays, in: 14...365, step: 7)
                        .font(Theme.bodyFont)
                        .padding(.top, 4)
                }

                // Summary
                VStack(spacing: 12) {
                    if currentWeightKg > goalWeightKg {
                        Text("Haftada yaklaşık \(String(format: "%.2f", weeklyLoss)) kg verirsin")
                            .font(Theme.headlineFont)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if isAggressive {
                            Label("Çok agresif, süreyi uzatmanı öneririz", systemImage: "exclamationmark.triangle.fill")
                                .font(Theme.bodyFont)
                                .foregroundStyle(Theme.orange)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else if currentWeightKg < goalWeightKg {
                        Text("Haftada yaklaşık \(String(format: "%.2f", abs(weeklyLoss))) kg alırsın")
                            .font(Theme.headlineFont)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("Kilonu korumayı hedefliyorsun")
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
    }
}
