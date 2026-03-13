//
//  GroqService.swift
//  VoiceMeal
//

import Foundation

struct ParsedMeal: Codable, Identifiable {
    var id: String { name }
    let name: String
    let amount: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct MealParseResponse: Codable {
    let meals: [ParsedMeal]
    let clarification_needed: Bool
    let clarification_question: String?
    let isCorrection: Bool?
    let targetFoodName: String?
    let correctedCalories: Int?
    let correctedProtein: Double?
    let correctedCarbs: Double?
    let correctedFat: Double?
    let correctedAmount: String?
}

struct MealSuggestion: Codable {
    let title: String
    let body: String
    let meals: [SuggestedMeal]
}

struct SuggestedMeal: Codable {
    let name: String
    let portion: String
    let calories: Int
    let protein: Int
}

class GroqService {

    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let model = "llama-3.3-70b-versatile"

    private let systemPrompt = """
        Sen bir beslenme asistan\u{0131}s\u{0131}n. Kullan\u{0131}c\u{0131}n\u{0131}n T\u{00FC}rk\u{00E7}e konu\u{015F}mas\u{0131}ndan \
        yenilen yemekleri \u{00E7}\u{0131}kar ve SADECE JSON format\u{0131}nda yan\u{0131}t ver.

        Emin olmad\u{0131}\u{011F}\u{0131}n miktar veya yemek varsa clarification_needed true yap \
        ve clarification_question alan\u{0131}na T\u{00FC}rk\u{00E7}e soru yaz.

        E\u{011F}er kullan\u{0131}c\u{0131} bir d\u{00FC}zeltme yap\u{0131}yorsa (\u{00F6}rn: "asl\u{0131}nda protein \
        s\u{00FC}t\u{00FC} 250 kalori", "hay\u{0131}r yanl\u{0131}\u{015F} yazd\u{0131}m tavuk 300 gram", \
        "de\u{011F}i\u{015F}tir", "g\u{00FC}ncelle"), isCorrection: true yap ve \
        hangi yeme\u{011F}i d\u{00FC}zeltece\u{011F}ini targetFoodName'e yaz. \
        D\u{00FC}zeltilen de\u{011F}erleri correctedCalories, correctedProtein, \
        correctedCarbs, correctedFat, correctedAmount alanlar\u{0131}na yaz. \
        Normal yemek giri\u{015F}iyse isCorrection: false.

        E\u{011F}er kullan\u{0131}c\u{0131} sadece miktar\u{0131} de\u{011F}i\u{015F}tiriyorsa (\u{00F6}rn: "50 grama \
        d\u{00FC}\u{015F}\u{00FC}r", "yar\u{0131}s\u{0131}n\u{0131} sil"), kalorileri ve makrolar\u{0131} da orant\u{0131}l\u{0131} \
        olarak hesapla. \u{00D6}rnek: 100g = 250 kcal ise, 50g = 125 kcal olmal\u{0131}. \
        Orijinal kay\u{0131}ttaki kalori yo\u{011F}unlu\u{011F}unu kullan: \
        kalori_yo\u{011F}unlu\u{011F}u = orijinal_kalori / orijinal_miktar, \
        yeni_kalori = kalori_yo\u{011F}unlu\u{011F}u * yeni_miktar. \
        correctedCalories, correctedProtein, correctedCarbs, \
        correctedFat alanlar\u{0131}n\u{0131} MUTLAKA doldur. \
        Hi\u{00E7}bir zaman sadece miktar\u{0131} de\u{011F}i\u{015F}tirip makrolar\u{0131} bo\u{015F} b\u{0131}rakma.

        JSON format\u{0131} kesinlikle \u{015F}u \u{015F}ekilde olmal\u{0131}, ba\u{015F}ka hi\u{00E7}bir \u{015F}ey yazma:
        {
          "meals": [
            {
              "name": "string",
              "amount": "string",
              "calories": number,
              "protein": number,
              "carbs": number,
              "fat": number
            }
          ],
          "clarification_needed": boolean,
          "clarification_question": "string or null",
          "isCorrection": boolean,
          "targetFoodName": "string or null",
          "correctedCalories": "number or null",
          "correctedProtein": "number or null",
          "correctedCarbs": "number or null",
          "correctedFat": "number or null",
          "correctedAmount": "string or null"
        }
        """

    func parseMeals(transcript: String) async throws -> MealParseResponse {
        let apiKey = Config.groqAPIKey
        print("[GroqService] API key present: \(!apiKey.isEmpty), length: \(apiKey.count)")
        guard !apiKey.isEmpty else {
            print("[GroqService] ERROR: API key is empty")
            throw GroqError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript]
            ],
            "temperature": 0.1
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[GroqService] REQUEST: \(request.httpMethod!) \(endpoint)")
        print("[GroqService] Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let httpBody = request.httpBody, let bodyString = String(data: httpBody, encoding: .utf8) {
            print("[GroqService] Body: \(bodyString)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[GroqService] ERROR: Network request failed: \(error)")
            throw error
        }

        let rawResponse = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
        let httpResponse = response as? HTTPURLResponse
        print("[GroqService] RESPONSE status: \(httpResponse?.statusCode ?? -1)")
        print("[GroqService] RESPONSE body: \(rawResponse)")

        guard let httpResponse, (200...299).contains(httpResponse.statusCode) else {
            print("[GroqService] ERROR: Bad status code \(httpResponse?.statusCode ?? -1)")
            throw GroqError.apiError
        }

        let chatResponse: ChatCompletionResponse
        do {
            chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            print("[GroqService] ERROR: Failed to decode ChatCompletionResponse: \(error)")
            throw error
        }

        guard let content = chatResponse.choices.first?.message.content else {
            print("[GroqService] ERROR: No content in response choices")
            throw GroqError.emptyResponse
        }

        print("[GroqService] LLM content: \(content)")

        // Strip markdown code fences if present
        let jsonString = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("[GroqService] ERROR: Could not convert cleaned JSON to data")
            throw GroqError.invalidJSON
        }

        do {
            let result = try JSONDecoder().decode(MealParseResponse.self, from: jsonData)
            print("[GroqService] SUCCESS: Parsed \(result.meals.count) meals")
            return result
        } catch {
            print("[GroqService] ERROR: Failed to decode MealParseResponse: \(error)")
            print("[GroqService] Cleaned JSON was: \(jsonString)")
            throw GroqError.invalidJSON
        }
    }

    // MARK: - Daily Insight

    private let insightSystemPrompt = """
        Sen ki\u{015F}isel bir beslenme ve fitness ko\u{00E7}usun. \
        Kullan\u{0131}c\u{0131}n\u{0131}n g\u{00FC}nl\u{00FC}k biyometrik verilerini analiz edip \
        SADECE 2-3 c\u{00FC}mlelik k\u{0131}sa, samimi, T\u{00FC}rk\u{00E7}e bir g\u{00FC}nl\u{00FC}k \
        de\u{011F}erlendirme yaz. Bilimsel ama sohbet dili kullan. \
        Emoji kullanabilirsin. Asla liste yapma, d\u{00FC}z metin yaz.
        """

    func generateDailyInsight(
        hrvStatus: HRVStatus,
        todayHRV: Double?,
        hrvBaseline: Double?,
        sleep: SleepData?,
        todayActivities: [String],
        remainingCalories: Int,
        calorieDeficit: Int,
        intensityLevel: Double
    ) async throws -> String {
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else { throw GroqError.missingAPIKey }

        let hrvText: String
        if let hrv = todayHRV {
            let baselineText = hrvBaseline.map { String(format: "%.0f", $0) } ?? "?"
            hrvText = "\(String(format: "%.0f", hrv))ms (7 g\u{00FC}nl\u{00FC}k ort: \(baselineText)ms, durum: \(hrvStatus.rawValue))"
        } else {
            hrvText = "Veri yok"
        }

        let sleepText: String
        if let s = sleep {
            let hours = s.totalMinutes / 60
            let mins = s.totalMinutes % 60
            sleepText = "\(hours)s \(mins)dk toplam, \(s.deepSleepMinutes) dk derin uyku, kalite: \(s.quality.rawValue)"
        } else {
            sleepText = "Veri yok"
        }

        let activityNames = todayActivities
            .compactMap { GoalEngine.activityDisplayNames[$0] }
            .joined(separator: ", ")

        let intensityText: String
        switch intensityLevel {
        case ...0.3: intensityText = "Hafif"
        case 0.3...0.7: intensityText = "Orta"
        default: intensityText = "Yo\u{011F}un"
        }

        let today = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)

        let userPrompt = """
            Tarih: \(today)
            HRV: \(hrvText)
            Uyku: \(sleepText)
            Bug\u{00FC}nk\u{00FC} plan: \(activityNames)
            Kalan kalori: \(remainingCalories) kcal
            A\u{00E7}\u{0131}k: \(calorieDeficit) kcal
            Program yo\u{011F}unlu\u{011F}u: \(intensityText)

            Bu verilere g\u{00F6}re bug\u{00FC}n i\u{00E7}in k\u{0131}sa bir de\u{011F}erlendirme yap.
            """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": insightSystemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.7,
            "max_tokens": 200
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GroqError.apiError
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Meal Suggestion

    private let suggestionSystemPrompt = """
        Sen ki\u{015F}isel bir T\u{00FC}rk beslenme ko\u{00E7}usun. \
        Kullan\u{0131}c\u{0131}n\u{0131}n g\u{00FC}nl\u{00FC}k kalan makrolar\u{0131}na ve tercihlerine g\u{00F6}re \
        yemek \u{00F6}nerisi yapacaks\u{0131}n.

        \u{00D6}\u{011F}le/Ak\u{015F}am bildirimi (16:00) i\u{00E7}in:
        - Ak\u{015F}am yeme\u{011F}i i\u{00E7}in tam \u{00F6}\u{011F}\u{00FC}n \u{00F6}ner
        - Eksik makrolar\u{0131} tamamlayacak sporcu dostu yemek
        - T\u{00FC}rk mutfa\u{011F}\u{0131}ndan \u{00F6}rnekler kullan
        - Gerekirse "marketten \u{015F}unu al" diyebilirsin

        Gece kapan\u{0131}\u{015F} bildirimi (21:30) i\u{00E7}in:
        - Hafif, sindirimi kolay, uyku \u{00F6}ncesi uygun
        - Protein a\u{011F}\u{0131}rl\u{0131}kl\u{0131} k\u{00FC}\u{00E7}\u{00FC}k at\u{0131}\u{015F}t\u{0131}rmal\u{0131}k
        - \u{00D6}rnekler: kefir, yo\u{011F}urt, yumurta, protein s\u{00FC}t
        - Mideyi yormayacak \u{015F}eyler \u{00F6}ner

        SADECE JSON format\u{0131}nda yan\u{0131}t ver, ba\u{015F}ka hi\u{00E7}bir \u{015F}ey yazma.
        """

    func generateMealSuggestion(
        notificationType: MealNotificationType,
        remainingCalories: Int,
        remainingProtein: Int,
        remainingCarbs: Int,
        remainingFat: Int,
        todayMeals: [String],
        preferredProteins: [String],
        todayActivities: [String],
        hrvStatus: HRVStatus
    ) async throws -> MealSuggestion {
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else { throw GroqError.missingAPIKey }

        let typeText = notificationType == .afternoon ? "Ak\u{015F}am yeme\u{011F}i \u{00F6}nerisi" : "Gece at\u{0131}\u{015F}t\u{0131}rmal\u{0131}\u{011F}\u{0131} \u{00F6}nerisi"
        let mealsText = todayMeals.isEmpty ? "Hen\u{00FC}z bir \u{015F}ey yenmedi" : todayMeals.joined(separator: ", ")
        let activityNames = todayActivities
            .compactMap { GoalEngine.activityDisplayNames[$0] }
            .joined(separator: ", ")

        let today = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)

        let userPrompt = """
            Tarih: \(today)
            Bildirim tipi: \(typeText)
            Kalan kalori: \(remainingCalories) kcal
            Kalan protein: \(remainingProtein)g
            Kalan karb: \(remainingCarbs)g
            Kalan ya\u{011F}: \(remainingFat)g
            Bug\u{00FC}n yenenler: \(mealsText)
            Tercih edilen proteinler: \(preferredProteins.joined(separator: ", "))
            Bug\u{00FC}nk\u{00FC} aktivite: \(activityNames)
            Toparlanma durumu: \(hrvStatus.rawValue)

            JSON format\u{0131}:
            {
              "title": "k\u{0131}sa ba\u{015F}l\u{0131}k max 50 karakter",
              "body": "2-3 c\u{00FC}mle a\u{00E7}\u{0131}klama",
              "meals": [
                {
                  "name": "yemek ad\u{0131}",
                  "portion": "porsiyon",
                  "calories": 0,
                  "protein": 0
                }
              ]
            }
            """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": suggestionSystemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.7,
            "max_tokens": 400
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GroqError.apiError
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        let jsonString = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GroqError.invalidJSON
        }

        return try JSONDecoder().decode(MealSuggestion.self, from: jsonData)
    }
}

// MARK: - Groq API response types

private struct ChatCompletionResponse: Codable {
    let choices: [Choice]
}

private struct Choice: Codable {
    let message: Message
}

private struct Message: Codable {
    let content: String?
}

// MARK: - Errors

enum GroqError: LocalizedError {
    case missingAPIKey
    case apiError
    case emptyResponse
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "API anahtarı bulunamadı"
        case .apiError: "Groq API hatası"
        case .emptyResponse: "Boş yanıt alındı"
        case .invalidJSON: "Yanıt işlenemedi"
        }
    }
}
