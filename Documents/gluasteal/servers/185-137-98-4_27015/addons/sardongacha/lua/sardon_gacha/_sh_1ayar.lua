-- "addons\\sardongacha\\lua\\sardon_gacha\\_sh_1ayar.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Sardon Gacha — Asa Dileği (Genshin usulü asa gachası) ve TAB › Shine Store sekmesi
*
*   AKIŞ ÖZETİ
*   Adak (para birimi) görevlerden ve diğer sistemlerden kazanılır: SardonGacha.AdakVer(ply, miktar, sebep).
*   Dükkân'da Adak → Dilek Bileti. Afişte bilet → Dilek ×1 / ×10. Çıkan asa bir HpwRewrite kaplamasıdır
*   ve hesaba (Steam) yazılır; her karakterde asa menüsünde görünür. Elde olan asa tekrar çıkarsa
*   Yıldız Tozu verir, toz da Dükkân'da bilete döner. Gacha asası "ikinci asa" cezası yemez
*   (Ollivander sv_6etki → SardonGacha.Cezasiz).
*
*   Afişler (dönem temaları) Shine Admin › Asa Dileği sayfasından yönetilir: görsel URL, süre, havuz,
*   nadirlik oranları, pity, öne çıkan (UP) asalar. Cüzdan, pity, koleksiyon ve geçmiş steamid64'e bağlı.
*
*   Dosyalar: _sh_1 ayar · _sh_2 görev ödülleri · cl_0 doku · cl_1 tema · cl_2 veri · cl_3 sekme
*             cl_4 afiş · cl_5 pencereler · cl_6 çekiliş · cl_7 yönetim
*             sv_1 veri · sv_2 çekiliş · sv_3 ağ · sv_4 yönetim
*/
SardonGacha = SardonGacha or {}
local SG = SardonGacha

/*
*   Yönetimden değişen ekonomi ayarları (sunucu data/sardon_gacha/ayar.json, istemciye gider)
*/
SG.AyarVarsayilan = {
     adakAd = "Ofrenda",
     biletAd = "Boleto de deseo",
     tozAd = "Polvo de estrellas",
     biletFiyat = 160,          -- 1 bilet = bu kadar Adak
     tozBilet = 75,             -- 1 bilet = bu kadar Yıldız Tozu
     toz3 = 15,                 -- tekrar çıkan ★3 asanın tozu
     toz4 = 30,
     toz5 = 150,
     pityGoster = true,         -- afişte "★5 garantisine N dilek" yazısı
     adakNasil = "La ofrenda se gana con misiones, eventos y otras actividades del servidor.",
     storeKomut = "pulsarstore_open",   -- Shine Store eklentisi gelince sayfadaki düğmenin çalıştıracağı komut
}

SG.Ayar = SG.Ayar or {}
for k, v in pairs(SG.AyarVarsayilan) do
     if SG.Ayar[k] == nil then SG.Ayar[k] = v end
end

/*
*   Afiş (banner) alanları. havuz: { skin, ad, y (3/4/5), w (ağırlık), up (öne çıkan) }
*/
SG.AfisVarsayilan = {
     ad = "Póster nuevo",
     etiket = "Deseo de varita · Evento",
     aciklama = "",
     gorsel = "",               -- afiş görseli URL (png/jpg)
     arkaplan = "",             -- sayfa arka planı URL (boşsa Celestial gök)
     tur = "etkinlik",          -- etkinlik (UP + 50/50) · standart
     aktif = false,
     bas = 0,                   -- unix; 0 = hemen
     bit = 0,                   -- unix; 0 = süresiz
     sira = 1,
     b5 = 0.6, b4 = 5.1,        -- taban oranlar (%)
     h5 = 90, s5 = 74, a5 = 6,  -- ★5 kesin, yumuşak pity başlangıcı, her dilekte artış (%)
     h4 = 10,                   -- ★4 veya üstü kesin
     up5 = 50, up4 = 50,        -- ★5/★4 çıkınca öne çıkan asa olma ihtimali (%)
     garanti = true,            -- öne çıkanı kaçıran bir sonraki aynı nadirlikte kesin alır
     model = true,              -- afişte öne çıkan ★5 asanın 3B modeli dönsün
     havuz = {},
}

SG.Yildiz = {
     [3] = { ad = "Poco común", renk = Color(98, 152, 228), isik = Color(126, 182, 255) },
     [4] = { ad = "Épico", renk = Color(166, 108, 230), isik = Color(200, 150, 255) },
     [5] = { ad = "Legendario", renk = Color(226, 172, 74), isik = Color(255, 210, 120) },
}

function SG.YildizRenk(y) return (SG.Yildiz[y] or SG.Yildiz[3]).renk end
function SG.YildizIsik(y) return (SG.Yildiz[y] or SG.Yildiz[3]).isik end

/*
*   Ağ
*/
SG.NET = {
     "SardonGacha.Durum",       -- sv→cl cüzdan, pity, açık afişler, ayarlar, koleksiyon
     "SardonGacha.Istek",       -- cl→sv durum / çek / takas / geçmiş
     "SardonGacha.Sonuc",       -- sv→cl çekiliş sonucu
     "SardonGacha.Gecmis",      -- sv→cl dilek geçmişi
     "SardonGacha.Bildirim",    -- sv→cl kısa ileti
     "SardonGacha.Yonetim",     -- cl→sv yönetim istekleri
     "SardonGacha.YonetimVeri", -- sv→cl yönetim verisi
}
if SERVER then
     for _, ad in ipairs(SG.NET) do util.AddNetworkString(ad) end
end

SG.ISTEK = { DURUM = 1, CEK = 2, TAKAS = 3, GECMIS = 4 }

/*
*   Yetki
*/
SG.Yetki = "Sardon - Gacha Yönetimi"
if CAMI and CAMI.RegisterPrivilege then
     CAMI.RegisterPrivilege({ Name = SG.Yetki, MinAccess = "superadmin", Description = "Gestiona pósters, probabilidades y monederos del deseo de varita (ofrenda, boletos, polvo)." })
end

function SG.Yonetici(ply)
     if not IsValid(ply) then return false end
     if ply:IsSuperAdmin() then return true end
     if CAMI and CAMI.PlayerHasAccess then
          local ok, sonuc = pcall(CAMI.PlayerHasAccess, ply, SG.Yetki, nil)
          if ok and sonuc then return true end
     end
     return false
end

/*
*   Yardımcılar
*/
function SG.Sayi(n)
     n = math.floor(tonumber(n) or 0)
     local s = tostring(math.abs(n))
     local r = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
     if r:sub(1, 1) == "." then r = r:sub(2) end
     return (n < 0 and "-" or "") .. r
end

function SG.SureYazi(s)
     s = math.max(0, math.floor(tonumber(s) or 0))
     local g, sa, dk = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
     if g > 0 then return g .. " días " .. sa .. " h " .. dk .. " min" end
     if sa > 0 then return sa .. " h " .. dk .. " min" end
     return math.max(1, dk) .. " min"
end

-- Havuzdaki asanın görünen adı: yönetimin verdiği ad, yoksa kaplama adı sadeleştirilir
function SG.AsaAd(skin, ad)
     if isstring(ad) and ad ~= "" then return ad end
     local s = tostring(skin or "?")
     s = s:gsub("^Oli: ", ""):gsub("^staylofft ", ""):gsub("_", " ")
     return (s:gsub("^%l", string.upper))
end

function SG.AfisAcik(a, simdi)
     if not istable(a) or not a.aktif then return false end
     simdi = simdi or os.time()
     local bas, bit = tonumber(a.bas) or 0, tonumber(a.bit) or 0
     if bas > 0 and simdi < bas then return false end
     if bit > 0 and simdi >= bit then return false end
     return true
end

function SG.TabanOranlar(a)
     local b5 = math.Clamp(tonumber(a.b5) or 0.6, 0, 100)
     local b4 = math.Clamp(tonumber(a.b4) or 5.1, 0, 100 - b5)
     return { [5] = b5, [4] = b4, [3] = math.max(0, 100 - b5 - b4) }
end

-- Havuzdaki her asanın taban olasılığı (%, pity hariç), havuz sırasıyla. Öne çıkan (UP) asalar
-- kendi nadirliklerinin up5/up4 yüzdesini paylaşır, kalanını diğerleri ağırlığa göre paylaşır.
function SG.AsaOranlari(a)
     local taban = SG.TabanOranlar(a)
     local sonuc = {}
     for y = 3, 5 do
          local up, normal, wUp, wNor = {}, {}, 0, 0
          for i, e in ipairs(a.havuz or {}) do
               if e.y == y then
                    local w = math.max(0, tonumber(e.w) or 1)
                    if e.up and y >= 4 and a.tur ~= "standart" then
                         up[#up + 1] = i
                         wUp = wUp + w
                    else
                         normal[#normal + 1] = i
                         wNor = wNor + w
                    end
               end
          end
          local pay = math.Clamp(tonumber(y == 5 and a.up5 or a.up4) or 50, 0, 100) / 100
          if #up == 0 or wUp <= 0 then pay = 0 elseif #normal == 0 or wNor <= 0 then pay = 1 end
          for _, i in ipairs(up) do sonuc[i] = taban[y] * pay * math.max(0, tonumber(a.havuz[i].w) or 1) / wUp end
          for _, i in ipairs(normal) do sonuc[i] = wNor > 0 and taban[y] * (1 - pay) * math.max(0, tonumber(a.havuz[i].w) or 1) / wNor or 0 end
     end
     return sonuc, taban
end

-- k: son ★5'ten bu yana kaçıncı dilek (1'den başlar). Yumuşak pity s5'ten itibaren her dilekte a5 ekler.
function SG.Sans5(a, k)
     local h5 = math.max(1, math.floor(tonumber(a.h5) or 90))
     if k >= h5 then return 100 end
     local c = tonumber(a.b5) or 0.6
     local s5 = math.floor(tonumber(a.s5) or 0)
     if s5 > 0 and k >= s5 then c = c + (k - s5 + 1) * (tonumber(a.a5) or 0) end
     return math.Clamp(c, 0, 100)
end

-- Pity dahil ortalama oran (%): 1 / beklenen dilek sayısı
local function Ortalama(sans, tavan)
     local E, hayatta = 0, 1
     for k = 1, tavan do
          local p = math.Clamp(sans(k) / 100, 0, 1)
          E = E + k * hayatta * p
          hayatta = hayatta * (1 - p)
          if hayatta < 1e-9 then break end
     end
     return E > 0 and 100 / E or 0
end

function SG.Ortalama5(a)
     return Ortalama(function(k) return SG.Sans5(a, k) end, math.max(1, math.floor(tonumber(a.h5) or 90)))
end

function SG.Ortalama4(a)
     local h4 = math.max(1, math.floor(tonumber(a.h4) or 10))
     local b = SG.TabanOranlar(a)
     return Ortalama(function(k) return k >= h4 and 100 or b[4] end, h4)
end
