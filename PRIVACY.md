# VoiceMeal — Gizlilik Politikası / Privacy Policy

**Son Güncelleme / Last Updated:** 23 Nisan 2026 / April 23, 2026

---

## 🇹🇷 Türkçe

### Genel Bilgi

VoiceMeal, sesli komutlarla yemek ve kalori takibi yapmanızı sağlayan bir iOS uygulamasıdır. Gizliliğinizi ciddiye alıyoruz. Bu politika, hangi verilerin toplandığını, nasıl kullanıldığını ve nerede saklandığını açıkça anlatır.

**Kısa özet:** Verileriniz çoğunlukla cihazınızda kalır. Bulut sunucumuz yok. Yapay zeka analizi için Groq'a kısa süreli metin gönderilir. Hata takibi için Sentry kullanılır. Siz geri bildirim gönderdiğinizde EmailJS aracılığıyla geliştiriciye ulaşır.

### Topladığımız Veriler

**1. Cihazda saklanan veriler (yerel):**
- Profil bilgileri: İsim, yaş, boy, kilo, cinsiyet, aktivite seviyesi, hedef kilo (varsa)
- Yemek kayıtları: Ses transkripti sonucu oluşan yemek verileri (ad, porsiyon, kalori, makrolar)
- Günlük özetler (DailySnapshot): Günlük kalori, protein, TDEE verileri
- Beslenme raporları: Haftalık ve aylık AI tarafından üretilen yorumlar
- Uygulama ayarları (tema, dil, bildirim tercihleri)

Bu veriler sadece cihazınızdaki SwiftData veritabanında tutulur. Bulutumuza gönderilmez.

**2. Üçüncü taraf servislerine gönderilen veriler:**

**Groq (AI yemek analizi):**
- Ne gönderilir: Ses kaydınızdan üretilen metin transkripti + AI prompt
- Neden: Yemeği analiz edip kalori/makro hesabı için
- Saklanır mı: Groq'un saklama politikasına tabi — Groq API kullanım şartları: https://groq.com/privacy-policy/
- Ses dosyanız GÖNDERİLMEZ, sadece transkript metni

**Apple Speech Recognition (transkripsiyon):**
- Ne gönderilir: Ses kaydınız
- Neden: Sesli komutu metne çevirmek için
- Nerede işlenir: iOS 17+'da büyük çoğunlukla cihazda, bazen Apple sunucularına gönderilir
- Apple politikası: https://www.apple.com/legal/privacy/

**Sentry (hata takibi):**
- Ne gönderilir: Uygulama hatası olduğunda crash raporları, teknik log'lar, anonim cihaz bilgisi (iOS sürümü, model)
- Neden: Hataları tespit edip düzeltmek için
- Kişisel içerik (yemek isimleri, transkript) gönderilmez, sadece teknik hata bilgisi
- Sentry politikası: https://sentry.io/privacy/

**EmailJS (geri bildirim):**
- Ne zaman gönderilir: Siz telefonu sallayıp geri bildirim gönderdiğinizde VEYA "Sorun Bildir" butonuna bastığınızda
- Ne gönderilir: Sizin yazdığınız geri bildirim metni + son voice session'ın detayları (transkript, parse sonucu, süreler) + anonim cihaz bilgisi
- Neden: Geliştiricinin uygulamayı iyileştirmesi için
- Beta süresince daha detaylı log gönderilir, bu durum uygulama içinde açıkça belirtilmiştir

**3. HealthKit (opsiyonel):**
- Ne erişilir: İzin verirseniz kilo, boy gibi sağlık verileri
- Ne gönderilir: Hiçbir yere — sadece cihazınızda okunur ve uygulamaya senkronize edilir
- İzni istediğiniz zaman iPhone Ayarlar > Sağlık > Veri Erişimi'nden kaldırabilirsiniz

### Verilerinizin Saklanma Süresi

- **Cihazda saklanan veriler:** Siz uygulamayı silene kadar kalır. Uygulamayı silerseniz tüm veriler silinir.
- **Groq'a gönderilen istekler:** Groq'un kendi politikasına tabi (genellikle kısa süre)
- **Sentry hata logları:** 90 gün
- **EmailJS geri bildirim mailleri:** Geliştiricinin inbox'ında saklanır — istek üzerine silinir

### Üçüncü Taraflarla Paylaşım

Verilerinizi reklam amacıyla kimseye satmıyoruz. Yukarıda belirtilen servisler (Groq, Sentry, Apple, EmailJS) dışında kimseye veri aktarılmaz.

### Çocukların Gizliliği

VoiceMeal 13 yaş altı kullanıcılara yönelik değildir. Bilerek 13 yaş altı kullanıcılardan kişisel veri toplanmaz.

### Haklarınız

Avrupa Birliği (GDPR) veya Türkiye (KVKK) kapsamında aşağıdaki haklara sahipsiniz:
- **Erişim hakkı:** Hangi verilerinizi tuttuğumuzu sorma
- **Silme hakkı:** Verilerinizin silinmesini isteme (uygulamayı silerek veya bize ulaşarak)
- **Düzeltme hakkı:** Yanlış verilerin düzeltilmesini isteme
- **Veri taşıma hakkı:** Verilerinizin bir kopyasını talep etme

Bu hakları kullanmak için aşağıdaki iletişim bilgilerinden ulaşabilirsiniz.

### Beta Dönemi Özel Notu

Uygulama şu anda **beta aşamasındadır**. Beta süresince hata ayıklama amacıyla daha detaylı log'lar toplanabilir (voice session transkriptleri, Groq yanıtları, süreler vb.). Bu log'lar yalnızca uygulama iyileştirilmesi için kullanılır ve üçüncü taraflarla paylaşılmaz.

### Değişiklikler

Bu politika zaman zaman güncellenebilir. Önemli değişikliklerde uygulamada bildirim yapılır.

### İletişim

Gizlilik soruları veya veri silme talepleri için:

**E-posta:** alitarakci2@gmail.com
**GitHub:** https://github.com/alitarakci2/voicemeal

---

## 🇬🇧 English

### Overview

VoiceMeal is an iOS app that lets you track meals and calories via voice commands. We take your privacy seriously. This policy explains what data we collect, how we use it, and where it's stored.

**TL;DR:** Your data mostly stays on your device. We have no cloud server. AI analysis sends short text snippets to Groq temporarily. Sentry is used for crash reporting. When you send feedback, it reaches the developer via EmailJS.

### Data We Collect

**1. On-device data (local):**
- Profile: Name, age, height, weight, gender, activity level, goal weight (if any)
- Meal logs: Foods parsed from your voice transcripts (name, portion, calories, macros)
- Daily snapshots: Daily calorie, protein, TDEE data
- Nutrition reports: Weekly and monthly AI-generated summaries
- App settings (theme, language, notifications)

This data is stored only in the SwiftData database on your device. It is NOT uploaded to our cloud (we don't have one).

**2. Data sent to third-party services:**

**Groq (AI meal analysis):**
- What's sent: Text transcript from your voice recording + AI prompt
- Why: To analyze meals and estimate calories/macros
- Retention: Subject to Groq's policy — https://groq.com/privacy-policy/
- Your raw audio is NEVER sent, only the transcribed text

**Apple Speech Recognition (transcription):**
- What's sent: Your voice recording
- Why: To convert speech to text
- Where processed: Mostly on-device in iOS 17+, sometimes Apple servers
- Apple policy: https://www.apple.com/legal/privacy/

**Sentry (crash reporting):**
- What's sent: Crash logs, technical breadcrumbs, anonymous device info (iOS version, model) when errors occur
- Why: To detect and fix bugs
- Personal content (meal names, transcripts) is NOT sent, only technical error data
- Sentry policy: https://sentry.io/privacy/

**EmailJS (feedback):**
- When sent: When you shake your phone to send feedback OR tap "Report Issue"
- What's sent: Your feedback text + last voice session details (transcript, parse result, durations) + anonymous device info
- Why: So the developer can improve the app
- During beta, more detailed logs are sent; this is clearly indicated in-app

**3. HealthKit (optional):**
- What's accessed: Health data like weight, height (with your permission)
- Where sent: Nowhere — read locally on device and synced into the app
- You can revoke permission anytime via iPhone Settings > Health > Data Access

### Data Retention

- **On-device data:** Kept until you delete the app. Deleting the app deletes all data.
- **Groq requests:** Subject to Groq's own policy (typically short-term)
- **Sentry error logs:** 90 days
- **EmailJS feedback emails:** Stored in developer's inbox — deleted upon request

### Third-Party Sharing

We do NOT sell your data for advertising. Data is not shared with anyone outside the services listed above (Groq, Sentry, Apple, EmailJS).

### Children's Privacy

VoiceMeal is not directed at children under 13. We do not knowingly collect personal data from users under 13.

### Your Rights

Under EU GDPR or Turkey KVKK, you have:
- **Right to access:** Ask what data we hold about you
- **Right to deletion:** Request data deletion (by deleting the app or contacting us)
- **Right to correction:** Request correction of inaccurate data
- **Right to portability:** Request a copy of your data

To exercise these rights, use the contact info below.

### Beta Period Note

The app is currently **in beta**. During the beta period, we may collect more detailed logs for debugging purposes (voice session transcripts, Groq responses, timings, etc.). These logs are used solely for app improvement and never shared with third parties.

### Changes

This policy may be updated from time to time. Significant changes will be notified in the app.

### Contact

For privacy questions or data deletion requests:

**Email:** alitarakci2@gmail.com
**GitHub:** https://github.com/alitarakci2/voicemeal

---

**Effective Date:** April 23, 2026
