//
//  TooltipManager.swift
//  VoiceMeal
//

import Combine
import Foundation

class TooltipManager: ObservableObject {
    static let shared = TooltipManager()

    @Published var tooltipsEnabled: Bool {
        didSet { UserDefaults.standard.set(tooltipsEnabled, forKey: "tooltipsEnabled") }
    }

    private let seenKey = "seenTooltips"

    private init() {
        self.tooltipsEnabled = UserDefaults.standard.object(forKey: "tooltipsEnabled") as? Bool ?? true
    }

    func hasSeen(_ id: String) -> Bool {
        let seen = UserDefaults.standard.stringArray(forKey: seenKey) ?? []
        return seen.contains(id)
    }

    func markSeen(_ id: String) {
        var seen = UserDefaults.standard.stringArray(forKey: seenKey) ?? []
        if !seen.contains(id) {
            seen.append(id)
            UserDefaults.standard.set(seen, forKey: seenKey)
        }
    }

    func resetAll() {
        UserDefaults.standard.removeObject(forKey: seenKey)
    }
}
