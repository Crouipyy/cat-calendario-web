-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\_sh_3hesap.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: hesaplar (iki tarafta da çalışır; istemci Defter'de tahmin için kullanır)
--
-- Kayıt (k) alanları:
--   id, sahip (karakter id), tur, durum (Y.D), ad, cins ("e"/"d"), nadir (1..3), renk (tur.renkler sırası)
--   dogum (os.time; yumurtada nil), evre (0 yumurta, 1 bebek, 2 genç, 3 yetişkin), zGenc / zYetiskin (geçiş anı)
--   ih {a = açlık, t = temizlik, s = sevgi} (100 = tok/temiz/mutlu), z (son ilerletme zamanı)
--   bag (0..100), xp (eğitim), ceza (ömürden düşen sn), ilgi (son bakım zamanı)
--   urunSn (ürüne biriken mutlu süre), kese {[ürün] = adet}, keseG (galleon)
--   ku {bas, s (sıcaklık), iyi (iyi aralıkta geçen sn), cevir, sonCevir} (kuluçka), havuz {nadirlik...}
--   azalma, cezaCarpan, uretim (sahibinin SYB becerilerinden; sunucu yazar)
--   olumZ (ölüm anı; sunucu işler), sonEtk {[eylem] = zaman}
--
-- Ömür: dogum + Ayar.Omur - ceza. Bir ihtiyaç sıfırda kaldığı her sn ceza CezaOrani kadar artar.

local Y = SardonYaratik
local A = Y.Ayar
local D = Y.D

function Y.Tur(k)
     return k and Y.Turler[k.tur]
end

------------------------------------------------------------------------ yaş / ömür

function Y.Yas(k, simdi)
     if not k.dogum then return 0 end
     return math.max(0, (simdi or os.time()) - k.dogum)
end

function Y.OlumZamani(k)
     if not k.dogum then return nil end
     return k.dogum + A.Omur - (k.ceza or 0)
end

function Y.KalanOmur(k, simdi)
     local o = Y.OlumZamani(k)
     if not o then return nil end
     return math.max(0, o - (simdi or os.time()))
end

-- 0..1: ömrün ne kadarı yandı (mum için)
function Y.OmurOrani(k, simdi)
     if not k.dogum then return 0 end
     return math.Clamp(1 - (Y.KalanOmur(k, simdi) or 0) / A.Omur, 0, 1)
end

------------------------------------------------------------------------ eğitim seviyesi

-- n. seviyeye çıkmak için gereken XP (bir önceki seviyeden)
function Y.SeviyeGerek(n)
     return 40 + 15 * (n - 1)
end

-- xp → seviye, sonraki seviyeye ilerleme (0..1), o seviyenin gereği
function Y.Seviye(xp)
     xp = xp or 0
     local sev = 0
     while sev < A.EnFazlaSeviye do
          local g = Y.SeviyeGerek(sev + 1)
          if xp < g then return sev, xp / g, g end
          xp = xp - g
          sev = sev + 1
     end
     return sev, 1, 0
end

------------------------------------------------------------------------ mutluluk / görünüm

function Y.Mutluluk(k)
     local ih = k.ih
     if not ih then return 0 end
     return ((ih.a or 0) + (ih.t or 0) + (ih.s or 0)) / 3
end

function Y.Olcek(k)
     local tur = Y.Tur(k)
     if not tur then return 1 end
     if (k.evre or 0) == 0 then return (tur.yumurta and tur.yumurta.olcek) or 1 end
     return (tur.olcek or 1) * ((Y.Evreler[k.evre] or Y.Evreler[3]).olcek or 1)
end

-- bodygroup değeri (staylofft_color) — renk kayıtta renkler listesinin sırası
function Y.RenkBG(k)
     local tur = Y.Tur(k)
     local r = tur and tur.renkler[k.renk or 1]
     return r and r.bg or 0
end

function Y.RenkAdi(k)
     local tur = Y.Tur(k)
     local r = tur and tur.renkler[k.renk or 1]
     return r and r.ad or "?"
end

------------------------------------------------------------------------ yem

-- 1 = sever, 0.6 = genel yem (her türe yarım etkiyle), 0 = yanlış yem
function Y.YemUygunluk(tur, yem)
     if not tur or not Y.Yemler[yem] then return 0 end
     for _, b in ipairs(tur.besin or {}) do
          if b == yem then return 1 end
     end
     if Y.Yemler[yem].genel then return 0.6 end
     return 0
end

function Y.BesinYazi(tur)
     local t = {}
     for _, b in ipairs(tur.besin or {}) do
          if Y.Yemler[b] then t[#t + 1] = Y.Yemler[b].ad end
     end
     return table.concat(t, ", ")
end

-- yemlikte bu türün yiyebileceği en iyi yem
function Y.YemlikSec(tur, yemlik)
     if not yemlik then return nil end
     local iyi, iyiDeger
     for _, yem in ipairs(Y.YemSirasi) do
          local u = Y.YemUygunluk(tur, yem)
          if u > 0 and (yemlik[yem] or 0) > 0 and (not iyiDeger or u > iyiDeger) then
               iyi, iyiDeger = yem, u
          end
     end
     return iyi
end

------------------------------------------------------------------------ ilerletme

-- Kayıtta k.z'den simdi'ye kadar geçen süreyi işler. yemlik: sahibinin yemlik stoğu (tablo,
-- yerinde azalır) ya da nil. sunucu: ürün üretimi ve rastgelelik yalnız sunucuda.
function Y.Ilerlet(k, simdi, yemlik, sunucu)
     simdi = simdi or os.time()

     if k.durum == D.OLU or k.durum == D.YUMURTA or k.durum == D.KASE or k.durum == D.KAFES and not k.dogum then
          k.z = simdi
          return
     end

     if k.durum == D.KULUCKA then
          Y.KuluckaIlerlet(k, simdi)
          return
     end

     local tur = Y.Tur(k)
     if not tur or not k.dogum then k.z = simdi return end

     local t = k.z or simdi
     if simdi <= t then return end

     k.ih = k.ih or {a = 80, t = 100, s = 60}
     local ih = k.ih
     local carpan = (k.azalma or 1) * (A.EvreAzalma[k.evre or 1] or 1)
     if k.durum == D.AGIL then carpan = carpan * A.Ureme.Azalma end
     local hiz = {
          a = 100 / (tur.ihtiyac.aclik * 3600) * carpan,
          t = 100 / (tur.ihtiyac.temizlik * 3600) * carpan,
          s = 100 / (tur.ihtiyac.sevgi * 3600) * carpan,
     }
     local cezaCarpan = (k.cezaCarpan or 1) * A.CezaOrani
     local aralik = tur.urun and tur.urun.aralik and tur.urun.aralik * 3600

     while t < simdi do
          local dt = math.min(A.AdimSn, simdi - t)
          local sifir = 0

          for anahtar, r in pairs(hiz) do
               local v = (ih[anahtar] or 0) - r * dt
               if v < 0 then
                    sifir = sifir + math.min(dt, -v / r)
                    v = 0
               end
               ih[anahtar] = v
          end

          -- sahibi yokken vivaryumdaki (ağıldaki de) yemlikten yer
          if yemlik and (k.durum == D.VIVARYUM or k.durum == D.AGIL) then
               local guvenlik = 0
               while ih.a < A.YemlikEsik and guvenlik < 8 do
                    guvenlik = guvenlik + 1
                    local yem = Y.YemlikSec(tur, yemlik)
                    if not yem then break end
                    yemlik[yem] = (yemlik[yem] or 0) - 1
                    if yemlik[yem] <= 0 then yemlik[yem] = nil end
                    ih.a = math.min(100, ih.a + Y.Yemler[yem].aclik * Y.YemUygunluk(tur, yem))
               end
          end

          if sifir > 0 then
               k.ceza = (k.ceza or 0) + sifir * cezaCarpan
          end

          -- Çiftleşme Ağılı: huzurluyken süre işler, sahibine bağlıysa daha hızlı
          local ag = k.durum == D.AGIL and k.agil
          if ag and Y.Mutluluk(k) >= A.Ureme.Mutluluk then
               local hiz = 1 + A.Ureme.BagHiz * math.Clamp((k.bag or 0) / 100, 0, 1)
               ag.huzur = math.min((ag.huzur or 0) + dt * hiz, ag.sure or math.huge)
          end

          -- uzun süre ilgilenilmeyen yaratığın bağı zayıflar
          if t - (k.ilgi or k.dogum) > A.IlgiSuresi then
               k.bag = math.max(0, (k.bag or 0) - A.BagKaybi * dt / 86400)
          end

          -- ürün: genç ve yetişkin, mutluyken
          if sunucu and aralik and (k.evre or 0) >= 2 and Y.Mutluluk(k) >= A.UrunMutluluk then
               k.urunSn = (k.urunSn or 0) + dt
               local guvenlik = 0
               while k.urunSn >= aralik and guvenlik < 20 do
                    guvenlik = guvenlik + 1
                    k.urunSn = k.urunSn - aralik
                    Y.UrunUret(k, tur)
               end
          end

          t = t + dt

          local olum = Y.OlumZamani(k)
          if olum and t >= olum then
               k.olumZ = math.floor(olum)
               break
          end
     end

     k.z = simdi
end

-- kopya üzerinde tahmin (istemci; ürün yok)
function Y.Tahmin(k, simdi)
     local c = table.Copy(k)
     Y.Ilerlet(c, simdi or os.time(), nil, false)
     return c
end

function Y.UrunUret(k, tur)
     local u = tur.urun
     if not u then return end
     local nadir = k.nadir or 1

     if u.galleon then
          local g = math.random(u.galleon[1], u.galleon[2])
          g = math.floor(g * (Y.Nadirlik[nadir] and Y.Nadirlik[nadir].urun or 1) * (k.evre == 3 and 1.3 or 1))
          k.keseG = math.min((k.keseG or 0) + g, 400)
          return
     end

     local adet = math.random(u.adet[1], u.adet[2])
     if k.evre == 3 and math.random() < 0.5 then adet = adet + 1 end
     if nadir == 2 and math.random() < 0.5 then adet = adet + 1 end
     if nadir == 3 then adet = adet + 1 end
     if (k.uretim or 0) > 0 and math.random() < 0.5 then adet = adet + 1 end

     k.kese = k.kese or {}
     k.kese[u.ad] = math.min((k.kese[u.ad] or 0) + adet, A.KeseSiniri)
end

function Y.KeseDolu(k)
     if (k.keseG or 0) > 0 then return true end
     for _, n in pairs(k.kese or {}) do
          if n > 0 then return true end
     end
     return false
end

------------------------------------------------------------------------ kuluçka

function Y.KuluckaSure(k)
     local tur = Y.Tur(k)
     return ((tur and tur.kulucka) or 30) * 60
end

function Y.CevirAraligi(k)
     return Y.KuluckaSure(k) / (A.Kulucka.cevirSayisi + 1)
end

local function Soguma(k)
     local K = A.Kulucka
     return (100 - K.taban) / (Y.KuluckaSure(k) / K.sogumaPay)
end

function Y.KuluckaIlerlet(k, simdi)
     local K = A.Kulucka
     local ku = k.ku
     if not ku then k.z = simdi return end

     local t = k.z or ku.bas
     local bitis = ku.bas + Y.KuluckaSure(k)
     local son = math.min(simdi, bitis)

     if son > t then
          local dt = son - t
          local d = Soguma(k)
          local s0 = ku.s or K.baslangic

          if s0 > K.iyiAlt then
               local a = s0 > K.iyiUst and (s0 - K.iyiUst) / d or 0
               local b = (s0 - K.iyiAlt) / d
               local bas, bit = math.max(0, a), math.min(dt, b)
               if bit > bas then ku.iyi = (ku.iyi or 0) + (bit - bas) end
          end

          ku.s = math.max(K.taban, s0 - d * dt)
     end

     k.z = simdi
     if simdi >= bitis then k.catla = true end
end

function Y.KuluckaKalite(k)
     local ku = k.ku
     if not ku then return 0 end
     local sure = Y.KuluckaSure(k)
     local sicak = math.Clamp((ku.iyi or 0) / sure, 0, 1)
     local cevir = math.Clamp((ku.cevir or 0) / A.Kulucka.cevirSayisi, 0, 1)
     return 0.65 * sicak + 0.35 * cevir
end

function Y.KuluckaIlerleme(k, simdi)
     if not k.ku then return 0 end
     return math.Clamp(((simdi or os.time()) - k.ku.bas) / Y.KuluckaSure(k), 0, 1)
end

------------------------------------------------------------------------ gen

-- Yavru, ebeveynlerden birinin nadirliğini eşit ihtimalle alır (S+S=S, N+N=N, E+E=E, N+S=%50).
-- Kusursuz kuluçkada bir üst kademeye mutasyon şansı (Soy Bilimci becerisi artırır).
function Y.NadirlikBelirle(havuz, kalite, soyKademe)
     havuz = (havuz and #havuz > 0) and havuz or {1}
     local n = havuz[math.random(#havuz)]
     local sans = 0
     if kalite >= A.Kulucka.kusursuz then sans = A.Kulucka.mutasyon end
     sans = sans + 0.05 * (soyKademe or 0)
     if n < 3 and math.random() < sans then n = n + 1 end
     return math.Clamp(n, 1, 3)
end

-- Renk: Efsanevi kendi renklerinden birini alır (nadirlik uzaktan görünsün diye), dişi renk yalnız
-- dişilerde. Ebeveyn renkleri %45 ihtimalle geçer, yoksa sıradan renklerden rastgele.
function Y.RenkBelirle(tur, nadir, cins, ebeveyn)
     local liste = tur.renkler or {}
     if #liste <= 1 then return 1 end

     if nadir == 3 and tur.efsanevi then
          return tur.efsanevi[math.random(#tur.efsanevi)]
     end

     local yasak = {}
     for _, i in ipairs(tur.efsanevi or {}) do yasak[i] = true end
     if cins ~= "d" and tur.disi then yasak[tur.disi] = true end

     for _, r in ipairs(ebeveyn or {}) do
          if not yasak[r] and liste[r] and math.random() < 0.45 then return r end
     end

     if cins == "d" and tur.disi and math.random() < 0.5 then return tur.disi end

     local aday = {}
     for i = 1, #liste do
          if not yasak[i] and i ~= tur.disi then aday[#aday + 1] = i end
     end
     return aday[math.random(math.max(1, #aday))] or 1
end

------------------------------------------------------------------------ evre

-- Koşullar sağlanmışsa bir sonraki evreyi döndürür (sunucu uygular)
function Y.SonrakiEvre(k, simdi)
     local e = k.evre or 0
     if e == 1 then
          if Y.Yas(k, simdi) >= A.BebekMinYas and (k.bag or 0) >= A.BebekBag then return 2 end
     elseif e == 2 then
          if Y.Yas(k, simdi) >= A.GencMinYas and Y.Seviye(k.xp) >= A.YetiskinSeviye then return 3 end
     end
end

-- Arayüz için: bir sonraki evreye ne eksik
function Y.EvreEksik(k, simdi)
     local e = k.evre or 0
     local out = {}
     if e == 1 then
          local kalan = A.BebekMinYas - Y.Yas(k, simdi)
          if kalan > 0 then out[#out + 1] = "yaş: " .. Y.SureYazi(kalan) end
          if (k.bag or 0) < A.BebekBag then out[#out + 1] = "bağ " .. math.floor(k.bag or 0) .. "/" .. A.BebekBag end
     elseif e == 2 then
          local kalan = A.GencMinYas - Y.Yas(k, simdi)
          if kalan > 0 then out[#out + 1] = "yaş: " .. Y.SureYazi(kalan) end
          local sev = Y.Seviye(k.xp)
          if sev < A.YetiskinSeviye then out[#out + 1] = "eğitim " .. sev .. "/" .. A.YetiskinSeviye end
     end
     return out
end

------------------------------------------------------------------------ SYB becerileri

function Y.Beceri(char, ad)
     local G = SardonGelisim
     local no = A.Beceri[ad]
     if not char or not no or not G or not G.Kademe then return 0 end
     local ok, v = pcall(G.Kademe, char, A.SYB, no)
     return ok and tonumber(v) or 0
end

function Y.Kapasite(char)
     local n = A.TemelKapasite
     if Y.Beceri(char, "sezgi") > 0 then n = n + 1 end
     if Y.Beceri(char, "usta") > 0 then n = n + 2 end
     n = n + math.min(Y.Beceri(char, "magizoolog"), 2)
     return n
end

-- Bu tehlike sınıfındaki türe sahip olabilir mi
function Y.SinifIzni(char, sinif)
     if sinif <= 2 then return true end
     if sinif == 3 then
          if Y.Beceri(char, "sezgi") > 0 then return true end
          return false, "Las criaturas clase XXX requieren SYB › Intuición de criaturas."
     end
     if sinif == 4 then
          if Y.Beceri(char, "izsurucu") >= 2 then return true end
          return false, "Las criaturas clase XXXX requieren SYB › Rastreador nivel 2."
     end
     if Y.Beceri(char, "magizoolog") > 0 then return true end
     return false, "Las criaturas clase XXXXX requieren SYB › Magizoólogo."
end

-- Sahibin becerilerinden kayda işlenen çarpanlar (sunucu ilerletmeden önce yazar)
function Y.SahipCarpanlari(k, char)
     if not char then return end
     k.azalma = 1 - 0.08 * Y.Beceri(char, "sefkat")
     -- 2026-11-10: Magizoolog 2 kademe (eskiden 3 × %20) → kademe başına %30
     k.cezaCarpan = 1 - 0.3 * math.min(Y.Beceri(char, "magizoolog"), 2)
     k.uretim = Y.Beceri(char, "usta")
end

------------------------------------------------------------------------ yazı

function Y.SureYazi(sn)
     sn = math.max(0, math.floor(sn or 0))
     local g = math.floor(sn / 86400)
     local s = math.floor((sn % 86400) / 3600)
     local d = math.floor((sn % 3600) / 60)
     if g > 0 then return g .. " gün " .. s .. " sa" end
     if s > 0 then return s .. " sa " .. d .. " dk" end
     if d > 0 then return d .. " dk" end
     return sn .. " sn"
end

function Y.SinifKod(sinif)
     return (Y.Siniflar[sinif] and Y.Siniflar[sinif].kod) or "?"
end

function Y.CinsAdi(c)
     return c == "d" and "Dişi" or "Erkek"
end
