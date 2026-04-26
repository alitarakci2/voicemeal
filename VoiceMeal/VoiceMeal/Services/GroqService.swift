//
//  GroqService.swift
//  VoiceMeal
//

import Foundation
import Sentry
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
    let isGuess: Bool?
    let guessedFoodName: String?
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

    private func languageInstruction(for code: String) -> String {
        switch code {
        case "tr":
            return "KRİTİK KURAL: YALNIZCA Türkçe yanıt ver. Başka hiçbir dil kullanma."
        case "en":
            return "CRITICAL RULE: Respond in English ONLY. Do not use any other language."
        case "es":
            return "REGLA CRÍTICA: Responde SOLO en español."
        case "de":
            return "KRITISCHE REGEL: Antworte NUR auf Deutsch."
        case "fr":
            return "RÈGLE CRITIQUE: Réponds UNIQUEMENT en français."
        default:
            return "CRITICAL RULE: Respond in English ONLY."
        }
    }

    private func foodNameLanguageRule(for code: String) -> String {
        switch code {
        case "tr":
            return "3. Tüm yanıtlar ve yemek isimleri TÜRKÇE olmalı. Başka dil kullanma."
        case "en":
            return "3. All responses and food names must be in ENGLISH. No other language."
        case "es":
            return "3. Todas las respuestas y nombres de comida deben estar en ESPAÑOL."
        case "de":
            return "3. Alle Antworten und Speisennamen müssen auf DEUTSCH sein."
        case "fr":
            return "3. Toutes les réponses et noms d'aliments doivent être en FRANÇAIS."
        default:
            return "3. All responses and food names must be in ENGLISH."
        }
    }

    private func foodNameSchemaRule(for code: String) -> String {
        switch code {
        case "tr":
            return "- name: Yemeğin adı MUTLAKA Türkçe olmalı."
        case "en":
            return "- name: Food name MUST be in English."
        case "es":
            return "- name: El nombre del alimento debe estar en español."
        case "de":
            return "- name: Speisennamen müssen auf Deutsch sein."
        case "fr":
            return "- name: Le nom de l'aliment doit être en français."
        default:
            return "- name: Food name MUST be in English."
        }
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
        \(foodNameLanguageRule(for: appLanguage))
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
          "waterMl": "number or null",
          "isGuess": "boolean or null",
          "guessedFoodName": "string or null"
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

            LANGUAGE FLEXIBILITY:
            User may say foods without explicit "ate", "had", "drank". \
            Treat ANY food mention as something they consumed. \
            Examples: "2 boiled eggs and soup" → parse both. \
            "eggs soup" → parse both. Do NOT require verbs.

            CLARIFICATION RULE — SPECIFICITY FIRST:
            Step 1 — Is a specific type stated?
              NO (bare generic like "soup", "meat", "salad") → ask which type.
              YES → go to Step 2.
            Step 2 — Is that specific type a real, recognizable food?
              YES (known food) → proceed without asking.
              NO (unrecognizable, garbled, or non-existent word) → ask which type they meant.
            Recognized specific types (NO clarification needed): lentil soup, tomato soup, \
            tarhana soup, chicken broth, minestrone, french onion soup, ezogelin soup, \
            chicken breast, ground beef, meatballs, grilled chicken, steak, chicken wings, \
            salmon fillet, sea bass, sardines, tuna, mackerel, \
            caesar salad, greek salad, garden salad, coleslaw, \
            rice pilaf, bulgur pilaf, rice with chickpeas, brown rice, \
            cheese pastry, spinach pie, croissant, cheese toast, \
            rice pudding, chocolate cake, baklava, ice cream, yogurt.
            - If amount is unclear, estimate with "~" prefix — do NOT ask
            - NEVER ask about calories/protein/carbs — you calculate these

            When asking (generic OR unrecognized type):
            - Set clarification_needed: true
            - Set clarification_question with 3-4 specific options in parentheses
            - Include best-guess meal in meals array anyway

            GUESS MODE (triggered when system prompt begins with \
            "NOTE: This is the user's 2nd clarification attempt"):
            - Do NOT ask another question
            - Pick the most phonetically similar real food from the transcript
            - Set isGuess: true, guessedFoodName: the food you chose
            - Set clarification_question: \
            "I think you meant '[food name]', is that right?"
            - Set clarification_needed: false
            - Fill meals[] with the guessed food and your best calorie estimate

            MULTI-FOOD RULE:
            When user mentions multiple foods:
            1. ALWAYS include ALL foods in the meals array with your best estimates
            2. For specific foods: estimate normally, include in meals
            3. For generic foods: include best-guess in meals, set clarification_needed: true
            4. In clarification_question, confirm specific items and ask about generic ones:
               Example: "Boiled eggs noted ✅ Which soup? (lentil/tomato/chicken broth)"
            5. Only ask ONE clarification question at a time

            If you cannot recognize the food at all:
            - Set clarification_needed: true
            - Include best-guess in meals array anyway
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
            CONSISTENCY CHECK:
            After determining calories and macros, verify: \
            protein×4 + carbs×4 + fat×9 ≈ calories. \
            If total deviates by more than 15%, adjust carbs first to match. \
            ONE QUESTION RULE: Ask maximum ONE clarification question per response. \
            After one clarification round, always proceed with best estimates.

            CRITICAL JSON RULES:
            - calories, protein, carbs, fat fields must be plain numbers ONLY: 200, not ~200
            - The "~" prefix for estimates goes ONLY in the "amount" field: "~1 bowl"
            - Never use ~ in numeric fields
            - Never add any prefix/suffix to numeric values
            \(foodNameSchemaRule(for: appLanguage))

            JSON format must be exactly as follows, write nothing else:
            \(jsonFormat)

            CRITICAL: Your response must be ONLY valid JSON.
            Do NOT write any text, explanation, or commentary before or after the JSON.
            Start your response directly with { and end with }
            """
        } else {
            return """
            \(expertPrompt)

            Kullanıcının Türkçe konuşmasından \
            yenilen yemekleri çıkar ve SADECE JSON formatında yanıt ver.

            DİL ESNEKLİĞİ:
            Kullanıcı "yedim", "içtim", "aldım" demeyebilir. \
            Herhangi bir yemek adı geçtiğinde yenilmiş kabul et. \
            Örnekler: "2 haşlanmış yumurta bir tabak çorba" → ikisini de parse et. \
            "yumurta çorba" → ikisini de parse et. Fiil ZORUNLU DEĞİL.

            SES TANIMA DÜZELTME LİSTESİ:
            Apple Speech Recognition bazı Türkçe yemek isimlerini yanlış tanıyabilir. \
            Aşağıdaki yanlış yazılmış kelimeleri transcript'te gördüğünde otomatik olarak \
            doğru karşılığıyla değiştir ve KULLANICIYA HİÇ SORMA. \
            Sanki kullanıcı doğru kelimeyi söylemiş gibi davran.

            ÇORBALAR:
            parhana / parana / tarana → tarhana çorbası
            mecimek / merçimek → mercimek
            ezogelın / ezo gelin → ezogelin
            ışkembe → işkembe

            ET YEMEKLERİ:
            köfde / kofte → köfte
            kebab → kebap
            şiş kebab → şiş kebap
            iskendır / ıskender → İskender
            dönır / doner → döner
            lahmacın → lahmacun
            çiğ köfde / çiğ kofte → çiğ köfte
            tantunı → tantuni
            köfte ızgara → ızgara köfte

            HAMUR İŞLERİ:
            menemın → menemen
            manti → mantı
            boreğı → böreği
            sigara böreğı → sigara böreği
            gozleme → gözleme
            acma → açma
            pogaca → poğaça

            PİLAVLAR:
            pillav → pilav
            bulgur pilav → bulgur pilavı

            SEBZE YEMEKLERİ:
            ımam bayıldı → imam bayıldı
            karnı yarık → karnıyarık
            saksuka / şakşuga → şakşuka
            mucver → mücver

            TATLILAR:
            kunefe → künefe
            sütlach → sütlaç
            sekerpare → şekerpare
            asure → aşure
            kazan dibi → kazandibi

            KAHVALTI:
            beyaz peynır → beyaz peynir
            lor peynir → lor peyniri

            İÇECEKLER:
            salgam → şalgam suyu
            sahlep → salep

            AÇIKLAMA KURALI — SPESİFİKLİK + TANINIRLIK KONTROLÜ:
            Adım 1 — Spesifik bir tür belirtildi mi?
              HAYIR (sadece "çorba", "et", "salata" gibi genel kelime) → hangi tür olduğunu sor.
              EVET → Adım 2'ye geç.
            Adım 2 — Belirtilen tür gerçek ve tanınabilir bir yemek mi?
              EVET (bilinen yemek) → SORMA, devam et.
              HAYIR (tanınmayan, hatalı duyulan veya var olmayan kelime) → hangi türü kastettiklerini sor.
            Tanınan spesifik türler (açıklama GEREKMEZ): tarhana çorbası, mercimek çorbası, \
            ezogelin çorbası, domates çorbası, tavuk suyu çorbası, kremalı mantar çorbası, \
            şehriye çorbası, yayla çorbası, \
            tavuk göğsü, kıyma, köfte, ızgara köfte, tavuk but, tavuk kanat, biftek, \
            somon, levrek, çipura, hamsi, ton balığı, uskumru, \
            sezar salata, çoban salata, mevsim salata, \
            bulgur pilavı, nohutlu pilav, bezelye pilavı, \
            su böreği, peynirli börek, kol böreği, poğaça, peynirli tost, \
            sütlaç, muhallebi, baklava, dondurma, yoğurt, çikolatalı pasta.
            - Miktar belirsizse "~" ile tahmin et — SORMA
            - ASLA kalori/protein/karbonhidrat sorma — bunları sen hesapla

            Soru sorulacak durumlar (genel kelime VEYA tanınmayan tür):
            - clarification_needed: true
            - clarification_question'da 3-4 spesifik seçenek ver parantez içinde
            - Yine de meals dizisine en iyi tahminle ekle

            TAHMİN MODU (sistem prompt "NOT: Bu kullanıcının 2. clarification \
            denemesidir." ile başladığında tetiklenir):
            - Başka SORU SORMA
            - Transcript'e fonetik benzerliği en yüksek gerçek Türk yemeğini TAHMİN ET
            - isGuess: true, guessedFoodName: tahmin ettiğin yemeğin adı
            - clarification_question: \
            "Sanırım '[yemek adı]' demek istediniz, doğru mu?"
            - clarification_needed: false
            - meals[]: tahmin ettiğin yemekle doldur, kalori tahminini ekle

            ÇOKLU YEMEK KURALI:
            Kullanıcı birden fazla yemek söylediğinde:
            1. TÜM yemekleri meals dizisine dahil et, en iyi tahminlerinle
            2. Spesifik yemekler için: normal tahmin yap, meals'a ekle
            3. Genel yemekler için: en iyi tahminle meals'a ekle, clarification_needed: true yap
            4. clarification_question'da spesifik olanları onayla, genel olanı sor:
               Örnek: "Haşlanmış yumurta tamam ✅ Hangi çorba? (mercimek/domates/tavuk suyu)"
            5. Tek seferde sadece BİR açıklama sorusu sor

            Eğer yemeği hiç tanıyamıyorsan:
            - clarification_needed: true
            - Yine de meals dizisine en iyi tahminle ekle
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
            TUTARLILIK KONTROLÜ:
            Kalori ve makroları belirledikten sonra doğrula: \
            protein×4 + karb×4 + yağ×9 ≈ kalori. \
            Fark %15'ten fazlaysa, önce karbı ayarla. \
            TEK SORU KURALI: Yanıt başına en fazla BİR açıklama sorusu sor. \
            Bir açıklama turundan sonra her zaman en iyi tahminle devam et.

            KRİTİK JSON KURALLARI:
            - calories, protein, carbs, fat alanları SADECE düz sayı olmalı: 200, ~200 DEĞİL
            - "~" tahmini sadece "amount" alanında kullanılır: "~1 tabak"
            - Sayısal alanlarda asla ~ kullanma
            - Sayısal değerlere asla önek/sonek ekleme
            \(foodNameSchemaRule(for: appLanguage))

            JSON formatı kesinlikle şu şekilde olmalı, başka hiçbir şey yazma:
            \(jsonFormat)

            KRİTİK: Yanıtın SADECE geçerli JSON olmalı.
            JSON öncesinde veya sonrasında HİÇBİR metin, açıklama veya yorum yazma.
            Yanıta doğrudan { ile başla ve } ile bitir.
            """
        }
    }

    private func cleanGroqJSON(_ raw: String) -> String {
        var cleaned = raw
        if let regex = try? NSRegularExpression(pattern: #":\s*~(\d+\.?\d*)"#) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: ": $1")
        }
        return cleaned
    }

    /// Extracts a JSON object from a possibly noisy response. Groq sometimes
    /// prefixes/suffixes the JSON block with prose; this pulls out the outer `{...}`.
    private func extractJSON(_ raw: String) -> String {
        if raw.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
            return raw
        }
        if let start = raw.firstIndex(of: "{"),
           let end = raw.lastIndex(of: "}") {
            return String(raw[start...end])
        }
        return raw
    }

    func parseMeals(transcript: String, personalContext: String = "", isSecondClarification: Bool = false) async throws -> MealParseResponse {
        let startTime = Date()
        var retried = false
        do {
            let response: MealParseResponse
            do {
                response = try await parseMealsSingleAttempt(transcript: transcript, personalContext: personalContext, isSecondClarification: isSecondClarification)
            } catch let error where Self.isTransientError(error) {
                retried = true
                FeedbackService.shared.addLog("Groq retry (attempt 2)")
                FeedbackService.shared.logVoiceEvent(
                    icon: "🔁",
                    message: "Groq retry (transient error)",
                    data: ["error_type": Self.errorTypeTag(error)]
                )
                FeedbackService.shared.trackVoiceMetric(.retry)
                let crumb = Breadcrumb()
                crumb.level = .warning
                crumb.category = "voice.parse.retry"
                crumb.message = "Transient error, retrying once"
                crumb.data = ["error_type": Self.errorTypeTag(error)]
                SentrySDK.addBreadcrumb(crumb)
                try await Task.sleep(for: .seconds(1))
                response = try await parseMealsSingleAttempt(transcript: transcript, personalContext: personalContext, isSecondClarification: isSecondClarification)
            }
            let elapsed = Date().timeIntervalSince(startTime)
            FeedbackService.shared.addLog("Groq parseMeals: \(String(format: "%.1f", elapsed))s\(retried ? " (retried)" : "")")

            // Log conversation to voice session so it shows up in feedback emails
            FeedbackService.shared.logVoiceEvent(
                icon: "🗣",
                message: "Sent: \(String(transcript.prefix(250)))"
            )
            let mealsSummary = response.meals
                .map { "\($0.name) \(Int($0.calories ?? 0))kcal" }
                .joined(separator: " | ")
            FeedbackService.shared.logVoiceEvent(
                icon: "📥",
                message: "Got: \(mealsSummary.isEmpty ? "(empty)" : String(mealsSummary.prefix(200)))",
                data: response.clarification_needed
                    ? ["q": String((response.clarification_question ?? "").prefix(100))]
                    : [:]
            )

            let completed = Breadcrumb()
            completed.level = .info
            completed.category = "voice.parse.completed"
            completed.message = "Groq parseMeals completed"
            completed.data = [
                "latency_ms": Int(elapsed * 1000),
                "transcript_chars": transcript.count,
                "meal_count": response.meals.count,
                "had_clarification": response.clarification_needed,
                "had_water": response.waterMl != nil,
                "had_retry": retried,
                "success": true
            ]
            SentrySDK.addBreadcrumb(completed)
            return response
        } catch {
            let failed = Breadcrumb()
            failed.level = .error
            failed.category = "voice.parse.failed"
            failed.message = "Groq parseMeals failed"
            failed.data = [
                "error_type": Self.errorTypeTag(error),
                "retry_attempted": retried,
                "transcript_chars": transcript.count
            ]
            SentrySDK.addBreadcrumb(failed)
            throw error
        }
    }

    private static func isTransientError(_ error: Error) -> Bool {
        guard let groq = error as? GroqError else { return false }
        switch groq {
        case .timeout, .networkError: return true
        case .apiError(let code) where code >= 500: return true
        default: return false
        }
    }

    private static func errorTypeTag(_ error: Error) -> String {
        guard let groq = error as? GroqError else { return "unknown" }
        switch groq {
        case .missingAPIKey: return "missing_api_key"
        case .timeout: return "timeout"
        case .networkError: return "network"
        case .emptyResponse: return "empty_response"
        case .invalidJSON: return "json_decode"
        case .apiError(let code):
            if code >= 500 { return "5xx" }
            if code >= 400 { return "4xx" }
            return "http_\(code)"
        }
    }

    private func parseMealsSingleAttempt(transcript: String, personalContext: String, isSecondClarification: Bool) async throws -> MealParseResponse {
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else {
            throw GroqError.missingAPIKey
        }

        let baseSystem = languageInstruction(for: appLanguage) + "\n\n" + systemPrompt(personalContext: personalContext)
        let systemContent: String
        if isSecondClarification {
            let signal = appLanguage == "en"
                ? "NOTE: This is the user's 2nd clarification attempt. Apply GUESS MODE immediately.\n\n"
                : "NOT: Bu kullanıcının 2. clarification denemesidir. TAHMİN MODU'nu hemen uygula.\n\n"
            systemContent = signal + baseSystem
        } else {
            systemContent = baseSystem
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemContent],
                ["role": "user", "content": transcript]
            ],
            "temperature": 0.15,
            "response_format": ["type": "json_object"]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            #if DEBUG
            print("❌ [GroqService] Network error: \(urlError.code.rawValue) - \(urlError.localizedDescription)")
            #endif
            if urlError.code == .timedOut {
                throw GroqError.timeout
            }
            throw GroqError.networkError
        }

        let httpResponse = response as? HTTPURLResponse
        guard let httpResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = httpResponse?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            #if DEBUG
            print("❌ [GroqService] HTTP \(code): \(body)")
            #endif
            SentrySDK.capture(message: "Groq API error: \(code)")
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

        let cleanedJSON = cleanGroqJSON(jsonString)
        let extractedJSON = extractJSON(cleanedJSON)

        guard let jsonData = extractedJSON.data(using: .utf8) else {
            #if DEBUG
            print("❌ [GroqService] Invalid JSON string: \(extractedJSON)")
            #endif
            throw GroqError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(MealParseResponse.self, from: jsonData)
        } catch {
            SentrySDK.capture(error: error)
            #if DEBUG
            print("❌ [GroqService] JSON decode error: \(error) — raw: \(jsonString)")
            #endif
            throw GroqError.invalidJSON
        }
    }

    // MARK: - Time of Day

    enum TimeOfDay: String {
        case morning  = "Sabah"    // 06:00 - 11:00
        case midday   = "Öğle"     // 11:00 - 15:00
        case evening  = "Akşam"    // 15:00 - 21:00
        case night    = "Gece"     // 21:00 - 06:00

        var englishName: String {
            switch self {
            case .morning: return "Morning"
            case .midday:  return "Midday"
            case .evening: return "Evening"
            case .night:   return "Night"
            }
        }

        static func from(date: Date) -> TimeOfDay {
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 6..<11:  return .morning
            case 11..<15: return .midday
            case 15..<21: return .evening
            default:      return .night
            }
        }
    }

    static func currentTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 6..<11:  return .morning
        case 11..<15: return .midday
        case 15..<21: return .evening
        default:      return .night
        }
    }

    private func insightDayStart() -> Date {
        let cal = Calendar.current
        let now = Date()
        let sixAM = cal.date(bySettingHour: 6, minute: 0, second: 0, of: now) ?? now
        if now < sixAM {
            return cal.date(byAdding: .day, value: -1, to: sixAM) ?? sixAM
        }
        return sixAM
    }

    private func insightTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 6..<11:  return .morning
        case 11..<15: return .midday
        case 15..<21: return .evening
        default:      return .night
        }
    }

    // MARK: - Insight prompt versioning + length telemetry

    // Bump when LENGTH CONSTRAINT or prompt shape changes. Mismatched caches re-generate.
    static let dailyInsightPromptVersion = 2
    static let weeklyInsightPromptVersion = 2
    static let programInsightPromptVersion = 2
    static let nutritionReportPromptVersion = 2

    func modeTag(for gapKind: CalorieGapKind) -> String {
        switch gapKind {
        case .deficit:  return "deficit"
        case .surplus:  return "surplus"
        case .maintain: return "maintain"
        case .observe:  return "observe"
        }
    }

    func logInsightLength(
        insightType: String,
        text: String,
        targetMin: Int,
        targetMax: Int,
        language: String,
        mode: String
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let charCount = trimmed.count
        let sentenceCount = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
        let withinTarget = charCount >= targetMin && charCount <= targetMax
        let crumb = Breadcrumb()
        crumb.level = .info
        crumb.category = "ai.insight"
        crumb.message = "insight.generated"
        crumb.data = [
            "insight_type": insightType,
            "char_count": charCount,
            "target_char_min": targetMin,
            "target_char_max": targetMax,
            "sentence_count": sentenceCount,
            "within_target": withinTarget,
            "language": language,
            "mode": mode
        ]
        SentrySDK.addBreadcrumb(crumb)
    }

    // MARK: - Daily Insight

    private func insightSystemPrompt(personalContext: String = "", gapKind: CalorieGapKind = .deficit) -> String {
        let expertBase = buildNutritionExpertPrompt(
            language: appLanguage == "en" ? "English" : "Turkish",
            locale: userLocale,
            personalContext: personalContext
        )

        let modeRulesEN: String = {
            switch gapKind {
            case .deficit:
                return """
                MODE: CUTTING (calorie deficit goal)
                - Eating target (dailyCalorieTarget) and calorie deficit (targetDeficit) are DIFFERENT things. Deficit = TDEE - eaten. Eating target = how much to eat.
                - If the user exceeded their eating target, mention it
                - If real deficit is greater than target deficit (lots of exercise), evaluate this positively
                - Never show TDEE as the eating target
                """
            case .surplus:
                return """
                MODE: BULKING (calorie surplus goal — user wants to GAIN weight/muscle)
                - Eating target (dailyCalorieTarget) and calorie surplus (targetDeficit is negative) are DIFFERENT things. Surplus = eaten - TDEE. Eating target = how much to eat.
                - The user is TRYING to eat ABOVE TDEE. Do NOT warn about exceeding TDEE; that is the goal.
                - If the user is behind their eating target (undereating), gently push them to eat more
                - Never use the word "deficit" or "açık" — this user is bulking
                - Never show TDEE as the eating target
                """
            case .maintain:
                return """
                MODE: MAINTENANCE (calorie balance — user wants to HOLD weight)
                - The goal is to eat AT TDEE, not below or above. Target deficit is ~0.
                - If the user is significantly below or above TDEE, note it neutrally; neither is "bad" but big swings each direction compound over days
                - Never use the word "deficit" or "surplus" as a goal framing — the goal is balance
                - Never show TDEE as the eating target
                """
            case .observe:
                return """
                MODE: OBSERVE (no weight goal — user is just logging)
                - The user has NO calorie target, NO deficit goal, NO surplus goal. They are tracking for awareness only.
                - Do NOT use the words: "deficit", "surplus", "target", "goal", "cutting", "bulking", "should eat".
                - Do NOT compare eaten vs TDEE as good/bad. Just note patterns (consistent times, protein balance, variety).
                - Frame feedback around awareness, nutritional balance, hydration, consistency — never judgment on totals.
                """
            }
        }()

        let modeRulesTR: String = {
            switch gapKind {
            case .deficit:
                return """
                MOD: KİLO VERME (kalori açığı hedefi)
                - Yeme hedefi (dailyCalorieTarget) ile kalori açığı (targetDeficit) FARKLI şeylerdir. Açık = TDEE - yenen. Yeme hedefi = ne kadar yemeli.
                - Kullanıcı yeme hedefini aştıysa bunu belirt
                - Gerçek açık hedef açıktan büyükse (çok spor yaptı) bunu olumlu değerlendir
                - Asla TDEE'yi yeme hedefi olarak gösterme
                """
            case .surplus:
                return """
                MOD: KİLO ALMA / KAS YAPMA (kalori fazlası hedefi — kullanıcı KİLO/KAS ALMAK istiyor)
                - Yeme hedefi (dailyCalorieTarget) ile kalori fazlası (targetDeficit negatif) FARKLI şeylerdir. Fazla = yenen - TDEE. Yeme hedefi = ne kadar yemeli.
                - Kullanıcı TDEE'nin ÜZERİNDE yemeye ÇALIŞIYOR. TDEE'yi aşıyor diye uyarma; hedef bu.
                - Kullanıcı yeme hedefinin altındaysa (az yiyor), daha çok yemesi için nazikçe teşvik et
                - "Açık" veya "deficit" kelimesini ASLA kullanma — bu kullanıcı bulk yapıyor
                - Asla TDEE'yi yeme hedefi olarak gösterme
                """
            case .maintain:
                return """
                MOD: KORUMA (kalori dengesi — kullanıcı kilosunu KORUMAK istiyor)
                - Hedef TDEE kadar yemek, altında veya üstünde değil. Hedef açık ~0.
                - Kullanıcı TDEE'nin belirgin altında veya üstündeyse nötr bir tonla belirt; hiçbiri "kötü" değil ama günlerce süren sapmalar birikir
                - "Açık" veya "fazla"yı hedef çerçevesi olarak ASLA kullanma — hedef denge
                - Asla TDEE'yi yeme hedefi olarak gösterme
                """
            case .observe:
                return """
                MOD: GÖZLEM (kilo hedefi yok — kullanıcı sadece kayıt tutuyor)
                - Kullanıcının kalori hedefi, açık hedefi veya fazla hedefi YOK. Sadece farkındalık için kaydediyor.
                - Şu kelimeleri KULLANMA: "açık", "fazla", "hedef", "kilo verme", "kilo alma", "şu kadar yemeli".
                - Yenen ile TDEE'yi iyi/kötü olarak KIYASLAMA. Sadece örüntüleri belirt (tutarlı saatler, protein dengesi, çeşitlilik).
                - Yorumu farkındalık, besin dengesi, su tüketimi, istikrar üzerine kur — toplam için yargı yapma.
                """
            }
        }()

        if appLanguage == "en" {
            return """
            \(expertBase)

            LENGTH CONSTRAINT: Write EXACTLY 2 meaningful sentences, 15-25 words each. Both sentences combined: 30-50 words, 120-180 characters. Do NOT write single-word sentences, greetings, or filler. Structure: direct observation + actionable tip. Always end with a complete sentence; never cut off mid-sentence.

            You are also a personal fitness coach. Analyze the user's CURRENT status. English, friendly tone, may use emojis, plain text (no lists).

            Time period rules:
            - Morning: Plan the day, motivate, what to watch out for
            - Midday: How the morning went, afternoon suggestions
            - Evening: Evening meal guidance based on remaining calories
            - Night: Day summary, prep for tomorrow, bedtime advice

            \(modeRulesEN)
            """
        } else {
            return """
            \(expertBase)

            UZUNLUK KURALI: TAM OLARAK 2 anlamlı cümle yaz, her biri 12-20 kelime. İki cümle toplam: 25-45 kelime, 120-180 karakter. Tek kelimelik cümleler, selamlaşma veya boş dolgu YAZMA. Yapı: doğrudan gözlem + somut öneri. Her zaman tam cümleyle bitir; asla yarıda kesme.

            Aynı zamanda kişisel bir fitness koçusun. Kullanıcının o ANKİ durumunu analiz et. Türkçe, samimi ton, emoji kullanabilirsin, düz metin (liste yapma).

            Zaman dilimi kuralları:
            - Sabah: Günü planla, motivasyon ver, neye dikkat etmeli
            - Öğle: Sabah nasıl geçti, öğleden sonra için öneri
            - Akşam: Kalan kalori durumuna göre akşam yemeği yönlendirmesi
            - Gece: Günün özeti, yarına hazırlık, uyku öncesi öneri

            \(modeRulesTR)
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
        waterMl: Int = 0,
        waterGoalMl: Int = 0,
        coachStyle: CoachStyle = .supportive,
        personalContext: String = "",
        completedWorkouts: [(type: String, duration: Int, calories: Int)] = [],
        isObserveMode: Bool = false
    ) async throws -> String {
        let startTime = Date()
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else { throw GroqError.missingAPIKey }

        let lang = appLanguage
        let noDataText = lang == "en" ? "No data" : "Veri yok"
        let effectiveTimeOfDay = insightTimeOfDay()
        let isLateNight = Calendar.current.component(.hour, from: Date()) < 6

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

        let completedSummary: String
        if completedWorkouts.isEmpty {
            completedSummary = lang == "en"
                ? "No workouts completed yet today (per HealthKit)"
                : "Bugün henüz tamamlanan antrenman yok (HealthKit'e göre)"
        } else {
            let parts = completedWorkouts.map { w in
                lang == "en"
                    ? "\(w.type) \(w.duration)min \(w.calories)kcal"
                    : "\(w.type) \(w.duration)dk \(w.calories)kcal"
            }
            completedSummary = parts.joined(separator: ", ")
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: .now)
        let hour = Calendar.current.component(.hour, from: .now)

        let isRestDay = todayActivities.isEmpty || todayActivities == ["rest"]
        let activityLine: String
        if lang == "en" {
            let completedLine = "Completed workouts today (HealthKit): \(completedSummary)"
            let plannedLine = isRestDay
                ? "Planned for today (schedule): No workouts planned (rest day)"
                : "Planned for today (schedule): \(activityNames) (PLANNED, not confirmed as completed)"
            activityLine = "\(completedLine)\n                \(plannedLine)"
        } else {
            let completedLine = "Bugün tamamlanan antrenmanlar (HealthKit): \(completedSummary)"
            let plannedLine = isRestDay
                ? "Bugün planlanan (program): Antrenman planlanmamış (dinlenme günü)"
                : "Bugün planlanan (program): \(activityNames) (PLANLANMIŞ, tamamlandığı doğrulanmamış)"
            activityLine = "\(completedLine)\n                \(plannedLine)"
        }

        var contextFlags: [String] = []
        if consumed == 0 {
            contextFlags.append(lang == "en"
                ? "⚠️ IMPORTANT: User has logged ZERO calories today. They have NOT used the app yet today. Do NOT say \"great job\" or \"you're on track\". Acknowledge they haven't logged anything. Encourage them to log their meals. Do NOT assume they ate nothing — they may have eaten but not logged it."
                : "⚠️ ÖNEMLİ: Kullanıcı bugün HİÇ kalori kaydetmemiş. Uygulamayı henüz kullanmamış. \"Harika gidiyorsun\" veya \"yolundasın\" DEME. Henüz kayıt yapmadığını belirt. Yemeklerini kaydetmesi için teşvik et. Hiç yemediğini VARSAYMA — yemiş ama kaydetmemiş olabilir.")
        }
        if consumed > 0 && proteinConsumed == 0 {
            contextFlags.append(lang == "en"
                ? "⚠️ User has eaten but logged 0g protein — protein data may be incomplete."
                : "⚠️ Kullanıcı yemek yemiş ama 0g protein kayıtlı — protein verisi eksik olabilir.")
        }
        if consumed > tdee && tdee > 0 {
            contextFlags.append(lang == "en"
                ? "⚠️ User has consumed more than their TDEE (\(tdee) kcal) today."
                : "⚠️ Kullanıcı bugün TDEE'sini (\(tdee) kcal) aşmış durumda.")
        }
        if hour >= 17 && consumed > 0 && consumed < 300 {
            contextFlags.append(lang == "en"
                ? "⚠️ It's evening and user has eaten very little today (<300 kcal) — may not have logged or may be fasting."
                : "⚠️ Akşam oldu ve kullanıcı bugün çok az yemiş (<300 kcal) — kaydetmemiş veya oruç tutuyor olabilir.")
        }
        let contextNote = contextFlags.isEmpty ? "" : "\n\n" + contextFlags.joined(separator: "\n")

        var userPrompt: String
        if lang == "en" {
            let remainingStatus = remainingCalories < 0 ? "exceeded target" : "within target"
            let deficitStatus = deficitGap > 0
                ? "need \(deficitGap) kcal more to reach target"
                : "exceeded target, great job"

            userPrompt = """
                Time: \(timeStr) (\(effectiveTimeOfDay.englishName))
                HRV: \(hrvText)
                Sleep: \(sleepText)
                \(activityLine)

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
                """ : "")\(contextNote)
                """
        } else {
            let remainingStatus = remainingCalories < 0 ? "hedefi aştı" : "hedef içinde"
            let deficitStatus = deficitGap > 0
                ? "hedefe ulaşmak için \(deficitGap) kcal daha lazım"
                : "hedefi geçtin, bravo"

            userPrompt = """
                Saat: \(timeStr) (\(effectiveTimeOfDay.rawValue))
                HRV: \(hrvText)
                Uyku: \(sleepText)
                \(activityLine)

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
                """ : "")\(contextNote)
                """
        }

        if isLateNight {
            let lateNightNote = lang == "en"
                ? "Note: It's past midnight but the day is still ongoing (biological day ends at 06:00)."
                : "Not: Gece yarısını geçti ama gün hala devam ediyor (biyolojik gün 06:00'da biter)."
            userPrompt = lateNightNote + "\n\n" + userPrompt
        }

        let quality = DataQualityService.dailyQuality(
            consumed: consumed,
            target: dailyCalorieTarget,
            appLanguage: lang
        )

        let dailyGapKind: CalorieGapKind = isObserveMode ? .observe : CalorieGapKind.from(signedTargetDeficit: targetDeficit)
        var systemPrompt = languageInstruction(for: lang) + "\n\n" + insightSystemPrompt(personalContext: personalContext, gapKind: dailyGapKind) + "\n\n" + coachPersonalityPrompt(for: coachStyle)
        if !quality.warningNote.isEmpty {
            systemPrompt = quality.warningNote + "\n\n" + systemPrompt
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.5,
            "max_tokens": 150
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            #if DEBUG
            print("❌ [GroqService] Network error: \(urlError.code.rawValue)")
            #endif
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            #if DEBUG
            print("❌ [GroqService] HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            #endif
            SentrySDK.capture(message: "Groq API error: \(code)")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        let elapsed = Date().timeIntervalSince(startTime)
        FeedbackService.shared.addLog("Groq dailyInsight: \(String(format: "%.1f", elapsed))s")
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        logInsightLength(
            insightType: "daily",
            text: trimmedContent,
            targetMin: 120,
            targetMax: 180,
            language: lang,
            mode: modeTag(for: dailyGapKind)
        )
        return trimmedContent
    }

    // MARK: - Weekly Insight

    private func weeklyInsightSystemPrompt(personalContext: String = "", gapKind: CalorieGapKind = .deficit) -> String {
        let expertBase = buildNutritionExpertPrompt(
            language: appLanguage == "en" ? "English" : "Turkish",
            locale: userLocale,
            personalContext: personalContext
        )

        let modeHintEN: String = {
            switch gapKind {
            case .deficit:  return "User's goal is a weekly calorie DEFICIT (cutting). Best days = highest deficit days."
            case .surplus:  return "User's goal is a weekly calorie SURPLUS (bulking, gaining weight/muscle). Best days = highest SURPLUS days (eaten above TDEE). Never frame falling below TDEE as progress — that is the opposite of the goal. Never use the word 'deficit'."
            case .maintain: return "User's goal is MAINTENANCE (calorie balance). Best days = days closest to TDEE. Large swings in either direction are off-target. Don't frame deficit or surplus as progress."
            case .observe:  return "User is in OBSERVE mode (no weight goal, logging only). Do NOT use 'deficit', 'surplus', 'target', 'best/worst day'. Focus on patterns (consistent logging, nutritional variety, hydration). No judgment on calorie totals."
            }
        }()

        let modeHintTR: String = {
            switch gapKind {
            case .deficit:  return "Kullanıcının hedefi haftalık kalori AÇIĞI (kilo verme). En iyi günler = en yüksek açığın olduğu günler."
            case .surplus:  return "Kullanıcının hedefi haftalık kalori FAZLASI (kilo/kas alma). En iyi günler = TDEE'nin en çok ÜZERİNDE yenen günler. TDEE'nin altına düşmeyi ilerleme olarak SUNMA — hedefin tersi. 'Açık' kelimesini kullanma."
            case .maintain: return "Kullanıcının hedefi KORUMA (kalori dengesi). En iyi günler = TDEE'ye en yakın günler. Her iki yöndeki büyük sapmalar hedef dışıdır. Açık veya fazlayı ilerleme olarak sunma."
            case .observe:  return "Kullanıcı GÖZLEM modunda (kilo hedefi yok, sadece kayıt). 'Açık', 'fazla', 'hedef', 'en iyi/kötü gün' kullanma. Örüntülere odaklan (tutarlı kayıt, besin çeşitliliği, su). Kalori toplamı için yargı yapma."
            }
        }()

        if appLanguage == "en" {
            return """
            \(expertBase)

            LENGTH CONSTRAINT: Write 3-4 sentences in ONE paragraph, 200-300 characters total. Each sentence must be meaningful (12-20 words, no single-word sentences). No greetings, no bullet points, no headings. Always end with a complete sentence.

            You are also a personal fitness coach. Analyze the user's weekly stats with the day-by-day breakdown. Cover (compactly): best/worst day + why, comparison to previous week if data exists, one pattern (weekends vs weekdays), and ONE actionable tip for next week. Scientific but conversational. Emojis ok. Plain text, no lists.

            MODE: \(modeHintEN)
            """
        } else {
            return """
            \(expertBase)

            UZUNLUK KURALI: TEK paragrafta 3-4 cümle yaz, toplam 200-300 karakter. Her cümle anlamlı olmalı (10-18 kelime, tek kelimelik cümle yazma). Selamlaşma, madde işareti veya başlık yok. Her zaman tam cümleyle bitir.

            Aynı zamanda kişisel bir fitness koçusun. Kullanıcının haftalık istatistiklerini gün gün analiz et. Şunları kısaca kapsa: en iyi/kötü gün + neden, önceki haftayla karşılaştırma (veri varsa), bir örüntü (hafta içi vs hafta sonu) ve gelecek hafta için TEK somut öneri. Bilimsel ama sohbet dili. Emoji olabilir. Düz metin, liste yok.

            MOD: \(modeHintTR)
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
        targetDeficit: Int = 0,
        currentWeight: Double,
        goalWeight: Double,
        previousWeekAvgCalories: Int = 0,
        previousWeekTotalDeficit: Int = 0,
        previousWeekDaysWithData: Int = 0,
        coachStyle: CoachStyle = .supportive,
        personalContext: String = "",
        isObserveMode: Bool = false
    ) async throws -> String {
        let startTime = Date()
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE"
        dateFormatter.locale = Locale(identifier: lang == "en" ? "en_US" : "tr_TR")

        let dayBreakdown = stats.map { day in
            let dayName = dateFormatter.string(from: day.date)
            if day.hasData {
                return "\(dayName): \(day.consumedCalories) kcal, \(Int(day.protein))g protein, deficit \(day.deficit) kcal"
            } else {
                return "\(dayName): \(lang == "en" ? "no data" : "veri yok")"
            }
        }.joined(separator: "\n                ")

        var previousWeekLine = ""
        if previousWeekDaysWithData >= 3 {
            let prevEstKg = String(format: "%.2f", Double(previousWeekTotalDeficit) / 7700.0)
            if lang == "en" {
                previousWeekLine = """

                    Previous week comparison:
                    Previous week avg calories: \(previousWeekAvgCalories) kcal (this week: \(avgCalories) kcal)
                    Previous week total deficit: \(previousWeekTotalDeficit) kcal (this week: \(totalDeficit) kcal)
                    Previous week estimated change: \(prevEstKg) kg (this week: \(estimatedKg) kg)
                    Previous week days with data: \(previousWeekDaysWithData)/7
                    """
            } else {
                previousWeekLine = """

                    Önceki hafta karşılaştırması:
                    Önceki hafta ort. kalori: \(previousWeekAvgCalories) kcal (bu hafta: \(avgCalories) kcal)
                    Önceki hafta toplam açık: \(previousWeekTotalDeficit) kcal (bu hafta: \(totalDeficit) kcal)
                    Önceki hafta tahmini değişim: \(prevEstKg) kg (bu hafta: \(estimatedKg) kg)
                    Önceki hafta veri olan gün: \(previousWeekDaysWithData)/7
                    """
            }
        }

        let userPrompt: String
        if lang == "en" {
            userPrompt = """
                Weekly summary:
                Days with data: \(daysWithData)/7
                Average calories: \(avgCalories) kcal
                Average protein: \(Int(avgProtein))g
                Total deficit: \(totalDeficit) kcal (target: \(targetDeficit * 7) kcal/week)
                Estimated change: \(estimatedKg) kg
                Streak: \(streak) days on target
                Trend: \(trend.rawValue)
                Current weight: \(String(format: "%.1f", currentWeight)) kg
                Goal weight: \(String(format: "%.1f", goalWeight)) kg
                Activities: \(activitySummary)

                Day-by-day breakdown:
                \(dayBreakdown)
                \(previousWeekLine)
                Write a weekly assessment based on this data.
                """
        } else {
            userPrompt = """
                Haftalık özet:
                Veri olan gün sayısı: \(daysWithData)/7
                Ortalama kalori: \(avgCalories) kcal
                Ortalama protein: \(Int(avgProtein))g
                Toplam açık: \(totalDeficit) kcal (hedef: \(targetDeficit * 7) kcal/hafta)
                Tahmini değişim: \(estimatedKg) kg
                Seri: \(streak) gün hedefe ulaştı
                Trend: \(trend.rawValue)
                Mevcut kilo: \(String(format: "%.1f", currentWeight)) kg
                Hedef kilo: \(String(format: "%.1f", goalWeight)) kg
                Aktiviteler: \(activitySummary)

                Gün gün detay:
                \(dayBreakdown)
                \(previousWeekLine)
                Bu verilere göre haftalık değerlendirme yap.
                """
        }

        let quality = DataQualityService.weeklyQuality(
            stats: stats,
            appLanguage: lang
        )
        guard quality.shouldShowInsight else { return "" }

        let weeklyGapKind: CalorieGapKind = isObserveMode ? .observe : CalorieGapKind.from(signedTargetDeficit: targetDeficit)
        var systemPrompt = languageInstruction(for: lang) + "\n\n" + weeklyInsightSystemPrompt(personalContext: personalContext, gapKind: weeklyGapKind) + "\n\n" + coachPersonalityPrompt(for: coachStyle)
        if !quality.warningNote.isEmpty {
            systemPrompt = quality.warningNote + "\n\n" + systemPrompt
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.5,
            "max_tokens": 260
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            #if DEBUG
            print("❌ [GroqService] Network error: \(urlError.code.rawValue)")
            #endif
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            #if DEBUG
            print("❌ [GroqService] HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            #endif
            SentrySDK.capture(message: "Groq API error: \(code)")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        let elapsed = Date().timeIntervalSince(startTime)
        FeedbackService.shared.addLog("Groq weeklyInsight: \(String(format: "%.1f", elapsed))s")
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        logInsightLength(
            insightType: "weekly",
            text: trimmedContent,
            targetMin: 200,
            targetMax: 300,
            language: lang,
            mode: modeTag(for: weeklyGapKind)
        )
        return trimmedContent
    }
    // MARK: - Program Insight

    private func programModeHintEN(gapKind: CalorieGapKind) -> String {
        switch gapKind {
        case .deficit:  return "Program goal: weight loss (calorie deficit). Success = consistent deficit."
        case .surplus:  return "Program goal: weight/muscle gain (calorie surplus). Success = consistent surplus. Never frame deficit as success. Never use the word 'deficit'."
        case .maintain: return "Program goal: weight maintenance (calorie balance). Success = staying near TDEE. Don't frame deficit or surplus as success."
        case .observe:  return "User is in OBSERVE mode — no program goal, logging only. Do NOT use 'program', 'success', 'deficit', 'surplus', 'target'. Frame feedback around awareness, consistency of logging, and nutritional patterns."
        }
    }

    private func programModeHintTR(gapKind: CalorieGapKind) -> String {
        switch gapKind {
        case .deficit:  return "Program hedefi: kilo verme (kalori açığı). Başarı = istikrarlı açık."
        case .surplus:  return "Program hedefi: kilo/kas alma (kalori fazlası). Başarı = istikrarlı fazla. Açığı başarı olarak SUNMA. 'Açık' kelimesini kullanma."
        case .maintain: return "Program hedefi: kilo koruma (kalori dengesi). Başarı = TDEE'ye yakın kalmak. Açık veya fazlayı başarı olarak sunma."
        case .observe:  return "Kullanıcı GÖZLEM modunda — program hedefi yok, sadece kayıt. 'Program', 'başarı', 'açık', 'fazla', 'hedef' kullanma. Yorumu farkındalık, kayıt tutarlılığı ve beslenme örüntüleri üzerine kur."
        }
    }

    private func programOngoingSystemPrompt(personalContext: String = "", gapKind: CalorieGapKind = .deficit) -> String {
        let expertBase = buildNutritionExpertPrompt(
            language: appLanguage == "en" ? "English" : "Turkish",
            locale: userLocale,
            personalContext: personalContext
        )

        if appLanguage == "en" {
            return """
            \(expertBase)

            LENGTH CONSTRAINT: Write 3-4 sentences in ONE paragraph, 200-300 characters total. Each sentence must be meaningful (12-20 words, no single-word sentences). No greetings, no bullet points. Always end with a complete sentence.

            You are also a personal fitness coach. The user's program is IN PROGRESS. Analyze progress so far: are they on track, what's working, what to adjust for the rest of the program. Motivating but realistic. Add ONE actionable suggestion. Plain text, emojis ok, no lists.

            MODE: \(programModeHintEN(gapKind: gapKind))
            """
        } else {
            return """
            \(expertBase)

            UZUNLUK KURALI: TEK paragrafta 3-4 cümle yaz, toplam 200-300 karakter. Her cümle anlamlı olmalı (10-18 kelime, tek kelimelik cümle yazma). Selamlaşma, madde işareti yok. Her zaman tam cümleyle bitir.

            Aynı zamanda kişisel bir fitness koçusun. Kullanıcının programı DEVAM EDİYOR. Şu ana kadarki ilerlemeyi analiz et: yolunda mı, neler işliyor, programın kalan kısmı için ne ayarlamalı. Motive edici ama gerçekçi. TEK somut öneri ekle. Düz metin, emoji olabilir, liste yok.

            MOD: \(programModeHintTR(gapKind: gapKind))
            """
        }
    }

    private func programCompletedSystemPrompt(personalContext: String = "", gapKind: CalorieGapKind = .deficit) -> String {
        let expertBase = buildNutritionExpertPrompt(
            language: appLanguage == "en" ? "English" : "Turkish",
            locale: userLocale,
            personalContext: personalContext
        )

        if appLanguage == "en" {
            return """
            \(expertBase)

            LENGTH CONSTRAINT: Write 6-8 sentences in ONE paragraph, 400-550 characters total. Each sentence must be meaningful (10-18 words, no single-word sentences). No headings, no bullet points. Always end with a complete sentence.

            You are also a personal fitness coach. The user has COMPLETED their program — this is a milestone assessment. Cover: overall outcome vs. goal, what they did consistently well, what was hardest, one pattern that stood out, and ONE concrete next step (continue / maintenance / new goal). Celebratory but honest tone — acknowledge effort even if numbers fell short. Emojis ok, plain text, no lists.

            MODE: \(programModeHintEN(gapKind: gapKind))
            """
        } else {
            return """
            \(expertBase)

            UZUNLUK KURALI: TEK paragrafta 6-8 cümle yaz, toplam 400-550 karakter. Her cümle anlamlı olmalı (10-16 kelime, tek kelimelik cümle yazma). Başlık, madde işareti yok. Her zaman tam cümleyle bitir.

            Aynı zamanda kişisel bir fitness koçusun. Kullanıcı programı TAMAMLADI — bu bir kilometre taşı değerlendirmesi. Şunları kapsa: hedefe göre genel sonuç, istikrarlı yaptığı şey, en zoru neydi, öne çıkan bir örüntü ve TEK somut sonraki adım (devam / koruma / yeni hedef). Kutlayıcı ama dürüst ton — rakamlar tutmasa bile emeği takdir et. Emoji olabilir, düz metin, liste yok.

            MOD: \(programModeHintTR(gapKind: gapKind))
            """
        }
    }

    func generateProgramInsight(summary: ProgramSummary, isCompleted: Bool = false, coachStyle: CoachStyle = .supportive, personalContext: String = "") async throws -> String {
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else { throw GroqError.missingAPIKey }

        let lang = appLanguage

        let totalProgramDays = summary.totalDays + summary.daysRemaining
        let quality = DataQualityService.programQuality(
            completedDays: summary.daysWithData,
            totalDays: totalProgramDays,
            appLanguage: lang
        )
        guard quality.shouldShowInsight else {
            return lang == "en"
                ? "Log at least 10% of your program days to see insights."
                : "İçgörü görmek için programın en az %10'unu kaydet."
        }
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

        let programGapKind: CalorieGapKind
        switch summary.goalDirection {
        case .losing: programGapKind = .deficit
        case .gaining: programGapKind = .surplus
        case .maintenance: programGapKind = .maintain
        }
        let builtPrompt = isCompleted
            ? programCompletedSystemPrompt(personalContext: personalContext, gapKind: programGapKind)
            : programOngoingSystemPrompt(personalContext: personalContext, gapKind: programGapKind)
        var systemPrompt = languageInstruction(for: lang) + "\n\n" + builtPrompt + "\n\n" + coachPersonalityPrompt(for: coachStyle)
        if !quality.warningNote.isEmpty {
            systemPrompt = quality.warningNote + "\n\n" + systemPrompt
        }

        let maxTokens = isCompleted ? 450 : 260
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.5,
            "max_tokens": maxTokens
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            #if DEBUG
            print("❌ [GroqService] Network error: \(urlError.code.rawValue)")
            #endif
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            #if DEBUG
            print("❌ [GroqService] HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            #endif
            SentrySDK.capture(message: "Groq API error: \(code)")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetMin = isCompleted ? 400 : 200
        let targetMax = isCompleted ? 550 : 300
        logInsightLength(
            insightType: isCompleted ? "program_completed" : "program_ongoing",
            text: trimmedContent,
            targetMin: targetMin,
            targetMax: targetMax,
            language: lang,
            mode: modeTag(for: programGapKind)
        )
        return trimmedContent
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

            CRITICAL: Your response must be ONLY valid JSON.
            Do NOT write any text, explanation, or commentary before or after the JSON.
            Start your response directly with { and end with }
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

            KRİTİK: Yanıtın SADECE geçerli JSON olmalı.
            JSON öncesinde veya sonrasında HİÇBİR metin, açıklama veya yorum yazma.
            Yanıta doğrudan { ile başla ve } ile bitir.
            """
        }
    }

    // meta-llama/llama-4-scout-17b-16e-instruct supports vision (multimodal) on Groq
    func analyzeFood(imageData: Data) async throws -> PhotoAnalysisResponse {
        let startTime = Date()
        let apiKey = Config.groqAPIKey
        guard !apiKey.isEmpty else {
            #if DEBUG
            print("📷 [ERROR] Missing API key")
            #endif
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
                            "text": languageInstruction(for: appLanguage) + "\n\n" + photoAnalysisPrompt
                        ]
                    ]
                ]
            ],
            "temperature": 0.2,
            "max_tokens": 600
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            #if DEBUG
            print("❌ [GroqService] Network error: \(urlError.code.rawValue)")
            #endif
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            #if DEBUG
            print("❌ [GroqService] HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            #endif
            SentrySDK.capture(message: "Groq API error: \(code)")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            #if DEBUG
            print("📷 [ERROR] Empty response content")
            #endif
            throw GroqError.emptyResponse
        }

        let jsonString = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let extractedJSON = extractJSON(cleanGroqJSON(jsonString))

        guard let jsonData = extractedJSON.data(using: .utf8) else {
            #if DEBUG
            print("📷 [ERROR] Could not convert JSON string to data")
            #endif
            throw GroqError.invalidJSON
        }

        do {
            let result = try JSONDecoder().decode(PhotoAnalysisResponse.self, from: jsonData)
            let elapsed = Date().timeIntervalSince(startTime)
            FeedbackService.shared.addLog("Groq analyzePhoto: \(String(format: "%.1f", elapsed))s")
            return result
        } catch {
            SentrySDK.capture(error: error)
            #if DEBUG
            print("📷 [ERROR] JSON decode failed: \(error) — raw: \(extractedJSON)")
            #endif
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
            #if DEBUG
            print("📷 [ERROR] Missing API key")
            #endif
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
            \(languageInstruction(for: appLanguage))
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
        request.timeoutInterval = 25
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            #if DEBUG
            print("❌ [GroqService] Network error: \(urlError.code.rawValue)")
            #endif
            throw urlError.code == .timedOut ? GroqError.timeout : GroqError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            #if DEBUG
            print("❌ [GroqService] HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            #endif
            SentrySDK.capture(message: "Groq API error: \(code)")
            throw GroqError.apiError(statusCode: code)
        }

        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            #if DEBUG
            print("📷 [ERROR] Empty clarification response")
            #endif
            throw GroqError.emptyResponse
        }

        let jsonString = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let extractedJSON = extractJSON(cleanGroqJSON(jsonString))

        guard let jsonData = extractedJSON.data(using: .utf8) else {
            #if DEBUG
            print("📷 [ERROR] Could not convert JSON to data")
            #endif
            throw GroqError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(PhotoAnalysisResponse.self, from: jsonData)
        } catch {
            SentrySDK.capture(error: error)
            #if DEBUG
            print("📷 [ERROR] JSON decode failed: \(error) — raw: \(extractedJSON)")
            #endif
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
        let lang = UserDefaults(suiteName: "group.indio.VoiceMeal")?
            .string(forKey: "appLanguage")
            ?? UserDefaults.standard.string(forKey: "appLanguage")
            ?? "tr"
        let isEN = lang == "en"
        switch self {
        case .missingAPIKey:
            return isEN ? "API key missing." : "API anahtarı bulunamadı"
        case .apiError(let code):
            switch code {
            case 401: return isEN ? "Invalid API key." : "API anahtarı geçersiz."
            case 429: return isEN ? "Too many requests. Please wait." : "Çok fazla istek. Biraz bekleyin."
            case 500...599: return isEN ? "Groq server is busy. Try again." : "Groq sunucusu meşgul. Tekrar deneyin."
            default: return isEN ? "Groq API error (HTTP \(code))." : "Groq API hatası (HTTP \(code))"
            }
        case .emptyResponse:
            return isEN ? "Empty response from server." : "Boş yanıt alındı"
        case .invalidJSON:
            return isEN ? "Could not process response. Try again." : "Yanıt işlenemedi. Tekrar deneyin."
        case .networkError:
            return isEN ? "No internet connection." : "İnternet bağlantısı yok."
        case .timeout:
            return isEN ? "Request timed out." : "Bağlantı zaman aşımına uğradı."
        }
    }
}
