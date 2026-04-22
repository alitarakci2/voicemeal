//
//  GoalSlider.swift
//  VoiceMeal
//

import SwiftUI

enum GoalAggressivenessLevel: Int, Comparable, Equatable {
    case safe = 0
    case moderate = 1
    case aggressive = 2
    case dangerous = 3
    case locked = 4

    static func < (lhs: GoalAggressivenessLevel, rhs: GoalAggressivenessLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct GoalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let currentWeight: Double
    let goalDays: Int

    private let trackHeight: CGFloat = 8
    private let thumbSize: CGFloat = 28
    private let labelOffset: CGFloat = 44

    private var weeklyChange: Double {
        guard goalDays > 0 else { return 0 }
        return (currentWeight - value) / (Double(goalDays) / 7.0)
    }

    private var absWeeklyChange: Double { abs(weeklyChange) }

    private var aggressivenessLevel: GoalAggressivenessLevel {
        if absWeeklyChange > 1.5 { return .locked }
        if absWeeklyChange > 1.0 { return .dangerous }
        if absWeeklyChange > 0.75 { return .aggressive }
        if absWeeklyChange > 0.5 { return .moderate }
        return .safe
    }

    private var levelColor: Color {
        switch aggressivenessLevel {
        case .safe:       return Theme.green
        case .moderate:   return Theme.accent
        case .aggressive: return Theme.orange
        case .dangerous:  return Theme.red
        case .locked:     return Theme.red.opacity(0.7)
        }
    }

    private var warningIcon: String? {
        switch aggressivenessLevel {
        case .safe, .moderate: return nil
        case .aggressive:      return "exclamationmark.triangle.fill"
        case .dangerous:       return "light.beacon.max.fill"
        case .locked:          return "lock.fill"
        }
    }

    private var progress: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    private var weeklyChangeText: String {
        let v = String(format: "%.1f", absWeeklyChange)
        return String(format: L.kgPerWeekFormat.localized, v)
    }

    private var directionArrow: String {
        if weeklyChange > 0.05 { return "\u{2193}" }   // ↓ losing
        if weeklyChange < -0.05 { return "\u{2191}" }  // ↑ gaining
        return "\u{2192}"                              // → stable
    }

    private var accessibilityLevelText: String {
        switch aggressivenessLevel {
        case .safe:       return ""
        case .moderate:   return "aggressive_goal".localized
        case .aggressive: return "aggressive_goal".localized
        case .dangerous:  return "unhealthy_pace".localized
        case .locked:     return "unhealthy_pace".localized
        }
    }

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let thumbX = progress * (trackWidth - thumbSize) + thumbSize / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.trackBackground)
                    .frame(height: trackHeight)
                    .frame(maxHeight: .infinity)

                Capsule()
                    .fill(levelColor)
                    .frame(width: max(thumbX, thumbSize / 2), height: trackHeight)
                    .frame(maxHeight: .infinity)
                    .animation(.easeOut(duration: 0.2), value: levelColor)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                    .overlay(
                        Circle()
                            .stroke(levelColor, lineWidth: 2)
                    )
                    .offset(x: thumbX - thumbSize / 2)

                floatingLabel
                    .fixedSize()
                    .offset(x: thumbX, y: -labelOffset)
                    .alignmentGuide(.leading) { d in d[HorizontalAlignment.center] }
            }
            .frame(height: max(thumbSize, trackHeight))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        updateValue(fromX: g.location.x, trackWidth: trackWidth)
                    }
            )
        }
        .frame(height: thumbSize + labelOffset + 8)
        .padding(.top, labelOffset + 4)
        .sensoryFeedback(trigger: aggressivenessLevel) { _, new in
            switch new {
            case .safe, .moderate: return .impact(weight: .light)
            case .aggressive:      return .impact(weight: .medium)
            case .dangerous:       return .impact(weight: .heavy)
            case .locked:          return .error
            }
        }
        .accessibilityElement()
        .accessibilityLabel("target_weight".localized)
        .accessibilityValue(accessibilityValueText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                let next = min(value + step, range.upperBound)
                value = next
            case .decrement:
                let next = max(value - step, range.lowerBound)
                value = next
            @unknown default:
                break
            }
        }
    }

    private var accessibilityValueText: String {
        let kgText = String(format: "%.1f", value) + " " + "kg".localized
        let weekly = weeklyChangeText
        if accessibilityLevelText.isEmpty {
            return "\(kgText), \(weekly)"
        }
        return "\(kgText), \(weekly), \(accessibilityLevelText)"
    }

    private var floatingLabel: some View {
        VStack(spacing: 2) {
            Text("\(String(format: "%.1f", value)) \("kg".localized)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                if let icon = warningIcon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                }
                Text("\(directionArrow) \(weeklyChangeText)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.95))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(levelColor)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        )
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(levelColor)
                .frame(width: 8, height: 5)
                .offset(y: 5)
        }
        .animation(.easeOut(duration: 0.2), value: aggressivenessLevel)
    }

    private func updateValue(fromX x: CGFloat, trackWidth: CGFloat) {
        let usable = trackWidth - thumbSize
        guard usable > 0 else { return }
        let clampedX = min(max(0, x - thumbSize / 2), usable)
        let ratio = clampedX / usable
        let span = range.upperBound - range.lowerBound
        let raw = range.lowerBound + Double(ratio) * span
        let stepped = (raw / step).rounded() * step
        let clamped = min(max(range.lowerBound, stepped), range.upperBound)
        if clamped != value {
            value = clamped
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
