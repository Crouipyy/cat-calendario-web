-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_1tema.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   İstemci teması: Karakter Gelişimi / Düşünseli (SHINE Celestial) diliyle aynı:
*   kömür yeşili zemin, eskitilmiş altın çizgiler, fildişi başlıklar (Cinzel), adaçayı gövde
*   metni (Montserrat), anlatıcı ve alıntılar için Playfair Display italik.
*/
local G = SardonGorev

G.R = {
     zemin = Color(11, 19, 17),
     zeminKoyu = Color(7, 11, 9),
     ic = Color(13, 20, 15),
     altin = Color(190, 162, 104),
     altinAcik = Color(223, 193, 128),
     pirinc = Color(156, 128, 80),
     fildisi = Color(232, 219, 182),
     fildisiAcik = Color(243, 229, 188),
     govde = Color(190, 194, 176),
     soluk = Color(146, 151, 129),
     cizgi = Color(125, 104, 69, 85),
     cizgiGuclu = Color(156, 129, 68, 150),
     sarap = Color(140, 52, 46),
     yesil = Color(150, 196, 140),
     kirmizi = Color(214, 108, 96),
     gumus = Color(214, 226, 244),
     beyaz = Color(255, 255, 255),
     siyah = Color(0, 0, 0),
}
local R = G.R

function G.O(x) return math.Round(x * ScrH() / 1080) end
local O = G.O

/*
*   Yazı tipleri (önbellekli)
*/
local AILE = {
     baslik = { "Cinzel SemiBold", 600 },
     baslikK = { "Cinzel", 700 },
     govde = { "Montserrat Medium", 500 },
     kalin = { "Montserrat SemiBold", 600 },
     cokKalin = { "Montserrat Bold", 700 },
     serif = { "Playfair Display", 500 },
     italik = { "Playfair Display", 500, true },
}
local fontlar = {}
-- 11-13 opt: önbellekler. G.F adı [tur][boy] (ad ScrH'a da bağlı: ScrH değişince boşalır); yazı ölçüleri
-- yazı tipi adına göre (ad piksel boyunu içerir, aynı ad hep aynı ölçü). Metin başına olanlar 300 kayıtta boşalır.
local TAVAN = 300
local fontAd, fontAdH, fontAdSayi = {}, nil, 0
local agYuks = {}                  -- [font] = surface.GetTextSize("Ag") yüksekliği
local harfOnb, harfSayi = {}, 0    -- [font][metin] = { n = harf sayısı, harf = {..}, hg = {..} } (aralıklı yazı)
local sarOnb, sarSayi = {}, 0      -- [font][genislik][metin] = satırlar

function G.F(boy, tur)
     tur = tur or "govde"
     -- 11-13 opt: aynı (tur, boy) ve ScrH için ad önbellekten; yazı tipi o ad ilk kurulurken yaratıldı
     local sh = ScrH()
     if sh ~= fontAdH then fontAd, fontAdH, fontAdSayi = {}, sh, 0 end
     local tt = fontAd[tur]
     local onb = tt and tt[boy]
     if onb then return onb end
     local px = math.max(10, math.Round(boy * sh / 1080))
     local ad = "SardonGorev." .. tur .. px
     if not fontlar[ad] then
          local a = AILE[tur] or AILE.govde
          surface.CreateFont(ad, { font = a[1], size = px, weight = a[2], italic = a[3], extended = true, antialias = true })
          fontlar[ad] = true
     end
     if boy == boy and tur == tur then   -- NaN anahtar olamaz
          if fontAdSayi >= TAVAN then fontAd, fontAdSayi, tt = {}, 0, nil end
          if not tt then tt = {} fontAd[tur] = tt end
          tt[boy] = ad
          fontAdSayi = fontAdSayi + 1
     end
     return ad
end

-- 11-13 opt: ad ve ölçü önbellekleri de boşaltılır
hook.Add("OnScreenSizeChanged", "SardonGorev.Font", function()
     fontlar = {}
     fontAd, fontAdH, fontAdSayi = {}, nil, 0
     agYuks, harfOnb, harfSayi, sarOnb, sarSayi = {}, {}, 0, {}, 0
end)

-- 3B (dünya) yazıları sabit boyda
surface.CreateFont("SardonGorev.D_Ad", { font = "Cinzel SemiBold", size = 46, weight = 600, extended = true, antialias = true })
surface.CreateFont("SardonGorev.D_Unvan", { font = "Montserrat Medium", size = 28, weight = 500, extended = true, antialias = true })
surface.CreateFont("SardonGorev.D_Balon", { font = "Montserrat Medium", size = 30, weight = 500, extended = true, antialias = true })
surface.CreateFont("SardonGorev.D_Isaret", { font = "Cinzel", size = 120, weight = 700, extended = true, antialias = true })

/*
*   Metin
*/
-- 11-13 opt: aralıklı yazının (font, metin) kaydı; yoksa boş kayıt açılır (harfleri ilk çizim doldurur)
local function HarfKaydi(metin, font)
     local t = harfOnb[font]
     local e = t and t[metin]
     if e then return e end
     e = {}
     if metin ~= metin or font ~= font then return e end   -- NaN anahtar olamaz: önbelleksiz
     if harfSayi >= TAVAN then harfOnb, harfSayi, t = {}, 0, nil end
     if not t then t = {} harfOnb[font] = t end
     t[metin] = e
     harfSayi = harfSayi + 1
     return e
end

function G.Genislik(metin, font, aralik)
     surface.SetFont(font)
     local w, h = surface.GetTextSize(metin)
     if aralik and aralik > 0 then
          -- 11-13 opt: harf sayısı (utf8.len(metin) or #metin) metin başına bir kez hesaplanır
          local e = HarfKaydi(metin, font)
          local n = e.n
          if not n then
               n = utf8.len(metin) or #metin
               e.n = n
          end
          w = w + aralik * math.max(0, n - 1)
     end
     return w, h
end

-- 11-13 opt: G.Yaz'ın iç kapanışı Bas dosya düzeyine alındı (her çağrıda kapanış yok). Aralıklı yazıda ilk
-- çizim eskisi gibi utf8.codes/utf8.char ile harf harf çizer, harfleri ve genişliklerini e'ye yazar; sonraki
-- çizimler aynı sırayla aynı toplamayı (cx = cx + w + aralik, math.Round(cx)) önbellekten yapar.
local function Bas(metin, e, px, py, aralik, dx, dy, r, g, b, a)
     surface.SetTextColor(r, g, b, a)
     if not aralik or aralik <= 0 then
          surface.SetTextPos(px + dx, py + dy)
          surface.DrawText(metin)
          return
     end
     local cx = px + dx
     local harf, hg = e.harf, e.hg
     if harf then
          for i = 1, #harf do
               surface.SetTextPos(math.Round(cx), py + dy)
               surface.DrawText(harf[i])
               cx = cx + hg[i] + aralik
          end
          return
     end
     harf, hg = {}, {}
     local n = 0
     for _, kod in utf8.codes(metin) do
          local c = utf8.char(kod)
          surface.SetTextPos(math.Round(cx), py + dy)
          surface.DrawText(c)
          local cw = surface.GetTextSize(c)
          n = n + 1
          harf[n], hg[n] = c, cw
          cx = cx + cw + aralik
     end
     e.harf, e.hg = harf, hg
end

-- hiza: 0 sol, 1 orta, 2 sağ; y satırın ortası. golge: 0..1
function G.Yaz(metin, font, x, y, renk, hiza, aralik, golge, alfa)
     metin = tostring(metin or "")
     alfa = alfa or 1
     surface.SetFont(font)
     -- 11-13 opt: "Ag" yüksekliği yazı tipi başına bir kez ölçülür
     local th = agYuks[font]
     if not th then
          local _, h = surface.GetTextSize("Ag")
          th = h
          if font == font then agYuks[font] = th end
     end
     local w = G.Genislik(metin, font, aralik)
     local px = math.Round(x - (hiza == 1 and w / 2 or (hiza == 2 and w or 0)))
     local py = math.Round(y - th / 2)
     local e = aralik and aralik > 0 and HarfKaydi(metin, font) or nil

     if golge and golge > 0 then
          Bas(metin, e, px, py, aralik, 1, 1, 0, 0, 0, (renk.a or 255) * golge * alfa)
          if golge > 0.6 then Bas(metin, e, px, py, aralik, 0, 1, 0, 0, 0, (renk.a or 255) * golge * 0.5 * alfa) end
     end
     Bas(metin, e, px, py, aralik, 0, 0, renk.r, renk.g, renk.b, (renk.a or 255) * alfa)
     return w
end

-- Kelime kaydırma; dönüş: satırlar
-- 11-13 opt: asıl hesap SarHesap'ta (değişmedi); G.Sar sonucu (font, genislik, metin) başına önbellekte tutar,
-- her çağrıda yeni bir tabloya kopyalayıp döner (çağıran tabloyu değiştirse de önbellek bozulmaz)
local function SarHesap(metin, genislik)
     local satirlar = {}
     for paragraf in string.gmatch(tostring(metin or "") .. "\n", "(.-)\n") do
          local satir = ""
          for kelime in string.gmatch(paragraf, "%S+") do
               local deneme = satir == "" and kelime or (satir .. " " .. kelime)
               if surface.GetTextSize(deneme) > genislik and satir ~= "" then
                    satirlar[#satirlar + 1] = satir
                    satir = kelime
               else
                    satir = deneme
               end
          end
          satirlar[#satirlar + 1] = satir
     end
     while #satirlar > 1 and satirlar[#satirlar] == "" do table.remove(satirlar) end
     return satirlar
end

function G.Sar(metin, font, genislik)
     surface.SetFont(font)
     -- önbellek yalnız metin dize, genişlik NaN olmayan sayı, font dize iken (tostring kimlik, anahtarlar geçerli)
     if not isstring(metin) or not isnumber(genislik) or genislik ~= genislik or not isstring(font) then
          return SarHesap(metin, genislik)
     end
     local tf = sarOnb[font]
     local tg = tf and tf[genislik]
     local s = tg and tg[metin]
     if not s then
          local satirlar = SarHesap(metin, genislik)
          s = {}
          for i = 1, #satirlar do s[i] = satirlar[i] end
          if sarSayi >= TAVAN then sarOnb, sarSayi, tf, tg = {}, 0, nil, nil end
          if not tf then tf = {} sarOnb[font] = tf end
          if not tg then tg = {} tf[genislik] = tg end
          tg[metin] = s
          sarSayi = sarSayi + 1
          return satirlar
     end
     local kopya = {}
     for i = 1, #s do kopya[i] = s[i] end
     return kopya
end

/*
*   Şekiller
*/
local matParilti = Material("sprites/glow04_noz", "smooth")
local matIsik = Material("sprites/light_glow02_add")
local gradL, gradR = Material("vgui/gradient-l"), Material("vgui/gradient-r")
local gradU, gradD = Material("vgui/gradient-u"), Material("vgui/gradient-d")
G.Mat = { parilti = matParilti, isik = matIsik, gradL = gradL, gradR = gradR, gradU = gradU, gradD = gradD }

function G.Renk(c, a) return Color(c.r, c.g, c.b, a) end

function G.Kutu(x, y, w, h, c)
     surface.SetDrawColor(c.r, c.g, c.b, c.a or 255)
     surface.DrawRect(x, y, w, h)
end

function G.Cerceve(x, y, w, h, c, t)
     surface.SetDrawColor(c.r, c.g, c.b, c.a or 255)
     surface.DrawOutlinedRect(x, y, w, h, t or 1)
end

function G.Parilti(cx, cy, boy, renk, alfa)
     surface.SetMaterial(matParilti)
     surface.SetDrawColor(renk.r, renk.g, renk.b, alfa or 255)
     surface.DrawTexturedRect(cx - boy / 2, cy - boy / 2, boy, boy)
     draw.NoTexture()
end

local baklava = { {}, {}, {}, {} }
function G.Baklava(cx, cy, h, renk, alfa, dolu)
     if dolu == false then
          surface.SetDrawColor(renk.r, renk.g, renk.b, alfa or renk.a or 255)
          surface.DrawLine(cx, cy - h, cx + h, cy)
          surface.DrawLine(cx + h, cy, cx, cy + h)
          surface.DrawLine(cx, cy + h, cx - h, cy)
          surface.DrawLine(cx - h, cy, cx, cy - h)
          return
     end
     local p = baklava
     p[1].x, p[1].y = cx, cy - h
     p[2].x, p[2].y = cx + h, cy
     p[3].x, p[3].y = cx, cy + h
     p[4].x, p[4].y = cx - h, cy
     surface.SetDrawColor(renk.r, renk.g, renk.b, alfa or renk.a or 255)
     draw.NoTexture()
     surface.DrawPoly(p)
end

-- Ortası parlak, uçları sönen yatay altın çizgi
function G.AltinCizgi(x, y, w, alfa, renk)
     renk = renk or R.altin
     alfa = alfa or 255
     local yarim = w / 2
     surface.SetDrawColor(renk.r, renk.g, renk.b, alfa)
     surface.SetMaterial(gradL)
     surface.DrawTexturedRect(x + yarim, y, yarim, 1)
     surface.SetMaterial(gradR)
     surface.DrawTexturedRect(x, y, yarim, 1)
     draw.NoTexture()
end

-- Panel: koyu zemin, ince altın çerçeve, köşelerde kısa kollar
-- 11-14 opt: köşe tabloları her çağrıda yeniden yazılan tek tabloda (çağrı başına 5 tablo yerine 0); yönler (3., 4.
-- alan) sabit, yalnız x / y yazılır. Köşe sırası ve değerleri aynı; DrawLine tabloyu görmez, G.Pano kendini çağırmaz.
local panoKose = { { 0, 0, 1, 1 }, { 0, 0, -1, 1 }, { 0, 0, 1, -1 }, { 0, 0, -1, -1 } }
function G.Pano(x, y, w, h, alfa, zemin)
     alfa = alfa or 1
     zemin = zemin or R.zemin
     surface.SetDrawColor(zemin.r, zemin.g, zemin.b, (zemin.a or 235) * alfa)
     surface.DrawRect(x, y, w, h)
     surface.SetDrawColor(R.cizgi.r, R.cizgi.g, R.cizgi.b, 120 * alfa)
     surface.DrawOutlinedRect(x, y, w, h, 1)
     local k = O(12)
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 220 * alfa)
     local pk = panoKose
     pk[1][1], pk[1][2] = x, y
     pk[2][1], pk[2][2] = x + w - 1, y
     pk[3][1], pk[3][2] = x, y + h - 1
     pk[4][1], pk[4][2] = x + w - 1, y + h - 1
     for _, c in ipairs(pk) do
          surface.DrawLine(c[1], c[2], c[1] + k * c[3], c[2])
          surface.DrawLine(c[1], c[2], c[1], c[2] + k * c[4])
     end
end

-- Yumuşak geçiş (0..1)
function G.Yumusak(x) x = math.Clamp(x, 0, 1) return x * x * (3 - 2 * x) end

/*
*   Sesler (oyunun kendi içeriği)
*/
G.UISes = {
     basla = "ambient/levels/canals/windchime2.wav",
     bitti = "ui/achievement_earned.wav",
     hedef = "garrysmod/save_load1.wav",
     ilerleme = "buttons/blip1.wav",
     basarisiz = "buttons/button10.wav",
     tik = "ui/buttonclickrelease.wav",
     secim = "garrysmod/ui_click.wav",
     ustune = "garrysmod/ui_hover.wav",
     karsilasma = "ambient/levels/canals/windchime5.wav",
}

function G.Cal(ad)
     local s = G.UISes[ad] or ad
     if s then surface.PlaySound(s) end
end

-- Türün rengi
function G.TurRenk(tur)
     local t = G.Tur(tur)
     return t and t.renk or R.altin
end
