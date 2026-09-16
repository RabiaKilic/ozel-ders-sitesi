Gökhan Kılıç - Matematik & Geometri Özel Ders Sitesi
=====================================================

İÇİNDEKİLER
- index.html          -> Sitenin kendisi (tarayıcıda açılır / GitHub Pages'e yüklenir)
- supabase-semasi.sql  -> Supabase SQL Editor'de bir kere çalıştırılacak veritabanı şeması

KURULUM DURUMU
- Supabase proje bağlantısı (URL + anon key) index.html içine işlenmiştir.
- SQL şemasını Supabase SQL Editor'de çalıştırman gerekiyor (henüz yapmadıysan).
- Authentication > Users bölümünden admin hesabını eklemen gerekiyor:
  gokhanhoca77@gmail.com şifresiyle, "Auto Confirm User" işaretli.

GITHUB'A YÜKLEME
cmd içinde bu klasörde şu komutları çalıştır:
  git init
  git add .
  git commit -m "İlk yükleme - özel ders randevu sitesi"
  git branch -M main
  git remote add origin https://github.com/RabiaKilic/ozel-ders-sitesi.git
  git push -u origin main

Sonra GitHub'da repo > Settings > Pages > Branch: main, / (root) seçip
siteyi https://rabiakilic.github.io/ozel-ders-sitesi/ adresinde yayınlayabilirsin.
