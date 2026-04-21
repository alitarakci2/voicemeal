//
//  VoiceMealWidget.swift
//  VoiceMealWidget
//

import SwiftUI
import WidgetKit

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let data = WidgetDataStore.shared.load() ?? .placeholder
        completion(SimpleEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let data = WidgetDataStore.shared.load() ?? .placeholder
        let entry = SimpleEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Language + Mode Helpers

private let widgetLanguage: String = {
    let lang = UserDefaults(suiteName: "group.indio.VoiceMeal")?
        .stringArray(forKey: "AppleLanguages")?.first
        ?? UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first
        ?? Locale.current.language.languageCode?.identifier
        ?? "tr"
    return lang.hasPrefix("en") ? "en" : "tr"
}()

private var isEN: Bool { widgetLanguage == "en" }

private enum WidgetGapMode { case deficit, surplus, maintain }

private func widgetGapMode(target: Int) -> WidgetGapMode {
    if target > 50 { return .deficit }
    if target < -50 { return .surplus }
    return .maintain
}

// Short uppercase label for rings/inline
private func modeShortLabel(_ mode: WidgetGapMode) -> String {
    switch mode {
    case .deficit:  return isEN ? "DEFICIT"  : "AÇIK"
    case .surplus:  return isEN ? "SURPLUS"  : "FAZLA"
    case .maintain: return isEN ? "BALANCE"  : "DENGE"
    }
}

// Lowercase inline word (for accessoryInline: "VoiceMeal · 612 açık")
private func modeInlineWord(_ mode: WidgetGapMode) -> String {
    switch mode {
    case .deficit:  return isEN ? "deficit"  : "açık"
    case .surplus:  return isEN ? "surplus"  : "fazla"
    case .maintain: return isEN ? "balance"  : "denge"
    }
}

// For accessibility label (readable sentence)
private func modeA11yWord(_ mode: WidgetGapMode) -> String {
    switch mode {
    case .deficit:  return isEN ? "deficit"  : "açık"
    case .surplus:  return isEN ? "surplus"  : "fazla"
    case .maintain: return isEN ? "balance"  : "denge"
    }
}

private func calorieA11y(value: Int, mode: WidgetGapMode) -> String {
    let unit = isEN ? "calorie" : "kalori"
    return "\(value) \(unit) \(modeA11yWord(mode))"
}

// MARK: - Theme

private struct WidgetTheme {
    let accent: Color
    let accentLight: Color
    let gradientTop: Color
    let gradientMid: Color
    let gradientBottom: Color

    static let purple = WidgetTheme(
        accent: Color(red: 0.424, green: 0.388, blue: 1.000),      // 6C63FF
        accentLight: Color(red: 0.616, green: 0.584, blue: 1.000), // 9D95FF
        gradientTop: Color(red: 0.176, green: 0.039, blue: 0.306), // 2D0A4E
        gradientMid: Color(red: 0.082, green: 0.031, blue: 0.157), // 150828
        gradientBottom: Color(red: 0.039, green: 0.039, blue: 0.059) // 0A0A0F
    )

    static let blue = WidgetTheme(
        accent: Color(red: 0.204, green: 0.596, blue: 0.859),      // 3498DB
        accentLight: Color(red: 0.365, green: 0.678, blue: 0.886), // 5DADE2
        gradientTop: Color(red: 0.039, green: 0.102, blue: 0.176), // 0A1A2D
        gradientMid: Color(red: 0.024, green: 0.051, blue: 0.094), // 060D18
        gradientBottom: Color(red: 0.039, green: 0.039, blue: 0.059) // 0A0A0F
    )

    static func from(_ raw: String) -> WidgetTheme {
        raw == "blue" ? .blue : .purple
    }
}

private let surplusColor = Color(red: 0.953, green: 0.612, blue: 0.071)  // F39C12
private let maintainColor = Color(red: 0.180, green: 0.800, blue: 0.443) // 2ECC71

private func modeColor(_ mode: WidgetGapMode, theme: WidgetTheme) -> Color {
    switch mode {
    case .deficit:  return theme.accent
    case .surplus:  return surplusColor
    case .maintain: return maintainColor
    }
}

private func modeColorLight(_ mode: WidgetGapMode, theme: WidgetTheme) -> Color {
    switch mode {
    case .deficit:  return theme.accentLight
    case .surplus:  return surplusColor.opacity(0.75)
    case .maintain: return maintainColor.opacity(0.75)
    }
}

// MARK: - Background

private struct WidgetBackground: View {
    let theme: WidgetTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.gradientTop, theme.gradientMid, theme.gradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Color.white.opacity(0.04)
        }
    }
}

// MARK: - Calorie Ring

private struct CalorieRingView<Center: View>: View {
    let progress: Double
    let color: Color
    let colorLight: Color
    let lineWidth: CGFloat
    @ViewBuilder let center: () -> Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(
                        colors: [color, colorLight, color],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            center()
        }
    }
}

// MARK: - Time formatter (user locale)

private let mealTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .short
    f.dateStyle = .none
    f.locale = Locale.current
    return f
}()

private func formatMealTime(_ date: Date) -> String {
    mealTimeFormatter.string(from: date)
}

private func lastMealLine(_ meal: WidgetMealEntry) -> String {
    let kcal = isEN ? "kcal" : "kcal"
    return "\(formatMealTime(meal.date)) · \(meal.name) · \(meal.calories) \(kcal)"
}

private var noMealText: String {
    isEN ? "No meals yet" : "Henüz yemek yok"
}

// MARK: - Small Widget

struct CalorieSmallView: View {
    let entry: SimpleEntry

    var body: some View {
        let theme = WidgetTheme.from(entry.data.theme)
        let mode = widgetGapMode(target: entry.data.targetDeficit)
        let value = abs(entry.data.actualDeficit)
        let color = modeColor(mode, theme: theme)
        let light = modeColorLight(mode, theme: theme)
        let progress = mode == .maintain
            ? max(0, 1 - min(Double(value) / 500.0, 1.0))
            : entry.data.deficitPercent

        VStack(spacing: 6) {
            CalorieRingView(
                progress: progress,
                color: color,
                colorLight: light,
                lineWidth: 10
            ) {
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("kcal")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(modeShortLabel(mode))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(color)
        }
        .padding(12)
        .widgetURL(URL(string: "voicemeal://record"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(calorieA11y(value: value, mode: mode))
    }
}

// MARK: - Medium Widget

struct CalorieMediumView: View {
    let entry: SimpleEntry

    var body: some View {
        let theme = WidgetTheme.from(entry.data.theme)
        let mode = widgetGapMode(target: entry.data.targetDeficit)
        let value = abs(entry.data.actualDeficit)
        let color = modeColor(mode, theme: theme)
        let light = modeColorLight(mode, theme: theme)
        let progress = mode == .maintain
            ? max(0, 1 - min(Double(value) / 500.0, 1.0))
            : entry.data.deficitPercent
        let proteinEaten = Int(entry.data.proteinEaten)
        let proteinTarget = Int(entry.data.proteinTarget)

        HStack(spacing: 14) {
            // Sol: kalori ring
            CalorieRingView(
                progress: progress,
                color: color,
                colorLight: light,
                lineWidth: 10
            ) {
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(modeShortLabel(mode))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(color)
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 10) {
                // Sağ üst: protein mini ring
                HStack(spacing: 10) {
                    CalorieRingView(
                        progress: entry.data.proteinPercent,
                        color: Color(red: 0.365, green: 0.627, blue: 1.0),
                        colorLight: Color(red: 0.565, green: 0.745, blue: 1.0),
                        lineWidth: 6
                    ) {
                        Text("P")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isEN ? "PROTEIN" : "PROTEİN")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.0)
                            .foregroundStyle(.white.opacity(0.55))
                        Text("\(proteinEaten) / \(proteinTarget) g")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }

                // Sağ alt: son yemek
                VStack(alignment: .leading, spacing: 2) {
                    Text(isEN ? "LAST MEAL" : "SON YEMEK")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.55))
                    if let last = entry.data.lastMeal {
                        Text(lastMealLine(last))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text(noMealText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mediumA11yLabel(value: value, mode: mode, proteinEaten: proteinEaten, proteinTarget: proteinTarget, lastMeal: entry.data.lastMeal))
    }

    private func mediumA11yLabel(value: Int, mode: WidgetGapMode, proteinEaten: Int, proteinTarget: Int, lastMeal: WidgetMealEntry?) -> String {
        let calorieStr = calorieA11y(value: value, mode: mode)
        let proteinStr = isEN
            ? "\(proteinEaten) grams of protein eaten, \(proteinTarget) grams target"
            : "\(proteinEaten) gram yenen protein, \(proteinTarget) gram hedef"
        let mealStr: String
        if let last = lastMeal {
            mealStr = isEN
                ? "last meal \(formatMealTime(last.date)) \(last.name)"
                : "son yemek \(formatMealTime(last.date)) \(last.name)"
        } else {
            mealStr = noMealText
        }
        return "\(calorieStr), \(proteinStr), \(mealStr)"
    }
}

// MARK: - Large Widget

struct CalorieLargeView: View {
    let entry: SimpleEntry

    private var dateHeader: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE · d MMM"
        return formatter.string(from: entry.date)
    }

    var body: some View {
        let theme = WidgetTheme.from(entry.data.theme)
        let mode = widgetGapMode(target: entry.data.targetDeficit)
        let value = abs(entry.data.actualDeficit)
        let color = modeColor(mode, theme: theme)
        let light = modeColorLight(mode, theme: theme)
        let progress = mode == .maintain
            ? max(0, 1 - min(Double(value) / 500.0, 1.0))
            : entry.data.deficitPercent
        let proteinEaten = Int(entry.data.proteinEaten)
        let proteinTarget = Int(entry.data.proteinTarget)

        VStack(spacing: 12) {
            // Üst: iki ring yanyana
            HStack(spacing: 18) {
                VStack(spacing: 6) {
                    CalorieRingView(
                        progress: progress,
                        color: color,
                        colorLight: light,
                        lineWidth: 12
                    ) {
                        VStack(spacing: 0) {
                            Text("\(value)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text("kcal")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(width: 120, height: 120)
                    Text(modeShortLabel(mode))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(color)
                }

                VStack(spacing: 6) {
                    CalorieRingView(
                        progress: entry.data.proteinPercent,
                        color: Color(red: 0.365, green: 0.627, blue: 1.0),
                        colorLight: Color(red: 0.565, green: 0.745, blue: 1.0),
                        lineWidth: 12
                    ) {
                        VStack(spacing: 0) {
                            Text("\(proteinEaten)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text("/ \(proteinTarget) g")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(width: 120, height: 120)
                    Text(isEN ? "PROTEIN" : "PROTEİN")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 0.365, green: 0.627, blue: 1.0))
                }
            }

            // Orta: tarih
            Text(dateHeader)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.6))

            Divider().overlay(Color.white.opacity(0.12))

            // Alt: son 3 meal
            VStack(alignment: .leading, spacing: 6) {
                Text(isEN ? "RECENT MEALS" : "SON YEMEKLER")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.55))

                if entry.data.lastMeals.isEmpty {
                    Text(noMealText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(entry.data.lastMeals.prefix(3).enumerated()), id: \.offset) { _, meal in
                        HStack(spacing: 8) {
                            Text(formatMealTime(meal.date))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(minWidth: 46, alignment: .leading)
                            Text(meal.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(meal.calories)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(color)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(largeA11yLabel(value: value, mode: mode, proteinEaten: proteinEaten, proteinTarget: proteinTarget, mealCount: entry.data.lastMeals.count))
    }

    private func largeA11yLabel(value: Int, mode: WidgetGapMode, proteinEaten: Int, proteinTarget: Int, mealCount: Int) -> String {
        let calorieStr = calorieA11y(value: value, mode: mode)
        let proteinStr = isEN
            ? "\(proteinEaten) grams of protein eaten, \(proteinTarget) grams target"
            : "\(proteinEaten) gram yenen protein, \(proteinTarget) gram hedef"
        let mealStr: String
        if mealCount == 0 {
            mealStr = noMealText
        } else {
            mealStr = isEN
                ? "\(mealCount) recent meals"
                : "\(mealCount) son yemek"
        }
        return "\(calorieStr), \(proteinStr), \(mealStr)"
    }
}

// MARK: - Lock Screen: Circular

struct CalorieLockCircularView: View {
    let entry: SimpleEntry

    var body: some View {
        let mode = widgetGapMode(target: entry.data.targetDeficit)
        let value = abs(entry.data.actualDeficit)
        let progress = mode == .maintain
            ? max(0, 1 - min(Double(value) / 500.0, 1.0))
            : entry.data.deficitPercent

        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .widgetAccentable()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(calorieA11y(value: value, mode: mode))
    }
}

// MARK: - Lock Screen: Rectangular

struct CalorieLockRectView: View {
    let entry: SimpleEntry

    var body: some View {
        let mode = widgetGapMode(target: entry.data.targetDeficit)
        let value = abs(entry.data.actualDeficit)
        let proteinEaten = Int(entry.data.proteinEaten)
        let proteinTarget = Int(entry.data.proteinTarget)

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(modeShortLabel(mode))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                Text("\(value)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .widgetAccentable()
            }
            Text("P \(proteinEaten) / \(proteinTarget) g")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rectA11yLabel(value: value, mode: mode, proteinEaten: proteinEaten, proteinTarget: proteinTarget))
    }

    private func rectA11yLabel(value: Int, mode: WidgetGapMode, proteinEaten: Int, proteinTarget: Int) -> String {
        let cal = calorieA11y(value: value, mode: mode)
        let protein = isEN
            ? "protein \(proteinEaten) of \(proteinTarget) grams"
            : "protein \(proteinEaten) bölü \(proteinTarget) gram"
        return "VoiceMeal \(cal), \(protein)"
    }
}

// MARK: - Lock Screen: Inline

struct CalorieInlineView: View {
    let entry: SimpleEntry

    var body: some View {
        let mode = widgetGapMode(target: entry.data.targetDeficit)
        let value = abs(entry.data.actualDeficit)
        Text("VoiceMeal · \(value) \(modeInlineWord(mode))")
    }
}

// MARK: - Widget Definitions

struct VoiceMealWidgetSmall: Widget {
    let kind = "VoiceMealSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CalorieSmallView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(theme: WidgetTheme.from(entry.data.theme))
                }
        }
        .configurationDisplayName("VoiceMeal")
        .description(isEN ? "Calorie ring at a glance" : "Hızlı kalori özeti")
        .supportedFamilies([.systemSmall])
    }
}

struct VoiceMealWidgetMedium: Widget {
    let kind = "VoiceMealMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CalorieMediumView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(theme: WidgetTheme.from(entry.data.theme))
                }
        }
        .configurationDisplayName("VoiceMeal")
        .description(isEN ? "Calories, protein, and last meal" : "Kalori, protein ve son yemek")
        .supportedFamilies([.systemMedium])
    }
}

struct VoiceMealWidgetLarge: Widget {
    let kind = "VoiceMealLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CalorieLargeView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(theme: WidgetTheme.from(entry.data.theme))
                }
        }
        .configurationDisplayName("VoiceMeal Detail")
        .description(isEN ? "Full daily summary with recent meals" : "Günlük detay ve son yemekler")
        .supportedFamilies([.systemLarge])
    }
}

struct VoiceMealWidgetLockCircular: Widget {
    let kind = "VoiceMealLockCircular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CalorieLockCircularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("VoiceMeal")
        .description(isEN ? "Calorie ring for lock screen" : "Kilit ekranı kalori ring")
        .supportedFamilies([.accessoryCircular])
    }
}

struct VoiceMealWidgetLockRect: Widget {
    let kind = "VoiceMealLockRect"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CalorieLockRectView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("VoiceMeal")
        .description(isEN ? "Calorie + protein strip" : "Kalori + protein şeridi")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct VoiceMealWidgetLockInline: Widget {
    let kind = "VoiceMealLockInline"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CalorieInlineView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("VoiceMeal")
        .description(isEN ? "Inline calorie line" : "Satır halinde kalori")
        .supportedFamilies([.accessoryInline])
    }
}

// MARK: - Bundle

@main
struct VoiceMealWidgetBundle: WidgetBundle {
    var body: some Widget {
        VoiceMealWidgetSmall()
        VoiceMealWidgetMedium()
        VoiceMealWidgetLarge()
        VoiceMealWidgetLockCircular()
        VoiceMealWidgetLockRect()
        VoiceMealWidgetLockInline()
    }
}
