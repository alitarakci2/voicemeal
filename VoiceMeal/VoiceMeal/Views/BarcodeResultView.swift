//
//  BarcodeResultView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct BarcodeResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var phase: Phase = .scanning
    @State private var scannedCode = ""
    @State private var product: FoodProduct?
    @State private var selectedAmount: Double = 100
    @State private var errorMessage: String?
    @State private var showSavedToast = false

    private let barcodeService = BarcodeService()

    private enum Phase {
        case scanning, loading, found, notFound
    }

    // MARK: - Portion parsing

    private var quantityValue: Double {
        guard let q = product?.quantity else { return 100 }
        return parseNumericValue(from: q)
    }

    private var quantityUnit: String {
        guard let q = product?.quantity else { return "g" }
        let lower = q.lowercased()
        if lower.contains("ml") || lower.contains("litre") || lower.contains("l") { return "ml" }
        return "g"
    }

    private var servingSizeValue: Double? {
        guard let s = product?.servingSize else { return nil }
        let val = parseNumericValue(from: s)
        return val > 0 ? val : nil
    }

    private var sliderMax: Double {
        max(quantityValue, 50)
    }

    private var calculatedCalories: Int {
        guard let cal = product?.caloriesPer100g else { return 0 }
        return Int(Double(cal) * selectedAmount / 100.0)
    }

    private var calculatedProtein: Double {
        (product?.proteinPer100g ?? 0) * selectedAmount / 100.0
    }

    private var calculatedCarbs: Double {
        (product?.carbsPer100g ?? 0) * selectedAmount / 100.0
    }

    private var calculatedFat: Double {
        (product?.fatPer100g ?? 0) * selectedAmount / 100.0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                switch phase {
                case .scanning:
                    BarcodeScannerView { code in
                        scannedCode = code
                        phase = .loading
                        Task { await lookupProduct(code) }
                    }
                    .ignoresSafeArea()

                case .loading:
                    loadingView

                case .found:
                    if let product {
                        foundView(product)
                    }

                case .notFound:
                    notFoundView
                }

                if showSavedToast {
                    VStack {
                        Spacer()
                        Text("Kaydedildi \u{2713}")
                            .font(Theme.headlineFont)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.green)
                            .clipShape(Capsule())
                            .padding(.bottom, 40)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("\u{0130}ptal") { dismiss() }
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Text("Barkod: \(scannedCode)")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                ProgressView()
                Text("\u{00DC}r\u{00FC}n aran\u{0131}yor...")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .themeCard()
        .padding()
    }

    // MARK: - Found

    private func foundView(_ product: FoodProduct) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Product info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\u{2705} \u{00DC}r\u{00FC}n Bulundu")
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.green)
                        Spacer()
                    }

                    Text(product.name)
                        .font(Theme.titleFont)
                        .foregroundStyle(Theme.textPrimary)

                    if let brands = product.brands, !brands.isEmpty {
                        Text("Marka: \(brands)")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    if let quantity = product.quantity, !quantity.isEmpty {
                        Text("Paket: \(quantity)")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding()
                .themeCard()

                // Nutrition per 100g
                if product.caloriesPer100g != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("100\(quantityUnit) ba\u{015F}\u{0131}na:")
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textPrimary)

                        HStack(spacing: 16) {
                            nutrientLabel("\(product.caloriesPer100g ?? 0) kcal", color: Theme.accent)
                            nutrientLabel("P: \(Int(product.proteinPer100g ?? 0))g", color: Theme.blue)
                            nutrientLabel("K: \(Int(product.carbsPer100g ?? 0))g", color: Theme.orange)
                            nutrientLabel("Y: \(Int(product.fatPer100g ?? 0))g", color: Theme.red)
                        }
                    }
                    .padding()
                    .themeCard()
                }

                // Portion calculator
                VStack(alignment: .leading, spacing: 12) {
                    Text("Porsiyon Hesapla")
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.textPrimary)

                    Text("Ne kadar yediniz?")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)

                    HStack {
                        Slider(value: $selectedAmount, in: 10...sliderMax, step: 5)
                            .tint(Theme.accent)
                        Text("\(Int(selectedAmount))\(quantityUnit)")
                            .font(Theme.bodyFont)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 70, alignment: .trailing)
                    }

                    HStack(spacing: 12) {
                        Text("\(Int(selectedAmount))\(quantityUnit)")
                            .fontWeight(.bold)
                        Text("\u{2192}")
                        Text("\(calculatedCalories) kcal")
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.accent)
                        Text("P:\(Int(calculatedProtein))g")
                            .foregroundStyle(Theme.blue)
                        Text("K:\(Int(calculatedCarbs))g")
                            .foregroundStyle(Theme.orange)
                        Text("Y:\(Int(calculatedFat))g")
                            .foregroundStyle(Theme.red)
                    }
                    .font(Theme.captionFont)
                }
                .padding()
                .themeCard()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        saveEntry(product)
                    } label: {
                        Text("Kaydet")
                            .font(Theme.headlineFont)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        resetScanner()
                    } label: {
                        Text("Tekrar Tara")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 20)
            }
            .padding()
        }
    }

    // MARK: - Not Found

    private var notFoundView: some View {
        VStack(spacing: 20) {
            Text("\u{2753} \u{00DC}r\u{00FC}n Bulunamad\u{0131}")
                .font(Theme.titleFont)
                .foregroundStyle(Theme.textPrimary)

            Text("Bu barkod veritaban\u{0131}nda yok.")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)

            if let error = errorMessage {
                Text(error)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.red)
            }

            VStack(spacing: 12) {
                Button {
                    resetScanner()
                } label: {
                    Text("Tekrar Dene")
                        .font(Theme.headlineFont)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Sesle Anlat")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }

    // MARK: - Helpers

    private func nutrientLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.captionFont)
            .fontWeight(.medium)
            .foregroundStyle(color)
    }

    private func lookupProduct(_ barcode: String) async {
        do {
            if let found = try await barcodeService.fetchProduct(barcode: barcode) {
                product = found
                selectedAmount = servingSizeValue
                    ?? (quantityValue > 0 ? quantityValue / 2 : 100)
                phase = .found
            } else {
                phase = .notFound
            }
        } catch {
            errorMessage = "Ba\u{011F}lant\u{0131} hatas\u{0131}: \(error.localizedDescription)"
            phase = .notFound
        }
    }

    private func saveEntry(_ product: FoodProduct) {
        var name = product.name
        if let brands = product.brands, !brands.isEmpty {
            name = "\(product.name) (\(brands))"
        }

        let entry = FoodEntry(
            name: name,
            amount: "\(Int(selectedAmount))\(quantityUnit)",
            calories: calculatedCalories,
            protein: calculatedProtein,
            carbs: calculatedCarbs,
            fat: calculatedFat
        )
        modelContext.insert(entry)
        try? modelContext.save()

        withAnimation {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }

    private func resetScanner() {
        phase = .scanning
        scannedCode = ""
        product = nil
        errorMessage = nil
        selectedAmount = 100
    }

    private func parseNumericValue(from text: String) -> Double {
        let digits = text.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted).joined()
        let normalized = digits.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 100
    }
}
