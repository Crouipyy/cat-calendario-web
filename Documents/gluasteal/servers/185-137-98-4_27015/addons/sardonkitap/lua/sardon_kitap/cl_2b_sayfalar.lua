-- "addons\\sardonkitap\\lua\\sardon_kitap\\cl_2b_sayfalar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: dünyaya bağlı (dinamik) sayfalar — içindekiler bölümleri ve ayrıntı sayfaları
--   tarif (Jigger)    : sunucudan gelen Temel tarifler (kitap bitince)
--   bitki (Spore)     : SARDON_AGRICULTURE.CROPS + keşif (s.bitki) + SK.BITKI_NOT
--   yaratik (Scamander): SardonYaratik.Turler + SardonHayvan.Turler + keşif (s.yaratik) + Newt'ün notları
--   yer (Bagshot)     : SK.YERLER + keşif (s.yer)
--   asa (Waffling)    : sunucudan gelen asa + SardonOli.Agaclar / Ozler (oyuncununki altın)
-- Bölüm: {id, baslik, sayac, girdiler = {{id, ad, alt, acik, altin}}, kilit = "metin"}
-- Ayrıntı: {baslik, ust, etiketler = {{ad, deger}}, paragraflar = {...}, not = "el yazısı", notImza}

local SK = SardonKitap

local SINIF = {"X", "XX", "XXX", "XXXX", "XXXXX"}
local SINIF_AD = {"Sıkıcı", "Zararsız, evcilleştirilebilir", "Yetkin bir büyücü baş edebilir", "Tehlikeli, uzmanlık ister", "Büyücü öldürdüğü bilinir"}
local ZORLUK = {"Kolay", "Orta", "Zor"}

local function Kesif(char, tur)
     local s = SK.Veri(char).s
     return istable(s) and istable(s[tur]) and s[tur] or {}
end

local function Say(girdiler)
     local n = 0
     for _, g in ipairs(girdiler) do if g.acik then n = n + 1 end end
     return n .. " / " .. #girdiler
end

local B = {}

B.tarif = function(char, ek)
     local girdiler = {}
     for i, t in ipairs(ek.tarif or {}) do
          girdiler[#girdiler + 1] = {id = "t" .. i, ad = t.ad, alt = "Temel düzey", acik = true, veri = t}
     end
     local kilit
     if not ek.tarif then kilit = "Bütün bölümleri okuyunca Temel düzey tarifler burada ve kazan başındaki Tarif Defteri'nde açılır." end
     return {{id = "tarif", baslik = "Tarif Defteri", sayac = ek.tarif and tostring(#girdiler) or "kilitli", girdiler = girdiler, kilit = kilit}}
end

B.bitki = function(char)
     local A = SARDON_AGRICULTURE
     local k = Kesif(char, "bitki")
     local girdiler = {}
     for ad, crop in SortedPairs(A and A.CROPS or {}) do
          girdiler[#girdiler + 1] = {id = ad, ad = k[ad] and ad or "? ? ?", alt = k[ad] and (ZORLUK[crop.zorluk or 1] or "") or "henüz hasat edilmedi", acik = k[ad] ~= nil, veri = crop}
     end
     return {{id = "bitki", baslik = "Bitkiler", sayac = Say(girdiler), girdiler = girdiler}}
end

B.yaratik = function(char)
     local k = Kesif(char, "yaratik")
     local girdiler = {}
     local Y = SardonYaratik and SardonYaratik.Turler or {}
     for id, t in SortedPairsByMemberValue(Y, "ad") do
          local key = "y:" .. id
          girdiler[#girdiler + 1] = {id = key, ad = k[key] and t.ad or "? ? ?", alt = k[key] and (SINIF[t.sinif or 1] or "") or "henüz görülmedi", acik = k[key] ~= nil, veri = {tur = t, yid = id, kaynak = "y"}}
     end
     local H = SardonHayvan and SardonHayvan.Turler or {}
     for id, t in SortedPairsByMemberValue(H, "ad") do
          local key = "h:" .. id
          local bilgi = SK.HAYVAN_BILGI[id] or {3, ""}
          girdiler[#girdiler + 1] = {id = key, ad = k[key] and t.ad or "? ? ?", alt = k[key] and SINIF[bilgi[1]] or "henüz görülmedi", acik = k[key] ~= nil, veri = {tur = t, hid = id, kaynak = "h"}}
     end
     return {{id = "yaratik", baslik = "Yaratıklar", sayac = Say(girdiler), girdiler = girdiler}}
end

B.yer = function(char)
     local k = Kesif(char, "yer")
     local girdiler = {}
     for _, y in ipairs(SK.YERLER or {}) do
          girdiler[#girdiler + 1] = {id = y.id, ad = k[y.id] and y.ad or "? ? ?", alt = k[y.id] and "ziyaret edildi" or "henüz gidilmedi", acik = k[y.id] ~= nil, veri = y}
     end
     return {{id = "yer", baslik = "Yerler", sayac = Say(girdiler), girdiler = girdiler}}
end

B.asa = function(char, ek)
     local O = SardonOli
     local asa = ek.asa
     local out = {}
     out[#out + 1] = {id = "asam", baslik = "Senin Asan", sayac = asa and "★" or "yok", girdiler = {{id = "asam", ad = asa and (asa.baslik or "Asan") or "Asan yok", alt = asa and (asa.seri or "") or "Ollivanders'a uğra", acik = asa ~= nil, veri = asa, altin = true}}}
     if O and O.Agaclar then
          local g = {}
          for _, a in ipairs(O.Agaclar) do
               if a.sinif == nil or a.sinif == "dukkan" or (asa and asa.agac == a.id) then
                    g[#g + 1] = {id = "a:" .. a.id, ad = a.ad, alt = a.en or "", acik = true, veri = a, altin = asa and asa.agac == a.id}
               end
          end
          out[#out + 1] = {id = "agac", baslik = "Asa Ağaçları", sayac = tostring(#g), girdiler = g}
     end
     if O and O.Ozler then
          local g = {}
          for _, o in ipairs(O.Ozler) do
               if o.sinif == nil or o.sinif == "dukkan" or (asa and asa.oz == o.id) then
                    g[#g + 1] = {id = "o:" .. o.id, ad = o.ad, alt = "", acik = true, veri = o, altin = asa and asa.oz == o.id}
               end
          end
          out[#out + 1] = {id = "oz", baslik = "Asa Özleri", sayac = tostring(#g), girdiler = g}
     end
     return out
end

function SK.DinamikBolumler(kitapId, char, ek)
     local k = SK.Kitap[kitapId]
     local f = k and k.dinamik and B[k.dinamik]
     if not f or not char then return {} end
     local ok, r = pcall(f, char, ek or {})
     return ok and r or {}
end

/*
*   ayrıntı sayfaları
*/
local D = {}

D.tarif = function(g)
     local t = g.veri
     local malz = {}
     for _, m in ipairs(t.malz or {}) do malz[#malz + 1] = m[2] .. " × " .. m[1] end
     local kar = {}
     if (t.sag or 0) > 0 then kar[#kar + 1] = t.sag .. " kez saat yönünde" end
     if (t.sol or 0) > 0 then kar[#kar + 1] = t.sol .. " kez saat yönünün tersine" end
     return {baslik = t.ad, ust = "Temel düzey tarif",
          etiketler = {{"Malzemeler", table.concat(malz, ", ")}, {"Karıştırma", #kar > 0 and table.concat(kar, ", ") or "karıştırılmaz"}},
          paragraflar = {t.aciklama ~= "" and t.aciklama or "Bu iksirin etkisi kitabın bu baskısında yazılmamış."},
          not_ = "Malzemeleri tarifteki sırayla koy, sonra ateşi yak. Karıştırırken saymayı unutma.", notImza = "A. Jigger"}
end

D.bitki = function(g)
     local c = g.veri or {}
     local ihtiyac = {}
     for ad, n in pairs(c.ihtiyac or {}) do ihtiyac[#ihtiyac + 1] = n .. " × " .. tostring(ad) end
     local ozellik = {}
     if c.sifali then ozellik[#ozellik + 1] = "şifalı" end
     if c.karanlik then ozellik[#ozellik + 1] = "karanlık bitki" end
     if c.savas then ozellik[#ozellik + 1] = "savaş bitkisi" end
     local et = {
          {"Zorluk", ZORLUK[c.zorluk or 1] or "?"},
          {"Büyüme", (c.sure or "?") .. " dakika"},
          {"Verim", c.verim and (c.verim[1] .. "–" .. c.verim[2]) or "?"},
     }
     if #ihtiyac > 0 then et[#et + 1] = {"Gübre / ek", table.concat(ihtiyac, ", ")} end
     if #ozellik > 0 then et[#et + 1] = {"Özellik", table.concat(ozellik, ", ")} end
     if c.fiyat then et[#et + 1] = {"Değeri", c.fiyat .. " Galleon"} end
     local metin = SK.BITKI_NOT[g.id] or (g.id .. ", saksıda " .. (c.sure or "?") .. " dakikada olgunlaşır. " .. (c.karanlik and "Karanlık bitkiler kafatası saksısında daha verimlidir." or "Sade bir saksıda iyi büyür."))
     return {baslik = g.id, ust = "Bin Büyülü Bitki ve Mantar", etiketler = et, paragraflar = {metin},
          not_ = (c.zorluk or 1) >= 3 and "Eldivenlerini tak. Bu bitki şaka kaldırmaz." or nil, notImza = "P. Spore"}
end

D.yaratik = function(g)
     local v = g.veri
     if v.kaynak == "y" then
          local t = v.tur
          local s = t.sinif or 1
          return {baslik = t.ad, ust = "Bakanlık sınıfı " .. (SINIF[s] or "?") .. " · " .. (SINIF_AD[s] or ""),
               etiketler = {{"Sınıf", SINIF[s] or "?"}}, paragraflar = {t.aciklama or ""},
               not_ = SK.YARATIK_NOT[v.yid], notImza = "N.A.F.S."}
     end
     local t = v.tur
     local bilgi = SK.HAYVAN_BILGI[v.hid] or {3, ""}
     return {baslik = t.ad, ust = "Bakanlık sınıfı " .. SINIF[bilgi[1]] .. " · " .. SINIF_AD[bilgi[1]],
          etiketler = {{"Sınıf", SINIF[bilgi[1]]}, {"Dayanıklılık", tostring(t.can or "?")}},
          paragraflar = {bilgi[2] ~= "" and bilgi[2] or (t.ad .. " hakkında bu baskıda pek bir şey yazılmamış.")},
          not_ = bilgi[1] >= 4 and "Yalnız yaklaşma. Gerçekten." or nil, notImza = "N.A.F.S."}
end

D.yer = function(g)
     local y = g.veri
     return {baslik = y.ad, ust = "Sihir Tarihi", etiketler = {}, paragraflar = {y.metin}, notImza = "B. Bagshot"}
end

D.asa = function(g)
     local O = SardonOli
     if g.id == "asam" then
          local asa = g.veri
          if not asa then
               return {baslik = "Henüz bir asan yok", ust = "Ollivanders", paragraflar = {"Asa büyücüyü seçer. Hogsmeade'deki Ollivanders'a uğra; Bay Ollivander sana uyan asayı bulacaktır."}}
          end
          local et = {}
          local agac = O and O.Agac and O.Agac[asa.agac or ""]
          local oz = O and O.Oz and O.Oz[asa.oz or ""]
          if agac then et[#et + 1] = {"Ağaç", agac.ad .. (agac.en and (" (" .. agac.en .. ")") or "")} end
          if oz then et[#et + 1] = {"Öz", oz.ad} end
          if asa.c4 and O and O.UzunlukYazi then et[#et + 1] = {"Uzunluk", O.UzunlukYazi(asa.c4)} end
          local e = asa.esneklik and O and O.EsneklikBilgi and O.EsneklikBilgi(asa.esneklik)
          if e and e.ad then et[#et + 1] = {"Esneklik", e.ad} end
          if asa.seri then et[#et + 1] = {"Kayıt", asa.seri} end
          return {baslik = asa.baslik or "Senin Asan", ust = "Ollivanders kaydı", etiketler = et,
               paragraflar = {asa.metin or "", agac and agac.not_ or "", oz and oz.not_ or ""},
               not_ = "Bu sayfa senin için altın varakla işlenmiştir.", notImza = "A. Waffling"}
     end
     local v = g.veri or {}
     return {baslik = v.ad or g.ad, ust = g.altin and "Senin asanın parçası" or (string.sub(g.id, 1, 1) == "a" and "Asa ağacı" or "Asa özü"),
          etiketler = {}, paragraflar = {v.not_ or ""}, not_ = g.altin and "Kendi asanı tanımak, onu kullanmanın yarısıdır." or nil, notImza = "A. Waffling"}
end

function SK.DinamikDetay(kitapId, g)
     local k = SK.Kitap[kitapId]
     local f = k and k.dinamik and D[k.dinamik]
     if not f or not g then return nil end
     local ok, r = pcall(f, g)
     return ok and r or nil
end
