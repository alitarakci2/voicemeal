//
//  HealthKitService.swift
//  VoiceMeal
//

import Foundation
import HealthKit

@Observable
class HealthKitService {
    var todayTotalBurn: Double = 0
    var todayExtrapolatedBurn: Double = 0
    var latestVO2Max: Double?
    var latestWeight: Double?
    var latestWeightDate: Date?
    var dayFraction: Double = 0
    var isExtrapolated: Bool = false
    var permissionGranted = false

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
        ]
        if HKQuantityType.quantityType(forIdentifier: .leanBodyMass) != nil {
            types.insert(HKQuantityType(.leanBodyMass))
        }

        do {
            try await store.requestAuthorization(toShare: [], read: types)
            permissionGranted = true
            return true
        } catch {
            print("[HealthKit] Permission error: \(error)")
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

    func fetchTodayBurnExtrapolated(bmr: Double) async -> Double {
        let rawBurn = await fetchTodayTotalBurn()

        let now = Date.now
        let startOfDay = Calendar.current.startOfDay(for: now)
        let secondsElapsed = now.timeIntervalSince(startOfDay)
        let fraction = secondsElapsed / 86400.0
        dayFraction = fraction

        guard fraction > 0.25 && rawBurn > 0 else {
            isExtrapolated = false
            todayExtrapolatedBurn = 0
            return 0
        }

        let extrapolated = rawBurn / fraction
        let capped = min(extrapolated, bmr * 2.5)
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
                    print("[HealthKit] VO2Max query error: \(error)")
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
                    print("[HealthKit] Weight query error: \(error)")
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

    private func fetchSum(store: HKHealthStore, type: HKQuantityType, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    print("[HealthKit] Query error for \(type.identifier): \(error)")
                }
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
