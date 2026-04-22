//
//  CalorieGapCopy.swift
//  VoiceMeal
//

import Foundation

enum CalorieGapKind {
    case deficit   // cutting: target is to eat below TDEE
    case surplus   // bulking: target is to eat above TDEE
    case maintain  // holding: target is ~zero balance
    case observe   // no goal: just logging, no judgment

    static func from(signedTargetDeficit: Int, threshold: Int = 50) -> CalorieGapKind {
        if signedTargetDeficit > threshold { return .deficit }
        if signedTargetDeficit < -threshold { return .surplus }
        return .maintain
    }

    static func from(profile: UserProfile, threshold: Double = 0.5) -> CalorieGapKind {
        if profile.isObserveMode { return .observe }
        let diff = profile.currentWeightKg - profile.goalWeightKg
        if diff > threshold { return .deficit }
        if diff < -threshold { return .surplus }
        return .maintain
    }
}

enum CalorieGapCopy {
    // "~%d açık" / "~%d fazla" / "~%d sapma" — for future/planned rows
    static func approxText(signedDeficit: Int, kind: CalorieGapKind) -> String {
        let v = abs(signedDeficit)
        switch kind {
        case .deficit:  return String(format: L.deficitApproxFormat.localized, v)
        case .surplus:  return String(format: L.surplusApproxFormat.localized, v)
        case .maintain: return String(format: L.maintainApproxFormat.localized, v)
        case .observe:  return String(format: L.observeKcalApproxFormat.localized, v)
        }
    }

    // "%d açık" / "%d fazla" / "%d sapma" — for past/today rows
    static func valueText(signedDeficit: Int, kind: CalorieGapKind) -> String {
        let v = abs(signedDeficit)
        switch kind {
        case .deficit:  return String(format: L.deficitValueFormat.localized, v)
        case .surplus:  return String(format: L.surplusValueFormat.localized, v)
        case .maintain:
            if v < 50 { return L.kcalOnTarget.localized }
            return String(format: L.maintainValueFormat.localized, v)
        case .observe:  return String(format: L.observeKcalValueFormat.localized, v)
        }
    }

    // "%d kcal açık" / "%d kcal fazla" — for weekly summary header
    static func kcalText(signedDeficit: Int, kind: CalorieGapKind) -> String {
        let v = abs(signedDeficit)
        switch kind {
        case .deficit:  return String(format: L.kcalDeficitFormat.localized, v)
        case .surplus:  return String(format: L.kcalSurplusFormat.localized, v)
        case .maintain:
            if v < 50 { return L.kcalOnTarget.localized }
            return String(format: L.kcalMaintainFormat.localized, v)
        case .observe:  return String(format: L.observeKcalValueFormat.localized, v)
        }
    }

    // Column header label — "Açık" / "Fazla" / "Denge"
    static func shortLabel(kind: CalorieGapKind) -> String {
        switch kind {
        case .deficit:  return L.deficitShort.localized
        case .surplus:  return L.surplusShort.localized
        case .maintain: return L.balanceShort.localized
        case .observe:  return L.observeShortLabel.localized
        }
    }

    // Card / ring title — "Kalori Açığı" / "Kalori Fazlası" / "Kalori Dengesi"
    static func cardTitle(kind: CalorieGapKind) -> String {
        switch kind {
        case .deficit:  return "calorie_deficit_label".localized
        case .surplus:  return "calorie_surplus_label".localized
        case .maintain: return "calorie_balance_label".localized
        case .observe:  return L.observeCardTitle.localized
        }
    }

    // "Gerçek açık" / "Gerçek fazla" / "Gerçek denge"
    static func realLabel(kind: CalorieGapKind) -> String {
        switch kind {
        case .deficit:  return L.realDeficit.localized
        case .surplus:  return L.realSurplus.localized
        case .maintain: return L.realBalance.localized
        case .observe:  return L.observeConsumedLabel.localized
        }
    }

    // Displayed signed value — always abs(), no minus sign
    static func displayValue(_ signedDeficit: Int) -> Int { abs(signedDeficit) }

    // Color logic: green when on target, red when wrong side, orange in between.
    // Uses ratio of actual vs target regardless of mode.
    // actual and target carry their own signs; we compare magnitude and direction.
    enum ColorCue { case good, warn, bad }

    static func colorCue(actual: Int, target: Int, kind: CalorieGapKind) -> ColorCue {
        switch kind {
        case .deficit:
            if actual <= 0 { return .bad }
            if target > 0, actual >= Int(Double(target) * 0.80) { return .good }
            return .warn
        case .surplus:
            if actual >= 0 { return .bad }
            if target < 0, actual <= Int(Double(target) * 0.80) { return .good }
            return .warn
        case .maintain:
            let diff = abs(actual)
            if diff <= 100 { return .good }
            if diff <= 300 { return .warn }
            return .bad
        case .observe:
            return .good
        }
    }
}
