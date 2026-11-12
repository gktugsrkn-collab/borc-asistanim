# BORÇ ASİSTANIM — Flutter Android başlangıç projesi

Bu depo, çevrimdışı çalışan ilk sürüm (MVP) kaynak kodunu ve GitHub Actions ile APK derleme iş akışını içerir.

## Bu sürümde çalışan özellikler
- Borç/kredi/kredi kartı kaydı
- Kredi için aylık taksitlerin takvimde otomatik oluşturulması
- Kredi kartı asgari ödeme kaydı ve aylık takvim görünümü
- Gelir ve gider kaydı, kategori ve tarih seçimi
- Borç bakiyesi ve ödenen taksit sayacı
- Yaklaşan ödemeler, aylık ödeme toplamı ve temel nakit akışı özeti
- Verilerin cihazda SharedPreferences ile saklanması
- Koyu lacivert ve turkuaz ağırlıklı arayüz

## APK nasıl alınır? (GitHub)
1. GitHub'da `borc-asistanim` adlı boş bir repository oluştur.
2. Bu ZIP içindeki dosyaları çıkar ve repository'nin köküne yükle.
3. `main` dalına gönder.
4. GitHub deposunda **Actions** sekmesini aç.
5. **Android APK** iş akışını seçip **Run workflow** çalıştır (push sonrası da otomatik çalışır).
6. İşlem tamamlanınca ilgili çalıştırmayı aç, **Artifacts** bölümünden `borc-asistanim-apk` dosyasını indir.
7. ZIP içindeki `app-release.apk` dosyasını Android telefona aktar ve kur. Gerekirse Android ayarlarından bu kaynağa uygulama yükleme izni ver.

## Yerel derleme
Flutter stable ve Android SDK kurulu bilgisayarda:
```bash
flutter create --platforms=android --org com.borcasistanim .
flutter pub get
flutter analyze
flutter build apk --release
```
APK yolu: `build/app/outputs/flutter-apk/app-release.apk`

## Önemli kapsam ve doğruluk notları
Bu, çalıştırılabilir ilk MVP'dir; tam üretim sürümü değildir. Bu ortamda Flutter/Android SDK bulunmadığı için APK burada derlenmedi. GitHub Actions, Android proje dosyalarını oluşturup APK'yı derlemek üzere yapılandırılmıştır.

- Bu sürümde taksit planı, girilen aylık taksit ve ilk ödeme tarihine göre takvim kayıtları üretir. Bankanın resmi ödeme planı yerine geçmez.
- Kredi kartı takvimi, girilen asgari tutarı sonraki aylara örnek olarak tekrarlar; ekstre kesim tarihi, dönem borcu ve değişken asgari tutar henüz modellenmemiştir.
- Bildirimler, arka planda otomatik hatırlatma, PDF/CSV raporu, banka bağlantısı, bulut yedekleme ve yapay zekâ bağlantısı henüz bu MVP'de yoktur.
- Faiz oranı alanı şu an kayıt amaçlıdır; erken kapama, bileşik faiz, vergi/ücret ve mevzuat hesaplaması yapıldığı anlamına gelmez.
- Analiz ekranı yalnızca girilen gelir/gider ve borç kayıtlarına göre basit nakit akışı özeti sunar. Finansal kararlar için banka ödeme planını ve güncel koşulları doğrulayın.

## Güvenlik
Uygulamaya gerçek banka şifresi, kart numarası, CVV veya internet bankacılığı kimlik bilgisi girmeyin. Veriler cihaz üzerinde tutulur; cihaz güvenliği ve yedekleme kullanıcı sorumluluğundadır.
