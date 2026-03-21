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
    @State private var voiceConfirmation: String?
    @State private var customAmountText = ""

    @StateObject private var speechService = SpeechService()

    private let barcodeService = BarcodeService()

    private enum Phase {
        case scanning, loading, found, notFound
    }

    // MARK: - Quantity parsing

    private var detectedQuantity: (amount: Double, unit: String, isDefault: Bool) {
        guard let product else { return (100, "g", true) }

        // 1. Try quantity field
        if let q = product.quantity, !q.isEmpty {
            let parsed = parseQuantity(q)
            return (parsed.amount, parsed.unit, false)
        }

        // 2. Try serving_size field
        if let s = product.servingSize, !s.isEmpty {
            let parsed = parseQuantity(s)
            return (parsed.amount, parsed.unit, false)
        }

        // 3. Detect from product name / brands keywords
        let combined = (product.name + " " + (product.brands ?? "")).lowercased()
        let liquidKeywords = [
            "s\u{00FC}t", "milk", "juice", "meyve suyu", "su ",
            "ayran", "kefir", "i\u{00E7}ecek", "drink", "soda",
            "limonata", "protein s\u{00FC}t", "\u{015F}i\u{015F}e",
        ]
        for keyword in liquidKeywords {
            if combined.contains(keyword) {
                return (500, "ml", true)
            }
        }

        // 4. Default: solid food
        return (100, "g", true)
    }

    private var maxAmount: Double {
        max(detectedQuantity.amount, 50)
    }

    private var unit: String {
        detectedQuantity.unit
    }

    private var quantityIsDefault: Bool {
        detectedQuantity.isDefault
    }

    private var sliderStep: Double {
        unit == "ml" ? 10 : 5
    }

    private var servingSizeValue: Double? {
        guard let s = product?.servingSize else { return nil }
        let val = parseQuantity(s).amount
        return val > 0 ? val : nil
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
                        Text("saved_confirmation".localized)
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
                    Button(L.cancel.localized) {
                        if speechService.isRecording { speechService.stopListening() }
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Text("\("barcode_label".localized): \(scannedCode)")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                ProgressView()
                Text("product_searching".localized)
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
                        Text("\u{2705} \("product_found".localized)")
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.green)
                        Spacer()
                    }

                    Text(product.name)
                        .font(Theme.titleFont)
                        .foregroundStyle(Theme.textPrimary)

                    if let brands = product.brands, !brands.isEmpty {
                        Text("\("brand".localized): \(brands)")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    if let quantity = product.quantity, !quantity.isEmpty {
                        Text("\("package".localized): \(quantity)")
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding()
                .themeCard()

                // Nutrition per 100g/100ml
                if product.caloriesPer100g != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: "per_hundred".localized, unit))
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
                    Text("portion_calculator".localized)
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.textPrimary)

                    Text("how_much".localized)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)

                    HStack {
                        Slider(value: $selectedAmount, in: 10...maxAmount, step: sliderStep)
                            .tint(Theme.accent)

                        Button {
                            handleVoiceTap()
                        } label: {
                            Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(speechService.isRecording ? Theme.red : .white)
                                .frame(width: 52, height: 52)
                                .background(speechService.isRecording ? Theme.red.opacity(0.2) : Theme.accent)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(selectedAmount))\(unit)")
                            .font(Theme.bodyFont)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 70, alignment: .trailing)
                    }

                    if quantityIsDefault {
                        HStack(spacing: 8) {
                            Text("\u{26A0}\u{FE0F} \("quantity_unknown".localized)")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.orange)
                            Spacer()
                            TextField("Miktar", text: $customAmountText)
                                .keyboardType(.decimalPad)
                                .font(Theme.bodyFont)
                                .frame(width: 70)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: customAmountText) {
                                    if let val = Double(customAmountText), val > 0 {
                                        selectedAmount = min(val, 5000)
                                    }
                                }
                            Text(unit)
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    if let confirmation = voiceConfirmation {
                        Text(confirmation)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.green)
                    }

                    HStack(spacing: 12) {
                        Text("\(Int(selectedAmount))\(unit)")
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
                        Text(L.save.localized)
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
                        Text("rescan".localized)
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
            Text("\u{2753} \("product_not_found".localized)")
                .font(Theme.titleFont)
                .foregroundStyle(Theme.textPrimary)

            Text("barcode_not_in_db".localized)
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
                    Text(L.retry.localized)
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
                    Text("voice_describe".localized)
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
                print("\u{1F4E6} Raw quantity: '\(found.quantity ?? "nil")'")
                print("\u{1F4E6} servingSize: '\(found.servingSize ?? "nil")'")
                print("\u{1F4E6} product name: '\(found.name)'")
                let detected = detectedQuantity
                print("\u{1F4E6} Parsed unit: '\(detected.unit)'")
                print("\u{1F4E6} Parsed maxAmount: \(detected.amount)")
                print("\u{1F4E6} isDefault: \(detected.isDefault)")
                selectedAmount = servingSizeValue
                    ?? (detected.amount > 0 ? detected.amount / 2 : 100)
                phase = .found
            } else {
                phase = .notFound
            }
        } catch {
            errorMessage = "\("connection_error".localized): \(error.localizedDescription)"
            phase = .notFound
        }
    }

    private func saveEntry(_ product: FoodProduct) {
        if speechService.isRecording { speechService.stopListening() }

        var name = product.name
        if let brands = product.brands, !brands.isEmpty {
            name = "\(product.name) (\(brands))"
        }

        let entry = FoodEntry(
            name: name,
            amount: "\(Int(selectedAmount))\(unit)",
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
        if speechService.isRecording { speechService.stopListening() }
        phase = .scanning
        scannedCode = ""
        product = nil
        errorMessage = nil
        selectedAmount = 100
        voiceConfirmation = nil
        customAmountText = ""
    }

    // MARK: - Quantity Parsing

    private func parseQuantity(_ quantity: String?) -> (amount: Double, unit: String) {
        guard let q = quantity else { return (250, "g") }
        let lower = q.lowercased()

        let number = q.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let amount = Double(number) ?? 100

        if lower.contains("ml") {
            return (amount, "ml")
        }
        if (lower.contains("l ") || lower.hasSuffix("l") || lower.contains("litre"))
            && !lower.contains("ml") {
            return (amount * 1000, "ml")
        }
        return (amount, "g")
    }

    // MARK: - Voice Input

    private func handleVoiceTap() {
        if speechService.isRecording {
            speechService.stopListening()
            let text = speechService.transcript
            print("\u{1F3A4} Voice text received: '\(text)'")
            print("\u{1F3A4} productUnit at parse time: '\(unit)'")
            let parsed = parseVoiceAmount(text, unit: unit, maxAmount: maxAmount)
            print("\u{1F3A4} Parsed amount: \(parsed ?? -1)")
            if let parsed {
                let clamped = min(max(parsed, 10), maxAmount)
                selectedAmount = clamped
                voiceConfirmation = String(format: "selected_amount".localized, Int(clamped), unit)
            } else if !text.isEmpty {
                voiceConfirmation = "\("not_understood".localized): \"\(text)\""
            }
        } else {
            voiceConfirmation = nil
            Task {
                let granted = await speechService.requestPermissions()
                if granted {
                    try? speechService.startListening()
                }
            }
        }
    }

    private func parseVoiceAmount(_ text: String, unit: String, maxAmount: Double) -> Double? {
        let lower = text.lowercased()
        print("\u{1F3A4} parseVoiceAmount called: text='\(text)' unit='\(unit)' max=\(maxAmount)")

        // Keyword amounts — check multi-word first
        if lower.contains("tamam\u{0131}") || lower.contains("hepsi")
            || lower.contains("bir \u{015F}i\u{015F}e") || lower.contains("bir kutu")
            || lower.contains("bir paket") {
            return maxAmount
        }
        if lower.contains("yar\u{0131}m") || lower.contains("yar\u{0131}s\u{0131}") {
            return maxAmount / 2
        }
        if lower.contains("\u{00E7}eyrek") {
            return maxAmount / 4
        }

        // Turkish compound numbers (check longer phrases first)
        let turkishNumbers: [(String, Double)] = [
            ("be\u{015F} y\u{00FC}z", 500), ("d\u{00F6}rt y\u{00FC}z", 400),
            ("\u{00FC}\u{00E7} y\u{00FC}z", 300), ("iki y\u{00FC}z elli", 250),
            ("iki y\u{00FC}z", 200), ("y\u{00FC}z elli", 150), ("y\u{00FC}z", 100),
            ("elli", 50), ("otuz", 30), ("yirmi", 20), ("on", 10),
            ("be\u{015F}", 5), ("d\u{00F6}rt", 4), ("\u{00FC}\u{00E7}", 3),
            ("iki", 2), ("bir", 1),
        ]
        for (word, value) in turkishNumbers {
            if lower.contains(word) {
                let result = value
                print("\u{1F3A4} Parsed amount (turkish word): \(result)")
                return result
            }
        }

        // Extract numeric digits: "250 mililitre" → 250, "300" → 300
        let words = lower.components(separatedBy: " ")
        for word in words {
            if let number = Double(word), number > 0 {
                print("\u{1F3A4} Parsed amount (digit): \(number)")
                return number
            }
        }

        print("\u{1F3A4} Parsed amount: nil")
        return nil
    }
}
