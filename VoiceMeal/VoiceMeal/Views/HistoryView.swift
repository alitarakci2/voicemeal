//
//  HistoryView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    private var dailyLogs: [DailyLog] {
        DailyLog.groupByDay(allEntries)
    }

    var body: some View {
        NavigationStack {
            Group {
                if dailyLogs.isEmpty {
                    ContentUnavailableView("Henüz kayıt yok", systemImage: "tray")
                } else {
                    List(dailyLogs) { log in
                        NavigationLink {
                            DayDetailView(log: log)
                        } label: {
                            HStack {
                                Text(log.date, format: .dateTime.day().month(.wide).year())
                                Spacer()
                                Text("\(log.totalCalories) kcal")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Geçmiş")
        }
    }
}

struct DayDetailView: View {
    let log: DailyLog

    var body: some View {
        List {
            Section {
                ForEach(log.entries, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(entry.calories) kcal")
                                .foregroundStyle(.secondary)
                        }
                        Text("P: \(Int(entry.protein))g  K: \(Int(entry.carbs))g  Y: \(Int(entry.fat))g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Text("Toplam")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(log.totalCalories) kcal")
                        .fontWeight(.semibold)
                }
                Text("Protein: \(Int(log.totalProtein))g | Karb: \(Int(log.totalCarbs))g | Yağ: \(Int(log.totalFat))g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(log.date.formatted(.dateTime.day().month(.wide).year()))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
