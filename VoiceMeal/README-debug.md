# Voice Flow Debug Logging

Eklendi: Sprint Debug (Build 6 öncesi). Production'a gitmemeli — `git revert` ile silinecek.

## Nerede ne var

| Dosya | Fonksiyon | Ne logluyor |
|-------|-----------|-------------|
| `HomeView+MealEntrySection.swift` | `sendToGroq()` | Transcript, appLanguage, clarificationAttempt, isSecondClarification |
| `HomeView+MealEntrySection.swift` | `sendToGroq()` | Counter değişimi (clarificationAttempt → N) |
| `HomeView+MealEntrySection.swift` | `runNormalMealParse()` | Fonksiyon girişi, parseMeals'a giden parametreler |
| `HomeView+MealEntrySection.swift` | `runNormalMealParse()` | Tam response (meals, clarification, isGuess, waterMl, isCorrection) |
| `HomeView+MealEntrySection.swift` | `runNormalMealParse()` | Her UI branch'i (🟢🟡🎯💧🔴) |
| `HomeView+MealEntrySection.swift` | `runNormalMealParse()` | Empty response dedektörü (⚠️⚠️⚠️) |
| `GroqService.swift` | `parseMealsSingleAttempt()` | System prompt (ilk 500 + son 500 karakter) |
| `GroqService.swift` | `parseMealsSingleAttempt()` | User prompt (transcript) |
| `GroqService.swift` | `parseMealsSingleAttempt()` | Ham API response (ilk 1000 karakter) |
| `GroqService.swift` | `parseMealsSingleAttempt()` | Decode sonucu (✅ OK veya ❌ hata) |

## Log prefix'leri

```
[VOICE]         sendToGroq giriş özeti
[GROQ]          parseMeals çağrısı + response özeti
[GROQ-PROMPT]   System prompt detayı
[GROQ-USER]     User prompt
[GROQ-RAW]      Ham JSON response
[GROQ-PARSED]   Decode sonucu
[UI]            Hangi UI branch'ine girildi
[COUNTER]       clarificationAttempt değişimi
[EMPTY RESPONSE] Bug tespit — hiçbir branch tetiklenmiyor
```

## Nasıl test edilir

1. Xcode → USB cihaz → Run
2. Debug Area → Activate Console (Cmd+Shift+Y)
3. Senaryo çalıştır, Console'u kopyala

**Test senaryoları:**
- `"çorba içtim"` → 🟡 Clarification bekleniyor, meals boş
- `"bir şeyler yedim"` → herhangi bir branch veya ⚠️ empty response
- `"iki yumurta yedim"` → 🟢 Normal parse
- `"tarhana çorbası içtim"` → 🟢 Normal parse (Sprint A liste)

## Silmek için

```bash
git revert <bu commit'in hash'i>
```

veya manüel: `[VOICE]`, `[GROQ]`, `[UI]`, `[COUNTER]`, `[EMPTY RESPONSE]` prefix'li
tüm `#if DEBUG ... #endif` bloklarını kaldır.

Lokasyonlar:
- `VoiceMeal/Views/HomeView+MealEntrySection.swift` — `sendToGroq`, `runNormalMealParse`
- `VoiceMeal/Services/GroqService.swift` — `parseMealsSingleAttempt`
