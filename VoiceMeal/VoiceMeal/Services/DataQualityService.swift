//
//  DataQualityService.swift
//  VoiceMeal
//

import Foundation

enum DataQualityLevel {
    case noData
    case tooEarly
    case likelyIncomplete
    case plausible
    case complete
}

struct DataQuality {
    let level: DataQualityLevel
    let warningNote: String
    let shouldShowInsight: Bool
}

enum DataQualityService {

    static func dailyQuality(
        consumed: Int,
        target: Int,
        appLanguage: String
    ) -> DataQuality {
        guard target > 0 else {
            return DataQuality(
                level: .noData,
                warningNote: appLanguage == "en"
                    ? "⚠️ No calorie target set."
                    : "⚠️ Kalori hedefi belirlenmemiş.",
                shouldShowInsight: false
            )
        }

        let ratio = Double(consumed) / Double(target)

        switch ratio {
        case 0:
            return DataQuality(
                level: .noData,
                warningNote: appLanguage == "en"
                    ? """
                      ⚠️ DATA QUALITY: User has logged 0 calories today.
                      They may not have logged yet, or it's early in the day.
                      Do NOT assume they ate nothing.
                      Encourage logging. Don't analyze nutrition.
                      """
                    : """
                      ⚠️ VERİ KALİTESİ: Kullanıcı bugün 0 kalori girmiş.
                      Henüz girmemiş olabilir ya da günün başı olabilir.
                      Hiç yemedi diye YORUMLAMA.
                      Kayıt yapmayı teşvik et. Beslenme analizi yapma.
                      """,
                shouldShowInsight: true
            )

        case ..<0.6:
            return DataQuality(
                level: .likelyIncomplete,
                warningNote: appLanguage == "en"
                    ? """
                      ⚠️ DATA QUALITY: User logged \(consumed) kcal \
                      but target is \(target) kcal (\(Int(ratio * 100))% of target).
                      Data may be INCOMPLETE — user may have eaten more \
                      but not logged everything yet.
                      Add a note like "if this is your complete intake..."
                      Do NOT say they definitely ate too little.
                      """
                    : """
                      ⚠️ VERİ KALİTESİ: Kullanıcı \(consumed) kcal girmiş, \
                      hedef \(target) kcal (hedefin %\(Int(ratio * 100))'i).
                      Veri EKSİK olabilir — tüm öğünleri girmemiş olabilir.
                      "Eğer bu günün tüm kaydıysa..." gibi ifadeler kullan.
                      Kesinlikle az yedi diye YORUMLAMA.
                      """,
                shouldShowInsight: true
            )

        default:
            return DataQuality(
                level: .complete,
                warningNote: "",
                shouldShowInsight: true
            )
        }
    }

    static func weeklyQuality(
        stats: [DayStat],
        appLanguage: String
    ) -> DataQuality {
        let daysWithData = stats.filter { $0.hasData }
        let plausibleDays = daysWithData.filter { stat in
            guard stat.targetCalories > 0 else { return false }
            let ratio = Double(stat.consumedCalories) / Double(stat.targetCalories)
            return ratio >= 0.6
        }

        let plausibleRatio = daysWithData.isEmpty ? 0.0 :
            Double(plausibleDays.count) / Double(daysWithData.count)

        if daysWithData.count < 3 {
            return DataQuality(
                level: .tooEarly,
                warningNote: "",
                shouldShowInsight: false
            )
        }

        if plausibleRatio < 0.5 {
            let note = appLanguage == "en"
                ? """
                  ⚠️ DATA QUALITY: Only \(plausibleDays.count)/\(daysWithData.count) \
                  days have plausible calorie data (≥60% of target logged).
                  Many days may have incomplete logging.
                  Avoid conclusions about calorie intake being "low".
                  Focus on consistency and encourage complete logging.
                  """
                : """
                  ⚠️ VERİ KALİTESİ: \(daysWithData.count) günden sadece \
                  \(plausibleDays.count) günde makul kalori verisi var.
                  Birçok günde eksik kayıt olabilir.
                  "Kalori alımı düşük" gibi sonuç çıkarma.
                  Tutarlılığa odaklan ve düzenli kayıt teşvik et.
                  """
            return DataQuality(
                level: .likelyIncomplete,
                warningNote: note,
                shouldShowInsight: true
            )
        }

        return DataQuality(
            level: .complete,
            warningNote: "",
            shouldShowInsight: true
        )
    }

    static func programQuality(
        completedDays: Int,
        totalDays: Int,
        appLanguage: String
    ) -> DataQuality {
        guard totalDays > 0 else {
            return DataQuality(
                level: .noData,
                warningNote: "",
                shouldShowInsight: false
            )
        }

        let progress = Double(completedDays) / Double(totalDays)

        if progress < 0.10 {
            return DataQuality(
                level: .tooEarly,
                warningNote: "",
                shouldShowInsight: false
            )
        }

        let progressPct = Int(progress * 100)

        let earlyNote: String
        if progress < 0.30 {
            earlyNote = appLanguage == "en"
                ? """
                  ℹ️ EARLY STAGE: Program is \(progressPct)% complete \
                  (\(completedDays)/\(totalDays) days).
                  This is early data — trends may change.
                  Be encouraging, note it's still early.
                  """
                : """
                  ℹ️ ERKEN DÖNEM: Program %\(progressPct) tamamlandı \
                  (\(completedDays)/\(totalDays) gün).
                  Henüz erken — eğilimler değişebilir.
                  Teşvik edici ol, henüz erken olduğunu belirt.
                  """
        } else {
            earlyNote = ""
        }

        return DataQuality(
            level: progress < 0.3 ? .likelyIncomplete : .complete,
            warningNote: earlyNote,
            shouldShowInsight: true
        )
    }
}
