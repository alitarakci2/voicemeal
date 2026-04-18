//
//  LocalizationKeys.swift
//  VoiceMeal
//

import Foundation

// swiftlint:disable type_name
enum L {
    // General
    static let save = "save"
    static let cancel = "cancel"
    static let close = "close"
    static let edit = "edit"
    static let delete = "delete"
    static let retry = "retry"
    static let ready = "ready"
    static let loading = "loading"
    static let error = "error"
    static let yes = "yes"
    static let no = "no"

    // HomeView
    static let dailyTarget = "daily_target"
    static let todayActivities = "today_activities"
    static let goalCalories = "goal_calories"
    static let eaten = "eaten"
    static let remaining = "remaining"
    static let calorieDeficit = "calorie_deficit"
    static let realDeficit = "real_deficit"
    static let targetDeficit = "target_deficit"
    static let protein = "protein"
    static let carbs = "carbs"
    static let fat = "fat"
    static let refresh = "refresh"
    static let whatDidYouEat = "what_did_you_eat"

    // Water
    static let waterTracking = "water_tracking"
    static let waterGoal = "water_goal"
    static let waterGoalReached = "water_goal_reached"

    // Photo Analysis
    static let photoAnalysis = "photo_analysis"
    static let analyzing = "analyzing"
    static let analyzingSubtitle = "analyzing_subtitle"
    static let detected = "detected"
    static let notDetected = "not_detected"
    static let portionCalculator = "portion_calculator"
    static let retakePhoto = "retake_photo"
    static let speakToAnswer = "speak_to_answer"

    // Barcode
    static let barcodeScan = "barcode_scan"
    static let barcodeHint = "barcode_hint"
    static let productFound = "product_found"
    static let productNotFound = "product_not_found"
    static let perHundred = "per_hundred"

    // Plan
    static let plan = "plan"
    static let today = "today"
    static let ongoing = "ongoing"
    static let previousDays = "previous_days"
    static let nextDays = "next_days"
    static let programStart = "program_start"
    static let thisWeek = "this_week"
    static let weeklyDeficit = "weekly_deficit"
    static let dayDetail = "day_detail"
    static let eatingGoal = "eating_goal"
    static let goalExceeded = "goal_exceeded"
    static let goalRemaining = "goal_remaining"
    static let noFoodLog = "no_food_log"
    static let foods = "foods"
    static let total = "total"
    static let deficit = "deficit"
    static let average = "average"
    static let calShort = "cal_short"
    static let deficitShort = "deficit_short"
    static let proShort = "pro_short"
    static let carbShort = "carb_short"
    static let fatShort = "fat_short"
    static let trendLosing = "trend_losing"
    static let trendWarning = "trend_warning"
    static let trendStable = "trend_stable"
    static let daysWithDataFormat = "days_with_data_format"
    static let kcalDeficitFormat = "kcal_deficit_format"
    static let targetKcalFormat = "target_kcal_format"
    static let targetValueFormat = "target_value_format"
    static let eatenValueFormat = "eaten_value_format"
    static let deficitApproxFormat = "deficit_approx_format"
    static let deficitValueFormat = "deficit_value_format"
    static let inProgress = "in_progress"
    static let planned = "planned"
    static let planForToday = "plan_for_today"
    static let statusGoalReached = "status_goal_reached"
    static let statusCalorieSurplus = "status_calorie_surplus"
    static let statusBehindDeficit = "status_behind_deficit"
    static let statusNoLog = "status_no_log"
    static let goalNoteOld = "goal_note_old"
    static let burnTdee = "burn_tdee"
    static let actualDeficitFormat = "actual_deficit_format"
    static let targetDeficitFormat = "target_deficit_format"
    static let exceededByFormat = "exceeded_by_format"
    static let goalExact = "goal_exact"
    static let caloriesLeftFormat = "calories_left_format"
    static let noDeficitSurplusFormat = "no_deficit_surplus_format"
    static let behindDeficitPctFormat = "behind_deficit_pct_format"
    static let deficitHitPctFormat = "deficit_hit_pct_format"

    // Statistics
    static let statistics = "statistics"
    static let weekly = "weekly"
    static let monthly = "monthly"
    static let program = "program"
    static let streak = "streak"
    static let currentStreak = "current_streak"
    static let bestStreak = "best_streak"
    static let weightEstimate = "weight_estimate"
    static let trend = "trend"
    static let losing = "losing"
    static let gaining = "gaining"
    static let stable = "stable"
    static let notEnoughData = "not_enough_data"
    static let programStartDate = "program_start_date"
    static let weightGoal = "weight_goal"
    static let startWeight = "start_weight"
    static let estimated = "estimated"
    static let goal = "goal"
    static let realWeight = "real_weight"
    static let onTrack = "on_track"
    static let behind = "behind"
    static let aheadOfSchedule = "ahead_of_schedule"

    // Settings
    static let settings = "settings"
    static let profile = "profile"
    static let gender = "gender"
    static let male = "male"
    static let female = "female"
    static let age = "age"
    static let height = "height"
    static let weight = "weight"
    static let targetWeight = "target_weight"
    static let duration = "duration"
    static let intensity = "intensity"
    static let easy = "easy"
    static let medium = "medium"
    static let aggressive = "aggressive"
    static let weeklySchedule = "weekly_schedule"
    static let notifications = "notifications"
    static let resetOnboarding = "reset_onboarding"
    static let nameField = "name_field"
    static let time = "time"
    static let done = "done"
    static let savedToast = "saved_toast"
    static let appSection = "app_section"
    static let version = "version"
    static let autoCalculate = "auto_calculate"
    static let waterFormula = "water_formula"
    static let preferredProteins = "preferred_proteins"
    static let scheduleChange = "schedule_change"
    static let scheduleChangeMessage = "schedule_change_message"
    static let weightConflict = "weight_conflict"
    static let weightConflictMessage = "weight_conflict_message"
    static let weightConflictMessageAlt = "weight_conflict_message_alt"
    static let resetConfirm = "reset_confirm"
    static let resetConfirmMessage = "reset_confirm_message"
    static let intensityLight = "intensity_light"
    static let intensityModerate = "intensity_moderate"
    static let intensityIntense = "intensity_intense"
    static let intensityLightDesc = "intensity_light_desc"
    static let intensityModerateDesc = "intensity_moderate_desc"
    static let intensityIntenseDesc = "intensity_intense_desc"
    static let intensityFooter = "intensity_footer"
    static let weightGainTooFast = "weight_gain_too_fast"
    static let weightGainFast = "weight_gain_fast"
    static let deficitCapped = "deficit_capped"
    static let language = "language"
    static let systemDefault = "system_default"
    static let languageRestart = "language_restart"
    static let proteinChicken = "protein_chicken"
    static let proteinFish = "protein_fish"
    static let proteinBeef = "protein_beef"
    static let proteinEgg = "protein_egg"
    static let proteinLegume = "protein_legume"
    static let proteinDairy = "protein_dairy"

    // Days
    static let monday = "monday"
    static let tuesday = "tuesday"
    static let wednesday = "wednesday"
    static let thursday = "thursday"
    static let friday = "friday"
    static let saturday = "saturday"
    static let sunday = "sunday"

    // Activities
    static let weights = "activity_weights"
    static let running = "activity_running"
    static let cycling = "activity_cycling"
    static let walking = "activity_walking"
    static let rest = "activity_rest"

    // Onboarding
    static let welcome = "welcome"
    static let next = "next"
    static let back = "back"
    static let start = "start"
    static let enterName = "enter_name"
    static let bodyMetrics = "body_metrics"
    static let weightGoalTitle = "weight_goal_title"
    static let intensityTitle = "intensity_title"
    static let scheduleTitle = "schedule_title"
    static let summary = "summary"

    // Insight
    static let dailyAssessment = "daily_assessment"
    static let refreshInsight = "refresh_insight"
    static let generatedAt = "generated_at"

    // DailyInsightCard
    static let analyzingInsight = "analyzing_insight"
    static let updating = "updating"
    static let insightFallback = "insight_fallback"
    static let insufficientData = "insufficient_data"
    static let updatedAt = "updated_at"
    static let qualityPrefix = "quality_prefix"

    // EditFoodEntryView
    static let food = "food"
    static let namePlaceholder = "name_placeholder"
    static let portion = "portion"
    static let nutritionValues = "nutrition_values"
    static let calorie = "calorie"
    static let proteinG = "protein_g"
    static let carbsG = "carbs_g"
    static let fatG = "fat_g"
    static let editEntry = "edit_entry"

    // WaterTrackingCard
    static let waterGoalReachedShort = "water_goal_reached_short"
    static let mlRemaining = "ml_remaining"
    static let add = "add"

    // PhotoAnalysisView
    static let notSure = "not_sure"
    static let voice = "voice"
    static let typeText = "type_text"
    static let amountOrDescription = "amount_or_description"
    static let confirmContinue = "confirm_continue"
    static let analysisError = "analysis_error"
    static let clarificationError = "clarification_error"

    // BarcodeResultView
    static let quantity = "quantity"
    static let confirmQuantity = "confirm_quantity"

    // Sprint 2 — HomeView
    static let record = "record"
    static let couldNotProcess = "could_not_process"
    static let tapMicRetry = "tap_mic_retry"
    static let analyzingMeal = "analyzing_meal"
    static let mayTakeSeconds = "may_take_seconds"
    static let reviewMeals = "review_meals"
    static let fixMeal = "fix_meal"
    static let tapMicAnswer = "tap_mic_answer"
    static let tellAboutFormat = "tell_about_format"
    static let listening = "listening"
    static let saveAll = "save_all"
    static let goalDetails = "goal_details"
    static let estWeekly = "est_weekly"
    static let extrapolatedTdee = "extrapolated_tdee"
    static let earlyMorning = "early_morning"
    static let healthkitInsufficient = "healthkit_insufficient"
    static let calculatedFormula = "calculated_formula"
    static let dayExtrapolatedFormat = "day_extrapolated_format"
    static let realtimeBurn = "realtime_burn"
    static let waitingData = "waiting_data"
    static let bmrEstimate = "bmr_estimate"
    static let healthData = "health_data"
    static let fitnessLevel = "fitness_level"
    static let weightHealth = "weight_health"
    static let formulaBreakdown = "formula_breakdown"
    static let activityMultiplier = "activity_multiplier"

    // Sprint 2 — SettingsView
    static let foodProfile = "food_profile"
    static let cookingLabel = "cooking_label"
    static let portionLabel = "portion_label"
    static let oilUsage = "oil_usage"
    static let cuisineLabel = "cuisine_label"
    static let mealsPerDay = "meals_per_day"

    // Sprint 2 — FeedbackSheet
    static let sendFeedback = "send_feedback"
    static let describeWhatHappened = "describe_what_happened"
    static let feedbackSent = "feedback_sent"
    static let autoIncluded = "auto_included"
    static let currentTab = "current_tab"
    static let sendingFeedback = "sending"

    // Sprint 2 — StatisticsView
    static let daysLabelShort = "days_label_short"
    static let bestFormat = "best_format"
    static let weeklyInsight = "weekly_insight"

    // Sprint 2 — Statistics Cards
    static let daysLogged = "days_logged"
    static let entriesLabel = "entries_label"
    static let avgShort = "avg_short"
    static let targetLabel = "target_label"
    static let highlights = "highlights"

    // Sprint 2 — PhotoAnalysisView
    static let mayTake515 = "may_take_5_15"

    // Sprint 2 — BestDayCard
    static let bestOfPeriod = "best_of_period"
    static let bestDeficitDay = "best_deficit_day"
    static let longestStreak = "longest_streak"
    static let daysShort = "days_short"
    static let consecutiveDaysLogged = "consecutive_days_logged"
    static let bestProteinDay = "best_protein_day"

    // Sprint 2 — MealInsightsCard
    static let mealInsights = "meal_insights"
    static let mealsPerDayStat = "meals_per_day_stat"
    static let kcalPerMeal = "kcal_per_meal"
    static let mostEatenCount = "most_eaten_count"
    static let mostEatenTitle = "most_eaten_title"

    // Sprint 2 — ProteinTrackingCard
    static let proteinGoalTitle = "protein_goal_title"
    static let daysOnTarget = "days_on_target"
    static let dailyAvg = "daily_avg"
    static let hitRate = "hit_rate"
    static let dailyBreakdown = "daily_breakdown"

    // Sprint 2 — ProgramSummaryView
    static let doneLower = "done_lower"
}
// swiftlint:enable type_name

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
