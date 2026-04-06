//
//  ContentView.swift
//  VoiceMealWatch Watch App
//

import SwiftUI

struct ContentView: View {
    @State private var sessionManager = WatchSessionManager()

    var body: some View {
        if sessionManager.hasData {
            TabView {
                CalorieSummaryView(session: sessionManager)
                MacroDetailView(session: sessionManager)
                MealListView(session: sessionManager)
            }
            .tabViewStyle(.verticalPage)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.system(size: 32))
                    .foregroundStyle(.gray)
                Text("iPhone'dan\nveri bekleniyor")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Calorie Summary (Page 1)

struct CalorieSummaryView: View {
    let session: WatchSessionManager

    private let accent = Color(red: 0.42, green: 0.39, blue: 1.0)

    private var progressColor: Color {
        if session.calorieProgress >= 1.0 { return .red }
        if session.calorieProgress >= 0.85 { return .orange }
        return accent
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: session.calorieProgress)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: session.calorieProgress)

                VStack(spacing: 1) {
                    Text("\(session.eatenCalories)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(session.goalCalories) kcal")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: 130, height: 130)

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("\(session.remainingCalories)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(session.remainingCalories >= 0 ? .green : .red)
                    Text("Kalan")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.gray)
                }

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 24)

                VStack(spacing: 2) {
                    Text("\(session.deficit)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(session.deficit > 0 ? .green : .red)
                    Text("Açık")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}

// MARK: - Macro Detail (Page 2)

struct MacroDetailView: View {
    let session: WatchSessionManager

    private let blue = Color(red: 0.04, green: 0.52, blue: 1.0)
    private let pink = Color(red: 1.0, green: 0.42, blue: 0.61)

    var body: some View {
        VStack(spacing: 14) {
            macroRow(
                label: "Protein",
                current: session.protein,
                target: session.proteinTarget,
                color: blue
            )

            macroRow(
                label: "Karbonhidrat",
                current: session.carbs,
                target: session.carbTarget,
                color: .orange
            )

            macroRow(
                label: "Yağ",
                current: session.fat,
                target: session.fatTarget,
                color: pink
            )
        }
        .padding(.horizontal, 12)
    }

    private func macroRow(label: String, current: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                Text("\(Int(current))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                + Text(" / \(Int(target))g")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.gray)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(
                            width: target > 0 ? min(geo.size.width * current / target, geo.size.width) : 0,
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.5), value: current)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Meal List (Page 3)

struct MealListView: View {
    let session: WatchSessionManager

    private let accent = Color(red: 0.42, green: 0.39, blue: 1.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                HStack {
                    Text("Bugün")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(session.meals.count) öğün")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 4)

                if session.meals.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray)
                        Text("Henüz kayıt yok")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 20)
                } else {
                    ForEach(session.meals) { meal in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text("P\(Int(meal.protein)) K\(Int(meal.carbs)) Y\(Int(meal.fat))")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.gray)
                            }
                            Spacer(minLength: 4)
                            Text("\(meal.calories)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(accent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    ContentView()
}
