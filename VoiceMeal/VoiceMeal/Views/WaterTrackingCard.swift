//
//  WaterTrackingCard.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct WaterTrackingCard: View {
    let todayWaterMl: Int
    let goalMl: Int
    let todayEntries: [WaterEntry]
    let onAdd: (Int, String) -> Void
    let onDelete: (WaterEntry) -> Void

    @State private var showEntries = false
    @State private var showCustomInput = false
    @State private var customAmount = ""

    private var progress: Double {
        guard goalMl > 0 else { return 0 }
        return min(Double(todayWaterMl) / Double(goalMl), 1.0)
    }

    private var percent: Int {
        guard goalMl > 0 else { return 0 }
        return Int(Double(todayWaterMl) / Double(goalMl) * 100)
    }

    private var remainingMl: Int {
        max(goalMl - todayWaterMl, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("\u{1F4A7} \("water_tracking".localized)")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(todayWaterMl) / \(goalMl) ml")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.trackBackground)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.blue)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 12)

            // Status line
            HStack {
                if todayWaterMl >= goalMl {
                    Text("\u{2705} \("water_goal_reached_emoji".localized)")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.green)
                } else {
                    Text(String(format: "water_remaining_format".localized, percent, remainingMl))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            // Quick-add buttons
            HStack(spacing: 8) {
                quickAddButton(200)
                quickAddButton(300)
                quickAddButton(500)

                Button {
                    showCustomInput = true
                } label: {
                    Text("...")
                        .font(Theme.bodyFont)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.cardFrameBorder, lineWidth: 1.0)
                        )
                }
                .buttonStyle(.plain)
            }

            // Custom input
            if showCustomInput {
                HStack(spacing: 8) {
                    TextField("ml", text: $customAmount)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)

                    Button("water_add_custom".localized) {
                        if let amount = Int(customAmount), amount > 0 {
                            onAdd(amount, "manual")
                            customAmount = ""
                            showCustomInput = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.blue)
                    .disabled(Int(customAmount) ?? 0 <= 0)

                    Spacer()

                    Button(L.close.localized) {
                        showCustomInput = false
                        customAmount = ""
                    }
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                }
            }

            // Entries list (long-press to show)
            if showEntries && !todayEntries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(todayEntries, id: \.id) { entry in
                        HStack {
                            Text("\(entry.amountMl) ml")
                                .font(Theme.captionFont)
                            Text(entry.source == "voice" ? "\u{1F3A4}" : entry.source == "quick" ? "\u{26A1}" : "")
                                .font(Theme.microFont)
                            Spacer()
                            Text(entry.date.formatted(.dateTime.hour().minute()))
                                .font(Theme.microFont)
                                .foregroundStyle(Theme.textTertiary)
                            Button {
                                onDelete(entry)
                            } label: {
                                Image(systemName: "trash")
                                    .font(Theme.microFont)
                                    .foregroundStyle(Theme.red)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        if entry.id != todayEntries.last?.id {
                            Theme.cardBorder
                                .frame(height: 1)
                        }
                    }
                }
                .padding(8)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .themeCard()
        .sensoryFeedback(.impact(weight: .light), trigger: todayWaterMl)
        .onLongPressGesture {
            withAnimation { showEntries.toggle() }
        }
    }

    private func quickAddButton(_ ml: Int) -> some View {
        Button {
            onAdd(ml, "quick")
        } label: {
            Text("+\(ml)")
                .font(Theme.bodyFont)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Theme.blue.opacity(0.15))
                .foregroundStyle(Theme.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
