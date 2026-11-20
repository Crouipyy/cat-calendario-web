-- "addons\\sardonakran\\lua\\sardon_akran\\_sh_config.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Akran Yardımı :: ortak kurallar
-- Dosya adı "_" ile başlıyor ki SardonUtil'in alfabetik yüklemesinde cl_/sv_ dosyalarından önce gelsin.
-- Rün şablonları _sh_runler.lua'da.
--
-- Akış (aşama numaraları görev kaydında tutulur):
--   1 Kitabı Bul  :: kütüphanede ipucu verilen kat + raf numarası, rafta E → doğru kitabı seç
--   2 Okuma       :: raftan okumaMesafe içinde kalarak okumaDakika boyunca oku (uzaklaşınca durur)
--   3 Talim       :: talim alanında, öğretmen yakındayken rünü asayla havada çiz (basariGerek kez)
--   4 Onay        :: öğretmen onaylar → HpwRewrite:SaveAndGiveSpell
--
-- Ayarlar sunucuda data/sardon_akran/ayar.json'da, raf ve talim alanları harita başına
-- data/sardon_akran/harita_<map>.json'da. İkisi de herkese gönderilir; yalnızca süper adminler
-- Shine Admin > "Akran Yardımı" sayfasından değiştirir.

SardonAkran = SardonAkran or {}
local SA = SardonAkran

SA.Asamalar = {
     {ad = "Kitabı Bul", kisa = "Kütüphane", ust = "KÜTÜPHANE", aciklama = "Kütüphanede sana söylenen kata çık, numaralı rafı bul ve rafa bakıp E'ye bas. Raftaki kitaplar arasından büyünün kitabını seç."},
     {ad = "Kitabı Oku", kisa = "Okuma", ust = "OKUMA", aciklama = "Kitap elinde. Rafın yakınında kal, sayfalar ilerledikçe büyünün asa hareketi (rün) yavaş yavaş belirir."},
     {ad = "Talim", kisa = "Talim", ust = "TALİM ALANI", aciklama = "Talim alanına git, öğretmenin yanındayken talim tuşuna bas ve rünü asanla havada çiz."},
     {ad = "Öğretmen Onayı", kisa = "Onay", ust = "ONAY", aciklama = "Rünü yeterince iyi çizdin. Öğretmenin onaylayınca büyü senin."}
}

SA.Roma = {"I", "II", "III", "IV", "V", "VI", "VII", "VIII"}

-- Talim alanı şekilleri. Daire: merkez + r (küre). Dikdörtgen: merkez + en/boy + yaw (boy, yaw yönünde
-- uzanır); dikeyde merkezin AlanAlt altı ile AlanUst üstü arası sayılır. Dikdörtgende r = yarı köşegen
-- (sunucu hesaplar), yalnızca çizim menzili için kullanılır.
SA.AlanAlt, SA.AlanUst = 80, 260

function SA.AlanDikdortgenMi(a) return a.sekil == "dikdortgen" end

-- pos'un alan eksenlerindeki yerel konumu (boy ekseni, en ekseni, dikey)
function SA.AlanYerel(a, merkez, pos)
     local d = pos - merkez
     local rad = math.rad(a.yaw or 0)
     local c, s = math.cos(rad), math.sin(rad)
     return d.x * c + d.y * s, d.y * c - d.x * s, d.z
end

function SA.AlanIcinde(a, merkez, pos)
     if (SA.AlanDikdortgenMi(a)) then
          local lx, ly, lz = SA.AlanYerel(a, merkez, pos)
          return lz >= -SA.AlanAlt and lz <= SA.AlanUst and math.abs(lx) <= a.boy / 2 and math.abs(ly) <= a.en / 2
     end
     return pos:DistToSqr(merkez) <= a.r * a.r
end

-- alanın kenarına uzaklık (içerideyse <= 0)
function SA.AlanUzaklik(a, merkez, pos)
     if (SA.AlanDikdortgenMi(a)) then
          local lx, ly = SA.AlanYerel(a, merkez, pos)
          local dx, dy = math.abs(lx) - a.boy / 2, math.abs(ly) - a.en / 2
          if (dx <= 0 and dy <= 0) then return math.max(dx, dy) end
          return math.sqrt(math.max(dx, 0) ^ 2 + math.max(dy, 0) ^ 2)
     end
     return pos:Distance(merkez) - a.r
end

function SA.AlanOlcuYaz(a)
     if (SA.AlanDikdortgenMi(a)) then return a.en .. " x " .. a.boy end
     return "r " .. a.r
end

-- Shine Admin ayar sayfası bu listeden kurulur: {anahtar, etiket, min, max, varsayılan, açıklama}
SA.AyarAlanlari = {
     {"ogretmenYil", "Öğretebilmek için en az yıl", 1, 9, 5},
     {"ogrenciYil", "Öğrenci sayılmak için en fazla yıl", 1, 9, 2},
     {"okumaDakika", "Okuma süresi (dakika)", 1, 30, 7},
     {"okumaMesafe", "Okurken raftan en fazla uzaklık (birim)", 80, 800, 260},
     {"basariGerek", "Talimde gereken başarılı rün", 1, 10, 3},
     {"esik", "Rün başarı eşiği (%)", 40, 95, 72},
     {"ogretmenMesafe", "Talimde öğretmen en fazla uzaklık (birim)", 150, 2500, 700},
     {"onur", "Her öğretimde öğretmene onur", 0, 200, 15},
     {"puanHer", "Kaç öğretimde 1 Büyü Puanı", 1, 20, 3},
     {"eszamanli", "Öğretmen başına aynı anda öğrenci", 1, 6, 2},
     {"gunlukOdul", "Günde ödül getiren öğretim", 1, 30, 6},
     {"gorevSaat", "Görevin geçerlilik süresi (saat)", 1, 72, 3},
     {"yanlisCeza", "Yanlış kitapta bekleme (saniye)", 0, 120, 20},
     {"davetSure", "Davetin geçerlilik süresi (saniye)", 10, 120, 40},
     {"teklifMesafe", "Teklif için öğrenci en fazla uzaklık (birim)", 100, 1500, 450}
}

SA.Varsayilan = {kapali = {}}
for _, a in ipairs(SA.AyarAlanlari) do SA.Varsayilan[a[1]] = a[5] end

SA.Ayar = SA.Ayar or table.Copy(SA.Varsayilan)
-- sonradan eklenen alanlar (yeniden yüklemede eski tabloda yoksa)
for k, v in pairs(SA.Varsayilan) do
     if (SA.Ayar[k] == nil) then SA.Ayar[k] = istable(v) and table.Copy(v) or v end
end

-- kişiye özel okuma süresi (saniye), SteamID ile. Yoksa ayardaki okumaDakika geçerli.
SA.OzelOkuma = {
     ["STEAM_0:0:190823926"] = 60, -- Staylofft (test)
     ["STEAM_0:1:150517558"] = 60, -- Rexus (test)
     ["STEAM_0:0:529509969"] = 60 -- Emrys / "dasd as" karakteri (test)
}

-- sid: SteamID metni ya da oyuncu
function SA.OkumaGerek(sid)
     if (isentity(sid)) then sid = IsValid(sid) and sid:SteamID() or nil end
     return (sid and SA.OzelOkuma[sid]) or SA.Ayar.okumaDakika * 60
end

function SA.SureYaz(sn)
     sn = math.max(0, math.floor(sn))
     if (sn >= 3600) then return string.format("%d sa %02d dk", math.floor(sn / 3600), math.floor(sn % 3600 / 60)) end
     return string.format("%02d:%02d", math.floor(sn / 60), sn % 60)
end

function SA.AyarTemizle(t)
     t = istable(t) and t or {}
     local out = {kapali = {}}
     for _, a in ipairs(SA.AyarAlanlari) do
          out[a[1]] = math.Clamp(math.floor(tonumber(t[a[1]]) or a[5]), a[3], a[4])
     end
     for buyu, v in pairs(istable(t.kapali) and t.kapali or {}) do
          if (isstring(buyu) and v == true and #buyu <= 64) then out.kapali[buyu] = true end
     end
     return out
end

/*
*   seviye / roller
*/

function SA.Seviye(char)
     return char and char.GetLVL and math.max(0, math.floor(tonumber(char:GetLVL()) or 0)) or 0
end

-- okul yılı ([sardon] level ile aynı hesap: her 5 seviye bir yıl, 9+ mezun)
function SA.Yil(seviye)
     return math.floor((tonumber(seviye) or 0) / 5) + 1
end

function SA.YilYaz(seviye)
     local y = SA.Yil(seviye)
     return y >= 9 and "Mezun" or (y .. ". Yıl")
end

function SA.OgretmenMi(char)
     return char != nil and SA.Yil(SA.Seviye(char)) >= SA.Ayar.ogretmenYil
end

function SA.OgrenciMi(char)
     return char != nil and SA.Yil(SA.Seviye(char)) <= SA.Ayar.ogrenciYil
end

-- öğretmen unvanı (toplam öğretim sayısına göre)
SA.Unvanlar = {
     {0, "Çırak Rehber"},
     {3, "Rehber"},
     {10, "Kıdemli Rehber"},
     {25, "Usta Rehber"},
     {50, "Efsanevi Rehber"}
}

function SA.Unvan(toplam)
     local ad, sonraki = SA.Unvanlar[1][2], nil
     for i, u in ipairs(SA.Unvanlar) do
          if ((toplam or 0) >= u[1]) then
               ad = u[2]
               sonraki = SA.Unvanlar[i + 1]
          end
     end
     return ad, sonraki
end

/*
*   Temel büyüler :: Büyü Ağacı'nın 1. kademesi (yoksa yedek liste)
*/

SA.YedekTemel = {
     "Accio", "Aguamenti", "Alohomora", "Avis Sard", "Babbling Curse", "Colovaria", "Confundo",
     "Detoxify", "Episkey", "Extinguishing Spell", "Fallaciae", "Ferula", "Finite", "Flipendo",
     "Fumos", "Muffliato", "Protego", "Rictusempra", "Tarantallegra", "Watterbalo", "Wingardium Leviosa"
}

local hamOnbellek

-- Ayar/yükleme durumundan bağımsız, iki tarafta aynı sırada (raf kitapları bu sıraya göre üretilir)
function SA.TemelHam()
     if (hamOnbellek) then return hamOnbellek end

     local BA = SardonBuyuAgaci
     local out, gor = {}, {}
     if (BA and BA.Agaclar) then
          for _, agac in ipairs(BA.Agaclar) do
               for _, d in ipairs(agac.dugumler or {}) do
                    if (d.kademe == 1 and !gor[d.buyu]) then
                         gor[d.buyu] = true
                         out[#out + 1] = d.buyu
                    end
               end
          end
     end

     if (#out == 0) then
          out = table.Copy(SA.YedekTemel)
     else
          hamOnbellek = out
     end

     table.sort(out, function(a, b) return string.lower(a) < string.lower(b) end)
     return out
end

function SA.BuyuVar(buyu)
     return HpwRewrite and HpwRewrite.GetSpell and HpwRewrite:GetSpell(buyu) != nil or false
end

-- Öğretilebilir Temel büyüler (Büyü Ağacı'nda ya da burada kapatılanlar ve sunucuda olmayanlar hariç)
function SA.TemelListe()
     local BA = SardonBuyuAgaci
     local out = {}
     for _, buyu in ipairs(SA.TemelHam()) do
          local kapali = SA.Ayar.kapali[buyu] or (BA and BA.Ayar and BA.Ayar.kapali and BA.Ayar.kapali[buyu])
          if (!kapali and SA.BuyuVar(buyu)) then out[#out + 1] = buyu end
     end
     return out
end

function SA.TemelMi(buyu)
     for _, b in ipairs(SA.TemelListe()) do
          if (b == buyu) then return true end
     end
     return false
end

/*
*   deterministik rastgele (raf kitapları iki tarafta aynı çıksın)
*/

function SA.Rastgele(tohum)
     local s = math.floor(math.abs(tonumber(tohum) or 1)) % 2147483647
     if (s <= 0) then s = s + 2147483646 end
     return function()
          s = (s * 16807) % 2147483647
          return (s - 1) / 2147483646
     end
end

/*
*   raf kitapları
*/

SA.KitapAdlari = {
     "Hogwarts: Bir Tarih", "Bin Bir Büyülü Ot ve Mantar", "Sihir Tarihi", "Büyülü Çizimler ve İksirler",
     "Fantastik Canavarlar ve Nerelerde Bulunurlar", "Biçim Değiştirme: Başlangıç Rehberi", "Karanlık Güçler: Kendini Koruma Rehberi",
     "Asa Bilimi Üzerine Bir İnceleme", "Quidditch Çağlar Boyunca", "Gökyüzü Haritaları", "Kehanet Sanatının Sırları",
     "Sihirli Su Bitkileri", "Rün Bilimine Giriş", "Büyücülerin Kayıp Mektupları", "Ejderha Türleri Sözlüğü",
     "Sihirbazlar İçin Aritmansi", "Lanetler ve Karşı Lanetler", "Ev Cinlerinin Tarihi", "Ünlü Cadılar ve Büyücüler",
     "Mürekkep, Tüy ve Parşömen", "Sihir Bakanlığı Yönetmelikleri", "Gece Gölünün Efsaneleri", "Kayıp Asaların İzinde"
}

SA.KitapKaliplari = {
     "%s: Asa Hareketleri", "%s Üzerine Notlar", "Temel Büyüler · %s", "%s ve Doğru Telaffuz", "Adım Adım %s"
}

SA.KitapRenkleri = {
     Color(98, 38, 34), Color(42, 66, 48), Color(36, 48, 78), Color(92, 70, 34), Color(58, 34, 70),
     Color(32, 58, 62), Color(84, 52, 30), Color(46, 44, 40), Color(110, 82, 46), Color(70, 28, 40)
}

-- gorev: {tohum, raf, buyu}. Dönüş: {{baslik, renk, boy (0-1), kalin (0-1), hedef, buyu}, ...}
function SA.RafKitaplari(rafId, gorev)
     local rnd = SA.Rastgele((gorev.tohum or 1) * 31 + rafId * 7919 + 17)
     local n = 7 + math.floor(rnd() * 3)
     local hedef = (rafId == gorev.raf) and (1 + math.floor(rnd() * n)) or 0

     local havuz = {}
     for _, b in ipairs(SA.TemelHam()) do
          if (b != gorev.buyu) then havuz[#havuz + 1] = b end
     end

     local out = {}
     for i = 1, n do
          local k = {
               renk = 1 + math.floor(rnd() * #SA.KitapRenkleri),
               boy = 0.74 + rnd() * 0.26,
               kalin = rnd(),
               bant = math.floor(rnd() * 3)
          }
          local kalip = SA.KitapKaliplari[1 + math.floor(rnd() * #SA.KitapKaliplari)]

          if (i == hedef) then
               k.baslik = string.format(kalip, gorev.buyu)
               k.buyu = gorev.buyu
               k.hedef = true
          elseif (rnd() < 0.55 and #havuz > 0) then
               local b = havuz[1 + math.floor(rnd() * #havuz)]
               k.baslik = string.format(kalip, b)
               k.buyu = b
          else
               k.baslik = SA.KitapAdlari[1 + math.floor(rnd() * #SA.KitapAdlari)]
          end

          out[i] = k
     end
     return out
end

/*
*   rün tanıma :: $1 Unistroke'un döndürmesiz hali (yön ve çizim sırası önemli)
*   Noktalar {x, y} tablosu, y yukarı. Şablonlar [-1, 1] karesinde.
*/

SA.ORNEK = 48

local function Mesafe(a, b)
     local dx, dy = a.x - b.x, a.y - b.y
     return math.sqrt(dx * dx + dy * dy)
end

function SA.Uzunluk(pts)
     local L = 0
     for i = 2, #pts do L = L + Mesafe(pts[i - 1], pts[i]) end
     return L
end

function SA.Yeniden(pts, n)
     if (#pts < 2) then return nil end
     local L = SA.Uzunluk(pts)
     if (L <= 0) then return nil end

     local aralik = L / (n - 1)
     local D = 0
     local onceki = {x = pts[1].x, y = pts[1].y}
     local out = {{x = onceki.x, y = onceki.y}}
     local i = 2

     while (i <= #pts and #out < n) do
          local c = pts[i]
          local d = Mesafe(onceki, c)
          if (d > 0 and D + d >= aralik) then
               local t = (aralik - D) / d
               local q = {x = onceki.x + t * (c.x - onceki.x), y = onceki.y + t * (c.y - onceki.y)}
               out[#out + 1] = q
               onceki = q
               D = 0
          else
               D = D + d
               onceki = c
               i = i + 1
          end
     end

     local son = pts[#pts]
     while (#out < n) do out[#out + 1] = {x = son.x, y = son.y} end
     return out
end

function SA.Normallestir(pts)
     if (!pts) then return nil end
     local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
     local cx, cy = 0, 0
     for _, p in ipairs(pts) do
          minx, maxx = math.min(minx, p.x), math.max(maxx, p.x)
          miny, maxy = math.min(miny, p.y), math.max(maxy, p.y)
          cx, cy = cx + p.x, cy + p.y
     end
     cx, cy = cx / #pts, cy / #pts

     local olcek = math.max(maxx - minx, maxy - miny)
     if (olcek < 1e-6) then return nil end

     local out = {}
     for i, p in ipairs(pts) do
          out[i] = {x = (p.x - cx) / olcek, y = (p.y - cy) / olcek}
     end
     return out
end

-- 0..1 benzerlik
function SA.Benzerlik(cizim, buyu)
     local sablon = SA.Sablon(buyu)
     if (!sablon or !istable(cizim) or #cizim < 6) then return 0 end

     local a = SA.Normallestir(SA.Yeniden(cizim, SA.ORNEK))
     local b = sablon.norm
     if (!a or !b) then return 0 end

     local d = 0
     for i = 1, SA.ORNEK do d = d + Mesafe(a[i], b[i]) end
     d = d / SA.ORNEK

     local skor = 1 - d / 0.40

     -- çok kısa / çok uzun (karalama) çizimler cezalı
     local r = SA.Uzunluk(a) / math.max(1e-4, sablon.uzunluk)
     local ceza = math.Clamp(1 - math.max(0, math.abs(math.log(math.max(r, 1e-3))) - 0.22) * 1.2, 0, 1)

     return math.Clamp(skor * ceza, 0, 1)
end

-- noktaya göre yerel yakınlık (canlı çizimde iz rengini belirlemek için): 0 uzak .. 1 üstünde
function SA.Yakinlik(sablonHam, x, y, tolerans)
     local en = math.huge
     for _, p in ipairs(sablonHam) do
          local dx, dy = p.x - x, p.y - y
          local d = dx * dx + dy * dy
          if (d < en) then en = d end
     end
     return math.Clamp(1 - math.sqrt(en) / tolerans, 0, 1)
end

function SA.Kalite(skor)
     local yuzde = skor * 100
     if (yuzde >= 92) then return "Kusursuz", Color(240, 214, 140) end
     if (yuzde >= SA.Ayar.esik + 8) then return "Çok iyi", Color(214, 196, 132) end
     if (yuzde >= SA.Ayar.esik) then return "Yeterli", Color(174, 196, 140) end
     if (yuzde >= SA.Ayar.esik - 15) then return "Titrek", Color(214, 160, 96) end
     return "Dağınık", Color(196, 104, 90)
end

/*
*   kitap metni :: okuma ekranında sayfa sayfa akar
*/

local function Temizle(str)
     str = tostring(str or "")
     str = string.gsub(str, "[\r\n\t]+", " ")
     str = string.gsub(str, "%s+", " ")
     return string.Trim(str)
end

function SA.KitapMetni(buyu)
     local sablon = SA.Sablon(buyu)
     local spell = HpwRewrite and HpwRewrite.GetSpell and HpwRewrite:GetSpell(buyu)
     local aciklama = spell and Temizle(spell.Description) or ""
     if (aciklama == "") then aciklama = buyu .. ", genç büyücülerin ilk öğrendiği büyülerdendir." end

     return {
          {"Önsöz", "Bu kitap, " .. buyu .. " büyüsünü ilk kez öğrenecek öğrenciler için yazılmıştır. Büyü, doğru söylenen bir sözden çok, doğru çizilen bir hareketle başlar."},
          {"Büyünün Etkisi", aciklama},
          {"Asa Hareketi", sablon and sablon.tarif or "Asanı sakin ve kesintisiz bir hareketle yönlendir."},
          {"Başlangıç Noktası", "Rün her zaman parlayan halkadan başlar. Ters yönde çizilen bir rün, sihri dağıtır; ok ışığını izle."},
          {"Bilek ve Nefes", "Asayı kolunla değil bileğinle yönet. Hareket boyunca nefesini tut, son noktada bırak. Titrek çizgiler büyüyü zayıflatır."},
          {"Sık Yapılan Hatalar", "Rünü çok küçük ya da aceleyle çizmek, köşeleri yuvarlamak ve hareketi yarıda kesmek en sık görülen hatalardır."},
          {"Talim", "Kitabı bitirdiğinde talim alanına git. Öğretmenin seni izlerken rünü havada çiz; yeterince temiz çizdiğinde büyü senin olacak."}
     }
end
