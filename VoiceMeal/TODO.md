# VoiceMeal — TODO

Biriktirilen görevler. Ne zaman vakit olursa, buradan alıp nokta atış çalışırız.

---

## Lokalizasyon

### Watch extension'ı gerçek `.strings` tabanına taşı
**Durum:** Şu an `watchString(tr, en)` helper'ı ile inline ternary kullanıyor (`VoiceMealWatch Watch App/ContentView.swift`). Ana uygulama `L.xxx.localized` kuralını kullanıyor; watch bundan sapıyor.

**Yapılacak:**
- [ ] `VoiceMealWatch Watch App/` hedefine `Localizable.strings` bundle ekle (tr.lproj + en.lproj)
- [ ] `watchString("Kalan", "Left")`, `watchString("Açık", "Deficit")`, vb. çağrıları `NSLocalizedString("key", comment: "")` veya `L.xxx.localized` eşdeğerine çevir
- [ ] Mevcut stringleri `.strings` dosyalarına taşı: `Kalan/Left`, `Açık/Deficit`, `Fazla/Surplus`, `Denge/Balance`, `Protein`, `Karb/Carbs`, `Yağ/Fat`, `Bugün/Today`, `öğün/meals`, `Henüz kayıt yok/No entries yet`, `iPhone'dan veri bekleniyor/Waiting for iPhone data`
- [ ] `watchString` helper'ını kaldır

### Widget extension'ını gerçek `.strings` tabanına taşı
**Durum:** `VoiceMealWidget/VoiceMealWidget.swift` dosyası baştan sona `widgetLanguage == "en" ? "x" : "y"` ternary'leri ile dolu. Ana uygulamaya uyumsuz.

**Yapılacak:**
- [ ] `VoiceMealWidget/` hedefine `Localizable.strings` bundle ekle (tr.lproj + en.lproj)
- [ ] Hardcode string'leri `.strings`'e taşı: `left/kaldi`, `Eating Goal/Yeme Hedefi`, `Water/Su`, `water/su`, `Calorie Deficit/Kalori Açığı`, `Calorie Surplus/Kalori Fazlası`, `Calorie Balance/Kalori Dengesi`, `deficit/açık`, `surplus/fazla`, `balance/denge`, widget configuration description'ları
- [ ] `widgetLanguage` helper'ı kalabilir (hangi dili kullanacağını seçmek için) ama display string'leri artık `.strings`'ten gelsin
- [ ] Türkçe tarafta Turkish karakterleri (`ı`, `ğ`, `ş`) doğru kullan — mevcut widget kodunda `Kalori Acigi`, `Detayli`, `Gunluk` gibi ASCII yazımlar var; `.strings`'e taşırken düzelt

### İki ekstansiyonda ortak CalorieGapCopy
**Durum:** `CalorieGapCopy` sadece ana uygulama target'ında; Watch ve Widget kendi mini mode helper'larını duplike ediyor.

**Yapılacak:**
- [ ] `CalorieGapCopy.swift` ve `CalorieGapKind`'i bir Swift Package veya "Shared" framework'e taşı
- [ ] Üç target da (ana app, Watch, Widget) aynı helper'ı kullansın — kod duplikasyonu sıfırlansın
- [ ] Localization key'leri de tek yerden gelsin

---

## Refactor

### DRY refactor: Goal validation logic (3 places)
**Context:** Step3Goal (binary warning >1kg/week), Plan Settings + GoalEntrySheet (4-tier warning), both duplicated.
**Goal:** Single GoalValidator helper, consistent thresholds across all 3 entry points.
**Risk:** Changing Step3Goal binary → 4-tier may affect existing onboarding UX; needs design review.
**Priority:** Low — V2 or post-launch polish.

---

## Performans

### HomeView re-render optimization
**Durum:** HomeView ~1356 satır, 30+ `@State` ve 3 `@Query`. TextField girişi her keystroke'ta tüm body'i yeniden render ettiriyor → klavye lag.

**Yapılacak:**
- [ ] HomeView'ı küçük sub-struct'lara böl, böylece SwiftUI sadece değişen kısmı yeniden render etsin
- [ ] Özellikle TextField'ın olduğu bölümleri kendi alt View'ına çıkar

---
