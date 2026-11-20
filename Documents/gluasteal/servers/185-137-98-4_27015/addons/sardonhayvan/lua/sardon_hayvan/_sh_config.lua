-- "addons\\sardonhayvan\\lua\\sardon_hayvan\\_sh_config.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Hayvan :: ortak ayarlar. Dosya adı "_" ile başlıyor ki SardonUtil
-- alfabetik yüklemede cl_/sv_ dosyalarından önce gelsin.
--
-- Sistem: haritada admin'in koyduğu bölgeler var. Bölgeye bir oyuncu girince
-- bölgenin içinde rastgele bir noktada 1 hayvan doğar ve oyunculara saldırır.
-- Bölgede kimse kalmayınca hayvan kaybolur. Öldürülen hayvan şansa bağlı
-- Helix eşyaları düşürür (oranlar sv_ganimet.lua'da, istemciye gitmez).
--
-- Modeller: workshop 3199740881 (oyuncu modelleri; melee animasyonları var,
-- elde silah gösterilmiyor).

SardonHayvan = SardonHayvan or {}

SardonHayvan.Ayar = {
     -- Bölge kontrol aralığı (sn). Her turda oyuncu x bölge mesafe kontrolü yapılır.
     Kontrol = 1,
     -- Haritadaki toplam canlı hayvan sınırı (bölge başı sınırlardan bağımsız)
     GlobalMax = 30,
     -- Bölgede oyuncu kalmazsa hayvan bu kadar sn sonra kaybolur
     BosKalma = 30,
     -- Doğma noktası her oyuncudan en az bu kadar uzak olur (yüze doğmasın)
     MinOyuncuMesafe = 300,
     -- Hedef bölge yarıçapının bu kadar dışına çıkınca takip bırakılır
     TasmaPayi = 350,
     -- Ad / can çubuğu çizim mesafesi (istemci)
     EtiketMesafe = 700
}

/*
*   Vuruş etkileri (türlerde etki = "<id>")
*
*   Etki EtkiSure sn sürer. Etki sürerken aynı etkiyi taşıyan bir vuruş daha
*   isabet ederse süre baştan başlar (üst üste binmez, tazelenir). Farklı
*   etkiler aynı anda olabilir. Ek hasar saniyede bir verilir (türün etkiHasar'ı).
*
*   ad    : HUD yazısı           renk : ekran efekti rengi
*   yavas : hareket hızı çarpanı (yalnızca donma)
*/
SardonHayvan.EtkiSure = 7

SardonHayvan.Etkiler = {
     zehir = {ad = "Zehirlendin", renk = Color(92, 220, 70)},
     kanama = {ad = "Kanıyorsun", renk = Color(200, 18, 22)},
     yanma = {ad = "Yanıyorsun", renk = Color(255, 120, 24)},
     donma = {ad = "Donuyorsun", renk = Color(120, 200, 255), yavas = 0.6},
     elektrik = {ad = "Çarpıldın", renk = Color(255, 236, 90)}
}

/*
*   Hayvan türleri
*
*   can, hasar        : can puanı, vuruş başı hasar
*   menzil            : gövde kenarından vuruş mesafesi
*   yuruyus, kosu     : hız (birim/sn)
*   bekleme           : iki vuruş arası sn
*   yaricap, boy      : çarpışma kutusu (model ne kadar büyük olursa olsun küçük tut;
*                       kocaman kutu dar yerlerde takılır)
*   olcek             : model ölçeği (görsel + çarpışma kutusu)
*   ses               : workshop ses ön eki -> "<ses>.pain" / "<ses>.die"
*   saldirgan = false : yalnızca kendisine vurulunca saldırır
*   etki, etkiHasar   : isabet eden vuruş oyuncuya bu etkiyi bulaştırır (SardonHayvan.Etkiler);
*                       etki sürerken her saniye etkiHasar kadar ek hasar verir
*/
SardonHayvan.Turler = {
     kurt = {
          ad = "Vahşi Kurt", model = "models/echo/direwolf_pm.mdl",
          can = 120, hasar = 10, menzil = 45, yuruyus = 90, kosu = 280, bekleme = 1.0,
          yaricap = 16, boy = 40, ses = "playermodel_direwolf",
          etki = "kanama", etkiHasar = 2
     },
     kurtadam = {
          ad = "Kurt Adam", model = "models/player/sarbatore/lycan_werewolf.mdl",
          can = 320, hasar = 22, menzil = 50, yuruyus = 100, kosu = 290, bekleme = 1.1,
          yaricap = 16, boy = 72,
          etki = "kanama", etkiHasar = 4
     },
     grifon = {
          ad = "Grifon", model = "models/echo/ark/griffin_pm.mdl",
          can = 260, hasar = 18, menzil = 55, yuruyus = 95, kosu = 270, bekleme = 1.2,
          yaricap = 18, boy = 72, ses = "playermodel_griffins",
          etki = "kanama", etkiHasar = 3
     },
     mantikor = {
          ad = "Mantikor", model = "models/echo/ark/manticore_pm.mdl",
          can = 380, hasar = 26, menzil = 60, yuruyus = 95, kosu = 260, bekleme = 1.3,
          yaricap = 20, boy = 72, ses = "playermodel_manticore",
          etki = "zehir", etkiHasar = 4
     },
     ejderha = {
          ad = "Ejderha", model = "models/echo/ark/dragon_pm.mdl",
          can = 900, hasar = 38, menzil = 80, yuruyus = 90, kosu = 240, bekleme = 1.6,
          yaricap = 24, boy = 80, ses = "playermodel_dragonark",
          etki = "yanma", etkiHasar = 6
     },
     timsah = {
          ad = "Bataklık Timsahı", model = "models/echo/ark/sarco_pm.mdl",
          can = 240, hasar = 18, menzil = 55, yuruyus = 80, kosu = 230, bekleme = 1.2,
          yaricap = 18, boy = 40, ses = "playermodel_sarcos",
          etki = "kanama", etkiHasar = 3
     },
     akrep = {
          ad = "Dev Akrep", model = "models/echo/ark/scorpion_pm.mdl",
          can = 160, hasar = 14, menzil = 45, yuruyus = 90, kosu = 250, bekleme = 1.0,
          yaricap = 18, boy = 40, ses = "playermodel_scorpion",
          etki = "zehir", etkiHasar = 3
     },
     kurbaga = {
          ad = "Dev Kurbağa", model = "models/echo/ark/toad_pm.mdl",
          can = 140, hasar = 10, menzil = 45, yuruyus = 80, kosu = 220, bekleme = 1.0,
          yaricap = 18, boy = 48, ses = "playermodel_toad",
          etki = "zehir", etkiHasar = 2
     },
     akbaba = {
          ad = "Dev Akbaba", model = "models/echo/ark/argentavis_pm.mdl",
          can = 180, hasar = 14, menzil = 50, yuruyus = 90, kosu = 260, bekleme = 1.1,
          yaricap = 18, boy = 64, ses = "playermodel_argentavis",
          etki = "kanama", etkiHasar = 2
     },
     sahin = {
          ad = "Fiyort Şahini", model = "models/echo/ark/fjordhawk_pm.mdl",
          can = 60, hasar = 6, menzil = 35, yuruyus = 90, kosu = 270, bekleme = 0.8,
          yaricap = 12, boy = 18, ses = "playermodel_fjordhawk",
          etki = "kanama", etkiHasar = 1
     },
     anka = {
          ad = "Anka Kuşu", model = "models/echo/ark/phoenix_pm.mdl",
          can = 500, hasar = 20, menzil = 70, yuruyus = 90, kosu = 250, bekleme = 1.4,
          yaricap = 24, boy = 72, ses = "playermodel_phoenix", saldirgan = false,
          etki = "yanma", etkiHasar = 4
     },
     kertenkele = {
          ad = "Fener Kertenkelesi", model = "models/echo/ark/lanternlizard_pm.mdl",
          can = 80, hasar = 7, menzil = 40, yuruyus = 80, kosu = 240, bekleme = 0.9,
          yaricap = 14, boy = 22, ses = "playermodel_lanternlizard",
          etki = "yanma", etkiHasar = 1
     },
     tuykusu = {
          ad = "Tüy Kuşu", model = "models/echo/ark/lanternbird_pm.mdl",
          can = 70, hasar = 6, menzil = 40, yuruyus = 85, kosu = 250, bekleme = 0.9,
          yaricap = 14, boy = 32, ses = "playermodel_lanternbird", saldirgan = false
     },
     boa = {
          ad = "Boa Yılanı", model = "models/echo/ark/boa_pm.mdl",
          can = 150, hasar = 13, menzil = 55, yuruyus = 70, kosu = 200, bekleme = 1.1,
          yaricap = 18, boy = 24, ses = "playermodel_snake",
          etki = "zehir", etkiHasar = 2
     },
     devboa = {
          ad = "Dev Boa", model = "models/echo/ark/boa_pm_bigger.mdl",
          can = 420, hasar = 24, menzil = 70, yuruyus = 70, kosu = 210, bekleme = 1.4,
          yaricap = 24, boy = 36, ses = "playermodel_snake2",
          etki = "zehir", etkiHasar = 4
     },
     wyvern = {
          ad = "Ateş Wyverni", model = "models/echo/ark/wyvern_pm.mdl",
          can = 700, hasar = 32, menzil = 80, yuruyus = 90, kosu = 250, bekleme = 1.5,
          yaricap = 28, boy = 90,
          etki = "yanma", etkiHasar = 5
     },
     wyvern_buz = {
          ad = "Buz Wyverni", model = "models/echo/ark/wyvernice_pm.mdl",
          can = 700, hasar = 30, menzil = 80, yuruyus = 90, kosu = 250, bekleme = 1.5,
          yaricap = 28, boy = 90,
          etki = "donma", etkiHasar = 3
     },
     wyvern_simsek = {
          ad = "Şimşek Wyverni", model = "models/echo/ark/wyvernlightning_pm.mdl",
          can = 650, hasar = 34, menzil = 80, yuruyus = 95, kosu = 270, bekleme = 1.4,
          yaricap = 28, boy = 90,
          etki = "elektrik", etkiHasar = 5
     },
     wyvern_zehir = {
          ad = "Zehir Wyverni", model = "models/echo/ark/wyvernpoison_pm.mdl",
          can = 680, hasar = 30, menzil = 80, yuruyus = 90, kosu = 250, bekleme = 1.5,
          yaricap = 28, boy = 90,
          etki = "zehir", etkiHasar = 5
     },
     wyvern_iskelet = {
          ad = "İskelet Wyvern", model = "models/echo/ark/wyvernskeletal_pm.mdl",
          can = 600, hasar = 30, menzil = 80, yuruyus = 90, kosu = 250, bekleme = 1.5,
          yaricap = 28, boy = 90,
          etki = "kanama", etkiHasar = 4
     },
     wyvern_tek = {
          ad = "Mekanik Wyvern", model = "models/echo/ark/wyverntek_pm.mdl",
          can = 750, hasar = 32, menzil = 80, yuruyus = 90, kosu = 250, bekleme = 1.5,
          yaricap = 28, boy = 90,
          etki = "elektrik", etkiHasar = 4
     },
     wyvern_dodo = {
          ad = "Dodo Wyvern", model = "models/echo/ark/wyverndodo_pm.mdl",
          can = 300, hasar = 14, menzil = 70, yuruyus = 80, kosu = 220, bekleme = 1.3,
          yaricap = 26, boy = 80
     },
     yuzsaran = {
          ad = "Yüz Saran", model = "models/echo/aliens_fireteam/facehugger_pm.mdl",
          can = 50, hasar = 8, menzil = 35, yuruyus = 100, kosu = 300, bekleme = 0.8,
          yaricap = 12, boy = 12, ses = "playermodel_xenomorph_facehugger",
          etki = "zehir", etkiHasar = 2
     }
}

-- Admin paneli için sıralı liste
SardonHayvan.TurSirasi = {}
for id, tur in pairs(SardonHayvan.Turler) do
     tur.id = id
     SardonHayvan.TurSirasi[#SardonHayvan.TurSirasi + 1] = id
end
table.sort(SardonHayvan.TurSirasi, function(a, b) return SardonHayvan.Turler[a].ad < SardonHayvan.Turler[b].ad end)

function SardonHayvan:Tur(id)
     return self.Turler[id]
end

for _, tur in pairs(SardonHayvan.Turler) do
     util.PrecacheModel(tur.model)
end

-- Admin paneli / bölge yönetimi yetkisi (ShineAdmin "staff" kuralıyla aynı)
function SardonHayvan.Yetkili(ply)
     return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end
