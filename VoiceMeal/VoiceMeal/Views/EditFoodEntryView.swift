//
//  EditFoodEntryView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct EditFoodEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let entry: FoodEntry
    var onSave: (() -> Void)?

    @State private var name: String
    @State private var amount: String
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String

    init(entry: FoodEntry, onSave: (() -> Void)? = nil) {
        self.entry = entry
        self.onSave = onSave
        _name = State(initialValue: entry.name)
        _amount = State(initialValue: entry.amount)
        _caloriesText = State(initialValue: "\(entry.calories)")
        _proteinText = State(initialValue: String(format: "%.1f", entry.protein))
        _carbsText = State(initialValue: String(format: "%.1f", entry.carbs))
        _fatText = State(initialValue: String(format: "%.1f", entry.fat))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Yemek") {
                    TextField("\u{0130}sim", text: $name)
                    TextField("Porsiyon", text: $amount)
                }

                Section("Besin De\u{011F}erleri") {
                    HStack {
                        Text("Kalori")
                        Spacer()
                        TextField("kcal", text: $caloriesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("g", text: $proteinText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Karb (g)")
                        Spacer()
                        TextField("g", text: $carbsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Ya\u{011F} (g)")
                        Spacer()
                        TextField("g", text: $fatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            .navigationTitle("Kayd\u{0131} D\u{00FC}zenle")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("\u{0130}ptal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        entry.name = name
        entry.amount = amount
        entry.calories = Int(caloriesText) ?? entry.calories
        entry.protein = Double(proteinText) ?? entry.protein
        entry.carbs = Double(carbsText) ?? entry.carbs
        entry.fat = Double(fatText) ?? entry.fat
        try? modelContext.save()
        onSave?()
        dismiss()
    }
}
