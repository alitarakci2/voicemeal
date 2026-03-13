//
//  PlanView.swift
//  VoiceMeal
//

import SwiftData
import SwiftUI

struct PlanView: View {
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @State private var planService = PlanService()
    @State private var selectedPlan: DayPlan?

    private var dayPlans: [DayPlan] {
        _ = planService.refreshID // force re-evaluation after regeneratePlans()
        guard let profile = profiles.first else { return [] }
        return planService.generateDayPlans(profile: profile, entries: allEntries)
    }

    private var todayID: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private var weeklyStats: (totalDeficit: Int, estimatedChangeKg: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else {
            return (0, 0)
        }
        let weekPlans = dayPlans.filter { $0.date >= weekStart && $0.date <= today && $0.status != .planned }
        let totalDeficit = weekPlans.reduce(0) { $0 + ($1.tdee - $1.consumedCalories) }
        let estimatedChange = weekPlans.reduce(0.0) { $0 + $1.estimatedWeightChangeKg }
        return (totalDeficit, estimatedChange)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Weekly summary
                        weeklySummaryCard
                            .padding(.bottom, 4)

                        ForEach(dayPlans) { plan in
                            DayRowView(plan: plan)
                                .id(plan.date)
                                .onTapGesture {
                                    selectedPlan = plan
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(todayID, anchor: .center)
                        }
                    }
                }
            }
            .navigationTitle("Plan")
            .onReceive(NotificationCenter.default.publisher(for: .profileUpdated)) { _ in
                planService.regeneratePlans()
            }
            .sheet(item: $selectedPlan) { plan in
                DayDetailSheetView(plan: plan)
            }
        }
    }

    private var weeklySummaryCard: some View {
        let stats = weeklyStats
        return VStack(alignment: .leading, spacing: 6) {
            Text("\u{1F4CA} Bu Hafta")
                .font(.subheadline)
                .fontWeight(.semibold)
            HStack {
                Text("Toplam a\u{00E7}\u{0131}k: \(stats.totalDeficit) kcal")
                    .font(.caption)
                Spacer()
                Text("Tahmini: \u{2248} \(String(format: "%+.2f", stats.estimatedChangeKg)) kg")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(stats.estimatedChangeKg <= 0 ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Day Row

struct DayRowView: View {
    let plan: DayPlan

    private var statusIcon: String {
        switch plan.status {
        case .completed: return "checkmark.circle.fill"
        case .exceeded: return "exclamationmark.triangle.fill"
        case .underate: return "arrow.down.circle.fill"
        case .missed: return "xmark.circle.fill"
        case .today: return "location.fill"
        case .planned: return "doc.text"
        }
    }

    private var statusColor: Color {
        switch plan.status {
        case .completed: return .green
        case .exceeded: return .yellow
        case .underate: return .blue
        case .missed: return .gray
        case .today: return .blue
        case .planned: return .gray
        }
    }

    private var dateLabel: String {
        if plan.status == .today {
            return "Bug\u{00FC}n"
        }
        return plan.date.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                Text(dateLabel)
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    ForEach(plan.activities, id: \.self) { activity in
                        Text(activityEmoji(activity))
                            .font(.callout)
                    }
                }
            }

            HStack {
                switch plan.status {
                case .today:
                    Text("\(plan.consumedCalories) / \(plan.targetCalories) kcal")
                        .font(.subheadline)
                    Spacer()
                    Text("devam ediyor...")
                        .font(.caption)
                        .foregroundStyle(.blue)

                case .planned:
                    Text("Hedef: \(plan.targetCalories) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    let plannedDeficit = plan.tdee - plan.targetCalories
                    Text("~\(plannedDeficit) a\u{00E7}\u{0131}k")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                case .missed:
                    Text("0 / \(plan.targetCalories) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()

                default:
                    Text("\(plan.consumedCalories) / \(plan.targetCalories) kcal")
                        .font(.subheadline)
                    Spacer()
                    let weightChange = plan.estimatedWeightChangeKg
                    Text("\u{2248} \(String(format: "%+.2f", weightChange)) kg")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(weightChange <= 0 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(plan.status == .today ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func activityEmoji(_ activity: String) -> String {
        switch activity {
        case "weights": return "\u{1F3CB}\u{FE0F}"
        case "running": return "\u{1F3C3}"
        case "cycling": return "\u{1F6B4}"
        case "walking": return "\u{1F6B6}"
        case "rest": return "\u{1F4A4}"
        default: return "\u{2753}"
        }
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheetView: View {
    let plan: DayPlan
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    private var dayEntries: [FoodEntry] {
        let calendar = Calendar.current
        return allEntries.filter { calendar.isDate($0.date, inSameDayAs: plan.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Date + activities
                    HStack {
                        Text(plan.status == .today ? "Bug\u{00FC}n" : plan.date.formatted(.dateTime.day().month(.wide).year()))
                            .font(.title3)
                            .fontWeight(.bold)
                        Spacer()
                        ForEach(plan.activities, id: \.self) { activity in
                            Text(GoalEngine.activityDisplayNames[activity] ?? activity)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }

                    // Status banner
                    statusBanner

                    // Calorie + macro progress
                    calorieSection

                    // Daily deficit (past and today only)
                    if plan.status != .planned {
                        let deficit = plan.tdee - plan.consumedCalories
                        HStack {
                            if deficit > 0 {
                                Text("\u{1F525} \(deficit) kcal a\u{00E7}\u{0131}k")
                                    .foregroundStyle(.green)
                            } else {
                                Text("\u{26A0}\u{FE0F} \(abs(deficit)) kcal fazla")
                                    .foregroundStyle(.red)
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }

                    macroSection

                    // Food entries
                    if plan.status == .planned {
                        Text("Bu g\u{00FC}n i\u{00E7}in plan")
                            .font(.headline)
                            .padding(.top, 4)
                        Text("Hedef: \(plan.targetCalories) kcal")
                            .foregroundStyle(.secondary)
                        Text("P: \(plan.targetProtein)g  K: \(plan.targetCarbs)g  Y: \(plan.targetFat)g")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if dayEntries.isEmpty {
                        Text("Yemek kayd\u{0131} yok")
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    } else {
                        Text("Yemekler")
                            .font(.headline)
                            .padding(.top, 4)
                        ForEach(dayEntries, id: \.id) { entry in
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
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("G\u{00FC}n Detay\u{0131}")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isPastOlderThan7Days: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfDay(for: .now))!
        return plan.date < sevenDaysAgo
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch plan.status {
        case .completed:
            Label("Hedefe ula\u{015F}\u{0131}ld\u{0131}", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .exceeded:
            Label("Hedef a\u{015F}\u{0131}ld\u{0131}", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
        case .underate:
            Label("Hedefin alt\u{0131}nda kald\u{0131}n \u{2014} \u{00E7}ok az yedin", systemImage: "arrow.down.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.blue)
        case .missed:
            Label("Ka\u{00E7}\u{0131}r\u{0131}ld\u{0131}", systemImage: "xmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.gray)
        case .today:
            Label("Devam ediyor", systemImage: "location.fill")
                .font(.subheadline)
                .foregroundStyle(.blue)
        case .planned:
            Label("Planland\u{0131}", systemImage: "doc.text")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        if isPastOlderThan7Days {
            Text("* Hedef, mevcut profil de\u{011F}erleriyle hesaplanm\u{0131}\u{015F}t\u{0131}r")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var calorieSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kalori")
                .font(.subheadline)
                .fontWeight(.medium)

            let progress = plan.targetCalories > 0 ? min(Double(plan.consumedCalories) / Double(plan.targetCalories), 1.0) : 0

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray4))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(plan.status == .exceeded ? Color.orange : plan.status == .underate ? Color.blue : Color.green)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 12)

            HStack {
                Text("\(plan.consumedCalories) / \(plan.targetCalories) kcal")
                    .font(.caption)
                Spacer()
                if plan.status != .planned {
                    Text("%\(plan.caloriePercentage)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private var macroSection: some View {
        VStack(spacing: 8) {
            macroBar("Protein", eaten: Int(plan.consumedProtein), target: plan.targetProtein, color: .blue)
            macroBar("Karb", eaten: Int(plan.consumedCarbs), target: plan.targetCarbs, color: .orange)
            macroBar("Ya\u{011F}", eaten: Int(plan.consumedFat), target: plan.targetFat, color: .yellow)
        }
    }

    private func macroBar(_ name: String, eaten: Int, target: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.caption)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                let progress = target > 0 ? min(Double(eaten) / Double(target), 1.0) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)

            Text("\(eaten)g / \(target)g")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

#Preview {
    PlanView()
        .modelContainer(for: [FoodEntry.self, UserProfile.self, DailySnapshot.self], inMemory: true)
}
