-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\_sh_5alan.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: vivaryum alanı (ortak) ve ağ adları
--
-- Alan, yöneticinin verdiği iki köşeden oluşan kutu (data/sardon_yaratik/<harita>.json, sunucu yazar,
-- herkese gönderir). İçinde yemlik ve kuluçka yuvası noktaları. Alan yokken vivaryum işlemleri kapalı.

local Y = SardonYaratik

Y.Alan = Y.Alan or {}

Y.NET = {
     ALAN = "SardonYaratik.Alan",          -- S→C alan verisi
     LISTE = "SardonYaratik.Liste",        -- S→C sahibinin yaratıkları (sıkıştırılmış JSON)
     ISLEM = "SardonYaratik.Islem",        -- C→S eylem
     BILDIRIM = "SardonYaratik.Bildirim",  -- S→C bildirim
     EFEKT = "SardonYaratik.Efekt",        -- S→C görsel etki
     OYUN = "SardonYaratik.Oyun",          -- S→C mini oyun başlat
     YONETIM = "SardonYaratik.Yonetim",    -- C→S yönetim
     YVERI = "SardonYaratik.YVeri",        -- S→C yönetim verisi
     BINEK = "SardonYaratik.Binek",        -- iki yönlü: binek olayları, Yön Duygusu listesi ve rotası
     ESLES = "SardonYaratik.Esles",        -- S→C başka oyuncudan eşleşme isteği
     AGIL = "SardonYaratik.Agil",          -- S→C Çiftleşme Ağılları'nın durumu (pano)
     YETENEK = "SardonYaratik.Yetenek",    -- S→C yetenek olayları (Fwooper deliliği, Jobberknoll dinle / haykırış)
}

function Y.AlanVar()
     return isvector(Y.Alan.min) and isvector(Y.Alan.max)
end

-- Kutunun köşeleri sıralı tutulur (min ≤ max). Alan genelde zeminde iki köşeyle verilir; tepeler
-- ve çukurlar için yükseklikte geniş pay bırakılır (haritanın yeraltı katı binlerce birim aşağıda).
Y.ALAN_ALT, Y.ALAN_UST = 300, 600

function Y.AlanIcinde(p, pay)
     if not Y.AlanVar() or not isvector(p) then return false end
     pay = pay or 0
     local a, b = Y.Alan.min, Y.Alan.max
     return p.x >= a.x - pay and p.x <= b.x + pay
          and p.y >= a.y - pay and p.y <= b.y + pay
          and p.z >= a.z - Y.ALAN_ALT - pay and p.z <= b.z + Y.ALAN_UST + pay
end

function Y.AlanMerkez()
     if not Y.AlanVar() then return nil end
     return (Y.Alan.min + Y.Alan.max) * 0.5
end

function Y.AlanAyarla(veri)
     table.Empty(Y.Alan)
     if istable(veri) then table.Merge(Y.Alan, veri) end
     Y.Alan.yemlik = Y.Alan.yemlik or {}
     Y.Alan.yuva = Y.Alan.yuva or {}
     Y.Alan.yemlikYon = Y.Alan.yemlikYon or {}
     Y.Alan.yuvaYon = Y.Alan.yuvaYon or {}
     Y.Alan.agil = Y.Alan.agil or {}
     Y.Alan.agilYon = Y.Alan.agilYon or {}
     Y.Alan.yasam = Y.Alan.yasam or {}
end

-- iki köşeden sıralı kutu
function Y.KutuSirala(a, b)
     return Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)),
          Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))
end

------------------------------------------------------------------------ yemlik ve kuluçka yuvası düzeni

-- Noktalar yöneticinin baktığı yönle saklanır (Y.Alan.yemlikYon / yuvaYon, derece): "ileri" noktayı
-- koyandan uzağa bakar, önü ona dönüktür. Katı parçalar sunucuda sabit prop_dynamic olarak doğar
-- (oyuncu içinden geçmez, yaratık yolları kaçınır); geri kalanı istemcide süs (cl_3dunya.lua).
local SAMAN = "models/props_normandy/haybale.mdl"
local BLOK = "models/halloween2015/hay_block.mdl"
local TOHUM = "models/sbs/hogsmeade/wu/hmm_gh_spiltseeds.mdl"
local CIT = "models/props_forest/fence_trail_256.mdl"
local CIT_KISA = "models/props_forest/fence_trail_128.mdl"
local SEPET = "models/sbs/hogsmeade/hm/hgs_comc_basket.mdl"
Y.YerDuzen = {
     yemlik = {
          {m = BLOK, ileri = 26, sag = 0, yaw = 0, kati = true},
          {m = "models/sbs/hogsmeade/hm/hgs_comc_basket.mdl", ileri = 2, sag = 0, yaw = 0, kati = true, sepet = true},
          {m = "models/props/tools/humans/bucket02.mdl", ileri = 8, sag = 25, yaw = 30},
          {m = TOHUM, ileri = -22, sag = -4, yaw = 15},
          {m = TOHUM, ileri = -15, sag = 20, yaw = 70, olcek = Vector(0.8, 0.8, 1)},
     },
     yuva = {
          {m = SAMAN, ileri = 4, sag = -40, yaw = -90, kati = true},
          {m = SAMAN, ileri = 4, sag = 40, yaw = 90, kati = true},
          {m = "models/props/tools/humans/firecamp01/brazier.mdl", ileri = 46, sag = 0, yaw = 0, kati = true, mangal = true},
          {m = BLOK, ileri = 2, sag = 0, yaw = 0, olcek = Vector(1.35, 0.72, 0.2), yatak = true},
     },
     -- Çiftleşme Ağılı: 512×512 ahşap çit, önü (koyana dönük taraf) açık giriş; arka-sağ köşede samanla
     -- dolu hasır sepet (yumurta buraya düşer), girişin solunda durum panosu. Çit parçalarının uzun
     -- ekseni modelin Y'si: yaw 0 sağ-sol, yaw 90 ileri-geri uzanır.
     agil = {
          {m = CIT, ileri = 256, sag = -128, yaw = 0, kati = true},
          {m = CIT, ileri = 256, sag = 128, yaw = 0, kati = true},
          {m = CIT, ileri = -128, sag = -256, yaw = 90, kati = true},
          {m = CIT, ileri = 128, sag = -256, yaw = 90, kati = true},
          {m = CIT, ileri = -128, sag = 256, yaw = 90, kati = true},
          {m = CIT, ileri = 128, sag = 256, yaw = 90, kati = true},
          {m = CIT_KISA, ileri = -256, sag = -192, yaw = 0, kati = true},
          {m = CIT_KISA, ileri = -256, sag = 192, yaw = 0, kati = true},
          -- saman serili zemin
          {m = BLOK, ileri = 150, sag = 140, yaw = 0, olcek = Vector(4.2, 2.3, 0.1)},
          {m = BLOK, ileri = 10, sag = -70, yaw = 25, olcek = Vector(4.6, 2.6, 0.08)},
          {m = BLOK, ileri = -120, sag = 90, yaw = -15, olcek = Vector(3.2, 1.8, 0.08)},
          -- saman sepeti (kase): sepet + içini dolduran saman
          {m = SEPET, ileri = 170, sag = 170, yaw = 20, olcek = Vector(2.7, 2.7, 1.35), kase = true},
          {m = BLOK, ileri = 170, sag = 170, yaw = 40, olcek = Vector(1.65, 0.85, 0.42), ust = 17},
          {m = "models/props/tools/humans/bucket02.mdl", ileri = 205, sag = 92, yaw = 0},
          {m = TOHUM, ileri = 120, sag = 200, yaw = 60},
          -- girişin solunda durum panosu (yazısı istemcide çizilir)
          {m = "models/props/prop_structure01/guidepost/guidepost01.mdl", ileri = -318, sag = -175, yaw = 180, olcek = Vector(0.42, 0.42, 0.42), tabela = true},
     },
}
Y.AgilYari = 256                        -- ağılın iç yarı genişliği
Y.AgilKase = {170, 170}                 -- sepetin yeri {ileri, sağ}
Y.AgilKaseUst = 25                      -- sepetteki samanın zeminden yüksekliği (yumurta samana gömülür)
Y.AgilGiris = {-330, 0}                 -- ağılın önünde, girişin karşısı
Y.YuvaYatakUst = 4.8                    -- saman yatağın zeminden yüksekliği; yumurtalar üstüne oturur
Y.YuvaCukur = {{-9, -14}, {-9, 0}, {-9, 14}, {11, -14}, {11, 0}, {11, 14}} -- yumurta çukurları {ileri, sağ}
Y.YemlikKutu = {Vector(-30, -34, 0), Vector(40, 34, 40)}                     -- nişan kutusu (yerel)

-- yer: noktaların tablosu (yemlik/yuva/yemlikYon/yuvaYon). 2026-11-10'dan beri yemlik ve yuva sahibin kendi
-- vivaryum dünyasında: sunucu Y.DunyaYerleri(charId) verir; istemcide Y.Alan bulunulan dünyanınkiyle gelir.
function Y.YerYon(cesit, i, yer)
     local t = (yer or Y.Alan)[cesit .. "Yon"]
     return (t and tonumber(t[i])) or 0
end

-- noktaya göre yerel (ileri, sağ) → dünya
function Y.YerKonum(p, yaw, ileri, sag)
     local a = Angle(0, yaw, 0)
     return p + a:Forward() * ileri + a:Right() * sag
end

-- kuluçka yuvasının yumurta çukurları (dünya; yükseklik noktanınki)
function Y.YuvaCukurlari(i, yer)
     yer = yer or Y.Alan
     local p = yer.yuva and yer.yuva[i]
     if not p then return {} end
     local yaw = Y.YerYon("yuva", i, yer)
     local out = {}
     for j, c in ipairs(Y.YuvaCukur) do out[j] = Y.YerKonum(p, yaw, c[1], c[2]) end
     return out
end

------------------------------------------------------------------------ Çiftleşme Ağılı

-- ağılın kimliği konumundan (sıra değişse de aynı ağıl): kayıtlar bununla ağıla bağlanır
function Y.AgilAnahtar(p)
     return string.format("%d,%d,%d", math.Round(p.x), math.Round(p.y), math.Round(p.z))
end

function Y.AgilBul(anahtar)
     for i, p in ipairs(Y.Alan.agil or {}) do
          if Y.AgilAnahtar(p) == anahtar then return i, p, Y.YerYon("agil", i) end
     end
end

-- ağılın yerel noktası (ileri, sağ) → dünya
function Y.AgilNokta(i, ileri, sag)
     local p = Y.Alan.agil and Y.Alan.agil[i]
     if not p then return nil end
     return Y.YerKonum(p, Y.YerYon("agil", i), ileri, sag)
end

-- dünya noktası → ağılın yerel (ileri, sağ)
function Y.AgilYerel(i, q)
     local p = Y.Alan.agil[i]
     local a = Angle(0, Y.YerYon("agil", i), 0)
     local d = q - p
     return d:Dot(a:Forward()), d:Dot(a:Right())
end

-- nokta ağılın içinde mi (pay: çitten içeri kaç birim)
function Y.AgilIcinde(i, q, pay)
     local p = Y.Alan.agil and Y.Alan.agil[i]
     if not p or math.abs(q.z - p.z) > 120 then return false end
     local ileri, sag = Y.AgilYerel(i, q)
     local s = Y.AgilYari - (pay or 0)
     return math.abs(ileri) <= s and math.abs(sag) <= s
end

-- konum bir yuvanın saman yatağının üstündeyse yatağın yüksekliği (yumurta çizimi), değilse 0
function Y.YatakUstu(p, yer)
     yer = yer or Y.Alan
     for i, y in ipairs(yer.yuva or {}) do
          local d = p - y
          if math.abs(d.z) < 40 and d:Length2DSqr() < 40 * 40 then
               local a = Angle(0, Y.YerYon("yuva", i, yer), 0)
               local ileri, sag = d:Dot(a:Forward()) - 2, d:Dot(a:Right())
               if math.abs(ileri) < 23 and math.abs(sag) < 24 then return Y.YuvaYatakUst end
          end
     end
     -- ağıldaki saman sepeti
     for i in ipairs(Y.Alan.agil or {}) do
          local q = Y.AgilNokta(i, Y.AgilKase[1], Y.AgilKase[2])
          if q and math.abs(p.z - q.z) < 40 and (p - q):Length2DSqr() < 30 * 30 then return Y.AgilKaseUst end
     end
     return 0
end

------------------------------------------------------------------------ yabani yaratıkların yaşam alanları

-- Y.Alan.yasam = {{p = Vector, r = yarıçap, turler = {tür id...}, n = nüfus}} (sv_9yabani.lua). Yetkili
-- Shine Admin'den hazır bir yaşam türü ya da tek bir tür seçip baktığı yere koyar.
Y.YasamHazir = {
     {ad = "Orman", turler = {"kneazle", "bowtruckle", "diricawl", "puffskein", "niffler"}},
     {ad = "Çayır", turler = {"mooncalf", "unicorn", "hippogriff", "puffskein"}},
     {ad = "Göl kıyısı", turler = {"giantpurpletoad", "fwooper", "jobberknoll", "diricawl"}},
     {ad = "Kayalık", turler = {"hippogriff", "graphorn", "niffler"}},
     {ad = "Gölgeli koru", turler = {"thestral", "kneazle", "fwooper"}},
}
-- doğada bulunmayanlar
Y.YabaniYok = {phoenix = true}

-- varlık durum kodları (entities/sardon_yaratik.lua DURUM_* devamı)
Y.ENT_YABANI = 4
Y.ENT_SERSEM = 5
Y.ENT_AGIL = 6                          -- ağılda eşiyle
Y.ENT_KASE = 7                          -- sepetteki yumurta
