//
//  HealthKitService.swift
//  VoiceMeal
//

import Foundation
import HealthKit

@Observable
class HealthKitService {
    var todayTotalBurn: Double = 0
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

        let types: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
        ]

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
