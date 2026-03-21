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

// MARK: - Widget Metric View

struct WidgetMetricView: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(icon).font(.title3)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(1, max(0, progress)))
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Large Progress Row

struct LargeProgressRow: View {
    let icon: String
    let label: String
    let consumed: Int
    let target: Int
    let color: Color
    var unit: String = "kcal"

    private var progress: Double {
        target > 0 ? Double(consumed) / Double(target) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(icon) \(label)")
                    .font(.caption)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(consumed) / \(target) \(unit)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(1, max(0, progress)))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - App Language Helper

private let widgetLanguage: String = {
    let lang = UserDefaults(suiteName: "group.indio.VoiceMeal")?
        .stringArray(forKey: "AppleLanguages")?.first
        ?? UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first
        ?? Locale.current.language.languageCode?.identifier
        ?? "tr"
    return lang.hasPrefix("en") ? "en" : "tr"
}()

private let widgetBackground = Color(red: 0.04, green: 0.04, blue: 0.06)

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundStyle(Color(red: 0.42, green: 0.39, blue: 1.0))
                Text("VoiceMeal")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider().overlay(Color.white.opacity(0.15))

            HStack(spacing: 0) {
                WidgetMetricView(
                    icon: "🎯",
                    value: "\(entry.data.remainingCaloriesClamped)",
                    unit: "kcal",
                    label: widgetLanguage == "en" ? "left" : "kaldi",
                    progress: Double(entry.data.consumedCalories) / Double(max(1, entry.data.targetCalories)),
                    color: entry.data.remainingCalories < 0 ? .orange : .green
                )

                Divider().frame(height: 50).overlay(Color.white.opacity(0.15))

                WidgetMetricView(
                    icon: "🔥",
                    value: "\(entry.data.actualDeficit)",
                    unit: "kcal",
                    label: widgetLanguage == "en" ? "deficit" : "acik",
                    progress: entry.data.deficitPercent,
                    color: entry.data.deficitPercent >= 1.0 ? .green : .orange
                )

                Divider().frame(height: 50).overlay(Color.white.opacity(0.15))

                WidgetMetricView(
                    icon: "💧",
                    value: entry.data.waterConsumed >= 1000
                        ? String(format: "%.1fL", Double(entry.data.waterConsumed) / 1000)
                        : "\(entry.data.waterConsumed)ml",
                    unit: "",
                    label: String(format: "%d%%", Int(entry.data.waterPercent * 100)),
                    progress: entry.data.waterPercent,
                    color: entry.data.waterPercent >= 1.0 ? .green : .blue
                )
            }
        }
        .padding()
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundStyle(Color(red: 0.42, green: 0.39, blue: 1.0))
                Text("VoiceMeal")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider().overlay(Color.white.opacity(0.15))

            // Three metric columns
            HStack(spacing: 0) {
                WidgetMetricView(
                    icon: "🎯",
                    value: "\(entry.data.remainingCaloriesClamped)",
                    unit: "kcal",
                    label: widgetLanguage == "en" ? "left" : "kaldi",
                    progress: Double(entry.data.consumedCalories) / Double(max(1, entry.data.targetCalories)),
                    color: entry.data.remainingCalories < 0 ? .orange : .green
                )

                Divider().frame(height: 50).overlay(Color.white.opacity(0.15))

                WidgetMetricView(
                    icon: "🔥",
                    value: "\(entry.data.actualDeficit)",
                    unit: "kcal",
                    label: widgetLanguage == "en" ? "deficit" : "acik",
                    progress: entry.data.deficitPercent,
                    color: entry.data.deficitPercent >= 1.0 ? .green : .orange
                )

                Divider().frame(height: 50).overlay(Color.white.opacity(0.15))

                WidgetMetricView(
                    icon: "💧",
                    value: entry.data.waterConsumed >= 1000
                        ? String(format: "%.1fL", Double(entry.data.waterConsumed) / 1000)
                        : "\(entry.data.waterConsumed)ml",
                    unit: "",
                    label: String(format: "%d%%", Int(entry.data.waterPercent * 100)),
                    progress: entry.data.waterPercent,
                    color: entry.data.waterPercent >= 1.0 ? .green : .blue
                )
            }

            Divider().overlay(Color.white.opacity(0.15))

            // Detailed progress bars
            VStack(spacing: 8) {
                LargeProgressRow(
                    icon: "🎯",
                    label: widgetLanguage == "en" ? "Eating Goal" : "Yeme Hedefi",
                    consumed: entry.data.consumedCalories,
                    target: entry.data.targetCalories,
                    color: .green
                )

                LargeProgressRow(
                    icon: "🔥",
                    label: widgetLanguage == "en" ? "Calorie Deficit" : "Kalori Acigi",
                    consumed: entry.data.actualDeficit,
                    target: entry.data.targetDeficit,
                    color: .orange
                )

                LargeProgressRow(
                    icon: "💧",
                    label: widgetLanguage == "en" ? "Water" : "Su",
                    consumed: entry.data.waterConsumed,
                    target: entry.data.waterGoal,
                    color: .blue,
                    unit: "ml"
                )
            }

            Spacer()

            // Last updated
            Text(widgetLanguage == "en"
                ? "Updated: \(entry.date.formatted(.dateTime.hour().minute()))"
                : "Son guncelleme: \(entry.date.formatted(.dateTime.hour().minute()))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Lock Screen Widget View

struct LockScreenWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text("🎯")
                    .font(.caption2)
                Text("\(entry.data.remainingCaloriesClamped)")
                    .font(.system(size: 13, weight: .bold))
                Text("kcal")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(spacing: 1) {
                Text("🔥")
                    .font(.caption2)
                Text("\(entry.data.actualDeficit)")
                    .font(.system(size: 13, weight: .bold))
                Text(widgetLanguage == "en" ? "deficit" : "acik")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(spacing: 1) {
                Text("💧")
                    .font(.caption2)
                Text("\(Int(entry.data.waterPercent * 100))%")
                    .font(.system(size: 13, weight: .bold))
                Text(widgetLanguage == "en" ? "water" : "su")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget Definitions

struct VoiceMealWidgetMedium: Widget {
    let kind = "VoiceMealMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(widgetBackground, for: .widget)
        }
        .configurationDisplayName("VoiceMeal")
        .description(widgetLanguage == "en" ? "Daily calorie and water tracking" : "Gunluk kalori ve su takibi")
        .supportedFamilies([.systemMedium])
    }
}

struct VoiceMealWidgetLarge: Widget {
    let kind = "VoiceMealLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LargeWidgetView(entry: entry)
                .containerBackground(widgetBackground, for: .widget)
        }
        .configurationDisplayName("VoiceMeal Detail")
        .description(widgetLanguage == "en" ? "Detailed calorie, deficit and water tracking" : "Detayli kalori, acik ve su takibi")
        .supportedFamilies([.systemLarge])
    }
}

struct VoiceMealWidgetLockScreen: Widget {
    let kind = "VoiceMealLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("VoiceMeal")
        .description(widgetLanguage == "en" ? "Calorie and water at a glance" : "Kalori ve su takibi")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Entry Point

@main
struct VoiceMealWidgetBundle: WidgetBundle {
    var body: some Widget {
        VoiceMealWidgetMedium()
        VoiceMealWidgetLarge()
        VoiceMealWidgetLockScreen()
    }
}
