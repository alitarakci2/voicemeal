//
//  HealthKitService.swift
//  VoiceMeal
//

import Foundation
import HealthKit

enum SleepQuality: String {
    case excellent = "M\u{00FC}kemmel"
    case good = "\u{0130}yi"
    case fair = "Orta"
    case poor = "K\u{00F6}t\u{00FC}"

    var localized: String {
        switch self {
        case .excellent: return "quality_excellent".localized
        case .good: return "quality_good".localized
        case .fair: return "quality_fair".localized
        case .poor: return "quality_poor".localized
        }
    }
}

struct SleepData {
    let totalMinutes: Int
    let deepSleepMinutes: Int
    let efficiency: Double
    let quality: SleepQuality
}

enum HRVStatus: String {
    case excellent = "M\u{00FC}kemmel"
    case normal = "Normal"
    case tired = "Yorgun"
    case veryTired = "\u{00C7}ok Yorgun"
    case noData = "Veri Yok"

    var localized: String {
        switch self {
        case .excellent: return "hrv_excellent".localized
        case .normal: return "hrv_normal".localized
        case .tired: return "hrv_tired".localized
        case .veryTired: return "hrv_very_tired".localized
        case .noData: return "hrv_no_data".localized
        }
    }
}

@Observable
class HealthKitService {
    var todayTotalBurn: Double = 0
    var todayExtrapolatedBurn: Double = 0
    var latestVO2Max: Double?
    var latestWeight: Double?
    var latestWeightDate: Date?
    var lastNightSleep: SleepData?
    var todayHRV: Double?
    var hrvBaseline: Double?
    var dayFraction: Double = 0
    var isExtrapolated: Bool = false
    var permissionGranted = false

    var hrvStatus: HRVStatus {
        guard let today = todayHRV, let baseline = hrvBaseline, baseline > 0 else {
            return .noData
        }
        let ratio = today / baseline
        switch ratio {
        case 1.10...: return .excellent
        case 0.90...: return .normal
        case 0.80...: return .tired
        default: return .veryTired
        }
    }

    private var store: HKHealthStore?

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    init() {
        if HKHealthStore.isHealthDataAvailable() {
            store = HKHealthStore()
        }
    }

    func requestPermission() async -> Bool {
        guard let store else {
            permissionGranted = false
            return false
        }

        var types: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.vo2Max),
            HKQuantityType(.bodyMass),
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.heartRateVariabilitySDNN),
        ]
        if HKQuantityType.quantityType(forIdentifier: .leanBodyMass) != nil {
            types.insert(HKQuantityType(.leanBodyMass))
        }

        do {
            try await store.requestAuthorization(toShare: [], read: types)
            permissionGranted = true
            return true
        } catch {

            permissionGranted = false
            return false
        }
    }

    func fetchTodayTotalBurn() async -> Double {
        guard let store else { return 0 }

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now, options: .strictStartDate)

        async let active = fetchSum(store: store, type: HKQuantityType(.activeEnergyBurned), predicate: predicate)
        async let basal = fetchSum(store: store, type: HKQuantityType(.basalEnergyBurned), predicate: predicate)

        let total = await active + basal
        todayTotalBurn = total
        return total
    }

    func fetchTodayActiveEnergy() async -> Double {
        guard let store else { return 0 }
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now, options: .strictStartDate)
        return await fetchSum(store: store, type: HKQuantityType(.activeEnergyBurned), predicate: predicate)
    }

    func fetchTodayBurnExtrapolated(bmr: Double, calculatedTDEE: Double) async -> Double {
        let rawBurn = await fetchTodayTotalBurn()

        let now = Date.now
        let startOfDay = Calendar.current.startOfDay(for: now)
        let secondsElapsed = now.timeIntervalSince(startOfDay)
        let fraction = secondsElapsed / 86400.0
        dayFraction = fraction

        guard fraction >= 0.40 && rawBurn > 0 else {
            isExtrapolated = false
            todayExtrapolatedBurn = 0
            return 0
        }

        let extrapolated = rawBurn / fraction
        let capped = min(extrapolated, bmr * 2.5)

        // If extrapolated is too far below formula TDEE, don't trust it
        guard capped >= calculatedTDEE * 0.85 else {
            isExtrapolated = false
            todayExtrapolatedBurn = 0
            return 0
        }

        isExtrapolated = true
        todayExtrapolatedBurn = capped
        return capped
    }

    func fetchLatestVO2Max() async -> Double? {
        guard let store else { return nil }

        let type = HKQuantityType(.vo2Max)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let result: Double? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    // VO2Max query error
                }
                let value = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit(from: "ml/kg*min"))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }

        latestVO2Max = result
        return result
    }

    func fetchLatestWeight() async -> Double? {
        guard let store else { return nil }

        let type = HKQuantityType(.bodyMass)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let result: (weight: Double, date: Date)? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    // Weight query error
                }
                if let sample = samples?.first as? HKQuantitySample {
                    let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    continuation.resume(returning: (kg, sample.startDate))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            store.execute(query)
        }

        latestWeight = result?.weight
        latestWeightDate = result?.date
        return result?.weight
    }

    func fetchLastNightSleep() async -> SleepData? {
        guard let store else { return nil }

        let type = HKCategoryType(.sleepAnalysis)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Last night = yesterday 18:00 to today 12:00
        let calendar = Calendar.current
        let now = Date()
        let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        let yesterdayEvening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now)!)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterdayEvening, end: todayNoon, options: .strictStartDate)

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, results, error in
                if let error {
                    // Sleep query error
                }
                let categorySamples = (results as? [HKCategorySample]) ?? []
                continuation.resume(returning: categorySamples)
            }
            store.execute(query)
        }

        guard !samples.isEmpty else {
            lastNightSleep = nil
            return nil
        }

        var totalSeconds: TimeInterval = 0
        var deepSeconds: TimeInterval = 0

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)

            switch value {
            case .asleepDeep, .asleepREM:
                deepSeconds += duration
                totalSeconds += duration
            case .asleepCore, .asleepUnspecified, .awake:
                totalSeconds += duration
            default:
                totalSeconds += duration
            }
        }

        var totalMinutes = Int(totalSeconds / 60)
        let deepMinutes = Int(deepSeconds / 60)

        // Sanity cap: prevent multi-day accumulation errors
        if totalMinutes > 600 {
            // Unusual sleep duration, capping at 10h
            totalMinutes = 600
        }
        let efficiency = totalSeconds > 0 ? deepSeconds / totalSeconds : 0
        let totalHours = totalSeconds / 3600

        let quality: SleepQuality
        if totalHours >= 7.5 && efficiency >= 0.20 {
            quality = .excellent
        } else if totalHours >= 6.5 {
            quality = .good
        } else if totalHours >= 5.5 {
            quality = .fair
        } else {
            quality = .poor
        }

        let data = SleepData(
            totalMinutes: totalMinutes,
            deepSleepMinutes: deepMinutes,
            efficiency: efficiency,
            quality: quality
        )
        lastNightSleep = data
        return data
    }

    func fetchTodayHRV() async -> Double? {
        guard let store else { return nil }

        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: .now, options: .strictStartDate)

        let result: Double? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    // HRV query error
                }
                let value = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }

        todayHRV = result
        return result
    }

    func fetchHRVBaseline() async -> Double? {
        guard let store else { return nil }

        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: .now, options: .strictStartDate)

        let values: [Double] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    // HRV baseline query error
                }
                let vals = (samples as? [HKQuantitySample])?.map {
                    $0.quantity.doubleValue(for: .secondUnit(with: .milli))
                } ?? []
                continuation.resume(returning: vals)
            }
            store.execute(query)
        }

        guard values.count >= 3 else {
            hrvBaseline = nil
            return nil
        }

        let avg = values.reduce(0, +) / Double(values.count)
        hrvBaseline = avg
        return avg
    }

    private func fetchSum(store: HKHealthStore, type: HKQuantityType, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    // Query error
                }
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
