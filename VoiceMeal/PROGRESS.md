# VoiceMeal — Project Status & Test Guide
Last updated: April 2026

## 1. FEATURE INVENTORY

### Core Input Methods
| Feature | File(s) | Status |
|---------|---------|--------|
| Voice meal entry | HomeView.swift, SpeechService.swift, GroqService.swift | ✅ Complete |
| Photo meal analysis | PhotoAnalysisView.swift, CameraPicker.swift, GroqService.swift | ✅ Complete |
| Barcode scanning | BarcodeScannerView.swift, BarcodeResultView.swift, BarcodeService.swift | ✅ Complete |
| Manual meal editing | EditFoodEntryView.swift | ✅ Complete |
| Meal correction via voice | HomeView.swift (isCorrection flow), GroqService.swift | ✅ Complete |
| Water tracking via voice | HomeView.swift (waterMl detection) | ✅ Complete |

### Tracking & Goals
| Feature | File(s) | Status |
|---------|---------|--------|
| Daily calorie target | GoalEngine.swift, HomeView.swift | ✅ Complete |
| Macro tracking (P/C/F) | GoalEngine.swift, HomeView.swift | ✅ Complete |
| Calorie deficit tracking | GoalEngine.swift, HomeView.swift | ✅ Complete |
| Water tracking | WaterTrackingCard.swift, WaterEntry.swift, WaterGoalService.swift | ✅ Complete |
| TDEE calculation | GoalEngine.swift (Mifflin-St Jeor + activity multiplier) | ✅ Complete |
| HealthKit TDEE (burn) | HealthKitService.swift, GoalEngine.swift | ✅ Complete |
| TDEE extrapolation | HealthKitService.swift (fetchTodayBurnExtrapolated) | ✅ Complete |
| Daily snapshot persistence | DailySnapshot.swift, SnapshotService.swift | ✅ Complete |
| TDEE evening warning banner | TDEEWarningBanner.swift, HomeView.swift | ✅ Complete |
| Goal info detail sheet | HomeView.swift (showGoalInfo) | ✅ Complete |

### Plan Tab
| Feature | File(s) | Status |
|---------|---------|--------|
| Daily plan view | PlanView.swift, PlanService.swift | ✅ Complete |
| Day detail view | PlanView.swift (DayDetailView) | ✅ Complete |
| Past/future day navigation | PlanView.swift (collapsible sections) | ✅ Complete |
| Weekly summary card | PlanView.swift (weeklyCardExpanded) | ✅ Complete |
| Day status colors | DayPlan.swift (completed/exceeded/underate/missed) | ✅ Complete |

### Statistics Tab
| Feature | File(s) | Status |
|---------|---------|--------|
| Weekly statistics | StatisticsView.swift, StatisticsService.swift | ✅ Complete |
| Monthly statistics | StatisticsView.swift, StatisticsService.swift | ✅ Complete |
| Program summary | ProgramSummaryView.swift, StatisticsService.swift | ✅ Complete |
| Calorie chart | CalorieChartView.swift | ✅ Complete |
| Deficit chart | DeficitChartView.swift | ✅ Complete |
| Macro chart | MacroChartView.swift | ✅ Complete |
| Activity chart | ActivityChartView.swift | ✅ Complete |
| Streak tracking | StatisticsService.swift (currentStreak, bestStreak) | ✅ Complete |
| Weight estimate | StatisticsService.swift (deficit / 7700 kg) | ✅ Complete |
| Trend detection | StatisticsService.swift (losing/gaining/stable) | ✅ Complete |

### AI Coach
| Feature | File(s) | Status |
|---------|---------|--------|
| Daily insight | DailyInsightCard.swift, GroqService.swift | ✅ Complete |
| Weekly insight | StatisticsView.swift, GroqService.swift | ✅ Complete |
| Program insight | ProgramSummaryView.swift, GroqService.swift | ✅ Complete |
| Coach style (4 types) | CoachStyle.swift | ✅ Complete |
| Locale-aware prompts | GroqService.swift (buildNutritionExpertPrompt) | ✅ Complete |
| Personal context | UserProfile.personalContext, SettingsView.swift | ✅ Complete |

### Settings
| Feature | File(s) | Status |
|---------|---------|--------|
| Profile editing | SettingsView.swift | ✅ Complete |
| Coach style selection | SettingsView.swift | ✅ Complete |
| Personal context | SettingsView.swift (TextEditor) | ✅ Complete |
| Weight reminder | NotificationService.swift, SettingsView.swift | ✅ Complete |
| Water tracking toggle | SettingsView.swift | ✅ Complete |
| Language switching (TR/EN) | SettingsView.swift, Localizable.strings | ✅ Complete |
| HealthKit weight sync | GoalEngine.swift (syncWeight), SettingsView.swift | ✅ Complete |
| Reset onboarding | SettingsView.swift | ✅ Complete |

### Onboarding
| Feature | File(s) | Status |
|---------|---------|--------|
| Welcome + name | Step1WelcomeView.swift | ✅ Complete |
| Body metrics | Step2BodyView.swift | ✅ Complete |
| Goal weight + duration | Step3GoalView.swift | ✅ Complete |
| Intensity selection | Step4IntensityView.swift | ✅ Complete |
| Weekly schedule | Step5ScheduleView.swift | ✅ Complete |
| Summary | Step6SummaryView.swift | ✅ Complete |
| HealthKit import | OnboardingContainerView.swift (step 0) | ✅ Complete |
| Coach style selection | OnboardingContainerView.swift (step 6) | ✅ Complete |

### Widgets
| Feature | File(s) | Status |
|---------|---------|--------|
| Medium widget | VoiceMealWidget.swift (MediumWidgetView) | ✅ Complete |
| Large widget | VoiceMealWidget.swift (LargeWidgetView) | ✅ Complete |
| Lock screen widget | VoiceMealWidget.swift (LockScreenWidgetView) | ✅ Complete |
| Widget data store | WidgetDataStore.swift (App Group shared) | ✅ Complete |

### Apple Watch
| Feature | File(s) | Status |
|---------|---------|--------|
| Calorie summary page | Watch ContentView.swift (CalorieSummaryView) | ✅ Complete |
| Macro detail page | Watch ContentView.swift (MacroDetailView) | ✅ Complete |
| Meal list page | Watch ContentView.swift (MealListView) | ✅ Complete |
| Phone→Watch sync | WatchConnectivityService.swift, WatchSessionManager.swift | ✅ Complete |

### HealthKit Integration
| Feature | File(s) | Status |
|---------|---------|--------|
| Active + basal energy | HealthKitService.swift | ✅ Complete |
| VO2 Max | HealthKitService.swift | ✅ Complete |
| Body mass (weight) | HealthKitService.swift | ✅ Complete |
| Height | HealthKitService.swift | ✅ Complete |
| Sleep analysis | HealthKitService.swift (quality + deep sleep) | ✅ Complete |
| HRV (SDNN) | HealthKitService.swift (today + 7-day baseline) | ✅ Complete |
| Biological sex + age | HealthKitService.swift (for onboarding) | ✅ Complete |

---

## 2. ARCHITECTURE OVERVIEW

### Tech Stack
- **UI:** SwiftUI (iOS 17+), dark theme only
- **Persistence:** SwiftData
- **AI:** Groq API (Llama 4 Scout 17B)
- **Health:** Apple HealthKit
- **Speech:** Apple Speech Framework (SFSpeechRecognizer, tr-TR locale)
- **Barcode:** OpenFoodFacts API
- **Watch:** WatchConnectivity framework
- **Widget:** WidgetKit with App Group shared data

### Models (SwiftData)
| Model | Purpose |
|-------|---------|
| `UserProfile` | User settings, goals, schedule, preferences |
| `FoodEntry` | Individual meal records (name, amount, macros, date) |
| `WaterEntry` | Water intake records (ml, source, date) |
| `DailySnapshot` | End-of-day snapshot of targets, consumed, TDEE, health data |

### Non-persisted Models
| Model | Purpose |
|-------|---------|
| `DayPlan` | Computed daily plan with targets and status |
| `DayStat` | Computed statistics for a single day |
| `DailyLog` | Grouping helper for FoodEntry by day |
| `ProgramSummary` | Full program statistics aggregate |
| `CoachStyle` | Enum with 4 coach personalities + prompt text |
| `ParsedMeal` | Groq response: parsed food item |
| `MealParseResponse` | Groq response: full meal parse with corrections |
| `PhotoAnalysisResponse` | Groq response: photo analysis |
| `FoodProduct` | OpenFoodFacts product data |
| `WidgetData` | Codable struct for widget App Group |
| `WatchMeal` | Watch-side meal display model |

### Services
| Service | Type | Purpose |
|---------|------|---------|
| `GroqService` | @Observable | AI meal parsing, photo analysis, daily/weekly/program insights |
| `GoalEngine` | @Observable | TDEE, BMR, deficit, calorie/macro targets |
| `HealthKitService` | @Observable | All HealthKit queries (burn, weight, sleep, HRV, VO2) |
| `StatisticsService` | @Observable | Weekly/monthly stats, streaks, trends, program data |
| `PlanService` | @Observable | Generate day plans from profile + entries + snapshots |
| `WaterGoalService` | @Observable | Smart water goal calculation |
| `BarcodeService` | @Observable | OpenFoodFacts API lookup |
| `SpeechService` | ObservableObject | iOS Speech recognition |
| `SnapshotService` | Static struct | Save/fetch DailySnapshot |
| `NotificationService` | Singleton | Weight reminders, notification scheduling |
| `WatchConnectivityService` | Singleton | iPhone→Watch data sync |
| `WidgetDataStore` | Singleton | App Group UserDefaults for widget |
| `Config` | Static enum | API key from Info.plist |

### Views
```
ContentView (root)
├── OnboardingContainerView
│   ├── Step 0: HealthKit intro
│   ├── Step1WelcomeView (name)
│   ├── Step2BodyView (gender, age, height, weight)
│   ├── Step3GoalView (target weight, duration)
│   ├── Step4IntensityView (deficit %)
│   ├── Step5ScheduleView (weekly activities)
│   └── Step6SummaryView + CoachStyle
│
├── Tab 0: HomeView
│   ├── DailyInsightCard (AI coach)
│   ├── WaterTrackingCard
│   ├── TDEEWarningBanner
│   ├── MealConfirmationView (post-voice)
│   ├── PhotoAnalysisView (camera flow)
│   ├── BarcodeResultView (barcode flow)
│   │   └── BarcodeScannerView (AVFoundation camera)
│   ├── EditFoodEntryView (manual edit)
│   ├── FoodEntryRowView (meal list item)
│   └── CameraPicker (UIImagePicker wrapper)
│
├── Tab 1: PlanView
│   └── DayDetailView (inline)
│
├── Tab 2: StatisticsView
│   ├── CalorieChartView
│   ├── DeficitChartView
│   ├── MacroChartView
│   ├── ActivityChartView
│   └── ProgramSummaryView
│
└── Tab 3: SettingsView
```

### Key Data Flows

**Voice → Meal Entry:**
1. User taps mic → SpeechService starts → transcript captured
2. Transcript → GroqService.parseMeals() → MealParseResponse
3. If clarification needed → show question → user speaks again → re-parse
4. If correction → find target entry → update values
5. If normal → show MealConfirmationView → user confirms → FoodEntry saved
6. SnapshotService updates daily snapshot
7. WidgetDataStore updated → widget refreshes
8. WatchConnectivityService syncs to Watch

**Photo → Meal Entry:**
1. CameraPicker captures image → UIImage + Data
2. GroqService.analyzePhoto() → PhotoAnalysisResponse
3. If clarification → voice/text follow-up
4. Confirmed meals → FoodEntry saved

**Barcode → Meal Entry:**
1. BarcodeScannerView detects code (AVFoundation)
2. BarcodeService.fetchProduct() → OpenFoodFacts
3. BarcodeResultView shows product + portion slider/voice
4. User selects amount → macros calculated proportionally → FoodEntry saved

**TDEE Calculation:**
1. BMR via Mifflin-St Jeor formula
2. Activity multiplier from weekly schedule (1.2–1.725)
3. VO2 Max adjustment (+/- 5-10%)
4. If HealthKit burn available and > BMR → use HealthKit
5. After 40% of day passed → extrapolate HealthKit burn to full day
6. TDEE evening warning if actual < morning TDEE by >15%

**Goal Calculation:**
1. Raw deficit = (current - goal weight) × 7700 / goalDays
2. Capped at 35% of TDEE (deficit) or 20% (surplus)
3. Eating target = TDEE - cappedDeficit
4. Minimum floor = BMR × 0.85
5. Protein = 2g/kg body weight
6. Fat = 25% of calories / 9
7. Carbs = remaining calories / 4

---

## 3. TEST CHECKLIST

### Onboarding
- [ ] Fresh install shows onboarding (step 0: HealthKit intro)
- [ ] HealthKit permission request works on real device
- [ ] HealthKit auto-fills gender, age, height, weight
- [ ] Step 1: Name field required, "Devam" disabled if empty
- [ ] Step 2: Gender toggle, age stepper (15-80), height/weight sliders
- [ ] Step 3: Goal weight, duration slider, weekly loss/gain preview
- [ ] Step 3: Too aggressive warning shows when pace is unhealthy
- [ ] Step 4: Three intensity options with deficit % preview
- [ ] Step 5: Weekly schedule grid (tap to toggle activities)
- [ ] Step 5: Template buttons (Başlangıç, İleri) pre-fill
- [ ] Step 6: Coach style selection (4 options)
- [ ] Summary: All values shown correctly
- [ ] "Başla" creates UserProfile and transitions to main app
- [ ] Back navigation works at every step

### Voice Recording
- [ ] Mic button requests permissions on first use
- [ ] Recording starts, "Dinliyorum..." label shows
- [ ] Transcript updates live as user speaks
- [ ] Stop → sends to Groq → shows analyzing spinner
- [ ] Successful parse shows MealConfirmationView with name, amount, macros
- [ ] "Kaydet" saves FoodEntry + shows "Kaydedildi ✓" toast
- [ ] "Tekrar" resets flow for new recording
- [ ] Clarification: question appears, user can voice-answer
- [ ] Correction: "aslında 300 kalori" → isCorrection flow → updates existing entry
- [ ] Amount correction: "yarısını sil" → recalculates macros proportionally
- [ ] Water detection: "su içtim" → adds water entry if tracking enabled
- [ ] Multi-item: "çorba ve pilav yedim" → multiple meals in confirmation
- [ ] Error handling: network error shows message, no crash

### Photo Analysis
- [ ] Camera button checks permission, requests if needed
- [ ] Camera opens (not grey screen)
- [ ] Photo captured → PhotoAnalysisView opens
- [ ] "Yemek analiz ediliyor..." spinner shows
- [ ] Food detected: meals listed with confidence level
- [ ] "Bu doğru, devam et" saves all detected meals
- [ ] "Emin değilim" triggers clarification flow (voice or text)
- [ ] Clarification → re-analyzes with context → updated results
- [ ] "Tekrar Çek" dismisses and reopens camera
- [ ] Simulator shows error message (camera unavailable)

### Barcode Scanner
- [ ] Barcode button opens scanner camera
- [ ] Scan line animation visible
- [ ] Valid barcode detected → "Ürün aranıyor..." loading
- [ ] Product found: name, brand, package, per-100g values shown
- [ ] Portion slider adjusts calories/macros proportionally
- [ ] ml/g unit auto-detected from product quantity field
- [ ] Voice input: "yarım paket" → parses amount
- [ ] Custom amount text field works
- [ ] "Kaydet" saves with calculated values
- [ ] Product not found: "Bu barkod veritabanında yok" message
- [ ] "Sesle Anlat" fallback → voice recording for unrecognized products

### Daily Target Card (HomeView)
- [ ] Eating target shows goal, eaten, remaining
- [ ] Progress ring fills based on eaten/goal ratio
- [ ] Macros (P/C/F) show consumed / target with progress bars
- [ ] Calorie deficit shows actual vs target
- [ ] Values update immediately after meal entry
- [ ] Goal info (ℹ️) sheet shows TDEE details, BMR, multiplier, deficit breakdown
- [ ] TDEE confidence label shows (Düşük/Orta/Yüksek)
- [ ] HealthKit burn reflected in TDEE when available
- [ ] Exceeded eating target shows orange/red indicators

### TDEE Warning Banner
- [ ] Shows between 17:00-19:00 if TDEE dropped >15% from morning
- [ ] Workout scenario: informational, "Tamam" dismisses
- [ ] No-workout scenario: offers updated eating goal, "Hedefi Güncelle" / "Kalsın"
- [ ] Does not reappear after dismissal

### Today's Meals List
- [ ] Meals listed chronologically with emoji, name, amount, calories
- [ ] Swipe to delete with confirmation alert
- [ ] Tap to edit → EditFoodEntryView
- [ ] Edit saves changes, list updates
- [ ] Delete removes entry, totals recalculate

### Plan Tab
- [ ] Today highlighted at center of visible days
- [ ] 3 days before/after today shown by default
- [ ] "Önceki günler" / "Sonraki günler" expand sections
- [ ] Each day shows: activities, consumed/target, status emoji
- [ ] Day status: ✅ completed (80%+ deficit), ⚠️ exceeded, ❌ underate, ⬜ missed, 📋 planned
- [ ] Tap day → DayDetailView with meals, macros, deficit breakdown
- [ ] Weekly summary card shows total deficit, expandable
- [ ] Past days use snapshot data (locked targets)
- [ ] Future days use current profile calculations

### Statistics Tab
- [ ] Segmented control: Haftalık / Aylık / Program
- [ ] Weekly: calorie chart (7 days), excludes today from averages
- [ ] Weekly: streak count (consecutive 80%+ deficit days)
- [ ] Weekly: weight estimate from deficit sum / 7700
- [ ] Weekly: trend (losing/gaining/stable from last 3 days)
- [ ] Weekly insight: AI generates at end of week, cached
- [ ] Monthly: 30-day chart, cumulative deficit
- [ ] Monthly: "2 hafta veri gerekli" if insufficient data
- [ ] Program: full program stats from createdAt to now
- [ ] Program: on-track indicator (behind/near/ahead)
- [ ] Program: best day / worst day
- [ ] Program: adherence %, workout days, streak
- [ ] Program: AI insight (cached per program stats)
- [ ] Charts render with correct colors and labels
- [ ] Macro averages shown (P/C/F)
- [ ] Activity distribution pie chart

### Settings
- [ ] All profile fields load from saved UserProfile
- [ ] Name, gender, age, height, weight editable
- [ ] Weight slider shows 2-decimal precision (0.1 step)
- [ ] Coach style: 4 options with radio selection
- [ ] Personal context: TextEditor saves free-text notes
- [ ] Weight reminder toggle + days stepper (1-7) + time picker
- [ ] Water tracking toggle
- [ ] Water auto-calculate toggle + manual ml slider
- [ ] Language: System / Türkçe / English segmented
- [ ] Language change shows restart alert
- [ ] Save button persists all changes
- [ ] "Kaydedildi" toast appears
- [ ] HealthKit weight conflict alert if >0.5kg difference
- [ ] Reset onboarding: confirmation → deletes profile → shows onboarding

### Widget
- [ ] Medium widget: remaining kcal, deficit, water % with progress bars
- [ ] Large widget: same + detailed progress rows + last updated time
- [ ] Lock screen widget: 3-column compact (calories, deficit, water)
- [ ] Data updates via App Group after each meal entry
- [ ] Widget refreshes every 15 minutes
- [ ] Widget respects app language (TR/EN)

### Apple Watch
- [ ] Page 1: Calorie ring (eaten/goal), remaining, deficit
- [ ] Page 2: Macro bars (protein, carbs, fat) with targets
- [ ] Page 3: Meal list with name, macros, calories
- [ ] "iPhone'dan veri bekleniyor" when no data
- [ ] Data syncs via WatchConnectivity (message + applicationContext)
- [ ] Data updates after meal entry on iPhone

### AI Coach
- [ ] Daily insight generates based on time of day
- [ ] Morning: plan + motivate, Midday: progress, Evening: dinner guidance, Night: summary
- [ ] Coach style affects tone (supportive/motivational/drill/scientific)
- [ ] Personal context is included in all AI prompts
- [ ] Locale-aware prompts adapt to user's region
- [ ] Language matches app language (TR/EN)
- [ ] Weekly insight generates (cached per week)
- [ ] Program insight generates (cached per summary)
- [ ] Insight shows "de güncellendi" timestamp
- [ ] Refresh button regenerates insight
- [ ] HRV, sleep, activities data included in daily insight

### Notifications
- [ ] Permission requested on first launch
- [ ] Weight reminder fires at configured time
- [ ] Reminder skipped if recent HealthKit weight exists
- [ ] Reminder re-scheduled after settings save
- [ ] Notifications shown as banner + sound when app is foreground

### i18n (Internationalization)
- [ ] All UI strings in Localizable.strings for TR and EN
- [ ] Language toggle in settings changes all strings
- [ ] Groq responds in correct language (languageInstruction appended)
- [ ] Widget labels switch language
- [ ] Notification text switches language
- [ ] Onboarding text switches language
- [ ] Watch app currently Turkish-only (hardcoded strings)

### Background & Lifecycle
- [ ] 5 minutes in background → returns to HomeView (tab 0)
- [ ] Scene phase changes tracked correctly
- [ ] Watch sync triggered on profile update and meal entry

---

## 4. KNOWN ISSUES

- **Watch app strings hardcoded in Turkish** — Watch ContentView.swift has "Kalan", "Açık", "Bugün", "Henüz kayıt yok" etc. hardcoded, not localized
- **SpeechService locale hardcoded to tr-TR** — SpeechService.swift line 18: `SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))` — won't recognize English speech
- **Photo analysis uses Groq** — GroqService photo endpoint sends image via base64 to standard chat completion, which may not work optimally with Llama models for vision tasks
- **No offline fallback** — All AI features require internet; no graceful degradation for offline use
- **Weight estimate includes gain direction** — `estimatedWeightLostWeekKg` naming implies loss but formula works for gain too (returns negative)
- **Item.swift unused** — Default Xcode template file still in project

---

## 5. PENDING / FUTURE

- **App Store preparation** — Screenshots, description, review guidelines
- **Premium features** — Water tracking currently behind "Premium" section label but no paywall
- **More languages** — Locale-aware prompts support 15+ regions but only TR/EN UI strings exist
- **Watch app localization** — Hardcoded Turkish strings need Localizable.strings
- **SpeechService locale** — Should respect appLanguage for English users
- **Offline mode** — Cache recent AI responses, allow manual entry without network
- **Food history / favorites** — Quick re-entry of common meals
- **Export data** — CSV/PDF export of nutrition history
- **Social features** — Share progress, challenges
- **iPad support** — Layout optimizations for larger screens

---

## 6. KEY CONSTANTS

| Constant | Value |
|----------|-------|
| App Group | `group.indio.VoiceMeal` |
| Bundle ID | `indio.VoiceMeal` |
| Widget Bundle ID | `indio.VoiceMeal.VoiceMealWidget` |
| Groq Model | `meta-llama/llama-4-scout-17b-16e-instruct` |
| Groq Endpoint | `https://api.groq.com/openai/v1/chat/completions` |
| Barcode API | `https://world.openfoodfacts.org/api/v0/product/{code}.json` |
| API Key Source | `Config.xcconfig` → `GROQ_API_KEY` → `Info.plist` |
| Min iOS | 17.0 |
| BMR Formula | Mifflin-St Jeor |
| Protein Target | 2.0g per kg body weight |
| Fat Target | 25% of daily calories |
| Max Deficit Cap | 35% of TDEE |
| Max Surplus Cap | 20% of TDEE |
| Min Calorie Floor | BMR × 0.85 |
| Weight Change | 7700 kcal = 1 kg |
| TDEE Extrapolation | After 40% of day, capped at BMR × 2.5 |
| Streak Threshold | ≥80% of target deficit |
| Background Tab Reset | 5 minutes (300 seconds) |
| Widget Refresh | Every 15 minutes |
| Speech Locale | `tr-TR` (hardcoded) |
| Theme Accent | `#6C63FF` |

---

## 7. FILE INVENTORY (52 Swift files)

### Models (6)
- `UserProfile.swift` — User settings, goals, schedule, coach style, personal context
- `FoodEntry.swift` — Meal record (name, amount, calories, P/C/F, date)
- `WaterEntry.swift` — Water intake record (ml, source, date)
- `DailySnapshot.swift` — Daily snapshot with targets, consumed, health data
- `DailyLog.swift` — Helper to group FoodEntry by day
- `DayPlan.swift` — Computed daily plan with status
- `CoachStyle.swift` — 4 coach personalities with TR/EN prompts

### Services (11)
- `GroqService.swift` — AI: meal parsing, photo, insights (locale-aware)
- `GoalEngine.swift` — TDEE, BMR, deficit, macro targets
- `HealthKitService.swift` — All HealthKit queries
- `StatisticsService.swift` — Weekly/monthly/program stats
- `PlanService.swift` — Day plan generation
- `SpeechService.swift` — iOS speech recognition
- `BarcodeService.swift` — OpenFoodFacts lookup
- `NotificationService.swift` — Weight reminders
- `SnapshotService.swift` — Daily snapshot CRUD
- `WaterGoalService.swift` — Smart water goal calculation
- `WatchConnectivityService.swift` — iPhone→Watch sync

### Views (19)
- `HomeView.swift` — Main recording tab, meal list, target cards
- `PlanView.swift` — Plan tab with day plans
- `StatisticsView.swift` — Stats tab (weekly/monthly/program)
- `ProgramSummaryView.swift` — Program overview with AI insight
- `SettingsView.swift` — All settings
- `DailyInsightCard.swift` — AI daily insight card
- `WaterTrackingCard.swift` — Water tracking UI
- `TDEEWarningBanner.swift` — Evening TDEE warning
- `PhotoAnalysisView.swift` — Photo meal analysis flow
- `BarcodeResultView.swift` — Barcode product result
- `BarcodeScannerView.swift` — AVFoundation barcode camera
- `MealConfirmationView.swift` — Post-voice meal confirmation + emoji helper
- `EditFoodEntryView.swift` — Manual meal editing
- `CameraPicker.swift` — UIImagePicker wrapper
- `FoodEntryRowView.swift` — Meal list row component
- Onboarding: Step1Welcome, Step2Body, Step3Goal, Step4Intensity, Step5Schedule, Step6Summary, OnboardingContainer

### Utils (3)
- `Config.swift` — API key from Info.plist
- `Theme.swift` — Colors, fonts, card modifiers
- `LocalizationKeys.swift` — Type-safe localization key enum (L.xxx)

### Shared (1)
- `WidgetDataStore.swift` — App Group data for widget

### Widget (2)
- `VoiceMealWidget.swift` — Medium, Large, Lock Screen widgets
- `WidgetDataStore.swift` — Widget copy of shared data store

### Watch (3)
- `VoiceMealWatchApp.swift` — Watch app entry point
- `ContentView.swift` — 3-page Watch UI (calories, macros, meals)
- `WatchSessionManager.swift` — Watch-side data receiver

### Resources
- `en.lproj/Localizable.strings` — 490+ English strings
- `tr.lproj/Localizable.strings` — 520+ Turkish strings
- `Config.xcconfig` — GROQ_API_KEY
