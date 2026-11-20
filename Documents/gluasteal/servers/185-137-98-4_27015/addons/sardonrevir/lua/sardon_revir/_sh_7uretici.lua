-- "addons\\sardonrevir\\lua\\sardon_revir\\_sh_7uretici.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: konuşma üretici.
-- Her satırın anahtarı vardır; gönüllünün son ~400 satırı (sqlite'ta karakter geçmişi) yeniden seçilmez.
-- Hasta konuşması = kişilik kalıbı + hastalık hikâyesi + belirti cümleleri + bağlam satırı; aynı hastalık
-- iki farklı kişilikte, iki farklı günde, iki farklı bağlamda bambaşka duyulur.
-- Metinler sunucuda üretilir (geçmiş orada), istemciye hazır cümle gider.

local R = SardonRevir

R.GECMIS_UZUNLUK = 400

R.HaneAd = {"Gryffindor", "Ravenclaw", "Slytherin", "Hufflepuff"} -- HOGWARTS_HOUSE sırası
R.Rakip = {Gryffindor = "Slytherin", Slytherin = "Gryffindor"}

function R.OyuncuHane(char)
     local no = char and char.GetHouse and char:GetHouse()
     return no and R.HaneAd[no] or nil
end

function R.IlkAd(ad)
     ad = tostring(ad or "")
     return string.match(ad, "^(%S+)") or ad
end

function R.Doldur(metin, j)
     metin = tostring(metin or "")
     if (!j) then return metin end
     return (string.gsub(metin, "{(%w+)}", function(k)
          local v = j[k]
          return v != nil and tostring(v) or ""
     end))
end

-- Listeden, geçmişte olmayan bir satır seç. gecmis: {[anahtar] = true}
function R.SatirSec(liste, on, gecmis)
     if (!istable(liste) or #liste == 0) then return nil end
     local adaylar = {}
     for i = 1, #liste do
          if (!gecmis or !gecmis[on .. i]) then adaylar[#adaylar + 1] = i end
     end
     if (#adaylar == 0) then
          for i = 1, #liste do adaylar[i] = i end
     end
     local i = adaylar[math.random(#adaylar)]
     return liste[i], on .. i
end

-- Konuşma bağlamı: üretici satırları buna göre süsler. gecmisDizi: sıralı anahtar listesi
function R.GecmisSet(dizi)
     local s = {}
     for _, k in ipairs(dizi or {}) do s[k] = true end
     return s
end

function R.GecmisEkle(dizi, anahtar)
     if (!anahtar) then return end
     dizi[#dizi + 1] = anahtar
     while (#dizi > R.GECMIS_UZUNLUK) do table.remove(dizi, 1) end
end

--[[
*   hasta kimliği
]]

-- tohumdan hasta: müdavim ya da rastgele. mudavim = R.Mudavimler kaydı (sunucu seçer)
function R.HastaKimlik(tohum, mudavim)
     local rnd = R.Rastgele(tohum)
     local k = {}
     if (mudavim) then
          k.ad, k.hane, k.cins, k.yil, k.kisilik, k.mudavim = mudavim.ad, mudavim.hane, mudavim.cins, mudavim.yil, mudavim.kisilik, mudavim.id
     else
          k.cins = rnd() < 0.5 and "e" or "k"
          k.ad = R.Sec(R.Adlar[k.cins], rnd) .. " " .. R.Sec(R.Soyadlar, rnd)
          k.hane = R.Sec(R.Haneler, rnd)
          k.yil = rnd(1, 7)
          k.kisilik = R.Kisilikler[rnd(#R.Kisilikler)].id
     end
     local m = R.HaneModel[k.hane] or R.HaneModel.Gryffindor
     k.model = m[k.cins == "k" and 2 or 1]
     -- [sardon] ogrenci HL gövdesi: yüz addan seçilir (istemci görünümü ad + modelden kurar, cl_2aktor HLGiydir)
     local O = SardonOgrenci
     if (O and O.Hazir and O.Hazir() and O.Model and HLStudents and HLStudents.FacesOf) then
          local c = k.cins == "k" and "f" or "m"
          local n = 0
          for _, f in ipairs(HLStudents.FacesOf(c)) do if (!f.kanon) then n = n + 1 end end
          k.model = O.Model(c, n > 0 and (tonumber(util.CRC(k.ad)) % n) + 1 or 1)
     end
     return k
end

--[[
*   satır üretimi
]]

local function KisilikListe(kisilik, kat)
     local t = R.KisilikMetin[kisilik] or R.KisilikMetin.kibar
     return t[kat] or R.KisilikMetin.kibar[kat]
end

-- H: hasta kaydı (sv_3nobet), g: geçmiş seti, dizi: sıralı geçmiş, j: jetonlar
local function Al(liste, on, g, dizi)
     local m, k = R.SatirSec(liste, on, g)
     if (k) then
          g[k] = true
          if (dizi) then R.GecmisEkle(dizi, k) end
     end
     return m
end

function R.Jeton(H, gonullu)
     local j = {pomfrey = "Madam Pomfrey"}
     if (H) then
          j.ad = R.IlkAd(H.kimlik.ad)
          j.hane = H.kimlik.hane
          j.yil = H.kimlik.yil
          j.hasta = H.kimlik.ad
          j.no = H.yatak
     end
     if (gonullu) then
          j.oyuncu = gonullu.ad
          j.unvan = gonullu.unvan
     end
     return j
end

function R.Kalip(H, kat, g, dizi, j)
     local mud = H.kimlik.mudavim and R.MudavimHarita[H.kimlik.mudavim]
     if (mud and mud[kat] and math.random() < 0.6) then
          return R.Doldur(Al(mud[kat], "m." .. mud.id .. "." .. kat .. ".", g, dizi), j)
     end
     return R.Doldur(Al(KisilikListe(H.kimlik.kisilik, kat), "s." .. H.kimlik.kisilik .. "." .. kat .. ".", g, dizi), j)
end

-- Bağlam satırı: en özel olandan başlanır; bir hastada en fazla bir tane
local BAGLAM_SIRA = {"donus", "unvanYuksek", "dolunay", "quidditch", "ders", "ayniHane", "rakipHane", "kar", "yagmur", "gece", "sabah", "aksam"}

function R.BaglamSatiri(H, g, dizi, j)
     local b = H.baglam or {}
     for _, ad in ipairs(BAGLAM_SIRA) do
          local anahtar = ad == "ders" and b.ders or (b[ad] and ad)
          local liste = anahtar and R.Baglam[anahtar]
          if (liste) then
               -- özel bağlamlar daha sık söylenir
               local olasilik = (ad == "donus" or ad == "unvanYuksek") and 0.85 or (ad == "gece" or ad == "sabah" or ad == "aksam") and 0.35 or 0.6
               if (math.random() < olasilik) then
                    local jj = table.Copy(j)
                    jj.eski = b.eskiAd
                    return R.Doldur(Al(liste, "c." .. anahtar .. ".", g, dizi), jj)
               end
          end
     end
end

-- ilk karşılaşma: selam (+ bağlam)
function R.HastaSelam(H, g, dizi, j)
     if (H.hastalik.belirtiSet.bilincsiz) then return Al(R.HastaGenel.bilincsiz, "g.bil.", g, dizi) end
     if (H.hastalik.belirtiSet.konusamiyor) then return Al(R.HastaGenel.mirilti, "g.mir.", g, dizi) end
     local s = R.Kalip(H, "selam", g, dizi, j)
     local b = R.BaglamSatiri(H, g, dizi, j)
     if (b) then s = s .. " " .. b end
     if (H.hastalik.belirtiSet.kahkaha and math.random() < 0.6) then s = Al(R.HastaGenel.gulme, "g.gul.", g, dizi) .. " " .. s end
     return s
end

-- "Neler oldu?"
function R.HastaHikaye(H, g, dizi, j)
     local h = R.Hikayeler[H.hastalik.id] or {"Ne olduğunu ben de anlamadım."}
     local hik = Al(h, "h." .. H.hastalik.id .. ".", g, dizi)
     local hs = H.hastalik.belirtiSet
     if (hs.bilincsiz or hs.konusamiyor) then return hik end
     return R.Kalip(H, "hikayeGiris", g, dizi, j) .. " " .. hik
end

-- "Neler hissediyorsun?" → metin, açığa çıkan soz belirtileri
function R.HastaBelirti(H, g, dizi, j)
     local hs = H.hastalik.belirtiSet
     if (hs.bilincsiz) then return Al(R.HastaGenel.bilincsiz, "g.bil.", g, dizi), {} end

     local sozler = {}
     for _, b in ipairs(H.hastalik.belirtiler) do
          if (R.Belirtiler[b].kaynak == "soz") then sozler[#sozler + 1] = b end
     end
     if (hs.konusamiyor) then
          return Al(R.HastaGenel.mirilti, "g.mir.", g, dizi), sozler
     end
     if (#sozler == 0) then return R.Kalip(H, "belirtiYok", g, dizi, j), {} end

     -- sırayı karıştır (aynı hastalık her seferinde aynı sırayla anlatılmasın)
     for i = #sozler, 2, -1 do
          local k = math.random(i)
          sozler[i], sozler[k] = sozler[k], sozler[i]
     end

     local parca = {R.Kalip(H, "belirtiGiris", g, dizi, j)}
     for i, b in ipairs(sozler) do
          if (i > 1) then parca[#parca + 1] = R.Kalip(H, "belirtiAra", g, dizi, j) end
          parca[#parca + 1] = Al(R.BelirtiSoz[b] or {R.Belirtiler[b].ad .. "."}, "b." .. b .. ".", g, dizi)
     end
     return table.concat(parca, " "), sozler
end

-- Genel kişilik kategorisi (muayene, tarama, bekleme, yanlis, tutmadi, iyilesti, veda, rahatlat, sohbet)
function R.HastaSoz(H, kat, g, dizi, j)
     local hs = H.hastalik.belirtiSet
     if (hs.bilincsiz and kat != "iyilesti" and kat != "veda") then return Al(R.HastaGenel.bilincsiz, "g.bil.", g, dizi) end
     if (hs.konusamiyor and kat != "iyilesti" and kat != "veda") then return Al(R.HastaGenel.mirilti, "g.mir.", g, dizi) end
     local s = R.Kalip(H, kat, g, dizi, j)
     if (kat == "iyilesti") then
          local son = R.HastalikSon[H.hastalik.id]
          if (son and math.random() < 0.7) then s = s .. " " .. Al(son, "hs." .. H.hastalik.id .. ".", g, dizi) end
     elseif (hs.kahkaha and math.random() < 0.5) then
          s = Al(R.HastaGenel.gulme, "g.gul.", g, dizi) .. " " .. s
     end
     return s
end

-- Pomfrey: kat "ipucu.dinle" gibi iç içe de olabilir
function R.PomfreySoz(kat, g, dizi, j)
     local liste = R.Pomfrey
     for parca in string.gmatch(kat, "[^%.]+") do
          liste = istable(liste) and liste[parca] or nil
     end
     if (!istable(liste)) then return "" end
     return R.Doldur(Al(liste, "p." .. kat .. ".", g, dizi), j)
end

function R.SecenekMetin(id, g, dizi)
     local v = R.Secenek[id]
     if (isstring(v)) then return v end
     return Al(v, "o." .. id .. ".", g, dizi) or id
end

-- muayene / tarama anlatısı
function R.BulguMetin(belirti, g, dizi)
     return Al(R.BelirtiBulgu[belirti] or {R.Belirtiler[belirti].ad .. "."}, "f." .. belirti .. ".", g, dizi)
end

function R.KalintiMetin(kalinti, g, dizi)
     return Al(R.KalintiAnlati[kalinti] or {""}, "k." .. kalinti .. ".", g, dizi)
end
