//
//  BarcodeService.swift
//  VoiceMeal
//

import Foundation

struct FoodProduct {
    let name: String
    let brands: String?
    let quantity: String?
    let caloriesPer100g: Int?
    let proteinPer100g: Double?
    let carbsPer100g: Double?
    let fatPer100g: Double?
    let servingSize: String?
    let imageUrl: String?
}

@Observable
final class BarcodeService {
    func fetchProduct(barcode: String) async throws -> FoodProduct? {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("VoiceMeal iOS App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any]
        else {
            return nil
        }

        let name = (product["product_name_tr"] as? String)
            ?? (product["product_name"] as? String)
            ?? "Bilinmeyen Ürün"

        let brands = product["brands"] as? String
        let quantity = product["quantity"] as? String
        let servingSize = product["serving_size"] as? String
        let imageUrl = product["image_url"] as? String

        let nutriments = product["nutriments"] as? [String: Any]
        let calories = nutriments?["energy-kcal_100g"] as? Double
        let protein = nutriments?["proteins_100g"] as? Double
        let carbs = nutriments?["carbohydrates_100g"] as? Double
        let fat = nutriments?["fat_100g"] as? Double

        return FoodProduct(
            name: name,
            brands: brands,
            quantity: quantity,
            caloriesPer100g: calories.map { Int($0) },
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            servingSize: servingSize,
            imageUrl: imageUrl
        )
    }
}
