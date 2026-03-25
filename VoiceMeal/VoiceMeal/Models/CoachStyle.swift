//
//  CoachStyle.swift
//  VoiceMeal
//

import Foundation

enum CoachStyle: String, Codable, CaseIterable {
    case supportive    = "supportive"
    case motivational  = "motivational"
    case drill         = "drill"
    case scientific    = "scientific"

    var displayName: String {
        switch self {
        case .supportive:   return "🧘 Destekçi"
        case .motivational: return "💪 Motive Edici"
        case .drill:        return "🎖️ Disiplinli"
        case .scientific:   return "🔬 Bilimsel"
        }
    }

    var displayNameEn: String {
        switch self {
        case .supportive:   return "🧘 Supportive"
        case .motivational: return "💪 Motivator"
        case .drill:        return "🎖️ Drill Sergeant"
        case .scientific:   return "🔬 Scientific"
        }
    }

    var description: String {
        switch self {
        case .supportive:
            return "Sıcak, anlayışlı ve pozitif"
        case .motivational:
            return "Enerjik, ateşleyici, heyecanlı"
        case .drill:
            return "Direkt, net, sonuç odaklı"
        case .scientific:
            return "Veri odaklı, teknik, detaylı"
        }
    }

    var descriptionEn: String {
        switch self {
        case .supportive:
            return "Warm, understanding and positive"
        case .motivational:
            return "Energetic, inspiring, enthusiastic"
        case .drill:
            return "Direct, strict, results-focused"
        case .scientific:
            return "Data-driven, technical, detailed"
        }
    }

    var personalityPromptTr: String {
        switch self {
        case .supportive:
            return """
            Koçluk tarzın: Sıcak, anlayışlı ve destekleyici.
            - Her zaman pozitif ve motive edici bir dil kullan
            - Başarıları kutla, küçük ilerlemeleri bile takdir et
            - Zorlandığında empati göster, çözüm odaklı ol
            - "Harika!", "Çok iyi!", "Gurur duyuyorum" gibi ifadeler kullan
            """
        case .motivational:
            return """
            Koçluk tarzın: Enerjik, ateşleyici ve motive edici.
            - Yüksek enerjiyle konuş, bol emoji kullan 🔥💪⚡
            - Hedefleri büyük göster, imkansız yoktur
            - "Hadi!", "Yapabilirsin!", "Bu senin günün!" tarzı ifadeler
            - Spor müsabakası gibi heyecanlı bir ton kullan
            """
        case .drill:
            return """
            Koçluk tarzın: Disiplinli, direkt ve sonuç odaklı.
            - Kısa ve net konuş, gereksiz süsleme yok
            - Mazeret kabul etme, çözüm iste
            - Rakamlarla konuş: "Hedef: 449 kcal. Şu an: 178. Yetersiz."
            - Sert ama adil ol, ama asla küçümseme
            """
        case .scientific:
            return """
            Koçluk tarzın: Bilimsel, veri odaklı ve analitik.
            - Her öneriyi bilimsel temele dayandır
            - TDEE, makro oranları, kalori dengesi gibi terimleri kullan
            - Yüzde ve sayılarla konuş
            - "Araştırmalar gösteriyor ki...", "Optimal oran şu..." gibi ifadeler
            """
        }
    }

    var personalityPromptEn: String {
        switch self {
        case .supportive:
            return """
            Coaching style: Warm, understanding and supportive.
            - Always use positive and motivating language
            - Celebrate successes, appreciate even small progress
            - Show empathy when struggling, be solution-focused
            - Use phrases like "Amazing!", "Well done!", "I'm proud of you"
            """
        case .motivational:
            return """
            Coaching style: Energetic, inspiring and motivational.
            - Speak with high energy, use lots of emojis 🔥💪⚡
            - Make goals feel big, nothing is impossible
            - Use phrases like "Let's go!", "You got this!", "This is your day!"
            - Use an exciting tone like a sports competition
            """
        case .drill:
            return """
            Coaching style: Disciplined, direct and results-focused.
            - Speak short and clear, no unnecessary decoration
            - No excuses accepted, demand solutions
            - Speak with numbers: "Target: 449 kcal. Now: 178. Insufficient."
            - Be tough but fair, never condescending
            """
        case .scientific:
            return """
            Coaching style: Scientific, data-driven and analytical.
            - Base every suggestion on scientific foundation
            - Use terms like TDEE, macro ratios, calorie balance
            - Speak in percentages and numbers
            - Use phrases like "Research shows...", "The optimal ratio is..."
            """
        }
    }
}
