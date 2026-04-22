//
//  UserProfile.swift
//  VoiceMeal
//

import Foundation
import SwiftData

// MARK: - Food Habits Enums

enum CookingLocation: String, Codable, CaseIterable {
    case mostly_home = "mostly_home"
    case mixed = "mixed"
    case mostly_outside = "mostly_outside"

    func label(_ lang: String) -> String {
        switch self {
        case .mostly_home:    return lang == "en" ? "Mostly home-cooked" : "Çoğunlukla evde"
        case .mixed:          return lang == "en" ? "Mix of home & outside" : "Karma (ev + dışarı)"
        case .mostly_outside: return lang == "en" ? "Mostly dining out" : "Çoğunlukla dışarıda"
        }
    }

    var emoji: String {
        switch self {
        case .mostly_home: return "🏠"
        case .mixed: return "🔄"
        case .mostly_outside: return "🍽️"
        }
    }
}

enum PortionSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"

    func label(_ lang: String) -> String {
        switch self {
        case .small:  return lang == "en" ? "Small (light eater)" : "Küçük (az yerim)"
        case .medium: return lang == "en" ? "Medium (standard)" : "Orta (standart)"
        case .large:  return lang == "en" ? "Large (hearty eater)" : "Büyük (doyunca yerim)"
        }
    }

    var emoji: String {
        switch self {
        case .small: return "🥗"
        case .medium: return "🍽️"
        case .large: return "🍖"
        }
    }
}

enum OilUsage: String, Codable, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"

    func label(_ lang: String) -> String {
        switch self {
        case .low:      return lang == "en" ? "Low oil / light cooking" : "Az yağ kullanırım"
        case .moderate: return lang == "en" ? "Moderate oil" : "Orta düzeyde yağ"
        case .high:     return lang == "en" ? "Rich / oily cooking" : "Yağlı severim"
        }
    }

    var emoji: String {
        switch self {
        case .low: return "💧"
        case .moderate: return "🫒"
        case .high: return "🧈"
        }
    }
}

enum ProteinSource: String, Codable, CaseIterable {
    case chicken = "chicken"
    case red_meat = "red_meat"
    case fish = "fish"
    case legumes = "legumes"
    case mixed = "mixed"

    func label(_ lang: String) -> String {
        switch self {
        case .chicken:  return lang == "en" ? "Chicken / Turkey" : "Tavuk / Hindi"
        case .red_meat: return lang == "en" ? "Red meat (beef/lamb)" : "Kırmızı et (dana/kuzu)"
        case .fish:     return lang == "en" ? "Fish / Seafood" : "Balık / Deniz ürünleri"
        case .legumes:  return lang == "en" ? "Legumes / Plant-based" : "Baklagil / Bitkisel"
        case .mixed:    return lang == "en" ? "Mixed / Varies" : "Karma / Değişken"
        }
    }

    var emoji: String {
        switch self {
        case .chicken: return "🍗"
        case .red_meat: return "🥩"
        case .fish: return "🐟"
        case .legumes: return "🫘"
        case .mixed: return "🔄"
        }
    }
}

enum CuisinePreference: String, Codable, CaseIterable {
    case turkish_home = "turkish_home"
    case fast_food = "fast_food"
    case mediterranean = "mediterranean"
    case mixed = "mixed"

    func label(_ lang: String) -> String {
        switch self {
        case .turkish_home:  return lang == "en" ? "Turkish home cooking" : "Türk ev yemekleri"
        case .fast_food:     return lang == "en" ? "Fast food / Street food" : "Fast food / Sokak yemekleri"
        case .mediterranean: return lang == "en" ? "Mediterranean / Light" : "Akdeniz / Hafif"
        case .mixed:         return lang == "en" ? "Mixed cuisines" : "Karma mutfak"
        }
    }

    var emoji: String {
        switch self {
        case .turkish_home: return "🫕"
        case .fast_food: return "🍔"
        case .mediterranean: return "🥗"
        case .mixed: return "🌍"
        }
    }
}

enum MealFrequency: String, Codable, CaseIterable {
    case two_meals = "two_meals"
    case three_meals = "three_meals"
    case four_plus = "four_plus"

    func label(_ lang: String) -> String {
        switch self {
        case .two_meals:   return lang == "en" ? "2 meals (no breakfast)" : "2 öğün (kahvaltı yok)"
        case .three_meals: return lang == "en" ? "3 meals (standard)" : "3 öğün (standart)"
        case .four_plus:   return lang == "en" ? "4-5 meals with snacks" : "Ara öğünlerle 4-5 öğün"
        }
    }

    var emoji: String {
        switch self {
        case .two_meals: return "🌙"
        case .three_meals: return "☀️"
        case .four_plus: return "⏰"
        }
    }
}

// MARK: - User Profile

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var gender: String
    var age: Int
    var heightCm: Double
    var currentWeightKg: Double
    var goalWeightKg: Double
    var goalDays: Int
    var intensityLevel: Double // deprecated - hidden in UI
    var weeklyScheduleJSON: String
    var programStartDate: Date?
    var notification1Enabled: Bool
    var notification1Hour: Int
    var notification1Minute: Int
    var notification2Enabled: Bool
    var notification2Hour: Int
    var notification2Minute: Int
    var preferredProteinsJSON: String
    var programStartWeightKg: Double = 0
    var waterGoalOverrideMl: Int?
    var isWaterTrackingEnabled: Bool = false
    var useMetric: Bool = true
    var preferredLanguage: String = ""
    var weightReminderEnabled: Bool = true
    var weightReminderDays: Int = 1
    var weightReminderHour: Int = 9
    var coachStyleRaw: String = CoachStyle.supportive.rawValue
    var personalContext: String = ""
    // Food habits questionnaire (raw strings for SwiftData)
    var cookingLocationRaw: String = CookingLocation.mostly_home.rawValue
    var portionSizeRaw: String = PortionSize.medium.rawValue
    var oilUsageRaw: String = OilUsage.moderate.rawValue
    var proteinSourceRaw: String = ProteinSource.mixed.rawValue
    var cuisinePreferenceRaw: String = CuisinePreference.turkish_home.rawValue
    var mealFrequencyRaw: String = MealFrequency.two_meals.rawValue
    var createdAt: Date
    var updatedAt: Date

    var coachStyle: CoachStyle {
        get { CoachStyle(rawValue: coachStyleRaw) ?? .supportive }
        set { coachStyleRaw = newValue.rawValue }
    }

    /// Single source of truth for program start. Uses explicit programStartDate when set,
    /// falls back to account creation date for existing users.
    var effectiveProgramStart: Date {
        programStartDate ?? createdAt
    }

    var cookingLocation: CookingLocation {
        get { CookingLocation(rawValue: cookingLocationRaw) ?? .mostly_home }
        set { cookingLocationRaw = newValue.rawValue }
    }
    var portionSize: PortionSize {
        get { PortionSize(rawValue: portionSizeRaw) ?? .medium }
        set { portionSizeRaw = newValue.rawValue }
    }
    var oilUsage: OilUsage {
        get { OilUsage(rawValue: oilUsageRaw) ?? .moderate }
        set { oilUsageRaw = newValue.rawValue }
    }
    var proteinSource: ProteinSource {
        get { ProteinSource(rawValue: proteinSourceRaw) ?? .mixed }
        set { proteinSourceRaw = newValue.rawValue }
    }
    var cuisinePreference: CuisinePreference {
        get { CuisinePreference(rawValue: cuisinePreferenceRaw) ?? .turkish_home }
        set { cuisinePreferenceRaw = newValue.rawValue }
    }
    var mealFrequency: MealFrequency {
        get { MealFrequency(rawValue: mealFrequencyRaw) ?? .two_meals }
        set { mealFrequencyRaw = newValue.rawValue }
    }

    var preferredProteins: [String] {
        get {
            guard let data = preferredProteinsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return ["tavuk", "bal\u{0131}k", "dana", "yumurta", "baklagil", "s\u{00FC}t \u{00FC}r\u{00FC}nleri"]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                preferredProteinsJSON = json
            }
        }
    }

    var generatedFoodContext: String {
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        if lang == "en" {
            return """
            User food profile:
            - Cooking: \(cookingLocation.label("en"))
            - Portion size: \(portionSize.label("en"))
            - Oil/fat usage: \(oilUsage.label("en"))
            - Main protein: \(proteinSource.label("en"))
            - Cuisine: \(cuisinePreference.label("en"))
            - Meal frequency: \(mealFrequency.label("en"))
            Use this to calibrate portion estimates and calorie calculations.
            """
        } else {
            return """
            Kullanıcı yemek profili:
            - Yemek yeri: \(cookingLocation.label("tr"))
            - Porsiyon: \(portionSize.label("tr"))
            - Yağ kullanımı: \(oilUsage.label("tr"))
            - Ana protein: \(proteinSource.label("tr"))
            - Mutfak: \(cuisinePreference.label("tr"))
            - Öğün düzeni: \(mealFrequency.label("tr"))
            Bu bilgileri porsiyon tahmini ve kalori hesabında kullan.
            """
        }
    }

    /// Combined AI context: food profile + personal notes.
    var fullAIContext: String {
        var parts: [String] = []
        let food = generatedFoodContext
        if !food.isEmpty { parts.append(food) }
        if !personalContext.isEmpty { parts.append(personalContext) }
        return parts.joined(separator: "\n\n")
    }

    var weeklySchedule: [[String]] {
        get {
            guard let data = weeklyScheduleJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([[String]].self, from: data) else {
                return Array(repeating: ["rest"], count: 7)
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                weeklyScheduleJSON = json
            }
        }
    }

    init(
        name: String,
        gender: String,
        age: Int,
        heightCm: Double,
        currentWeightKg: Double,
        goalWeightKg: Double,
        goalDays: Int,
        intensityLevel: Double,
        weeklySchedule: [[String]]
    ) {
        self.id = UUID()
        self.name = name
        self.gender = gender
        self.age = age
        self.heightCm = heightCm
        self.currentWeightKg = currentWeightKg
        self.goalWeightKg = goalWeightKg
        self.goalDays = goalDays
        self.intensityLevel = intensityLevel
        if let data = try? JSONEncoder().encode(weeklySchedule),
           let json = String(data: data, encoding: .utf8) {
            self.weeklyScheduleJSON = json
        } else {
            self.weeklyScheduleJSON = "[[\"rest\"],[\"rest\"],[\"rest\"],[\"rest\"],[\"rest\"],[\"rest\"],[\"rest\"]]"
        }
        self.notification1Enabled = true
        self.notification1Hour = 16
        self.notification1Minute = 0
        self.notification2Enabled = true
        self.notification2Hour = 21
        self.notification2Minute = 30
        let defaultProteins = ["tavuk", "bal\u{0131}k", "dana", "yumurta", "baklagil", "s\u{00FC}t \u{00FC}r\u{00FC}nleri"]
        if let data = try? JSONEncoder().encode(defaultProteins),
           let json = String(data: data, encoding: .utf8) {
            self.preferredProteinsJSON = json
        } else {
            self.preferredProteinsJSON = "[]"
        }
        self.createdAt = .now
        self.updatedAt = .now
    }
}
