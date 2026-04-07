//
//  GroqService.swift
//  VoiceMeal
//

import Foundation
import UIKit

struct ParsedMeal: Codable, Identifiable {
    var id: String { name }
    var name: String
    var amount: String
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
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
    let waterMl: Int?
}

struct PhotoAnalysisResponse: Codable {
    let detected: Bool
    let meals: [ParsedMeal]?
    let clarification_needed: Bool
    let clarification_question: String?
    let confidence: String
    let description: String
}

@Observable
class GroqService {

    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

    var currentLanguage: String {
        Locale.current.language.languageCode?.identifier ?? "tr"
    }

    var appLanguage: String {
        let saved = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? ""
        if saved.hasPrefix("tr") { return "tr" }
        if saved.hasPrefix("en") { return "en" }
        return Locale.current.language.languageCode?.identifier ?? "tr"
    }

    private var languageInstruction: String {
        if appLanguage == "en" {
            return "\n\nIMPORTANT: Respond in English. The user's app language is English."
        }
        return "\n\nIMPORTANT: Respond in Turkish (Türkçe). The user's app language is Turkish."
    }

    func coachPersonalityPrompt(for coachStyle: CoachStyle) -> String {
        let lang = appLanguage
        return lang == "en"
            ? coachStyle.personalityPromptEn
            : coachStyle.personalityPromptTr
    }

    private let model = "meta-llama/llama-4-scout-17b-16e-instruct"

    // MARK: - Locale-Aware Nutrition Expert

    var userLocale: String {
        Locale.current.region?.identifier ?? "TR"
    }

    func localeToDescription(_ locale: String) -> String {
        switch locale {
        case "TR": return "Turkish"
        case "US", "CA": return "American/North American"
        case "GB", "IE": return "British"
        case "DE", "AT", "CH": return "German/Central European"
        case "JP": return "Japanese"
        case "KR": return "Korean"
        case "IT": return "Italian"
        case "FR": return "French"
        case "ES", "MX": return "Spanish/Latin American"
        case "BR": return "Brazilian"
        case "IN": return "Indian"
        case "CN", "TW", "HK": return "Chinese"
        case "GR": return "Greek/Mediterranean"
        case "SA", "AE", "EG": return "Middle Eastern/Arabic"
        default: return "International"
        }
    }

    func buildNutritionExpertPrompt(language: String, locale: String, personalContext: String) -> String {
        let localeDescription = localeToDescription(locale)

        var prompt = """
        You are a world-class nutrition expert and dietitian \
        with deep knowledge of all global cuisines.

        USER CONTEXT:
        - Language: \(language)
        - Region/Culture: \(localeDescription)

        EXPERTISE:
        - You know standard portion sizes for \(localeDescription) cuisine
        - You recognize local dishes, brands, and ingredients
        - You understand cooking methods common in this region
        - You know local restaurant chains and their typical portions

        UNIVERSAL PORTION STANDARDS:
        - 1 bowl soup = 250-300ml
        - 1 main dish serving = 200-250g
        - 1 glass liquid = 200-250ml
        - 1 tablespoon oil = 10ml = 90 kcal
        - 1 medium egg = 70 kcal, P:6g, K:0g, Y:5g

        CRITICAL RULES:
        1. NEVER return null for calories/protein/carbs/fat
        2. Always estimate if uncertain - use "~" in amount
        3. Use \(language) language in all responses
        4. Apply \(localeDescription) portion standards
        5. Consider local cooking methods (oil usage, etc.)
        """

        if !personalContext.isEmpty {
            prompt += """

            IMPORTANT - Personal notes about this user:
            \(personalContext)
            Apply these preferences when estimating portions \
            and nutritional values.
            """
        }

        return prompt
    }

    private func systemPrompt(personalContext: String = "") -> String {
        let jsonFormat = """
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
          "correctedAmount": "string or null",
          "waterMl": "number or null"
        }
        """

        let expertPrompt = buildNutritionExpertPrompt(
            language: appLanguage == "en" ? "English" : "Turkish",
            locale: userLocale,
            personalContext: personalContext
        )

        let nullWarning: String
        if appLanguage == "en" {
            nullWarning = """

            CRITICAL: calories and all macro values (protein, carbs, fat) can NEVER be null. \
            Even if you are not sure, make a reasonable estimate and indicate with '~' in the amount field.
            """
        } else {
            nullWarning = """

            KRİTİK: calories ve tüm makro değerler (protein, carbs, fat) ASLA null olamaz. \
            Emin olmasan bile makul bir tahmin yap ve amount alanına '~' ile belirt.
            """
        }

        if appLanguage == "en" {
            return """
            \(expertPrompt)

            Extract foods eaten from the user's speech \
            and respond ONLY in JSON format.

            CLARIFICATION RULES:
            - If food name is GENERIC (soup, meat, salad, fruit, drink, food), \
            you MUST ask which specific type:
              "Which soup? (lentil, tomato, chicken broth, ezogelin...)"
              "Which meat? (chicken, beef, lamb...)"
            - If food name is SPECIFIC (lentil soup, chicken breast, apple), \
            do NOT ask - proceed with estimation
            - If amount is unclear for a specific food, estimate with "~" prefix, do NOT ask
            - Only ask ONE clarification question at a time
            - Keep questions short and give examples in parentheses
            - NEVER ask about calories/protein/carbs - you calculate these

            If you can recognize the food:
            - Assume reasonable portion (1 serving, 1 bowl etc)
            - ESTIMATE calories/protein/carbs/fat
            - Return clarification_needed: false
            - Write "~1 serving (estimated)" in amount field

            If you cannot recognize the food at all:
            - Set clarification_needed: true
            - Ask what the food was

            If the user is making a correction (e.g. "actually the protein shake is 250 calories", \
            "no I was wrong, 300 grams of chicken", "change", "update"), set isCorrection: true \
            and write which food to correct in targetFoodName. \
            Write corrected values in correctedCalories, correctedProtein, \
            correctedCarbs, correctedFat, correctedAmount. \
            If it's a normal food entry, set isCorrection: false.

            If the user changes only the amount (e.g. "reduce to 50g", "delete half"), \
            calculate calories and macros proportionally. \
            Example: 100g = 250 kcal, then 50g = 125 kcal. \
            Use the calorie density from the original entry. \
            ALWAYS fill correctedCalories, correctedProtein, correctedCarbs, correctedFat. \
            Never change only the amount without updating macros.

            If the user mentions drinking water ("I drank water", "a glass of water", \
            "500ml water"), write the amount in ml in the waterMl field. \
            1 glass = 200ml, 1 bottle = 500ml. \
            If there's food with water, fill both meals and waterMl. \
            If no water, set waterMl: null.
            \(nullWarning)
            JSON format must be exactly as follows, write nothing else:
            \(jsonFormat)
            """
        } else {
            return """
            \(expertPrompt)

            Kullanıcının Türkçe konuşmasından \
            yenilen yemekleri çıkar ve SADECE JSON formatında yanıt ver.

            AÇIKLAMA KURALLARI:
            - Yemek adı GENEL ise (çorba, et, salata, meyve, içecek, yemek), \
            hangi tür olduğunu MUTLAKA sor:
              "Hangi çorba? (mercimek, domates, tavuk suyu, ezogelin...)"
              "Hangi et? (tavuk, dana, kuzu...)"
            - Yemek adı SPESIFIK ise (mercimek çorbası, tavuk göğsü, elma), \
            SORMA - tahminine devam et
            - Spesifik yemek için miktar belirsizse "~" ile tahmin et, SORMA
            - Tek seferde sadece BİR açıklama sorusu sor
            - Soruları kısa tut ve parantez içinde örnekler ver
            - ASLA kalori/protein/karbonhidrat sorma - bunları sen hesapla

            Eğer yemeği tanıyorsan, miktar belirsiz olsa bile:
            - Makul bir porsiyon varsay (1 porsiyon, 1 kase vs)
            - calories/protein/carbs/fat değerlerini TAHMİN et
            - clarification_needed: false ile döndür
            - amount alanına "~1 porsiyon (tahmini)" yaz

            Eğer yemeği hiç tanıyamıyorsan:
            - clarification_needed: true
            - Yemeğin ne olduğunu sor

            Eğer kullanıcı bir düzeltme yapıyorsa (örn: "aslında protein \
            sütü 250 kalori", "hayır yanlış yazdım tavuk 300 gram", \
            "değiştir", "güncelle"), isCorrection: true yap ve \
            hangi yemeği düzelteceğini targetFoodName'e yaz. \
            Düzeltilen değerleri correctedCalories, correctedProtein, \
            correctedCarbs, correctedFat, correctedAmount alanlarına yaz. \
            Normal yemek girişiyse isCorrection: false.

            Eğer kullanıcı sadece miktarı değiştiriyorsa (örn: "50 grama \
            düşür", "yarısını sil"), kalorileri ve makroları da orantılı \
            olarak hesapla. Örnek: 100g = 250 kcal ise, 50g = 125 kcal olmalı. \
            Orijinal kayıttaki kalori yoğunluğunu kullan: \
            kalori_yoğunluğu = orijinal_kalori / orijinal_miktar, \
            yeni_kalori = kalori_yoğunluğu * yeni_miktar. \
            correctedCalories, correctedProtein, correctedCarbs, \
            correctedFat alanlarını MUTLAKA doldur. \
            Hiçbir zaman sadece miktarı değiştirip makroları boş bırakma.

            Eğer kullanıcı su içtiğini belirtiyorsa ("su içtim", "bir bardak su", \
            "500ml su", "2 bardak su"), waterMl alanına ml cinsinden yaz. \
            1 bardak = 200ml, 1 şişe = 500ml. \
            Su ile birlikte yemek de varsa hem meals hem waterMl doldur. \
            Su yoksa waterMl: null yaz.
            \(nullWarning)
            JSON formatı kesinlikle şu şekilde olmalı, başka hiçbir şey yazma:
            \(jsonFormat)
            """
        }
    }

    func parseMeals(transcript: String, personalContext: String = "") async throws -> MealParseResponse {
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else {
            throw GroqError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt(personalContext: personalContext) + languageInstruction],
                ["role": "user", "content": transcript]
            ],
            "temperature": 0.1
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            print("❌ [GroqService] Network error: \(urlError.code.rawValue) - \(urlError.localizedDescription)")
            if urlError.code == .timedOut {
                throw GroqError.timeout
            }
            throw GroqError.networkError
        }

        let httpResponse = response as? HTTPURLResponse
        guard let httpResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = httpResponse?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ [GroqService] HTTP \(code): \(body)")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        // Strip markdown code fences if present
        let jsonString = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ [GroqService] Invalid JSON string: \(jsonString)")
            throw GroqError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(MealParseResponse.self, from: jsonData)
        } catch {
            print("❌ [GroqService] JSON decode error: \(error) — raw: \(jsonString)")
            throw GroqError.invalidJSON
        }
    }

    // MARK: - Time of Day

    enum TimeOfDay: String {
        case morning  = "Sabah"    // 06:00 - 11:00
        case midday   = "Öğle"     // 11:00 - 15:00
        case evening  = "Akşam"    // 15:00 - 20:00
        case night    = "Gece"     // 20:00 - 06:00
    }

    static func currentTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 6..<11:  return .morning
        case 11..<15: return .midday
        case 15..<20: return .evening
        default:      return .night
        }
    }

    // MARK: - Daily Insight

    private func insightSystemPrompt(personalContext: String = "") -> String {
        let expertBase = buildNutritionExpertPrompt(
            language: appLanguage == "en" ? "English" : "Turkish",
            locale: userLocale,
            personalContext: personalContext
        )

        if appLanguage == "en" {
            return """
            \(expertBase)

            You are also a personal fitness coach. \
            Analyze the user's CURRENT status. \
            ONLY 2-3 sentences, English, friendly, you may use emojis.

            Time period rules:
            - Morning: Plan the day, motivate, what to watch out for
            - Midday: How the morning went, afternoon suggestions
            - Evening: Evening meal guidance based on remaining calories/deficit
            - Night: Day summary, prep for tomorrow, bedtime advice

            IMPORTANT:
            - Eating target (dailyCalorieTarget) and calorie deficit (targetDeficit) \
            are DIFFERENT things. Deficit = TDEE - eaten. Eating target = how much to eat.
            - If the user exceeded their eating target, mention it
            - But if real deficit is greater than target deficit (lots of exercise), \
            evaluate this positively
            - Never show TDEE as the eating target
            Never make lists, write plain text. Respond ONLY in English.
            """
        } else {
            return """
            \(expertBase)

            Aynı zamanda kişisel bir fitness koçusun. \
            Kullanıcının o ANKİ durumunu analiz et. \
            SADECE 2-3 cümle, Türkçe, samimi, emoji kullanabilirsin.

            Zaman dilimi kuralları:
            - Sabah: Günü planla, motivasyon ver, neye dikkat etmeli
            - Öğle: Sabah nasıl geçti, öğleden sonra için öneri
            - Akşam: Kalan kalori/açık durumuna göre akşam yemeği yönlendirmesi
            - Gece: Günün özeti, yarına hazırlık, uyku öncesi öneri

            ÖNEMLİ:
            - Yeme hedefi (dailyCalorieTarget) ile kalori açığı (targetDeficit) \
            FARKLI şeylerdir. Açık = TDEE - yenen. Yeme hedefi = ne kadar yemeli.
            - Kullanıcı yeme hedefini aştıysa bunu belirt
            - Ama gerçek açık hedef açıktan büyükse (çok spor yaptı) \
            bunu olumlu değerlendir
            - Asla TDEE'yi yeme hedefi olarak gösterme
            Asla liste yapma, düz metin yaz. SADECE Türkçe yanıt ver.
            """
        }
    }

    func generateDailyInsight(
        timeOfDay: TimeOfDay,
        hrvStatus: HRVStatus,
        todayHRV: Double?,
        hrvBaseline: Double?,
        sleep: SleepData?,
        todayActivities: [String],
        consumed: Int,
        dailyCalorieTarget: Int,
        remainingCalories: Int,
        targetDeficit: Int,
        actualDeficit: Int,
        deficitGap: Int,
        proteinConsumed: Double,
        proteinTarget: Int,
        tdee: Int,
        intensityLevel: Double,
        waterMl: Int = 0,
        waterGoalMl: Int = 0,
        coachStyle: CoachStyle = .supportive,
        personalContext: String = ""
    ) async throws -> String {
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else { throw GroqError.missingAPIKey }

        let lang = appLanguage
        let noDataText = lang == "en" ? "No data" : "Veri yok"

        let hrvText: String
        if let hrv = todayHRV {
            let baselineText = hrvBaseline.map { String(format: "%.0f", $0) } ?? "?"
            hrvText = "\(String(format: "%.0f", hrv))ms (baseline: \(baselineText)ms, status: \(hrvStatus.rawValue))"
        } else {
            hrvText = noDataText
        }

        let sleepText: String
        if let s = sleep {
            let hours = s.totalMinutes / 60
            let mins = s.totalMinutes % 60
            sleepText = lang == "en"
                ? "\(hours)h \(mins)min total, quality: \(s.quality.rawValue)"
                : "\(hours)s \(mins)dk toplam, kalite: \(s.quality.rawValue)"
        } else {
            sleepText = noDataText
        }

        let activityNames = todayActivities
            .compactMap { GoalEngine.activityDisplayNames[$0] }
            .joined(separator: ", ")

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: .now)

        let userPrompt: String
        if lang == "en" {
            let remainingStatus = remainingCalories < 0 ? "exceeded target" : "within target"
            let deficitStatus = deficitGap > 0
                ? "need \(deficitGap) kcal more to reach target"
                : "exceeded target, great job"

            userPrompt = """
                Time: \(timeStr) (\(timeOfDay.rawValue))
                HRV: \(hrvText)
                Sleep: \(sleepText)
                Today's activity: \(activityNames)

                --- NUTRITION STATUS ---
                Eating target: \(dailyCalorieTarget) kcal
                Consumed so far: \(consumed) kcal
                Remaining for eating target: \(remainingCalories) kcal
                (\(remainingStatus))

                Calorie deficit target: \(targetDeficit) kcal/day
                Current real deficit: \(actualDeficit) kcal
                Deficit gap: \(deficitGap) kcal
                (\(deficitStatus))

                Protein: \(String(format: "%.0f", proteinConsumed))g / \(proteinTarget)g target
                TDEE: \(tdee) kcal
                \(waterGoalMl > 0 ? """

                --- WATER STATUS ---
                Water consumed: \(waterMl) ml / \(waterGoalMl) ml target
                """ : "")
                """
        } else {
            let remainingStatus = remainingCalories < 0 ? "hedefi aştı" : "hedef içinde"
            let deficitStatus = deficitGap > 0
                ? "hedefe ulaşmak için \(deficitGap) kcal daha lazım"
                : "hedefi geçtin, bravo"

            userPrompt = """
                Saat: \(timeStr) (\(timeOfDay.rawValue))
                HRV: \(hrvText)
                Uyku: \(sleepText)
                Bugünkü aktivite: \(activityNames)

                --- BESLENME DURUMU ---
                Yeme hedefi: \(dailyCalorieTarget) kcal
                Şu ana kadar yendi: \(consumed) kcal
                Yeme hedefine göre kalan: \(remainingCalories) kcal
                (\(remainingStatus))

                Kalori açığı hedefi: \(targetDeficit) kcal/gün
                Şu anki gerçek açık: \(actualDeficit) kcal
                Açık farkı: \(deficitGap) kcal
                (\(deficitStatus))

                Protein: \(String(format: "%.0f", proteinConsumed))g / \(proteinTarget)g hedef
                TDEE: \(tdee) kcal
                \(waterGoalMl > 0 ? """

                --- SU DURUMU ---
                İçilen su: \(waterMl) ml / \(waterGoalMl) ml hedef
                """ : "")
                """
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": insightSystemPrompt(personalContext: personalContext) + languageInstruction + "\n\n" + coachPersonalityPrompt(for: coachStyle)],
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            print("❌ [GroqService] Network error: \(urlError.code.rawValue)")
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ [GroqService] HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Weekly Insight

    private func weeklyInsightSystemPrompt(personalContext: String = "") -> String {
        let expertBase = buildNutritionExpertPrompt(
            language: appLanguage == "en" ? "English" : "Turkish",
            locale: userLocale,
            personalContext: personalContext
        )

        if appLanguage == "en" {
            return """
            \(expertBase)

            You are also a personal fitness coach. \
            Analyze the user's weekly statistics and write \
            ONLY a 2-3 sentence short, friendly weekly assessment in English. \
            Use scientific but conversational language. \
            You may use emojis. Never make lists, write plain text. \
            Respond ONLY in English. Do not use Turkish words.
            """
        } else {
            return """
            \(expertBase)

            Aynı zamanda kişisel bir fitness koçusun. \
            Kullanıcının haftalık istatistiklerini analiz edip \
            SADECE 2-3 cümlelik kısa, samimi, Türkçe bir haftalık \
            değerlendirme yaz. Bilimsel ama sohbet dili kullan. \
            Emoji kullanabilirsin. Asla liste yapma, düz metin yaz. \
            SADECE Türkçe yanıt ver.
            """
        }
    }

    func generateWeeklyInsight(
        stats: [DayStat],
        streak: Int,
        trend: TrendDirection,
        avgCalories: Int,
        avgProtein: Double,
        totalDeficit: Int,
        currentWeight: Double,
        goalWeight: Double,
        coachStyle: CoachStyle = .supportive,
        personalContext: String = ""
    ) async throws -> String {
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else { throw GroqError.missingAPIKey }

        let daysWithData = stats.filter { $0.hasData }.count
        let estimatedKg = String(format: "%.2f", Double(totalDeficit) / 7700.0)

        let lang = appLanguage
        let dayWord = lang == "en" ? "days" : "gün"
        let activitySummary = Dictionary(
            stats.flatMap { $0.activities }.map { ($0, 1) },
            uniquingKeysWith: +
        ).map { "\(GoalEngine.activityDisplayNames[$0.key] ?? $0.key): \($0.value) \(dayWord)" }
        .joined(separator: ", ")

        let userPrompt: String
        if lang == "en" {
            userPrompt = """
                Weekly summary:
                Days with data: \(daysWithData)/7
                Average calories: \(avgCalories) kcal
                Average protein: \(Int(avgProtein))g
                Total deficit: \(totalDeficit) kcal
                Estimated change: \(estimatedKg) kg
                Streak: \(streak) days on target
                Trend: \(trend.rawValue)
                Current weight: \(String(format: "%.1f", currentWeight)) kg
                Goal weight: \(String(format: "%.1f", goalWeight)) kg
                Activities: \(activitySummary)

                Write a short weekly assessment based on this data.
                """
        } else {
            userPrompt = """
                Haftalık özet:
                Veri olan gün sayısı: \(daysWithData)/7
                Ortalama kalori: \(avgCalories) kcal
                Ortalama protein: \(Int(avgProtein))g
                Toplam açık: \(totalDeficit) kcal
                Tahmini değişim: \(estimatedKg) kg
                Seri: \(streak) gün hedefe ulaştı
                Trend: \(trend.rawValue)
                Mevcut kilo: \(String(format: "%.1f", currentWeight)) kg
                Hedef kilo: \(String(format: "%.1f", goalWeight)) kg
                Aktiviteler: \(activitySummary)

                Bu verilere göre kısa bir haftalık değerlendirme yap.
                """
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": weeklyInsightSystemPrompt(personalContext: personalContext) + languageInstruction + "\n\n" + coachPersonalityPrompt(for: coachStyle)],
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            print("❌ [GroqService] Network error: \(urlError.code.rawValue)")
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ [GroqService] HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    // MARK: - Program Insight

    private func programInsightSystemPrompt(personalContext: String = "") -> String {
        let expertBase = buildNutritionExpertPrompt(
            language: appLanguage == "en" ? "English" : "Turkish",
            locale: userLocale,
            personalContext: personalContext
        )

        if appLanguage == "en" {
            return """
            \(expertBase)

            You are also a personal fitness coach. \
            Analyze the user's program summary and write \
            a 2-3 sentence assessment in English. \
            Be motivating but realistic. \
            Add an important suggestion if applicable. \
            You may use emojis. Write plain text, no lists. \
            Respond ONLY in English. Do not use Turkish words.
            """
        } else {
            return """
            \(expertBase)

            Aynı zamanda kişisel bir fitness koçusun. \
            Kullanıcının program özetini analiz et ve \
            2-3 cümlelik Türkçe bir değerlendirme yap. \
            Motive edici ama gerçekçi ol. \
            Varsa önemli bir öneri ekle. \
            Emoji kullanabilirsin. Düz metin yaz, liste yapma. \
            SADECE Türkçe yanıt ver.
            """
        }
    }

    func generateProgramInsight(summary: ProgramSummary, coachStyle: CoachStyle = .supportive, personalContext: String = "") async throws -> String {
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else { throw GroqError.missingAPIKey }

        let lang = appLanguage
        let noDataText = lang == "en" ? "No data" : "Veri yok"

        let goalText: String
        switch summary.goalDirection {
        case .losing: goalText = lang == "en" ? "lose weight" : "kilo vermek"
        case .gaining: goalText = lang == "en" ? "gain weight" : "kilo almak"
        case .maintenance: goalText = lang == "en" ? "maintain weight" : "kiloyu korumak"
        }

        let bestDayText: String
        if let best = summary.bestDay {
            bestDayText = "\(best.date.formatted(.dateTime.day().month(.abbreviated))) \u{2014} \(best.value) kcal"
        } else { bestDayText = noDataText }

        let worstDayText: String
        if let worst = summary.worstDay {
            worstDayText = "\(worst.date.formatted(.dateTime.day().month(.abbreviated))) \u{2014} \(worst.value) kcal"
        } else { worstDayText = noDataText }

        let userPrompt: String
        if lang == "en" {
            userPrompt = """
                User's goal: \(goalText)
                Program duration: \(summary.totalDays) days / \(summary.totalDays + summary.daysRemaining) days
                Adherence rate: %\(summary.adherencePercent)
                Start weight: \(String(format: "%.1f", summary.startWeight)) kg
                Goal weight: \(String(format: "%.1f", summary.goalWeight)) kg
                Estimated change: \(String(format: "%.2f", summary.estimatedWeightChangeKg)) kg
                Expected change: \(String(format: "%.2f", summary.expectedChangeByNow)) kg
                On track: \(summary.onTrack ? "Yes" : "No")
                Average calories: \(summary.avgDailyCalories) kcal
                Average protein: \(Int(summary.avgDailyProtein))g
                Total deficit: \(summary.totalDeficitKcal) kcal
                Streak: \(summary.currentStreak) days (best: \(summary.bestStreak))
                Workout days: \(summary.totalWorkoutDays)
                Best day: \(bestDayText)
                Hardest day: \(worstDayText)
                Progress: %\(summary.progressPercent)

                Write a short program assessment based on this data.
                """
        } else {
            userPrompt = """
                Kullanıcının hedefi: \(goalText)
                Program süresi: \(summary.totalDays) gün / \(summary.totalDays + summary.daysRemaining) gün
                Takip oranı: %\(summary.adherencePercent)
                Başlangıç kilo: \(String(format: "%.1f", summary.startWeight)) kg
                Hedef kilo: \(String(format: "%.1f", summary.goalWeight)) kg
                Tahmini değişim: \(String(format: "%.2f", summary.estimatedWeightChangeKg)) kg
                Beklenen değişim: \(String(format: "%.2f", summary.expectedChangeByNow)) kg
                Hedefe uygunluk: \(summary.onTrack ? "Evet" : "Hayır")
                Ortalama kalori: \(summary.avgDailyCalories) kcal
                Ortalama protein: \(Int(summary.avgDailyProtein))g
                Toplam açık: \(summary.totalDeficitKcal) kcal
                Seri: \(summary.currentStreak) gün (en iyi: \(summary.bestStreak))
                Antrenman günleri: \(summary.totalWorkoutDays)
                En iyi gün: \(bestDayText)
                En zor gün: \(worstDayText)
                İlerleme: %\(summary.progressPercent)

                Bu verilere göre kısa bir program değerlendirmesi yap.
                """
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": programInsightSystemPrompt(personalContext: personalContext) + languageInstruction + "\n\n" + coachPersonalityPrompt(for: coachStyle)],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.7,
            "max_tokens": 250
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            print("❌ [GroqService] Network error: \(urlError.code.rawValue)")
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ [GroqService] HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Photo Food Analysis

    private var photoAnalysisPrompt: String {
        let jsonFormat = """
        {
          "detected": true/false,
          "meals": [
            {
              "name": "food name",
              "amount": "estimated amount (grams or portion)",
              "calories": number,
              "protein": number,
              "carbs": number,
              "fat": number
            }
          ],
          "clarification_needed": true/false,
          "clarification_question": "question or null",
          "confidence": "high/medium/low",
          "description": "short description"
        }
        """

        if appLanguage == "en" {
            return """
            You are a nutrition expert. Analyze the food in the photo.

            Respond ONLY in JSON format, write nothing else:
            \(jsonFormat)

            If the food amount is unclear, set clarification_needed: true. \
            Write clarification_question in English.
            If food cannot be identified, return detected: false.
            If the photo doesn't contain food, return detected: false.
            Recognize foods from all cuisines. List each food on the plate separately.
            Write name and description in English.
            """
        } else {
            return """
            Sen bir beslenme uzmanısın. Fotoğraftaki yiyeceği analiz et.

            SADECE JSON formatında yanıt ver, başka hiçbir şey yazma:
            \(jsonFormat)

            Eğer yemek miktarı belirsizse clarification_needed: true yap. \
            clarification_question alanına Türkçe soru yaz.
            Eğer yemek tanınamıyorsa detected: false döndür.
            Fotoğraf yemek içermiyorsa detected: false döndür.
            Türk yemeklerini iyi tanı. Tabaktaki her yemeği ayrı listele.
            name ve description alanlarını Türkçe yaz.
            """
        }
    }

    // meta-llama/llama-4-scout-17b-16e-instruct supports vision (multimodal) on Groq
    func analyzeFood(imageData: Data) async throws -> PhotoAnalysisResponse {
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else {
            print("📷 [ERROR] Missing API key")
            throw GroqError.missingAPIKey
        }

        let base64Image = imageData.base64EncodedString()

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": photoAnalysisPrompt + languageInstruction
                        ]
                    ]
                ]
            ],
            "temperature": 0.2,
            "max_tokens": 600
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            print("❌ [GroqService] Network error: \(urlError.code.rawValue)")
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ [GroqService] HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            print("📷 [ERROR] Empty response content")
            throw GroqError.emptyResponse
        }

        let jsonString = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("📷 [ERROR] Could not convert JSON string to data")
            throw GroqError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(PhotoAnalysisResponse.self, from: jsonData)
        } catch {
            print("📷 [ERROR] JSON decode failed: \(error)")
            throw GroqError.invalidJSON
        }
    }

    func clarifyFoodAnalysis(
        originalResponse: PhotoAnalysisResponse,
        clarification: String,
        imageData: Data
    ) async throws -> PhotoAnalysisResponse {
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else {
            print("📷 [ERROR] Missing API key")
            throw GroqError.missingAPIKey
        }

        let base64Image = imageData.base64EncodedString()

        let contextPrompt = """
            \(photoAnalysisPrompt)

            Previous analysis results:
            \(originalResponse.description)

            User clarification: \(clarification)

            Return updated JSON with this information.
            Set clarification_needed: false since the user clarified.
            \(languageInstruction)
            """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": contextPrompt
                        ]
                    ]
                ]
            ],
            "temperature": 0.2,
            "max_tokens": 600
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            print("❌ [GroqService] Network error: \(urlError.code.rawValue)")
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ [GroqService] HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            print("📷 [ERROR] Empty clarification response")
            throw GroqError.emptyResponse
        }

        let jsonString = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("📷 [ERROR] Could not convert JSON to data")
            throw GroqError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(PhotoAnalysisResponse.self, from: jsonData)
        } catch {
            print("📷 [ERROR] JSON decode failed: \(error)")
            throw GroqError.invalidJSON
        }
    }

    // MARK: - Image Compression

    static func compressImage(_ image: UIImage) -> Data? {
        let maxSize: CGFloat = 512
        var targetImage = image

        if max(image.size.width, image.size.height) > maxSize {
            let scale = maxSize / max(image.size.width, image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        let maxBytes = 300_000
        if let data = targetImage.jpegData(compressionQuality: 0.5), data.count <= maxBytes {
            return data
        }

        return targetImage.jpegData(compressionQuality: 0.3)
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
    case apiError(statusCode: Int)
    case emptyResponse
    case invalidJSON
    case networkError
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "API anahtarı bulunamadı"
        case .apiError(let code):
            switch code {
            case 401: "API anahtarı geçersiz."
            case 429: "Çok fazla istek. Biraz bekleyin."
            case 500...599: "Groq sunucusu meşgul. Tekrar deneyin."
            default: "Groq API hatası (HTTP \(code))"
            }
        case .emptyResponse: "Boş yanıt alındı"
        case .invalidJSON: "Yanıt işlenemedi. Tekrar deneyin."
        case .networkError: "İnternet bağlantısı yok."
        case .timeout: "Bağlantı zaman aşımına uğradı."
        }
    }
}
