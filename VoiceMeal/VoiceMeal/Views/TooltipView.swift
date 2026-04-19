//
//  TooltipView.swift
//  VoiceMeal
//

import SwiftUI

struct InfoTooltipButton: View {
    let tooltip: TooltipItem
    var size: CGFloat = 13
    @State private var showSheet = false
    @ObservedObject private var manager = TooltipManager.shared

    var body: some View {
        if manager.tooltipsEnabled {
            Button {
                showSheet = true
                manager.markSeen(tooltip.id)
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: size))
                    .foregroundStyle(manager.hasSeen(tooltip.id) ? Theme.textTertiary : Theme.accent)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSheet) {
                TooltipSheet(tooltip: tooltip)
            }
        }
    }
}

struct TooltipSheet: View {
    let tooltip: TooltipItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.gradientTop, Color(hex: "0A0A0F")],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accent)

                Text(tooltip.titleKey.localized)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(tooltip.bodyKey.localized)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
