# VoiceMeal — Sprint Progress

## Tech Stack
- SwiftUI + SwiftData (iOS 17+)
- Apple Speech Framework
- Groq API (llama-3.3-70b-versatile)
- Apple HealthKit (HRV, uyku, VO2Max, kilo, aktif/dinlenme enerji)

## Tamamlanan Sprintler
- Sprint 0: Proje kurulum, klasör yapısı, GitHub
- Sprint 1: Mikrofon + Speech-to-Text (Türkçe)
- Sprint 2: Groq API + JSON parse + kalori tahmini
- Sprint 3: SwiftData kayıt + günlük özet + geçmiş
- Sprint 4: Onboarding + çoklu aktivite seçimi
- Sprint 5: GoalEngine + günlük hedef kartı
- Sprint 6: Apple Health + BMR fallback
- Sprint 7: Takvim ekranı (geçmiş + bugün + gelecek)
- Sprint 8: VO2Max + extrapolasyon + DailySnapshot sistemi
- Sprint 9: HRV + uyku + Groq insight kartı + kilo tahmini
- Sprint 10: Ayarlar ekranı (profil düzenleme)
- Sprint 11: Akşam bildirimi + Groq yemek önerisi
- Sprint 12: Yemek kaydı düzenleme (sesle + manuel + silme)
- Sprint 13: İstatistik sekmesi + grafikler
- Sprint 14: UI Polish (dark premium tasarım)
- Sprint 15: Program özeti (başlangıçtan bugüne)

## Bekleyen Sprintler
- Sprint 16: Widget (ana ekran, kalan kalori)
- Sprint 17: Uçtan uca test + bug fix
- Sprint 18: App Store hazırlığı (ikon, splash, metadata)

## Mimari Notlar
- GoalEngine: tek instance, EnvironmentObject olarak paylaşılıyor
- DailySnapshot: her gün kapanışta kaydediliyor (midnight listener)
- TDEE: sabah 09:40 öncesi formül, sonrası HealthKit extrapolasyon
- HRV: 7 günlük baseline, bugünkü değerle karşılaştırılıyor
- Groq insight: günde 1 kez üretiliyor (07:00-11:00 arası)
- Meal suggestion: 2 saatte 1 cache, 16:00 ve 21:30 bildirimleri
- PlanService: geçmiş → snapshot, bugün → GoalEngine, gelecek → formül

## Bilinen Açık Konular
- 4-5 gün gerçek kullanım sonrası uçtan uca test yapılacak
- Widget henüz eklenmedi
- App Store hazırlığı yapılmadı

## Kullanıcı Tercihleri
- Protein kaynakları: tavuk, balık, dana, yumurta, baklagil, süt ürünleri
- Bildirim 1: 16:00 (akşam yemeği planı)
- Bildirim 2: 21:30 (gece kapanış atıştırmalığı)
- Hedef: kilo vermek
- Zorluk: orta
- Metrik sistem (kg, cm)
