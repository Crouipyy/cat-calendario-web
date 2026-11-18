-- "addons\\sardonogrenci\\lua\\sardon_ogrenci\\cl_4ayna.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Öğrenci :: Görünüm Aynası arayüzü (tam ekran). Yaratmada Helix akışının içinde açılır
-- (cl_5baglanti.lua), sonradan /Gorunum ile düzenleme kipinde.
--   O.AynaAc{durum, kip = "yarat"|"duzenle", ebeveyn, hane, giyili, baslangic, kart, geri = fn(ayna), tamam = fn(ayna, durum)}
-- Ortam (gece mavisi zemin, sıcak ışık, huzmeler, 3B stüdyo: cl_3sahne.lua) eski aynadan. Menü "işaretli model":
-- modelin üstünde kemiklere bağlı işaretler (tam boy ve yüz haritası), iki yan sütunda altın çizgili etiketler
-- (adı + güncel değeri), işarete tıklayınca yanda açılan kart (sekmeler, kaydırıcılar, renk petekleri, HSV seçici),
-- altta kısa yol şeridi, üst sağda görünüm / döndür / duruş / geri al / rastgele / sıfırla.
local O = SardonOgrenci

local function S(x)
     return math.max(1, math.Round(x * ScrH() / 1080))
end
O.Olcek = S

-- model dosyası bu bilgisayarda var mı (istemcide IsValidModel önbelleğe bağlı; sonuç önbellekte)
local icerik = {}
function O.IcerikVar(yol)
     local v = icerik[yol]
     if v == nil then
          v = file.Exists(yol, "GAME")
          icerik[yol] = v
     end
     return v
end

local function fontlar()
     surface.CreateFont("SOg.Ust", {font = "Montserrat SemiBold", size = S(11), extended = true})
     surface.CreateFont("SOg.Baslik", {font = "Cinzel SemiBold", size = S(34), weight = 600, extended = true})
     surface.CreateFont("SOg.Inferior", {font = "Montserrat Medium", size = S(14), extended = true})
     surface.CreateFont("SOg.Kat", {font = "Cinzel SemiBold", size = S(27), weight = 600, extended = true})
     surface.CreateFont("SOg.Bolum", {font = "Cinzel SemiBold", size = S(15), weight = 600, extended = true})
     surface.CreateFont("SOg.Ray", {font = "Cinzel SemiBold", size = S(17), weight = 600, extended = true})
     surface.CreateFont("SOg.Dugme", {font = "Cinzel SemiBold", size = S(19), weight = 700, extended = true})
     surface.CreateFont("SOg.Kart", {font = "Cinzel SemiBold", size = S(17), weight = 600, extended = true})
     surface.CreateFont("SOg.Metin", {font = "Montserrat Medium", size = S(14), extended = true})
     surface.CreateFont("SOg.Kucuk", {font = "Montserrat Medium", size = S(12), extended = true})
     surface.CreateFont("SOg.Etiket", {font = "Montserrat SemiBold", size = S(11), extended = true})
     surface.CreateFont("SOg.Deger", {font = "Montserrat SemiBold", size = S(12), extended = true})
     surface.CreateFont("SOg.Etk", {font = "Cinzel SemiBold", size = S(19), weight = 600, extended = true})
end
fontlar()
hook.Add("OnScreenSizeChanged", "SardonOgrenci.Font", fontlar)

local gradU, gradD = Material("vgui/gradient-u"), Material("vgui/gradient-d")
local gradL, gradR = Material("vgui/gradient-l"), Material("vgui/gradient-r")

local R = {
     altin = Color(226, 190, 120), parlak = Color(250, 224, 168), soluk = Color(226, 190, 120, 72),
     cizgi = Color(226, 190, 120, 34), metin = Color(238, 232, 218), gri = Color(156, 151, 144),
     sonuk = Color(104, 100, 98), kirmizi = Color(226, 112, 96), murekkep = Color(26, 18, 9),
     camUst = Color(26, 30, 50, 232), camAlt = Color(7, 9, 16, 236), karo = Color(18, 21, 33, 236),
     karoUst = Color(36, 36, 54, 246), koyu = Color(9, 11, 18, 240),
}
O.Renkler = R

-- msd/ui/error.wav (ws 2486994157) içinde cue noktası var: surface.PlaySound onu döngülü sayar, hiç durmaz.
-- BASS (sound.PlayFile) cue döngüsüne bakmaz → bir kez çalar; üst üste tıklamada 0,2 sn sınır.
-- kanal yerelde tutulur: referanssız kanal çöp toplanınca ses yarıda kesilir
local hataSonraki, hataKanal = 0, nil
local function hataSesi()
     local t = RealTime()
     if t < hataSonraki then return end
     hataSonraki = t + 0.2
     sound.PlayFile("sound/msd/ui/error.wav", "noplay", function(kanal)
          if IsValid(kanal) then
               if IsValid(hataKanal) then hataKanal:Stop() end
               hataKanal = kanal
               kanal:Play()
          else
               surface.PlaySound("buttons/button16.wav")
          end
     end)
end

local function ses(ad)
     if ad == "hata" then
          hataSesi()
     elseif ad == "buyu" then
          surface.PlaySound("hpwrewrite/magicchimes0" .. math.random(1, 3) .. ".wav")
     elseif ad == "ust" then
          surface.PlaySound("msd/ui/toggle.wav")
     else
          surface.PlaySound("msd/ui/click.wav")
     end
end

----------------------------------------------------------------------------------------
-- Çizim yardımcıları (DrawPoly köşeleri ekranda saat yönünde, öncesinde NoTexture)
----------------------------------------------------------------------------------------
local function renkA(c, a)
     return Color(c.r, c.g, c.b, a)
end

local function poly(p, renk)
     draw.NoTexture()
     surface.SetDrawColor(renk)
     surface.DrawPoly(p)
end

local function kesik(x, y, w, h, k)
     return {
          {x = x + k, y = y}, {x = x + w - k, y = y}, {x = x + w, y = y + k}, {x = x + w, y = y + h - k},
          {x = x + w - k, y = y + h}, {x = x + k, y = y + h}, {x = x, y = y + h - k}, {x = x, y = y + k},
     }
end

-- kesik köşeli cam yüzey: koyu dolgu, üstten soğuk ışık, ince altın kenar (üst kenar parlak)
local function cam(x, y, w, h, k, alfa)
     alfa = alfa or 1
     local p = kesik(x, y, w, h, k)
     poly(p, renkA(R.camAlt, R.camAlt.a * alfa))

     for _, v in ipairs(p) do
          v.u, v.v = 0.5, (v.y - y) / h
     end
     surface.SetMaterial(gradU)
     surface.SetDrawColor(R.camUst.r, R.camUst.g, R.camUst.b, R.camUst.a * alfa)
     surface.DrawPoly(p)

     for i = 1, #p do
          local a, b = p[i], p[i % #p + 1]
          local ust = a.y <= y + k and b.y <= y + k
          surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, (ust and 120 or 40) * alfa)
          surface.DrawLine(a.x, a.y, b.x, b.y)
     end
end

local function daire(x, y, r, renk, parca)
     parca = parca or math.Clamp(math.floor(r * 1.2), 16, 56)
     local p = {}
     for i = 0, parca - 1 do
          local t = i / parca * math.pi * 2
          p[#p + 1] = {x = x + math.cos(t) * r, y = y + math.sin(t) * r}
     end
     poly(p, renk)
end

-- kalınlıklı halka ya da yay (derece; 0 sağ, saat yönünde)
local function yay(x, y, r, kalin, renk, a0, a1, parca)
     a0, a1 = a0 or 0, a1 or 360
     parca = parca or math.max(6, math.floor((a1 - a0) / 7))
     draw.NoTexture()
     surface.SetDrawColor(renk)
     local ic = r - kalin
     for i = 0, parca - 1 do
          local t1 = math.rad(a0 + (a1 - a0) * i / parca)
          local t2 = math.rad(a0 + (a1 - a0) * (i + 1) / parca)
          surface.DrawPoly({
               {x = x + math.cos(t1) * r, y = y + math.sin(t1) * r},
               {x = x + math.cos(t2) * r, y = y + math.sin(t2) * r},
               {x = x + math.cos(t2) * ic, y = y + math.sin(t2) * ic},
               {x = x + math.cos(t1) * ic, y = y + math.sin(t1) * ic},
          })
     end
end

local function petek(x, y, r)
     local p = {}
     for i = 0, 5 do
          local t = math.rad(-90 + i * 60)
          p[#p + 1] = {x = x + math.cos(t) * r, y = y + math.sin(t) * r}
     end
     return p
end

local function elmas(x, y, r)
     return {{x = x, y = y - r}, {x = x + r, y = y}, {x = x, y = y + r}, {x = x - r, y = y}}
end

local function kalinCizgi(x1, y1, x2, y2, t, renk)
     local dx, dy = x2 - x1, y2 - y1
     draw.NoTexture()
     surface.SetDrawColor(renk)
     surface.DrawTexturedRectRotated((x1 + x2) / 2, (y1 + y2) / 2, math.sqrt(dx * dx + dy * dy) + t * 0.5, t, -math.deg(math.atan2(dy, dx)))
end

local function tik(x, y, b, renk, t)
     kalinCizgi(x - b * 0.45, y, x - b * 0.1, y + b * 0.35, t, renk)
     kalinCizgi(x - b * 0.1, y + b * 0.35, x + b * 0.5, y - b * 0.35, t, renk)
end

-- ok başı (yon 1 sağ, -1 sol)
local function ok(x, y, b, renk, t, yon)
     kalinCizgi(x - b * 0.3 * yon, y - b * 0.5, x + b * 0.3 * yon, y, t, renk)
     kalinCizgi(x + b * 0.3 * yon, y, x - b * 0.3 * yon, y + b * 0.5, t, renk)
end

-- harf aralıklı yazı (küçük başlıklar)
local function aralikli(metin, font, x, y, renk, aralik, hiza)
     surface.SetFont(font)
     local harf, toplam = {}, 0
     for _, c in utf8.codes(metin) do
          local h = utf8.char(c)
          local w = surface.GetTextSize(h)
          harf[#harf + 1] = {h, w}
          toplam = toplam + w + aralik
     end
     toplam = math.max(0, toplam - aralik)
     if hiza == TEXT_ALIGN_CENTER then
          x = x - toplam / 2
     elseif hiza == TEXT_ALIGN_RIGHT then
          x = x - toplam
     end
     surface.SetTextColor(renk.r, renk.g, renk.b, renk.a or 255)
     for _, h in ipairs(harf) do
          surface.SetTextPos(math.Round(x), math.Round(y))
          surface.DrawText(h[1])
          x = x + h[2] + aralik
     end
     return toplam
end

-- metni genişliğe sığdır (sonuna …)
local function sigdir(metin, font, genislik)
     surface.SetFont(font)
     if surface.GetTextSize(metin) <= genislik then return metin end
     local harf = {}
     for _, c in utf8.codes(metin) do harf[#harf + 1] = utf8.char(c) end
     for n = #harf - 1, 1, -1 do
          local s = string.TrimRight(table.concat(harf, "", 1, n)) .. "…"
          if surface.GetTextSize(s) <= genislik then return s end
     end
     return "…"
end

-- arayüz ikonu: öğrenci paketinin ic_* ikonları (beyaz), yoksa gömülü yedek
local YEDEK = {face = "ik_yuz", hair = "ik_sac", eye = "ik_goz", skin = "ik_ten", presets = "ik_beden",
     makeup = "ik_ifade", outfit = "ik_beden", zar = "ik_zar", sifirla = "ik_sifirla", kilit = "ik_kilit", vucut = "ik_vucut"}

local function ikonMat(ad)
     local m = O.IkonMat and O.IkonMat("hl_students/ui/ic_" .. ad .. ".png")
     if m then return m end
     return YEDEK[ad] and O.Doku(YEDEK[ad]) or nil
end

local function ikon(ad, x, y, b, renk)
     local m = ikonMat(ad)
     if not m then return false end
     surface.SetMaterial(m)
     surface.SetDrawColor(renk.r, renk.g, renk.b, renk.a or 255)
     surface.DrawTexturedRect(x, y, b, b)
     return true
end

O.UI = {S = S, R = R, ses = ses, cam = cam, poly = poly, kesik = kesik, daire = daire, yay = yay, petek = petek,
     elmas = elmas, tik = tik, ok = ok, aralikli = aralikli, sigdir = sigdir, ikon = ikon, kalinCizgi = kalinCizgi}

----------------------------------------------------------------------------------------
-- Düğmeler
----------------------------------------------------------------------------------------
-- Ana düğme: altın kesik köşeli yüzey, gezen parıltı, kayan ok
local ANA = {}

function ANA:Init()
     self:SetText("")
     self.metin = ""
     self.vurgu = 0
     self.parilti = math.Rand(0, 3)
end

function ANA:Paint(w, h)
     local etkin = self:IsEnabled()
     self.vurgu = Lerp(FrameTime() * 10, self.vurgu, (etkin and self:IsHovered()) and 1 or 0)
     local v = self.vurgu
     local k = math.floor(h * 0.3)
     local p = kesik(0, 0, w, h, k)

     if not etkin then
          poly(p, Color(40, 40, 46, 230))
          draw.SimpleText(self.metin, "SOg.Dugme", w / 2, h / 2, R.sonuk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          return
     end

     poly(p, Color(156 + 30 * v, 116 + 26 * v, 60 + 18 * v))
     for _, n in ipairs(p) do n.u, n.v = 0.5, n.y / h end
     surface.SetMaterial(gradU)
     surface.SetDrawColor(255, 232, 178, 210)
     surface.DrawPoly(p)

     -- gezen ışık bandı (panelin sınırına kırpılır)
     local t = (RealTime() * 0.42 + self.parilti) % 1.6
     if t < 1 then
          local bx = -w * 0.25 + t * w * 1.5
          surface.SetDrawColor(255, 248, 230, 80 + 60 * v)
          surface.SetMaterial(gradR)
          surface.DrawTexturedRectRotated(bx - S(14), h / 2, S(28), h * 2.4, -18)
          surface.SetMaterial(gradL)
          surface.DrawTexturedRectRotated(bx + S(14), h / 2, S(28), h * 2.4, -18)
     end

     -- iç ince çerçeve
     local ic = kesik(S(4), S(4), w - S(8), h - S(8), k - S(3))
     for i = 1, #ic do
          local a, b = ic[i], ic[i % #ic + 1]
          surface.SetDrawColor(R.murekkep.r, R.murekkep.g, R.murekkep.b, 70)
          surface.DrawLine(a.x, a.y, b.x, b.y)
     end

     surface.SetFont("SOg.Dugme")
     local tw = surface.GetTextSize(self.metin)
     local okB = S(12)
     local x = w / 2 - (tw + okB + S(10)) / 2
     draw.SimpleText(self.metin, "SOg.Dugme", x, h / 2, R.murekkep, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     ok(x + tw + S(12) + okB * 0.3 + S(4) * v, h / 2, okB, R.murekkep, S(2.4), 1)
end

function ANA:OnCursorEntered()
     if self:IsEnabled() then ses("ust") end
end

vgui.Register("SOg.Ana", ANA, "DButton")

-- Hayalet düğme: yalnız yazı + ok, üzerine gelince alt çizgi uzar
local HAYALET = {}

function HAYALET:Init()
     self:SetText("")
     self.metin = ""
     self.vurgu = 0
     self.yon = -1
end

function HAYALET:Paint(w, h)
     self.vurgu = Lerp(FrameTime() * 10, self.vurgu, self:IsHovered() and 1 or 0)
     local v = self.vurgu
     local renk = v > 0.5 and R.parlak or R.metin
     local okB = S(11)
     local x = S(6)
     if self.yon < 0 then
          ok(x + okB * 0.3 - S(3) * v, h / 2, okB, renk, S(2), -1)
          x = x + okB + S(10)
     end
     surface.SetFont("SOg.Dugme")
     local tw = surface.GetTextSize(self.metin)
     draw.SimpleText(self.metin, "SOg.Dugme", x, h / 2, renk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 60 + 160 * v)
     surface.DrawRect(x, h / 2 + S(14), tw * (0.25 + 0.75 * v), 1)
end

function HAYALET:OnCursorEntered()
     ses("ust")
end

vgui.Register("SOg.Hayalet", HAYALET, "DButton")

-- Yuvarlak simge düğmesi (ipucu yazısını ayna kendisi çizer)
local YUVARLAK = {}

function YUVARLAK:Init()
     self:SetText("")
     self.vurgu = 0
end

function YUVARLAK:Paint(w, h)
     local aktif = self.aktif and self.aktif()
     local kapali = self.etkin and not self.etkin()
     self.vurgu = Lerp(FrameTime() * 10, self.vurgu, (not kapali and (self:IsHovered() or aktif)) and 1 or 0)
     local v = self.vurgu
     local cx, cy, r = w / 2, h / 2, math.min(w, h) / 2 - 1
     daire(cx, cy, r, aktif and Color(52, 40, 22, 245) or Color(10, 12, 20, 210))
     yay(cx, cy, r, 1.5, renkA(R.altin, kapali and 30 or (50 + 170 * v)))
     local renk = kapali and renkA(R.altin, 70) or ((aktif or v > 0.5) and R.parlak or R.altin)
     if self.ikon and ikon(self.ikon, cx - r * 0.55, cy - r * 0.55, r * 1.1, renk) then return end
     if self.cizim then self.cizim(cx, cy, r, renk) end
end

function YUVARLAK:OnCursorEntered()
     ses("ust")
end

vgui.Register("SOg.Yuvarlak", YUVARLAK, "DButton")

----------------------------------------------------------------------------------------
-- İçerik bileşenleri
----------------------------------------------------------------------------------------
-- Bölüm başlığı: Cinzel + ince çizgi; sag: sağda soluk yazı (dizi ya da işlev)
local BASLIK = {}

function BASLIK:Init()
     self:SetTall(S(34))
     self:DockMargin(0, S(12), 0, S(6))
end

function BASLIK:Paint(w, h)
     local metin = self.metin or ""
     draw.SimpleText(metin, "SOg.Bolum", 0, h / 2, R.altin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     surface.SetFont("SOg.Bolum")
     local tw = surface.GetTextSize(metin)
     local sag = isfunction(self.sag) and self.sag() or self.sag
     local sw = 0
     if sag and sag ~= "" then
          surface.SetFont("SOg.Kucuk")
          sw = surface.GetTextSize(sag) + S(12)
          draw.SimpleText(sag, "SOg.Kucuk", w, h / 2, R.gri, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     end
     local x0, x1 = tw + S(12), w - sw
     if x1 > x0 then
          surface.SetDrawColor(R.cizgi)
          surface.DrawRect(x0, h / 2, x1 - x0, 1)
          poly(elmas(x0, h / 2 + 0.5, S(2.5)), R.soluk)
     end
end

vgui.Register("SOg.Baslik", BASLIK, "Panel")

-- Karo: ikon / renk / boş; seçilince altın çerçeve + onay rozeti, üzerine gelince kalkar
local KARO = {}

function KARO:Init()
     self:SetText("")
     self.vurgu = 0
end

function KARO:Paint(w, h)
     local secili = self.secili and self.secili()
     self.vurgu = Lerp(FrameTime() * 12, self.vurgu, self:IsHovered() and 1 or 0)
     local v = self.vurgu
     local yazi = self.yazi and S(18) or 0
     local yuk = h - yazi
     local kalk = math.Round(S(3) * v)
     local r = S(8)

     if secili then
          draw.RoundedBox(r + 1, 0, S(3) - kalk, w, yuk - S(3), R.altin)
          draw.RoundedBox(r, S(2), S(5) - kalk, w - S(4), yuk - S(7), R.karoUst)
     else
          draw.RoundedBox(r, 0, S(3) - kalk, w, yuk - S(3), Color(18 + 14 * v, 21 + 13 * v, 33 + 15 * v, 236))
     end

     local ix, iy, iw = S(5), S(8) - kalk, w - S(10)
     local ih = yuk - S(13)
     if self.mat then
          surface.SetMaterial(self.mat)
          surface.SetDrawColor(255, 255, 255, self.kilitli and 90 or 255)
          local b = math.min(iw, ih)
          surface.DrawTexturedRect(ix + (iw - b) / 2, iy + (ih - b) / 2, b, b)
     elseif self.renk then
          draw.RoundedBox(S(6), ix + S(2), iy + S(2), iw - S(4), ih - S(4), self.renk)
     elseif self.bos then
          local cx, cy = ix + iw / 2, iy + ih / 2
          local rr = math.min(iw, ih) * 0.22
          yay(cx, cy, rr, S(2), renkA(R.gri, 160))
          kalinCizgi(cx - rr * 0.7, cy + rr * 0.7, cx + rr * 0.7, cy - rr * 0.7, S(2), renkA(R.gri, 160))
     end

     if self.metinIc then
          draw.SimpleText(self.metinIc, self.metinFont or "SOg.Metin", ix + iw / 2, iy + ih / 2, secili and R.parlak or R.metin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end

     if self.numara then
          draw.SimpleText(self.numara, "SOg.Etiket", S(9), yuk - S(9) - kalk, renkA(R.metin, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
     end

     if secili then
          local bx, by = w - S(11), S(12) - kalk
          daire(bx, by, S(8), R.altin)
          tik(bx, by, S(7), R.murekkep, S(2))
     end

     if self.yazi then
          self.yaziKisa = self.yaziKisa or sigdir(self.yazi, "SOg.Kucuk", w - S(4))
          draw.SimpleText(self.yaziKisa, "SOg.Kucuk", w / 2, h - S(8), secili and R.parlak or R.gri, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
end

function KARO:DoClick()
     if self.kilitli then
          ses("hata")
          return
     end
     if self.Sec then self:Sec() end
end

vgui.Register("SOg.Karo", KARO, "DButton")

-- Altıgen renk peteği
local PETEK = {}

function PETEK:Init()
     self:SetText("")
     self.vurgu = 0
end

function PETEK:Paint(w, h)
     local secili = self.secili and self.secili()
     self.vurgu = Lerp(FrameTime() * 12, self.vurgu, self:IsHovered() and 1 or 0)
     local cx, cy = w / 2, h / 2
     local r = math.min(w, h) / 2 - S(2)

     if secili then
          poly(petek(cx, cy, r + S(1)), R.parlak)
          poly(petek(cx, cy, r - S(1.5)), R.koyu)
     elseif self.vurgu > 0.01 then
          poly(petek(cx, cy, r + S(1)), renkA(R.altin, 150 * self.vurgu))
          poly(petek(cx, cy, r - S(0.5)), R.koyu)
     end

     local rr = (secili and r - S(3.5) or r - S(1.5)) * (1 + 0.04 * self.vurgu)
     if self.bos then
          poly(petek(cx, cy, rr), Color(30, 32, 44))
          kalinCizgi(cx - rr * 0.45, cy + rr * 0.45, cx + rr * 0.45, cy - rr * 0.45, S(2), R.gri)
     else
          local c = self.renk
          poly(petek(cx, cy, rr), Color(c.r * 0.62, c.g * 0.62, c.b * 0.62))
          poly(petek(cx, cy - rr * 0.07, rr * 0.88), c)
          poly(petek(cx - rr * 0.28, cy - rr * 0.34, rr * 0.18), Color(255, 255, 255, 40))
     end
end

function PETEK:DoClick()
     if self.Sec then self:Sec() end
end

vgui.Register("SOg.Petek", PETEK, "DButton")

-- Petek ızgarası: çocukları bal peteği düzeninde dizer (tek satırlar yarım hücre kayık)
local IZGARA = {}

function IZGARA:Init()
     self.hucre = S(38)
     self.bosluk = S(4)
end

function IZGARA:Kur(genislik, hucre, adet)
     self.hucre = hucre
     local adim = hucre + self.bosluk
     self.sutun = math.max(2, math.floor((genislik + self.bosluk) / adim))
     local satirBasina = self.sutun * 2 - 1
     local tam = math.floor(adet / satirBasina) * 2
     local kalan = adet % satirBasina
     local satir = tam + (kalan > 0 and (kalan > self.sutun and 2 or 1) or 0)
     self:SetTall(math.max(1, satir) * math.floor(hucre * 0.88) + math.floor(hucre * 0.14) + S(2))
end

function IZGARA:PerformLayout(w, h)
     local adim = self.hucre + self.bosluk
     local satirH = math.floor(self.hucre * 0.88)
     local x, y, s = 0, 0, 0
     for _, c in ipairs(self:GetChildren()) do
          local tek = s % 2 == 1
          local adet = tek and self.sutun - 1 or self.sutun
          c:SetSize(self.hucre, self.hucre)
          c:SetPos((tek and adim / 2 or 0) + x * adim, y)
          x = x + 1
          if x >= adet then
               x, s, y = 0, s + 1, y + satirH
          end
     end
end

vgui.Register("SOg.PetekIzgara", IZGARA, "Panel")

-- Kaydırıcı: elmas tutamak, iki yönlüde ortada çentik; çift tık varsayılana döner
local SURGU = {}

function SURGU:Init()
     self:SetTall(S(42))
     self:DockMargin(0, 0, 0, S(4))
     self:SetCursor("hand")
     self.deger, self.min, self.max, self.varsayilan = 0, -1, 1, 0
     self.vurgu = 0
end

function SURGU:DegerYazi()
     if self.bicim then return self.bicim(self.deger) end
     if self.min < 0 then
          local p = math.Round(self.deger * 100)
          return (p > 0 and "+" or "") .. p
     end
     return string.format("%%%d", math.Round((self.deger - self.min) / (self.max - self.min) * 100))
end

function SURGU:Paint(w, h)
     self.vurgu = Lerp(FrameTime() * 10, self.vurgu, (self:IsHovered() or self.surukle) and 1 or 0)
     local v = self.vurgu
     draw.SimpleText(self.ad or "", "SOg.Metin", S(2), S(11), R.metin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     draw.SimpleText(self:DegerYazi(), "SOg.Deger", w - S(2), S(11), v > 0.5 and R.parlak or R.gri, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

     local y = h - S(12)
     local x0, x1 = S(8), w - S(8)
     surface.SetDrawColor(255, 255, 255, 22)
     surface.DrawRect(x0, y, x1 - x0, S(2))

     local oran = (self.deger - self.min) / (self.max - self.min)
     local hx = x0 + (x1 - x0) * oran
     local iki = self.min < 0 and self.max > 0
     local ox = iki and (x0 + (x1 - x0) * (-self.min / (self.max - self.min))) or x0
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 150 + 100 * v)
     surface.DrawRect(math.min(ox, hx), y, math.abs(hx - ox), S(2))
     if iki then
          surface.SetDrawColor(R.soluk)
          surface.DrawRect(ox, y - S(4), 1, S(10))
     end

     local r = S(6) + S(2) * v
     if self.surukle then
          local radyal = O.Doku("radyal")
          if radyal then
               surface.SetMaterial(radyal)
               surface.SetDrawColor(250, 210, 140, 90)
               surface.DrawTexturedRect(hx - r * 3, y + 1 - r * 3, r * 6, r * 6)
          end
     end
     poly(elmas(hx, y + 1, r + S(2)), R.koyu)
     poly(elmas(hx, y + 1, r), v > 0.5 and R.parlak or R.altin)
end

function SURGU:Guncelle()
     local mx = self:CursorPos()
     local x0, x1 = S(8), self:GetWide() - S(8)
     local oran = math.Clamp((mx - x0) / math.max(1, x1 - x0), 0, 1)
     local v = self.min + (self.max - self.min) * oran
     if self.adim then v = math.Round(v / self.adim) * self.adim end
     -- iki yönlüde ortaya yapışır
     if self.min < 0 and self.max > 0 and math.abs(v) < (self.max - self.min) * 0.02 then v = 0 end
     v = math.Clamp(v, self.min, self.max)
     if v ~= self.deger then
          self.deger = v
          if self.degisti then self.degisti(v) end
     end
end

function SURGU:OnMousePressed(k)
     if k ~= MOUSE_LEFT then return end
     local simdi = RealTime()
     if self.sonTik and simdi - self.sonTik < 0.3 then
          self.sonTik = nil
          if self.basla then self.basla() end
          self.deger = self.varsayilan
          if self.degisti then self.degisti(self.deger) end
          if self.bitti then self.bitti() end
          ses("tik")
          return
     end
     self.sonTik = simdi
     self.surukle = true
     self:MouseCapture(true)
     if self.basla then self.basla() end
     self:Guncelle()
end

function SURGU:OnMouseReleased()
     if not self.surukle then return end
     self.surukle = false
     self:MouseCapture(false)
     if self.bitti then self.bitti() end
end

function SURGU:Think()
     if not self.surukle then return end
     if not input.IsMouseDown(MOUSE_LEFT) then
          self:OnMouseReleased()
          return
     end
     self:Guncelle()
end

vgui.Register("SOg.Surgu", SURGU, "Panel")

-- Hap sekmeler (bölümler, duruşlar)
local SEKME = {}

function SEKME:Init()
     self:SetTall(S(28))
     self:SetCursor("hand")
     self.vurgu = {}
     self.alanlar = {}
end

function SEKME:Paint(w, h)
     surface.SetFont("SOg.Etiket")
     local mx = self:CursorPos()
     local x = 0
     self.alanlar = {}
     for i, b in ipairs(self.liste or {}) do
          local tw = surface.GetTextSize(b.ad)
          local bw = tw + S(26)
          local on = self.secili and self.secili() == b.id
          local ust = self:IsHovered() and mx >= x and mx < x + bw
          self.vurgu[i] = Lerp(FrameTime() * 12, self.vurgu[i] or 0, (on or ust) and 1 or 0)
          if on then
               draw.RoundedBox(h / 2, x, 0, bw, h, R.altin)
          else
               draw.RoundedBox(h / 2, x, 0, bw, h, Color(255, 255, 255, 7 + 16 * self.vurgu[i]))
          end
          draw.SimpleText(b.ad, "SOg.Etiket", x + bw / 2, h / 2, on and R.murekkep or (ust and R.metin or R.gri), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          self.alanlar[i] = {x, x + bw, b.id}
          x = x + bw + S(6)
     end
end

function SEKME:OnMousePressed(k)
     if k ~= MOUSE_LEFT then return end
     local mx = self:CursorPos()
     for _, a in ipairs(self.alanlar) do
          if mx >= a[1] and mx < a[2] then
               if not self.secili or self.secili() ~= a[3] then
                    ses("tik")
                    if self.sec then self.sec(a[3]) end
               end
               return
          end
     end
end

vgui.Register("SOg.Sekmeler", SEKME, "Panel")

-- Büyük seçim kartı (cinsiyet): kesik köşeli cam, çizilmiş siluet, başlık + açıklama
local KART = {}

function KART:Init()
     self:SetText("")
     self.vurgu = 0
end

local function siluet(cx, cy, b, kiz, renk)
     daire(cx, cy - b * 0.62, b * 0.17, renk)
     draw.RoundedBox(b * 0.12, cx - b * 0.22, cy - b * 0.42, b * 0.44, b * 0.5, renk)
     if kiz then
          poly({{x = cx - b * 0.2, y = cy + b * 0.02}, {x = cx + b * 0.2, y = cy + b * 0.02}, {x = cx + b * 0.32, y = cy + b * 0.36}, {x = cx - b * 0.32, y = cy + b * 0.36}}, renk)
          draw.RoundedBox(2, cx - b * 0.17, cy + b * 0.36, b * 0.1, b * 0.36, renk)
          draw.RoundedBox(2, cx + b * 0.07, cy + b * 0.36, b * 0.1, b * 0.36, renk)
     else
          draw.RoundedBox(2, cx - b * 0.2, cy + b * 0.06, b * 0.17, b * 0.66, renk)
          draw.RoundedBox(2, cx + b * 0.03, cy + b * 0.06, b * 0.17, b * 0.66, renk)
     end
end

function KART:Paint(w, h)
     local secili = self.secili and self.secili()
     self.vurgu = Lerp(FrameTime() * 10, self.vurgu, self:IsHovered() and 1 or 0)
     local v = self.vurgu
     local k = S(10)
     local p = kesik(0, 0, w, h, k)
     poly(p, secili and Color(44, 36, 24, 240) or Color(16 + 10 * v, 19 + 9 * v, 30 + 10 * v, 236))
     if secili then
          local radyal = O.Doku("radyal")
          if radyal then
               surface.SetMaterial(radyal)
               surface.SetDrawColor(226, 170, 90, 70)
               surface.DrawTexturedRect(-h * 0.2, -h * 0.4, h * 1.6, h * 1.8)
          end
     end
     for i = 1, #p do
          local a, b = p[i], p[i % #p + 1]
          surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, secili and 200 or (40 + 80 * v))
          surface.DrawLine(a.x, a.y, b.x, b.y)
     end

     local renk = secili and R.parlak or renkA(R.altin, 170 + 85 * v)
     siluet(S(42), h / 2 + S(2), h * 0.62, self.cins == "f", renk)
     draw.SimpleText(self.baslik or "", "SOg.Kart", S(78), h / 2 - S(9), secili and R.parlak or R.metin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     draw.SimpleText(self.alt or "", "SOg.Kucuk", S(78), h / 2 + S(12), R.gri, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

     if secili then
          daire(w - S(16), S(16), S(8), R.altin)
          tik(w - S(16), S(16), S(7), R.murekkep, S(2))
     end
end

function KART:DoClick()
     if self.Sec then self:Sec() end
end

function KART:OnCursorEntered()
     ses("ust")
end

vgui.Register("SOg.Kart", KART, "DButton")

-- HSV renk seçici: doygunluk/parlaklık karesi + ton şeridi + önizleme; renk Color, değişince degisti(Color)
local SECICI = {}

function SECICI:Init()
     self:SetTall(S(150))
     self:DockMargin(0, S(4), 0, S(8))
     self.ton, self.doy, self.par = 0, 0, 1
     self:SetCursor("crosshair")
end

function SECICI:Ayarla(c)
     self.ton, self.doy, self.par = ColorToHSV(c)
end

function SECICI:Renk()
     return HSVToColor(self.ton, self.doy, self.par)
end

function SECICI:Alanlar(w, h)
     local kare = h
     return 0, 0, kare, kare, kare + S(10), S(16)
end

function SECICI:Paint(w, h)
     local kx, ky, kw, kh, tx, tw = self:Alanlar(w, h)
     -- doygunluk/parlaklık karesi: saf ton + soldan beyaz + alttan siyah
     local ton = HSVToColor(self.ton, 1, 1)
     surface.SetDrawColor(ton.r, ton.g, ton.b, 255)
     surface.DrawRect(kx, ky, kw, kh)
     surface.SetMaterial(gradL)
     surface.SetDrawColor(255, 255, 255, 255)
     surface.DrawTexturedRect(kx, ky, kw, kh)
     surface.SetMaterial(gradD)
     surface.SetDrawColor(0, 0, 0, 255)
     surface.DrawTexturedRect(kx, ky, kw, kh)
     surface.SetDrawColor(R.cizgi)
     surface.DrawOutlinedRect(kx, ky, kw, kh, 1)

     local px, py = kx + self.doy * kw, ky + (1 - self.par) * kh
     yay(px, py, S(6), S(2), Color(255, 255, 255))
     yay(px, py, S(7.5), 1, Color(0, 0, 0, 160))

     -- ton şeridi (yukarıdan aşağı 0..360)
     local dilim = kh / 6
     for i = 0, 5 do
          local a, b = HSVToColor(i * 60, 1, 1), HSVToColor((i + 1) * 60, 1, 1)
          surface.SetDrawColor(b.r, b.g, b.b, 255)
          surface.DrawRect(tx, ky + i * dilim, tw, math.ceil(dilim))
          surface.SetMaterial(gradU)
          surface.SetDrawColor(a.r, a.g, a.b, 255)
          surface.DrawTexturedRect(tx, ky + i * dilim, tw, math.ceil(dilim))
     end
     local hy = ky + self.ton / 360 * kh
     poly(elmas(tx - S(3), hy, S(4)), R.parlak)
     surface.SetDrawColor(255, 255, 255, 220)
     surface.DrawRect(tx, hy - 1, tw, 2)

     -- önizleme ve onaltılık değer
     local c = self:Renk()
     local ox = tx + tw + S(14)
     draw.RoundedBox(S(6), ox, ky, w - ox, S(46), c)
     draw.SimpleText(string.format("#%02X%02X%02X", c.r, c.g, c.b), "SOg.Deger", ox, ky + S(58), R.gri, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     draw.SimpleText(self.ipucuMetin or "Elige el tono en el cuadrado y el color en la barra.", "SOg.Kucuk", ox, ky + S(78), R.sonuk, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function SECICI:Guncelle()
     local w, h = self:GetSize()
     local kx, ky, kw, kh, tx, tw = self:Alanlar(w, h)
     local mx, my = self:CursorPos()
     if self.bolge == "kare" then
          self.doy = math.Clamp((mx - kx) / kw, 0, 1)
          self.par = math.Clamp(1 - (my - ky) / kh, 0, 1)
     elseif self.bolge == "ton" then
          self.ton = math.Clamp((my - ky) / kh, 0, 1) * 360
     end
     if self.degisti then self.degisti(self:Renk()) end
end

function SECICI:OnMousePressed(k)
     if k ~= MOUSE_LEFT then return end
     local w, h = self:GetSize()
     local kx, ky, kw, kh, tx, tw = self:Alanlar(w, h)
     local mx = self:CursorPos()
     if mx <= kx + kw then
          self.bolge = "kare"
     elseif mx >= tx - S(4) and mx <= tx + tw + S(4) then
          self.bolge = "ton"
     else
          return
     end
     self:MouseCapture(true)
     if self.basla then self.basla() end
     self:Guncelle()
end

function SECICI:OnMouseReleased()
     if not self.bolge then return end
     self.bolge = nil
     self:MouseCapture(false)
     if self.bitti then self.bitti() end
end

function SECICI:Think()
     if not self.bolge then return end
     if not input.IsMouseDown(MOUSE_LEFT) then
          self:OnMouseReleased()
          return
     end
     self:Guncelle()
end

vgui.Register("SOg.RenkSecici", SECICI, "Panel")

-- Yara yeri haritası: yüz dokusu üstünde yara damgası; sol sürükle taşı, sağ sürükle döndür, tekerlek boyut
local HARITA = {}
local U0, V0, YAYILIM = 0.12, 0.03, 0.76
local uiMat = {}

local function dokuMat(yol)
     if not uiMat[yol] then
          uiMat[yol] = CreateMaterial("sog_ui_" .. string.gsub(yol, "[^%w]", "_"), "UnlitGeneric",
               {["$basetexture"] = yol, ["$vertexcolor"] = 1, ["$vertexalpha"] = 1, ["$translucent"] = 1})
     end
     return uiMat[yol]
end

function HARITA:Init()
     self:SetCursor("sizeall")
end

function HARITA:Paint(w, h)
     local a = self.ayna
     local d = a.durum
     local _, _, CC = HLStudents.Data(d.gender)
     local sc = d.scar
     draw.RoundedBox(S(6), 0, 0, w, h, R.karo)

     local sk = CC.skins[d.skin or 0]
     local col = d.colors.skin
     local t = sk and sk.tint or Vector(1, 1, 1)
     surface.SetDrawColor(math.min(255, col.x * t.x * 255), math.min(255, col.y * t.y * 255), math.min(255, col.z * t.z * 255))
     surface.SetMaterial(dokuMat("models/hl_students/" .. (sk and sk.head or ((CC.dir or "") .. "head_d"))))
     surface.DrawTexturedRectUV(0, 0, w, w, U0, V0, U0 + YAYILIM, V0 + YAYILIM)

     local info = CC.scars and CC.scars[sc.id or 0]
     if info then
          local r = math.rad(sc.rot or 0)
          local c, sn, fu = math.cos(r), math.sin(r), sc.flip and -1 or 1
          local p = {}
          for k, q in ipairs({{0, 0}, {1, 0}, {1, 1}, {0, 1}}) do
               local dx, dy = (q[1] - 0.5) * sc.size * fu, (q[2] - 0.5) * sc.size
               local u, v = sc.x + c * dx - sn * dy, sc.y + sn * dx + c * dy
               p[k] = {x = (u - U0) / YAYILIM * w, y = (v - V0) / YAYILIM * w, u = q[1], v = q[2]}
          end
          -- aynalanınca köşe sırası ters döner: DrawPoly saat yönü ister
          if sc.flip then p = {p[2], p[1], p[4], p[3]} end
          surface.SetDrawColor(255, 255, 255)
          surface.SetMaterial(dokuMat("models/hl_students/" .. info.tex))
          surface.DrawPoly(p)
          for k = 1, 4 do
               local q1, q2 = p[k], p[k % 4 + 1]
               surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 110)
               surface.DrawLine(q1.x, q1.y, q2.x, q2.y)
          end
     end
     surface.SetDrawColor(R.soluk)
     surface.DrawOutlinedRect(0, 0, w, h, 1)
end

function HARITA:YerAyarla()
     local mx, my = self:CursorPos()
     local w = self:GetWide()
     local A = HLStudents.Config.ScarArea
     local sc = self.ayna.durum.scar
     sc.x = math.Clamp(U0 + mx / w * YAYILIM, A.x0, A.x1)
     sc.y = math.Clamp(V0 + my / w * YAYILIM, A.y0, A.y1)
end

function HARITA:OnMousePressed(k)
     if (self.ayna.durum.scar.id or 0) == 0 then return end
     self.surukle, self.sonX = k, gui.MouseX()
     self:MouseCapture(true)
     self.ayna:GecmisKaydet()
     if k == MOUSE_LEFT then
          self.ayna:Degistir(function() self:YerAyarla() end, nil, true)
     end
end

function HARITA:OnMouseReleased()
     self.surukle = nil
     self:MouseCapture(false)
end

function HARITA:Think()
     if not self.surukle then return end
     if not input.IsMouseDown(self.surukle) then
          self:OnMouseReleased()
          return
     end
     if self.surukle == MOUSE_LEFT then
          self.ayna:Degistir(function() self:YerAyarla() end, nil, true)
     elseif self.surukle == MOUSE_RIGHT then
          local mx = gui.MouseX()
          local fark = mx - self.sonX
          self.sonX = mx
          if fark ~= 0 then
               self.ayna:Degistir(function(d) d.scar.rot = math.NormalizeAngle((d.scar.rot or 0) + fark) end, nil, true)
          end
     end
end

function HARITA:OnMouseWheeled(dlt)
     if (self.ayna.durum.scar.id or 0) == 0 then return end
     local Z = HLStudents.Config.ScarSize
     self.ayna:Degistir(function(d) d.scar.size = math.Clamp(d.scar.size * (1.08 ^ dlt), Z[1], Z[2]) end, nil, true)
     return true
end

vgui.Register("SOg.YaraHarita", HARITA, "Panel")

-- Not metni
local function notEkle(ust, metin, renk)
     local l = ust:Add("DLabel")
     l:Dock(TOP)
     l:DockMargin(0, S(4), 0, S(6))
     l:SetFont("SOg.Kucuk")
     l:SetTextColor(renk or R.gri)
     l:SetWrap(true)
     l:SetAutoStretchVertical(true)
     l:SetText(metin)
     return l
end

----------------------------------------------------------------------------------------
-- Kategori içerikleri
----------------------------------------------------------------------------------------
local function baslik(ust, metin, sag)
     local b = ust:Add("SOg.Baslik")
     b:Dock(TOP)
     b.metin, b.sag = metin, sag
     return b
end

local function karoIzgara(ayna, ust, sutun)
     local l = ust:Add("DIconLayout")
     l:Dock(TOP)
     l:DockMargin(0, S(2), 0, S(8))
     l:SetSpaceX(S(8))
     l:SetSpaceY(S(8))
     return l, math.floor((ayna.icerikW - S(8) * (sutun - 1)) / sutun)
end

local function petekIzgara(ayna, ust, adet, hucre)
     local z = ust:Add("SOg.PetekIzgara")
     z:Dock(TOP)
     z:DockMargin(0, S(2), 0, S(8))
     z:Kur(ayna.icerikW, hucre or S(40), adet)
     return z
end

local function renkTablosu(c)
     return Color(c.r, c.g, c.b)
end

local function vektorRenk(v)
     return Color(math.Clamp(v.x, 0, 1) * 255, math.Clamp(v.y, 0, 1) * 255, math.Clamp(v.z, 0, 1) * 255)
end

local function yakin(a, c)
     return math.abs(a.x * 255 - c.r) < 2 and math.abs(a.y * 255 - c.g) < 2 and math.abs(a.z * 255 - c.b) < 2
end

-- palet + özel renk: anahtar = colors alanı (hair / eyes / brows)
-- palet + özel renk. al(durum) -> Vector, yaz(durum, Vector)
local function renkBolumuGenel(ayna, ust, metin, al, yaz, palet, bolge)
     baslik(ust, metin)
     local secici
     local z = petekIzgara(ayna, ust, #palet)
     for _, c in ipairs(palet) do
          local p = z:Add("SOg.Petek")
          p.renk = renkTablosu(c)
          p.secili = function() return yakin(al(ayna.durum), c) end
          p.Sec = function()
               ayna:Degistir(function(t) yaz(t, Vector(c.r / 255, c.g / 255, c.b / 255)) end, bolge)
               if IsValid(secici) then secici:Ayarla(p.renk) end
          end
     end

     baslik(ust, "Color personalizado")
     secici = ust:Add("SOg.RenkSecici")
     secici:Dock(TOP)
     secici:Ayarla(vektorRenk(al(ayna.durum)))
     secici.basla = function() ayna:GecmisKaydet() end
     secici.degisti = function(c) ayna:Degistir(function(t) yaz(t, Vector(c.r / 255, c.g / 255, c.b / 255)) end, nil, true) end
     secici.bitti = function() ayna.sahne:Parilti(bolge) end
     return secici
end

-- renkler alanı (hair / eyes / brows)
local function renkBolumu(ayna, ust, metin, anahtar, palet, bolge)
     return renkBolumuGenel(ayna, ust, metin, function(t) return t.colors[anahtar] end,
          function(t, v) t.colors[anahtar] = v end, palet, bolge)
end

local function surgu(ayna, ust, ad, min, max, deger, varsayilan, yaz, bicim)
     local s = ust:Add("SOg.Surgu")
     s:Dock(TOP)
     s.ad, s.min, s.max, s.deger, s.varsayilan, s.bicim = ad, min, max, deger, varsayilan, bicim
     s.basla = function() ayna:GecmisKaydet() end
     s.degisti = function(v) ayna:Degistir(function(t) yaz(t, v) end, nil, true) end
     return s
end

-- kişisel boy (O.KisiselBoyAralik ±%4); asıl boy okul yılından (_sh_3durum O.YilBoyu)
local BOYLAR = {{0.96, "Corto"}, {0.98, "Algo corto"}, {1, "Normal"}, {1.02, "Algo largo"}, {1.04, "Largo"}}

local function boyAdi(h)
     local en, ad = 1, ""
     for _, b in ipairs(BOYLAR) do
          if math.abs(b[1] - h) < en then en, ad = math.abs(b[1] - h), b[2] end
     end
     return ad
end

local KURUCU = {}

KURUCU.beden = function(ayna, ust)
     baslik(ust, "Género")
     local satir = ust:Add("Panel")
     satir:Dock(TOP)
     satir:SetTall(S(92))
     satir:DockMargin(0, 0, 0, S(6))
     local yar = (ayna.icerikW - S(10)) / 2
     local CINS = {{"m", "Estudiante chico", "Conjunto con pantalón"}, {"f", "Estudiante chica", "Conjunto con falda"}}
     for i, c in ipairs(CINS) do
          if c[1] == "m" or HLStudents.GearF then
               local k = satir:Add("SOg.Kart")
               k:SetSize(yar, S(92))
               k:SetPos((i - 1) * (yar + S(10)), 0)
               k.cins, k.baslik, k.alt = c[1], c[2], c[3]
               k.secili = function() return ayna.durum.gender == c[1] end
               k.Sec = function() ayna:CinsiyetSec(c[1]) end
          end
     end

     baslik(ust, "Altura", function() return boyAdi(ayna.durum.height or 1) end)
     local s = surgu(ayna, ust, "Escala", O.KisiselBoyAralik[1], O.KisiselBoyAralik[2], O.KisiselBoy(ayna.durum.height), 1,
          function(t, v) t.height = math.Round(v, 3) end, function(v) return string.format("%%%d", math.Round(v * 100)) end)
     s.bitti = function() ayna.sahne:Parilti("govde") end
     notEkle(ust, "Diferencia personal de altura. La altura real crece con el curso: 1.º más bajo, 7.º a tamaño completo.")

     -- kızda ayakkabının altında çorap ya da çıplak bacak (paketin ten dokulu bacağı, sh_bare_legs.lua)
     if ayna.durum.gender == "f" and HLStudents.GearF and HLStudents.GearF.pieces.f_legs_bare then
          baslik(ust, "Piernas", function() return ayna.durum.ciplakBacak and "Piernas desnudas" or "Con calcetines" end)
          local bk = ust:Add("SOg.Sekmeler")
          bk:Dock(TOP)
          bk:DockMargin(0, S(2), 0, S(6))
          bk.liste = {{id = false, ad = "CON CALCETINES"}, {id = true, ad = "PIERNAS DESNUDAS"}}
          bk.secili = function() return ayna.durum.ciplakBacak == true end
          bk.sec = function(v) ayna:Degistir(function(t) t.ciplakBacak = v or nil end, "ayak") end
          notEkle(ust, "Si llevas calcetines de ítem, se ven; si no, se usa esta opción bajo el zapato.")
     end

     baslik(ust, "Pose", "solo en el espejo")
     local poz = ust:Add("SOg.Sekmeler")
     poz:Dock(TOP)
     poz:DockMargin(0, S(2), 0, S(6))
     poz.liste = {}
     for i = 1, math.min(4, #O.SahnePoz) do poz.liste[#poz.liste + 1] = {id = i, ad = O.SahnePoz[i][2]} end
     poz.secili = function() return ayna.sahne.poz end
     poz.sec = function(i) ayna.sahne:Poz(i) end
     if #O.SahnePoz > 4 then
          local poz2 = ust:Add("SOg.Sekmeler")
          poz2:Dock(TOP)
          poz2.liste = {}
          for i = 5, #O.SahnePoz do poz2.liste[#poz2.liste + 1] = {id = i, ad = O.SahnePoz[i][2]} end
          poz2.secili = poz.secili
          poz2.sec = poz.sec
     end
end

-- küçük hap düğmesi (hazır hatlar): secili() iken altın
local function hap(ust, metin, secili, tikla)
     surface.SetFont("SOg.Etiket")
     local tw = surface.GetTextSize(metin)
     local b = ust:Add("DButton")
     b:SetText("")
     b:SetSize(tw + S(26), S(28))
     b.vurgu = 0
     b.Paint = function(this, w, h)
          local on = secili and secili()
          this.vurgu = Lerp(FrameTime() * 12, this.vurgu, this:IsHovered() and 1 or 0)
          draw.RoundedBox(h / 2, 0, 0, w, h, on and R.altin or Color(255, 255, 255, 8 + 18 * this.vurgu))
          draw.SimpleText(metin, "SOg.Etiket", w / 2, h / 2, on and R.murekkep or (this.vurgu > 0.5 and R.metin or R.gri), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
     b.DoClick = function() tikla() end
     b.OnCursorEntered = function() ses("ust") end
     return b
end

-- Dinlenme ifadesi: hazır ifadeler (üzerine gelince aynada dener) + gruplu ince ayar
KURUCU.ifade = function(ayna, ust)
     local d = ayna.durum
     baslik(ust, "Dinlenme ifadesi", function()
          for _, h in ipairs(O.IfadeHazir) do
               if O.IfadeAyni(ayna.durum.ifade or {}, h[2]) then return h[1] end
          end
          return "Personalizado"
     end)
     local l, b = karoIzgara(ayna, ust, 3)
     for _, h in ipairs(O.IfadeHazir) do
          local k = l:Add("SOg.Karo")
          k:SetSize(b, S(50))
          k.metinIc, k.metinFont = h[1], "SOg.Kucuk"
          k.secili = function() return O.IfadeAyni(ayna.durum.ifade or {}, h[2]) end
          k.Sec = function()
               ayna:IfadeOnizle(nil)
               ayna:Degistir(function(t) t.ifade = table.Copy(h[2]) end, "yuz")
               ayna:IcerikKur()
          end
          k.OnCursorEntered = function()
               ses("ust")
               ayna:IfadeOnizle(h[2])
          end
          k.OnCursorExited = function() ayna:IfadeOnizle(nil) end
     end
     notEkle(ust, "La expresión en reposo; en juego todos te verán así. Pasa el cursor: pruébala en el espejo. Habla y el parpadeo se añaden encima.")

     -- kısa yüz hareketleri (oyunda çark: I, ya da /ifade) ve konuşma: aynada dene
     baslik(ust, "Gestos faciales", "en juego: tecla I")
     local hl = ust:Add("DIconLayout")
     hl:Dock(TOP)
     hl:DockMargin(0, S(2), 0, S(6))
     hl:SetSpaceX(S(6))
     hl:SetSpaceY(S(6))
     local function oniz() return ayna.sahne.ent end
     for _, hr in ipairs(O.Hareket or {}) do
          hap(hl, hr[2], function()
               local e = oniz()
               return IsValid(e) and e.sogHareketOniz ~= nil and e.sogHareketOniz[1] == hr
          end, function()
               local e = oniz()
               if IsValid(e) then
                    e.sogHareketOniz = {hr, RealTime()}
                    ses("tik")
               end
          end)
     end
     hap(hl, "Probar habla", function()
          local e = oniz()
          return IsValid(e) and (e.sogKonusmaOniz or 0) > RealTime()
     end, function()
          local e = oniz()
          if IsValid(e) then
               e.sogKonusmaOniz = RealTime() + 4
               ses("tik")
          end
     end)
     notEkle(ust, "Los gestos duran unos segundos y vuelven a la expresión en reposo; todos los ven. Al hablar, la boca sigue el sonido.")

     for _, g in ipairs(O.IfadeGrup) do
          baslik(ust, g.ad)
          for _, it in ipairs(g.liste) do
               local ad, enCok = it[1], it[3]
               surgu(ayna, ust, it[2], 0, enCok, d.ifade[ad] or 0, 0, function(t, v) t.ifade[ad] = v end,
                    function(v) return string.format("%%%d", math.Round(v / enCok * 100)) end)
          end
          if g.ad == "Boca" then
               local sol, sag, enCok = O.IfadeYan[1], O.IfadeYan[2], O.IfadeYan[3]
               surgu(ayna, ust, "Comisuras (izq. / der.)", -enCok, enCok, (d.ifade[sag] or 0) - (d.ifade[sol] or 0), 0,
                    function(t, v)
                         t.ifade[sol] = v < 0 and -v or nil
                         t.ifade[sag] = v > 0 and v or nil
                    end, function(v)
                         local p = math.Round(v / enCok * 100)
                         return p == 0 and "0" or (p < 0 and ("sol %" .. -p) or ("der. %" .. p))
                    end)
          end
     end

     local sf = ust:Add("SOg.Hayalet")
     sf.metin, sf.yon = "Resetear expresión", 0
     sf:Dock(TOP)
     sf:SetTall(S(40))
     sf:DockMargin(0, S(10), 0, S(6))
     sf.DoClick = function()
          ayna:Degistir(function(t) t.ifade = {} end, "yuz")
          ayna:IcerikKur()
     end
end

-- Hazır hatlar: bir bölgeye ait olanlar o bölgenin kartında, genel olanlar Yüz tipi kartında
local HAZIR_BOLGE = {["Nariz aguileña"] = "burun", ["Nariz respingona"] = "burun", ["Labios carnosos"] = "agiz",
     ["Ojos grandes"] = "goz", ["Mandíbula ancha"] = "cene"}

local function hazirHatlar(ayna, ust, kart)
     local liste = {}
     for _, h in ipairs(O.YuzHazir) do
          if (HAZIR_BOLGE[h[1]] or "yuztipi") == kart then liste[#liste + 1] = h end
     end
     if #liste == 0 then return end
     baslik(ust, "Rasgos listos", #liste > 1 and "combinables" or nil)
     local hl = ust:Add("DIconLayout")
     hl:Dock(TOP)
     hl:DockMargin(0, S(2), 0, S(6))
     hl:SetSpaceX(S(6))
     hl:SetSpaceY(S(6))
     for _, h in ipairs(liste) do
          hap(hl, h[1], function()
               for ad, v in pairs(h[2]) do
                    if math.abs((ayna.durum.flex[ad] or 0) - v) > 0.002 then return false end
               end
               return true
          end, function()
               ayna:Degistir(function(t)
                    for ad, v in pairs(h[2]) do t.flex[ad] = v end
               end, "yuz")
               ayna:IcerikKur()
          end)
     end
end

-- kaydırıcı grubunun (HLStudents.Config.SlidersOf) öğeleri {denetleyici, ad}; yalniz: yalnız bu denetleyiciler
local function grupOgeleri(cins, grupAdi, yalniz)
     local t = {}
     for _, grup in ipairs(HLStudents.Config.SlidersOf(cins)) do
          if grup.group == grupAdi then
               for _, it in ipairs(grup.items) do
                    if not yalniz or yalniz[it[1]] then t[#t + 1] = it end
               end
          end
     end
     return t
end

local function grupKaydiricilari(ayna, ust, grupAdi, yalniz)
     local d = ayna.durum
     for _, it in ipairs(grupOgeleri(d.gender, grupAdi, yalniz)) do
          local ad = it[1]
          surgu(ayna, ust, it[2], -1, 1, d.flex[ad] or 0, 0, function(t, v) t.flex[ad] = v end)
     end
end

local function bolgeKurucu(grupAdi, yalniz, kart, metin)
     return function(ayna, ust)
          baslik(ust, "Rasgos")
          grupKaydiricilari(ayna, ust, grupAdi, yalniz)
          hazirHatlar(ayna, ust, kart)
          notEkle(ust, metin or "Arrastra el deslizador; doble clic resetea ese rasgo.")
     end
end

KURUCU.burun = bolgeKurucu("Burun", nil, "burun")
KURUCU.elmacik = bolgeKurucu("Pómulos y mejillas", nil, "elmacik")
KURUCU.cene = bolgeKurucu("Mandíbula", nil, "cene")
KURUCU.agiz = bolgeKurucu("Boca", nil, "agiz", "Forma de los labios. Sonrisa y comisuras están en la marca Expresión.")
KURUCU.kulak = bolgeKurucu("Cara", {ear_size = true}, "kulak")

-- Yüz tipi: paketin hazır yüzleri (her biri ayrı model, sh_faces.lua; 1 = ana yüz), genel hatlar, karıştır
KURUCU.yuztipi = function(ayna, ust)
     local d = ayna.durum
     local yuzler = HLStudents.FacesOf and HLStudents.FacesOf(d.gender) or {}
     if ayna.kanon then
          -- kanon karakter (_sh_4helix.lua): yüz kanonun modeli, değişmez
          baslik(ust, "Cara base", function() return ayna.kanon.ad end)
          notEkle(ust, ayna.kanon.ad .. " la cara del personaje canónico es fija. Al dejar el rol vuelves a tu cara.")
     elseif #yuzler > 1 then
          baslik(ust, "Cara base", function()
               local f = yuzler[ayna.durum.face or 1]
               return f and f.label or ""
          end)
          local l, b = karoIzgara(ayna, ust, 4)
          for i, f in ipairs(yuzler) do
               -- (kanon yüzleri listenin sonunda; yalnız rolle gelir)
               if f.kanon then break end
               local k = l:Add("SOg.Karo")
               k:SetSize(b, b)
               k.mat = O.IkonMat(f.icon)
               if not k.mat then k.metinIc, k.metinFont = f.label, "SOg.Kucuk" end
               k.ipucu = f.label
               k.secili = function() return (ayna.durum.face or 1) == i end
               k.Sec = function() ayna:Degistir(function(t) t.face = i end, "yuz") end
          end
          notEkle(ust, "La cara base cambia la estructura de la cabeza; los rasgos de las marcas se aplican encima.")
     end

     baslik(ust, "Genel")
     grupKaydiricilari(ayna, ust, "Cara", {face_width = true})
     hazirHatlar(ayna, ust, "yuztipi")

     local arac = ust:Add("Panel")
     arac:Dock(TOP)
     arac:SetTall(S(34))
     arac:DockMargin(0, S(10), 0, S(4))
     local a1 = arac:Add("SOg.Hayalet")
     a1.metin, a1.yon = "Aleatorizar cara", 0
     a1:Dock(LEFT)
     a1:SetWide(S(170))
     a1.DoClick = function()
          ayna:Degistir(function(t)
               t.flex = {}
               for _, grup in ipairs(HLStudents.Config.SlidersOf(t.gender)) do
                    for _, it in ipairs(grup.items) do
                         if math.random() < 0.7 then t.flex[it[1]] = math.Round(math.Rand(-0.5, 0.5), 2) end
                    end
               end
          end, "yuz")
          ayna:IcerikKur()
     end
     local a2 = arac:Add("SOg.Hayalet")
     a2.metin, a2.yon = "Resetear todos los rasgos", 0
     a2:Dock(LEFT)
     a2:SetWide(S(230))
     a2.DoClick = function()
          ayna:Degistir(function(t) t.flex = {} end, "yuz")
          ayna:IcerikKur()
     end
end

KURUCU.ten = function(ayna, ust, bolum)
     local d = ayna.durum
     local _, _, CC = HLStudents.Data(d.gender)

     if bolum == "ton" then
          baslik(ust, "Tono de piel", function() return (ayna.durum.skin or 0) == 0 and "Natural" or ("Tono " .. ayna.durum.skin) end)
          local z = petekIzgara(ayna, ust, #CC.skins + 1, S(44))
          local dogal = z:Add("SOg.Petek")
          dogal.renk = renkTablosu(CC.base_swatch or Color(170, 120, 100))
          dogal.secili = function() return (ayna.durum.skin or 0) == 0 end
          dogal.Sec = function() ayna:Degistir(function(t) t.skin = 0 end, "ten") end
          for i, sk in ipairs(CC.skins) do
               local p = z:Add("SOg.Petek")
               p.renk = renkTablosu(sk.swatch)
               p.secili = function() return ayna.durum.skin == i end
               p.Sec = function() ayna:Degistir(function(t) t.skin = i end, "ten") end
          end

          -- ince ayar: ten rengi çarpanı (colors.skin) açıklık + sıcaklık olarak
          baslik(ust, "Ajuste fino")
          local c = d.colors.skin
          local acik = math.Clamp(c.y, 0.8, 1.2)
          local sicak = math.Clamp(((c.x / math.max(acik, 0.01)) - 1) / 0.08, -1, 1)
          local function yaz(t, a, s)
               t.colors.skin = Vector(a * (1 + 0.08 * s), a, a * (1 - 0.08 * s))
          end
          local sa, ss
          sa = surgu(ayna, ust, "Claridad", 0.8, 1.2, acik, 1, function(t, v) yaz(t, v, ss.deger) end,
               function(v) return string.format("%%%d", math.Round(v * 100)) end)
          ss = surgu(ayna, ust, "Calidez", -1, 1, sicak, 0, function(t, v) yaz(t, sa.deger, v) end)
          sa.bitti = function() ayna.sahne:Parilti("ten") end
          ss.bitti = sa.bitti
          notEkle(ust, "El tono elige la textura de cara y brazos; el ajuste fino aclara, oscurece o calienta esa textura.")
     elseif bolum == "iz" then
          local BASLIK = {"Pecas y lunares", "Detalle de piel (enrojecimiento, marcas de acné, ojeras)"}
          for katman = 1, 2 do
               local liste = (CC.marks or {})[katman] or {}
               baslik(ust, BASLIK[katman])
               local l, b = karoIzgara(ayna, ust, 5)
               local yok = l:Add("SOg.Karo")
               yok:SetSize(b, b)
               yok.bos = true
               yok.secili = function() return (ayna.durum.marks[katman] or 0) == 0 end
               yok.Sec = function() ayna:Degistir(function(t) t.marks[katman] = 0 end, "yuz") end
               for i, it in ipairs(liste) do
                    local k = l:Add("SOg.Karo")
                    k:SetSize(b, b)
                    k.mat = O.IkonMat(it.icon)
                    k.numara = tostring(i)
                    k.secili = function() return ayna.durum.marks[katman] == i end
                    k.Sec = function() ayna:Degistir(function(t) t.marks[katman] = i end, "yuz") end
               end
          end
     elseif bolum == "yara" then
          baslik(ust, "Yara", function() return (ayna.durum.scar.id or 0) == 0 and "Nada" or ("Yara " .. ayna.durum.scar.id) end)
          local l, b = karoIzgara(ayna, ust, 5)
          local yok = l:Add("SOg.Karo")
          yok:SetSize(b, b)
          yok.bos = true
          yok.secili = function() return (ayna.durum.scar.id or 0) == 0 end
          yok.Sec = function()
               ayna:Degistir(function(t) t.scar.id = 0 end, "yuz")
               ayna:IcerikKur()
          end
          for i, it in ipairs(CC.scars or {}) do
               local k = l:Add("SOg.Karo")
               k:SetSize(b, b)
               k.mat = O.IkonMat(it.icon)
               k.numara = tostring(i)
               k.secili = function() return ayna.durum.scar.id == i end
               k.Sec = function()
                    ayna:Degistir(function(t)
                         t.scar = {id = i, x = it.x, y = it.y, rot = 0, size = it.size, flip = false}
                    end, "yuz")
                    ayna:IcerikKur()
               end
          end

          if (d.scar.id or 0) > 0 then
               baslik(ust, "Posición", "izq.: mover · der.: girar · rueda: tamaño")
               local satir = ust:Add("Panel")
               satir:Dock(TOP)
               local hw = math.floor(ayna.icerikW * 0.56)
               satir:SetTall(hw)
               local harita = satir:Add("SOg.YaraHarita")
               harita.ayna = ayna
               harita:SetPos(0, 0)
               harita:SetSize(hw, hw)

               local araclar = {
                    {"Girar a la izquierda", function(t) t.scar.rot = math.NormalizeAngle((t.scar.rot or 0) - 15) end},
                    {"Girar a la derecha", function(t) t.scar.rot = math.NormalizeAngle((t.scar.rot or 0) + 15) end},
                    {"Reducir", function(t) t.scar.size = math.Clamp(t.scar.size / 1.15, HLStudents.Config.ScarSize[1], HLStudents.Config.ScarSize[2]) end},
                    {"Aumentar", function(t) t.scar.size = math.Clamp(t.scar.size * 1.15, HLStudents.Config.ScarSize[1], HLStudents.Config.ScarSize[2]) end},
                    {"Voltear", function(t) t.scar.flip = not t.scar.flip end},
                    {"Posición inicial", function(t)
                         local info = CC.scars[t.scar.id]
                         if info then t.scar.x, t.scar.y, t.scar.size, t.scar.rot, t.scar.flip = info.x, info.y, info.size, 0, false end
                    end},
               }
               local ax = hw + S(12)
               local aw = ayna.icerikW - ax
               for i, a in ipairs(araclar) do
                    local dg = satir:Add("DButton")
                    dg:SetText("")
                    dg:SetPos(ax, (i - 1) * S(38))
                    dg:SetSize(aw, S(32))
                    dg.vurgu = 0
                    dg.Paint = function(this, w, h)
                         this.vurgu = Lerp(FrameTime() * 10, this.vurgu, this:IsHovered() and 1 or 0)
                         poly(kesik(0, 0, w, h, S(6)), Color(20 + 14 * this.vurgu, 23 + 13 * this.vurgu, 36 + 14 * this.vurgu, 236))
                         draw.SimpleText(a[1], "SOg.Kucuk", w / 2, h / 2, this.vurgu > 0.5 and R.parlak or R.metin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                    dg.DoClick = function() ayna:Degistir(a[2], "yuz") end
               end
          end
     end
end

KURUCU.sac = function(ayna, ust, bolum)
     local d = ayna.durum
     if ayna.kanon then
          -- kanon kafasının saçı modelin kendisinde (_sh_4helix.lua)
          baslik(ust, "Pelo", function() return ayna.kanon.ad end)
          notEkle(ust, ayna.kanon.ad .. " el pelo canónico va en el modelo; peinado y color no cambian.")
          return
     end
     local _, HR, CC = HLStudents.Data(d.gender)

     if bolum == "model" then
          baslik(ust, "Peinado", function()
               local h = HR.list[ayna.durum.hair or ""]
               return h and h.label or "Calvo"
          end)
          local l, b = karoIzgara(ayna, ust, 4)
          local kel = l:Add("SOg.Karo")
          kel:SetSize(b, b)
          kel.bos = true
          kel.ipucu = "Calvo"
          kel.secili = function() return ayna.durum.hair == "" end
          kel.Sec = function() ayna:Degistir(function(t) t.hair = "" end, "sac") end
          for _, id in ipairs(HR.order) do
               local h = HR.list[id]
               local k = l:Add("SOg.Karo")
               k:SetSize(b, b)
               k.mat = h.icon ~= "" and O.IkonMat(h.icon) or nil
               if not k.mat then k.metinIc, k.metinFont = h.label, "SOg.Kucuk" end
               k.ipucu = h.label
               k.secili = function() return ayna.durum.hair == id end
               k.Sec = function() ayna:Degistir(function(t) t.hair = id end, "sac") end
          end
     elseif bolum == "renk" then
          renkBolumu(ayna, ust, "Color de pelo", "hair", CC.hair_colors or {}, "sac")
     elseif bolum == "kas" then
          baslik(ust, "Forma de ceja")
          local l, b = karoIzgara(ayna, ust, 5)
          local dogal = l:Add("SOg.Karo")
          dogal:SetSize(b, b)
          dogal.metinIc = "Natural"
          dogal.metinFont = "SOg.Kucuk"
          dogal.secili = function() return (ayna.durum.brow or 0) == 0 end
          dogal.Sec = function() ayna:Degistir(function(t) t.brow = 0 end, "yuz") end
          for i, br in ipairs(CC.brows or {}) do
               local k = l:Add("SOg.Karo")
               k:SetSize(b, b)
               k.mat = O.IkonMat(br.icon)
               k.numara = tostring(i)
               k.secili = function() return ayna.durum.brow == i end
               k.Sec = function() ayna:Degistir(function(t) t.brow = i end, "yuz") end
          end
          renkBolumu(ayna, ust, "Color de ceja", "brows", CC.brow_colors or {}, "yuz")
     end
end

KURUCU.goz = function(ayna, ust, bolum)
     local d = ayna.durum
     local _, _, CC = HLStudents.Data(d.gender)
     if bolum == "renk" then
          local alanlar = HLStudents.EyeColourFields
          if alanlar then
               local kip = ust:Add("SOg.Sekmeler")
               kip:Dock(TOP)
               kip:DockMargin(0, S(8), 0, S(2))
               kip.liste = {{id = false, ad = "UN COLOR"}, {id = true, ad = "CADA OJO APARTE"}}
               kip.secili = function() return ayna.durum.eyes.advanced == true end
               kip.sec = function(v)
                    ayna:Degistir(function(t)
                         if v then
                              for _, k in ipairs(alanlar) do
                                   if not t.eyes[k] then t.eyes[k] = Vector(t.colors.eyes.x, t.colors.eyes.y, t.colors.eyes.z) end
                              end
                         end
                         t.eyes.advanced = v
                    end, "goz")
                    ayna:IcerikKur()
               end
          end

          if not (alanlar and d.eyes.advanced) then
               renkBolumu(ayna, ust, "Color de ojos", "eyes", CC.eye_colors or {}, "goz")
               if alanlar then notEkle(ust, "\"Cada ojo aparte\" permite colorear ojo derecho e izquierdo y el anillo interno/externo del iris (heterocromía, iris bicolor).") end
          else
               local HALKA = {{"left_outer", "IZQ. · EXT."}, {"left_inner", "IZQ. · INT."}, {"right_outer", "DER. · EXT."}, {"right_inner", "DER. · INT."}}
               ayna.gozHalka = ayna.gozHalka or "left_outer"
               local sec = ust:Add("SOg.Sekmeler")
               sec:Dock(TOP)
               sec:DockMargin(0, S(10), 0, S(2))
               sec.liste = {}
               for _, h in ipairs(HALKA) do sec.liste[#sec.liste + 1] = {id = h[1], ad = h[2]} end
               sec.secili = function() return ayna.gozHalka end
               sec.sec = function(k)
                    ayna.gozHalka = k
                    ayna:IcerikKur()
               end
               local alan = ayna.gozHalka
               renkBolumuGenel(ayna, ust, "Anillo del iris", function(t) return t.eyes[alan] or t.colors.eyes end,
                    function(t, v) t.eyes[alan] = v end, CC.eye_colors or {}, "goz")

               local kopya = ust:Add("SOg.Hayalet")
               local sol = string.StartWith(alan, "left")
               kopya.metin, kopya.yon = sol and "Copiar ojo izq. al der." or "Copiar ojo der. al izq.", 0
               kopya:Dock(TOP)
               kopya:SetTall(S(40))
               kopya:DockMargin(0, S(6), 0, S(2))
               kopya.DoClick = function()
                    local k, h = sol and "left" or "right", sol and "right" or "left"
                    ayna:Degistir(function(t)
                         t.eyes[h .. "_inner"] = Vector(t.eyes[k .. "_inner"])
                         t.eyes[h .. "_outer"] = Vector(t.eyes[k .. "_outer"])
                    end, "goz")
               end
               notEkle(ust, "Izquierda/derecha según el personaje. El anillo interno rodea la pupila; el externo es el borde del iris.")
          end
     else
          baslik(ust, "Dirección de la mirada")
          surgu(ayna, ust, "Izquierda / derecha", -1, 1, d.eyes.yaw or 0, 0, function(t, v) t.eyes.yaw = v end)
          surgu(ayna, ust, "Abajo / arriba", -1, 1, d.eyes.pitch or 0, 0, function(t, v) t.eyes.pitch = v end)
          notEkle(ust, "Los ojos miran fijos en esa dirección, giran con la cabeza y parpadean solos.")
     end
end

KURUCU.makyaj = function(ayna, ust, bolum)
     local d = ayna.durum
     local _, _, CC = HLStudents.Data(d.gender)
     local IP = d.gender == "f" and "f_" or ""

     if bolum == "stil" then
          baslik(ust, "Maquillaje / pintura facial", function() return (ayna.durum.makeup.style or 0) == 0 and "Nada" or ("Estilo " .. ayna.durum.makeup.style) end)
          local l, b = karoIzgara(ayna, ust, 4)
          local yok = l:Add("SOg.Karo")
          yok:SetSize(b, b)
          yok.bos = true
          yok.secili = function() return (ayna.durum.makeup.style or 0) == 0 end
          yok.Sec = function() ayna:Degistir(function(t) t.makeup.style = 0 end, "makyaj") end
          for i = 1, CC.makeup_styles or 0 do
               local k = l:Add("SOg.Karo")
               k:SetSize(b, b)
               k.mat = O.IkonMat("hl_students/icons/cc/" .. IP .. "makeup_" .. i .. ".png")
               k.numara = tostring(i)
               k.secili = function() return ayna.durum.makeup.style == i end
               k.Sec = function() ayna:Degistir(function(t) t.makeup.style = i end, "makyaj") end
          end
          notEkle(ust, "El estilo decide dónde cae el color en la cara; elige colores en la sección Colores.")
          return
     end

     local AD = {lip = "Ruj", blush = "Colorete", shadow = "Far", liner = "Delineador"}
     if d.gender ~= "f" then notEkle(ust, "En estudiantes chicos solo hay colorete (labial, sombra, delineador y pintura facial son de chicas).") end
     for _, parca in ipairs(HLStudents.Config.MakeupParts) do
          if parca == "blush" or d.gender == "f" then
               local liste = (CC.makeup_colors or {})[parca] or {}
               baslik(ust, AD[parca] or parca)
               local z = petekIzgara(ayna, ust, #liste + 1, S(36))
               local yok = z:Add("SOg.Petek")
               yok.bos = true
               yok.secili = function() return (ayna.durum.makeup[parca] or 0) == 0 and not (parca == "lip" and ayna.durum.makeup.lip_rgb) end
               yok.Sec = function()
                    ayna:Degistir(function(t)
                         t.makeup[parca] = 0
                         if parca == "lip" then t.makeup.lip_rgb = nil end
                    end, "makyaj")
               end
               for i, c in ipairs(liste) do
                    local p = z:Add("SOg.Petek")
                    -- palet doğrusal: ekranda gama
                    p.renk = Color(255 * c.x ^ (1 / 2.2), 255 * c.y ^ (1 / 2.2), 255 * c.z ^ (1 / 2.2))
                    p.secili = function() return ayna.durum.makeup[parca] == i and not (parca == "lip" and ayna.durum.makeup.lip_rgb) end
                    p.Sec = function()
                         ayna:Degistir(function(t)
                              t.makeup[parca] = i
                              if parca == "lip" then t.makeup.lip_rgb = nil end
                              if (t.makeup.style or 0) == 0 then t.makeup.style = 1 end
                         end, "makyaj")
                    end
               end

               if parca == "lip" then
                    baslik(ust, "Kendi ruj rengin")
                    local s = ust:Add("SOg.RenkSecici")
                    s:Dock(TOP)
                    local c0 = d.makeup.lip_rgb
                    s:Ayarla(c0 and Color(255 * c0.x ^ (1 / 2.2), 255 * c0.y ^ (1 / 2.2), 255 * c0.z ^ (1 / 2.2)) or Color(170, 60, 70))
                    s.basla = function() ayna:GecmisKaydet() end
                    s.degisti = function(c)
                         ayna:Degistir(function(t)
                              t.makeup.lip_rgb = Vector((c.r / 255) ^ 2.2, (c.g / 255) ^ 2.2, (c.b / 255) ^ 2.2)
                              if (t.makeup.lip or 0) == 0 then t.makeup.lip = 1 end
                         end, nil, true)
                    end
                    s.bitti = function() ayna.sahne:Parilti("makyaj") end
                    surgu(ayna, ust, "Intensidad del labial", 0, 1, d.makeup.lip_amt or 1, 1, function(t, v) t.makeup.lip_amt = v end)
                    surgu(ayna, ust, "Brillo del labial", 0, 1, d.makeup.lip_gloss or 0.3, 0.3, function(t, v) t.makeup.lip_gloss = v end)
               end
          end
     end
end

-- Kaşlar: stil (doku + renk; eski Saç kurucusunun "kas" bölümü) ve şekil (kaydırıcılar)
KURUCU.kas = function(ayna, ust, bolum)
     if bolum == "sekil" then
          baslik(ust, "Rasgos")
          grupKaydiricilari(ayna, ust, "Cejas")
          notEkle(ust, "Posición y forma de las cejas. Subir y fruncir están en la marca Expresión.")
          return
     end
     KURUCU.sac(ayna, ust, "kas")
end

-- Gözler: renk ve bakış eski kurucuda, şekil kaydırıcıları burada
local gozRenkBakis = KURUCU.goz
KURUCU.goz = function(ayna, ust, bolum)
     if bolum == "sekil" then
          baslik(ust, "Rasgos")
          grupKaydiricilari(ayna, ust, "Ojos")
          hazirHatlar(ayna, ust, "goz")
          return
     end
     gozRenkBakis(ayna, ust, bolum)
end

-- Başlangıç takımı: üst (12 renk; seçilince alt ona uyan renge geçer), alt ve ayakkabı (sabit renkli seçenekler)
KURUCU.ust = function(ayna, ust)
     local d = ayna.durum
     local B = O.Baslangic[d.gender]
     local p = O.GiysiParcasi(B.ust, d.gender)

     baslik(ust, O.Giysi[B.ust].ad, function() return "Color " .. ((ayna.durum.kiyafet or {}).ust or 1) end)
     local l, b = karoIzgara(ayna, ust, 4)
     for i = 1, p and #p.looks or 0 do
          local k = l:Add("SOg.Karo")
          k:SetSize(b, b)
          k.mat = O.IkonMat(O.GiysiIkonYolu(p, i, ayna.hane))
          k.numara = tostring(i)
          k.ipucu = "Color " .. i
          k.secili = function() return ayna.durum.kiyafet.ust == i end
          k.Sec = function()
               ayna:Degistir(function(t)
                    t.kiyafet.ust = i
                    t.kiyafet.alt = B.alt.eslesme[i] or t.kiyafet.alt
               end, "ust")
          end
     end
     notEkle(ust, "Al elegir el color, la prenda inferior se adapta; también puedes cambiarlo desde la marca Inferior.")

     baslik(ust, "Tu guardarropa")
     notEkle(ust, "Como en Hogwarts Legacy, entras al colegio con el conjunto inicial; llega al inventario como objetos equipados. Túnica, bufanda, sombrero, gafas y demás se obtienen en juego; la ropa de casa se tiñe con los colores de tu casa.", R.metin)
end

local function kiyafetSecenek(ayna, ust, metin, anahtar, liste, bolge)
     baslik(ust, metin, function()
          for _, s in ipairs(liste) do
               if s[1] == ayna.durum.kiyafet[anahtar] then return s[2] end
          end
          return ""
     end)
     local z = petekIzgara(ayna, ust, #liste, S(44))
     for _, s in ipairs(liste) do
          local pt = z:Add("SOg.Petek")
          pt.renk = s[3]
          pt.ipucu = s[2]
          pt.secili = function() return ayna.durum.kiyafet[anahtar] == s[1] end
          pt.Sec = function() ayna:Degistir(function(t) t.kiyafet[anahtar] = s[1] end, bolge) end
     end
end

KURUCU.alt = function(ayna, ust)
     local B = O.Baslangic[ayna.durum.gender]
     kiyafetSecenek(ayna, ust, O.Giysi[B.alt.giysi].ad, "alt", B.alt.secenek, "govde")
end

KURUCU.ayakkabi = function(ayna, ust)
     local B = O.Baslangic[ayna.durum.gender]
     kiyafetSecenek(ayna, ust, O.Giysi[B.ayakkabi.giysi].ad, "ayakkabi", B.ayakkabi.secenek, "ayak")
end

-- Görünümlerim: bu bilgisayarda kayıtlı görünümler (data/sardon_ogrenci/gorunum/*.json) ve paylaşım kodu
-- ("SOG1:" + base64(sıkıştırılmış JSON)); yüklenen her şey O.Temizle'den geçer
local KAYIT_KLASOR = "sardon_ogrenci/gorunum"
local KOD_ON = "SOG1:"
local KATLA = {["Ç"] = "c", ["ç"] = "c", ["Ğ"] = "g", ["ğ"] = "g", ["İ"] = "i", ["ı"] = "i", ["Ö"] = "o", ["ö"] = "o",
     ["Ş"] = "s", ["ş"] = "s", ["Ü"] = "u", ["ü"] = "u"}

local function dosyaAdi(ad)
     local s2 = string.gsub(tostring(ad), "[\195\196\197][\128-\191]", KATLA)
     s2 = string.gsub(string.lower(s2), "[^%w]+", "_")
     return string.sub(string.Trim(s2, "_"), 1, 40)
end

local function kayitlar()
     local t = {}
     for _, f in ipairs(file.Find(KAYIT_KLASOR .. "/*.json", "DATA") or {}) do
          local veri = util.JSONToTable(file.Read(KAYIT_KLASOR .. "/" .. f, "DATA") or "")
          if istable(veri) and istable(veri.durum) then
               veri.dosya = f
               t[#t + 1] = veri
          end
     end
     table.sort(t, function(a, b) return (a.tarih or 0) > (b.tarih or 0) end)
     return t
end

-- ayna durumunun kaydedilecek kopyası (kıyafet yalnız yaratmada anlamlı)
local function kayitDurumu(ayna)
     local d = O.Temizle(table.Copy(ayna.durum)) or {}
     if ayna.secenek.baslangic and ayna.durum.kiyafet then d.kiyafet = table.Copy(ayna.durum.kiyafet) end
     return d
end

function O.GorunumKodu(d)
     return KOD_ON .. string.gsub(util.Base64Encode(util.Compress(util.TableToJSON(d))) or "", "%s", "")
end

function O.GorunumKodCoz(kod)
     kod = string.gsub(tostring(kod or ""), "%s", "")
     if string.sub(kod, 1, #KOD_ON) ~= KOD_ON then return nil end
     local ham = util.Base64Decode(string.sub(kod, #KOD_ON + 1))
     local json = ham and util.Decompress(ham)
     local t = json and util.JSONToTable(json)
     return istable(t) and t or nil
end

-- yüklenen görünüm aynaya (doğrulanmış); false: geçersiz
local function gorunumYukle(ayna, veri)
     local y = istable(veri) and O.Temizle(table.Copy(veri))
     if not y then return false end
     local kiyafet = ayna.secenek.baslangic and istable(veri.kiyafet) and veri.kiyafet or nil
     ayna:Degistir(function(t)
          for k in pairs(t) do t[k] = nil end
          for k, v in pairs(y) do t[k] = v end
          if ayna.secenek.baslangic then t.kiyafet = O.BaslangicTemizle(y.gender, kiyafet or {}) end
     end, "govde")
     ayna:IcerikKur()
     return true
end

local function girisKutusu(ebeveyn, ipucu)
     local g = ebeveyn:Add("DTextEntry")
     g:SetFont("SOg.Metin")
     g:SetPaintBackground(false)
     g.Paint = function(this, w, h)
          draw.RoundedBox(S(6), 0, 0, w, h, Color(10, 12, 20, 235))
          surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, this:HasFocus() and 180 or 60)
          surface.DrawOutlinedRect(0, 0, w, h, 1)
          if this:GetValue() == "" and not this:HasFocus() then
               draw.SimpleText(ipucu, "SOg.Metin", S(10), h / 2, R.sonuk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
          this:DrawTextEntryText(R.metin, R.soluk, R.parlak)
     end
     return g
end

local function kucukDugme(ebeveyn, metin, tikla)
     local b = ebeveyn:Add("DButton")
     b:SetText("")
     surface.SetFont("SOg.Etiket")
     b:SetWide(surface.GetTextSize(metin) + S(26))
     b.vurgu = 0
     b.metin = metin
     b.Paint = function(this, w, h)
          this.vurgu = Lerp(FrameTime() * 12, this.vurgu, this:IsHovered() and 1 or 0)
          draw.RoundedBox(h / 2, 0, 0, w, h, this.vurgulu and R.altin or Color(255, 255, 255, 10 + 20 * this.vurgu))
          draw.SimpleText(this.metin, "SOg.Etiket", w / 2, h / 2, this.vurgulu and R.murekkep or (this.vurgu > 0.5 and R.metin or R.gri), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
     b.DoClick = function(this) tikla(this) end
     b.OnCursorEntered = function() ses("ust") end
     return b
end

-- Vücut oranları (_sh_8vucut.lua): kaydırıcı çarpanın 1'den farkını taşır, ortası doğal
local function vucutOzet(d)
     local n = table.Count(d.vucut or {})
     return n == 0 and "Proporciones naturales" or (n .. " proporciones ajustadas")
end

KURUCU.vucut = function(ayna, ust)
     baslik(ust, "Oranlar", function() return vucutOzet(ayna.durum) end)
     local surguler = {}
     for _, b in ipairs(O.Vucut) do
          local id, uc = b[1], b[5]
          local s = surgu(ayna, ust, b[2], b[3] - 1, b[4] - 1, ((ayna.durum.vucut or {})[id] or 1) - 1, 0,
               function(t, v)
                    t.vucut = t.vucut or {}
                    t.vucut[id] = 1 + v
               end,
               function(v)
                    local y = math.Round(v * 100)
                    if y == 0 then return "Natural" end
                    return (y > 0 and uc[2] or uc[1]) .. string.format(" %%%d", math.abs(y))
               end)
          s.bitti = function() ayna.sahne:Parilti((id == "kafa" or id == "boyun") and "ust" or "govde") end
          surguler[#surguler + 1] = s
     end
     local sifir = kucukDugme(ust, "Volver a proporciones naturales", function()
          if not ayna.durum.vucut then return end
          ayna:Degistir(function(t) t.vucut = nil end, "govde")
          for _, s in ipairs(surguler) do s.deger = 0 end
     end)
     sifir:Dock(TOP)
     sifir:SetTall(S(30))
     sifir:DockMargin(0, S(6), S(170), S(8))
     notEkle(ust, "Las proporciones cambian en un rango pequeño; la ropa se adapta. Si un hechizo o pose altera un hueso, vuelve al acabar.")
end

KURUCU.kayit = function(ayna, ust)
     baslik(ust, "Guardar este aspecto")
     local satir = ust:Add("Panel")
     satir:Dock(TOP)
     satir:SetTall(S(38))
     satir:DockMargin(0, S(2), 0, S(6))
     local ad = girisKutusu(satir, "Pon un nombre al aspecto")
     ad:Dock(FILL)
     local kaydet = kucukDugme(satir, "Guardar", function()
          local metin = string.Trim(ad:GetValue() or "")
          if metin == "" then
               ses("hata")
               return
          end
          local dosya = dosyaAdi(metin)
          if dosya == "" then dosya = "gorunum" end
          file.CreateDir(KAYIT_KLASOR)
          file.Write(KAYIT_KLASOR .. "/" .. dosya .. ".json", util.TableToJSON({ad = metin, tarih = os.time(), durum = kayitDurumu(ayna)}))
          ses("buyu")
          ayna.bildirim, ayna.bildirimZaman = "Guardado: " .. metin, RealTime()
          ayna:IcerikKur()
     end)
     kaydet:Dock(RIGHT)
     kaydet:DockMargin(S(8), S(4), 0, S(4))
     kaydet.vurgulu = true

     local liste = kayitlar()
     baslik(ust, "Aspectos guardados", #liste > 0 and (#liste .. " guardado(s)") or "aún no hay")
     for _, v in ipairs(liste) do
          local sr = ust:Add("Panel")
          sr:Dock(TOP)
          sr:SetTall(S(48))
          sr:DockMargin(0, 0, 0, S(6))
          sr.Paint = function(this, w, h)
               draw.RoundedBox(S(6), 0, 0, w, h, Color(18, 21, 33, 225))
               draw.SimpleText(sigdir(v.ad or v.dosya, "SOg.Kart", w - S(150)), "SOg.Kart", S(12), S(16), R.metin, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
               draw.SimpleText((v.durum.gender == "f" and "Chica" or "Chico") .. "  ·  " .. os.date("%d.%m.%Y %H:%M", v.tarih or 0), "SOg.Kucuk", S(12), S(34), R.gri, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
          local sil = kucukDugme(sr, "Borrar", function(this)
               if not this.onay or RealTime() - this.onay > 3 then
                    this.onay = RealTime()
                    this.metin = "¿Seguro?"
                    surface.SetFont("SOg.Etiket")
                    this:SetWide(surface.GetTextSize(this.metin) + S(26))
                    sr:InvalidateLayout()
                    return
               end
               file.Delete(KAYIT_KLASOR .. "/" .. v.dosya)
               ses("tik")
               ayna:IcerikKur()
          end)
          sil:Dock(RIGHT)
          sil:DockMargin(S(6), S(10), S(8), S(10))
          local yukle = kucukDugme(sr, "Cargar", function()
               if gorunumYukle(ayna, v.durum) then
                    ayna.bildirim, ayna.bildirimZaman = "Cargado: " .. (v.ad or ""), RealTime()
               else
                    ses("hata")
               end
          end)
          yukle:Dock(RIGHT)
          yukle:DockMargin(S(6), S(10), 0, S(10))
     end

     baslik(ust, "Código para compartir")
     local kopya = kucukDugme(ust, "Copiar el código de este aspecto", function()
          SetClipboardText(O.GorunumKodu(kayitDurumu(ayna)))
          ses("tik")
          ayna.bildirim, ayna.bildirimZaman = "Código copiado al portapapeles", RealTime()
     end)
     kopya:Dock(TOP)
     kopya:SetTall(S(30))
     kopya:DockMargin(0, S(2), S(150), S(8))
     local satir2 = ust:Add("Panel")
     satir2:Dock(TOP)
     satir2:SetTall(S(38))
     local kod = girisKutusu(satir2, "Pega el código aquí (Ctrl+V)")
     kod:Dock(FILL)
     local uygula = kucukDugme(satir2, "Aplicar", function()
          local veri = O.GorunumKodCoz(kod:GetValue())
          if veri and gorunumYukle(ayna, veri) then
               ayna.bildirim, ayna.bildirimZaman = "Cargado desde código", RealTime()
               kod:SetValue("")
          else
               ses("hata")
               ayna.bildirim, ayna.bildirimZaman = "Código no válido", RealTime()
          end
     end)
     uygula:Dock(RIGHT)
     uygula:DockMargin(S(8), S(4), 0, S(4))
     notEkle(ust, "Los guardados solo están en este PC. El código sirve para compartir el aspecto; todo lo cargado se revalida.")
end

----------------------------------------------------------------------------------------
-- Kartlar: işaretin açtığı düzenleme kartı. seviye: kartın evi (govde = tam boy, yuz = yüz haritası); odak: kamera
-- (cl_3sahne ODAK); grup: kartın yüz hattı denetleyicileri {grup adı, yalnız} (sayaç, kart içi sıfırlama);
-- ozet(d): işaret etiketinin alt yazısı, renk(d): yanındaki renk beneği
----------------------------------------------------------------------------------------
local function yuzAdi(d)
     local yuzler = HLStudents.FacesOf and HLStudents.FacesOf(d.gender) or {}
     local f = yuzler[d.face or 1]
     return f and f.label or "Cara principal"
end

local function sacAdi(d)
     if O.KanonYuzMu and O.KanonYuzMu(d.gender, d.face) then return "Pelo canónico" end
     local _, HR = HLStudents.Data(d.gender)
     local h = HR and HR.list[d.hair or ""]
     return h and h.label or "Calvo"
end

local function ifadeAdi(d)
     for _, h in ipairs(O.IfadeHazir) do
          if O.IfadeAyni(d.ifade or {}, h[2]) then return h[1] end
     end
     return "Personalizado"
end

local function tenRengi(d)
     local _, _, CC = HLStudents.Data(d.gender)
     local sk = CC and CC.skins and CC.skins[d.skin or 0]
     local c = sk and sk.swatch or (CC and CC.base_swatch) or Color(170, 120, 100)
     return Color(c.r, c.g, c.b)
end

local function secenekBul(liste, no)
     for _, s in ipairs(liste or {}) do
          if s[1] == no then return s end
     end
end

local function oynananHat(d, ogeler)
     local n = 0
     for _, it in ipairs(ogeler or {}) do
          if math.abs(d.flex[it[1]] or 0) > 0.001 then n = n + 1 end
     end
     return n
end

local KARTLAR = {
     beden = {ad = "Cuerpo", ust = "CUERPO", ikon = "presets", seviye = "govde", odak = "govde", kur = KURUCU.beden,
          aciklama = "Género, altura y pose en el espejo.",
          ozet = function(d) return (d.gender == "f" and "Chica" or "Chico") .. " · " .. boyAdi(d.height or 1) end},
     vucut = {ad = "Cuerpo", ust = "CUERPO", ikon = "vucut", seviye = "govde", odak = "govde", kur = KURUCU.vucut,
          aciklama = "Proporciones de cabeza, cuello, hombros, torso y brazos.", ozet = vucutOzet},
     yuztipi = {ad = "Tipo de cara", ust = "CARA", ikon = "face", seviye = "yuz", odak = "yuz", kur = KURUCU.yuztipi,
          aciklama = "Estructura base de la cabeza y rasgos generales.", ozet = yuzAdi},
     burun = {ad = "Nariz", ust = "RASGOS FACIALES", ikon = "face", seviye = "yuz", odak = "yuz", kur = KURUCU.burun,
          grup = {"Burun"}, aciklama = "Ancho, puente y punta de la nariz."},
     elmacik = {ad = "Pómulos", ust = "RASGOS FACIALES", ikon = "face", seviye = "yuz", odak = "yuz", kur = KURUCU.elmacik,
          grup = {"Pómulos y mejillas"}, aciklama = "Pómulos y relleno de mejillas."},
     cene = {ad = "Mandíbula", ust = "RASGOS FACIALES", ikon = "face", seviye = "yuz", odak = "yuz", kur = KURUCU.cene,
          grup = {"Mandíbula"}, aciklama = "Línea y punta de la mandíbula."},
     agiz = {ad = "Boca", ust = "RASGOS FACIALES", ikon = "face", seviye = "yuz", odak = "yuz", kur = KURUCU.agiz,
          grup = {"Boca"}, aciklama = "Ancho de la boca y grosor de labios."},
     kulak = {ad = "Orejas", ust = "RASGOS FACIALES", ikon = "face", seviye = "yuz", odak = "yuz", kur = KURUCU.kulak,
          grup = {"Cara", {ear_size = true}}, aciklama = "Tamaño de las orejas."},
     ifade = {ad = "Expresión", ust = "EXPRESIÓN EN REPOSO", ikon = "makeup", seviye = "yuz", odak = "yuz", kur = KURUCU.ifade,
          aciklama = "Cómo queda tu cara en reposo.", ozet = ifadeAdi},
     goz = {ad = "Ojos", ust = "OJOS", ikon = "eye", seviye = "yuz", odak = "goz", kur = KURUCU.goz, grup = {"Ojos"},
          aciklama = "Color del iris, forma de los ojos y dirección de la mirada.",
          bolumler = {{id = "renk", ad = "COLOR", odak = "goz"}, {id = "sekil", ad = "FORMA", odak = "yuz"},
               {id = "bakis", ad = "MIRADA", odak = "yuz"}},
          ozet = function(d) return d.eyes.advanced and "Cada ojo aparte" or "Un color" end,
          renk = function(d) return vektorRenk(d.eyes.advanced and d.eyes.left_outer or d.colors.eyes) end},
     kas = {ad = "Cejas", ust = "CEJAS", ikon = "face", seviye = "yuz", odak = "yuz", kur = KURUCU.kas, grup = {"Cejas"},
          aciklama = "Textura, color y forma de las cejas.",
          bolumler = {{id = "stil", ad = "ESTILO", odak = "yuz"}, {id = "sekil", ad = "FORMA", odak = "yuz"}},
          ozet = function(d) return (d.brow or 0) == 0 and "Natural" or ("Ceja " .. d.brow) end,
          renk = function(d) return vektorRenk(d.colors.brows) end},
     sac = {ad = "Pelo", ust = "PELO", ikon = "hair", seviye = "yuz", odak = "sac", kur = KURUCU.sac,
          aciklama = "Peinado y color.",
          bolumler = {{id = "model", ad = "MODELO", odak = "sac"}, {id = "renk", ad = "COLOR", odak = "sac"}},
          ozet = sacAdi, renk = function(d) return vektorRenk(d.colors.hair) end},
     ten = {ad = "Piel", ust = "PIEL", ikon = "skin", seviye = "yuz", odak = "ten", kur = KURUCU.ten,
          aciklama = "Tono de piel, pecas, marcas y cicatrices.",
          bolumler = {{id = "ton", ad = "TONO", odak = "ten"}, {id = "iz", ad = "MARCAS", odak = "yuz"},
               {id = "yara", ad = "CICATRIZ", odak = "yuz"}},
          ozet = function(d) return (d.skin or 0) == 0 and "Tono natural" or ("Tono " .. d.skin) end, renk = tenRengi},
     makyaj = {ad = "Maquillaje", ust = "MAQUILLAJE", ikon = "makeup", seviye = "yuz", odak = "makyaj", kur = KURUCU.makyaj,
          aciklama = "Estilo y colores de pintura facial.",
          bolumler = {{id = "stil", ad = "ESTILO", odak = "makyaj", yalnizKiz = true}, {id = "renkler", ad = "COLORES", odak = "makyaj"}},
          ozet = function(d)
               local m = d.makeup or {}
               if d.gender ~= "f" then return (m.blush or 0) > 0 and "Colorete" or "Nada" end
               return (m.style or 0) == 0 and "Nada" or ("Estilo " .. m.style)
          end},
     ust = {ad = "Superior", ust = "CONJUNTO INICIAL", ikon = "chest", seviye = "govde", odak = "ust", baslangic = true,
          kur = KURUCU.ust, aciklama = "La prenda superior con la que entras a Hogwarts.",
          ozet = function(d) return "Color " .. ((d.kiyafet or {}).ust or 1) end},
     alt = {ad = "Inferior", adi = function(d) return d.gender == "f" and "Falda" or "Pantalón" end, ust = "CONJUNTO INICIAL",
          ikon = "trousers", seviye = "govde", odak = "govde", baslangic = true, kur = KURUCU.alt,
          aciklama = "La prenda inferior del conjunto inicial.",
          ozet = function(d)
               local s = secenekBul(O.Baslangic[d.gender].alt.secenek, (d.kiyafet or {}).alt)
               return s and s[2] or ""
          end,
          renk = function(d)
               local s = secenekBul(O.Baslangic[d.gender].alt.secenek, (d.kiyafet or {}).alt)
               return s and s[3]
          end},
     ayakkabi = {ad = "Calzado", ust = "CONJUNTO INICIAL", ikon = "shoes", seviye = "govde", odak = "ayak", baslangic = true,
          kur = KURUCU.ayakkabi, aciklama = "El calzado del conjunto inicial.",
          ozet = function(d)
               local s = secenekBul(O.Baslangic[d.gender].ayakkabi.secenek, (d.kiyafet or {}).ayakkabi)
               return s and s[2] or ""
          end,
          renk = function(d)
               local s = secenekBul(O.Baslangic[d.gender].ayakkabi.secenek, (d.kiyafet or {}).ayakkabi)
               return s and s[3]
          end},
}
KARTLAR.kayit = {ad = "Mis aspectos", ust = "AYNA", ikon = "saveload", kur = KURUCU.kayit, zarYok = true,
     aciklama = "Guarda, carga o comparte el aspecto con un código."}
for id, k in pairs(KARTLAR) do k.id = id end
O.AynaKart = KARTLAR

local function kartGrubu(k, cins)
     return k.grup and grupOgeleri(cins, k.grup[1], k.grup[2]) or nil
end

-- Kart zarı: yalnız o kartın kısmını rastgele yapar (O.Rastgele'nin ürettiği görünümden o kısmı alır)
local function grupKopyala(t, r, grupAdi)
     for _, it in ipairs(grupOgeleri(t.gender, grupAdi)) do t.flex[it[1]] = r.flex[it[1]] end
end

local ZAR = {
     yuztipi = function(t, r)
          t.face = r.face
          t.flex.face_width = r.flex.face_width
     end,
     sac = function(t, r)
          t.hair = r.hair
          t.colors.hair = r.colors.hair
     end,
     kas = function(t, r)
          t.brow = r.brow
          t.colors.brows = r.colors.brows
          grupKopyala(t, r, "Cejas")
     end,
     goz = function(t, r)
          t.colors.eyes = r.colors.eyes
          t.eyes.advanced = nil
          grupKopyala(t, r, "Ojos")
     end,
     ten = function(t, r)
          t.skin, t.marks = r.skin, r.marks
          t.scar = r.scar or {id = 0, x = 0.5, y = 0.4, rot = 0, size = 0.2, flip = false}
     end,
     -- makyaj her zaman bir şey seçsin (O.Rastgele çoğu zaman makyajsız bırakır); erkekte yalnız allık
     makyaj = function(t)
          local _, _, CC = HLStudents.Data(t.gender)
          local renkler = CC.makeup_colors or {}
          local m = {style = 0}
          if t.gender == "f" then
               m.style = math.random(math.max(1, CC.makeup_styles or 1))
               for _, parca in ipairs(HLStudents.Config.MakeupParts) do
                    local liste = renkler[parca] or {}
                    if #liste > 0 and math.random() < 0.7 then m[parca] = math.random(#liste) end
               end
          else
               local liste = renkler.blush or {}
               if #liste > 0 then m.style, m.blush = 1, math.random(#liste) end
          end
          t.makeup = m
     end,
     ifade = function(t, r) t.ifade = r.ifade end,
     beden = function(t)
          local A = O.KisiselBoyAralik
          t.height = math.Round(math.Rand(A[1], A[2]), 3)
     end,
     -- aralığın ortadaki %60'ı (uçlar bir arada tuhaf durur)
     vucut = function(t)
          local v = {}
          for _, b in ipairs(O.Vucut) do v[b[1]] = math.Rand(1 - (1 - b[3]) * 0.6, 1 + (b[4] - 1) * 0.6) end
          t.vucut = O.VucutTemizle(v)
     end,
     ust = function(t)
          local B = O.Baslangic[t.gender]
          local p = O.GiysiParcasi(B.ust, t.gender)
          local i = math.random(p and #p.looks or 1)
          t.kiyafet.ust = i
          t.kiyafet.alt = B.alt.eslesme[i] or t.kiyafet.alt
     end,
     alt = function(t)
          local B = O.Baslangic[t.gender].alt.secenek
          t.kiyafet.alt = B[math.random(#B)][1]
     end,
     ayakkabi = function(t)
          local B = O.Baslangic[t.gender].ayakkabi.secenek
          t.kiyafet.ayakkabi = B[math.random(#B)][1]
     end,
}
local ZAR_PARILTI = {sac = "sac", goz = "goz", makyaj = "makyaj", ten = "ten", beden = "govde", vucut = "govde", ust = "ust", alt = "govde",
     ayakkabi = "ayak"}

----------------------------------------------------------------------------------------
-- İşaretler, seviye başına. kemik (ya da iki kemiğin ortası) + ofs {ön, üst, sol} birim: yüz çerçevesinde (baş
-- kemiği), govde = true ise modelin kendi yönlerinde. yuzey: görünürlük için yüzeyin baktığı yön (aynı çerçeve,
-- varsayılan ön; hep: her açıdan görünür). taraf: karşıdan bakarken etiketin tarafı (-1 sol, 1 sağ); döndükçe
-- ekrandaki yerine göre değişir. seviye: kart yerine o seviyeye geçer (tam boyda Yüz).
----------------------------------------------------------------------------------------
local BAS = "ValveBiped.Bip01_Head1"
local ISARET = {
     govde = {
          {id = "sac", kart = "sac", kemik = BAS, ofs = {1.4, 4.4, -1.4}, hep = true, taraf = -1},
          {id = "yuz", seviye = "yuz", ad = "Cara", kemik = "nose", ofs = {0.7, -0.6, 0}, taraf = 1},
          {id = "ust", kart = "ust", kemik = "ValveBiped.Bip01_Spine2", ofs = {4.6, 2.5, 1.8}, govde = true, taraf = 1},
          {id = "ten", kart = "ten", kemik = "ValveBiped.Bip01_R_Hand", ofs = {0.8, -1.2, -0.6}, govde = true, yuzey = {0.6, 0, -1}, taraf = -1},
          {id = "beden", kart = "beden", kemik = "ValveBiped.Bip01_Pelvis", ofs = {3.4, -0.5, -5}, govde = true, yuzey = {1, 0, -0.5}, taraf = -1},
          {id = "vucut", kart = "vucut", kemik = "ValveBiped.Bip01_L_UpperArm", ofs = {0.6, 1.8, 1.2}, govde = true, yuzey = {1, 0, 0.6}, taraf = 1},
          {id = "alt", kart = "alt", kemik = {"ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf"}, ofs = {3, 0, 0.6}, govde = true, taraf = 1},
          {id = "ayakkabi", kart = "ayakkabi", kemik = "ValveBiped.Bip01_R_Toe0", ofs = {0.6, 1.4, -0.3}, govde = true, taraf = -1},
     },
     yuz = {
          {id = "sac", kart = "sac", kemik = BAS, ofs = {1.6, 4.5, -1.4}, hep = true, taraf = -1},
          {id = "yuztipi", kart = "yuztipi", kemik = "eye_left", ofs = {0.35, 1.9, -0.7}, yuzey = {1, 0.3, 0.2}, taraf = 1},
          {id = "kas", kart = "kas", kemik = "eye_right", ofs = {0.5, 0.45, -0.08}, yuzey = {1, 0, -0.45}, taraf = -1},
          {id = "goz", kart = "goz", kemik = "eye_right", ofs = {0.55, -0.18, 0}, yuzey = {1, 0, -0.5}, taraf = -1},
          {id = "makyaj", kart = "makyaj", kemik = "eye_left", ofs = {0.5, 0.12, 0.1}, yuzey = {1, 0, 0.5}, taraf = 1},
          {id = "burun", kart = "burun", kemik = "nose", ofs = {0.45, -0.9, 0}, taraf = 1},
          {id = "elmacik", kart = "elmacik", kemik = "eye_right", ofs = {-0.05, -1, -1}, yuzey = {1, 0, -0.7}, taraf = -1},
          {id = "kulak", kart = "kulak", kemik = BAS, ofs = {0.6, 0.7, -2.95}, yuzey = {0.6, 0, -1}, taraf = -1},
          {id = "agiz", kart = "agiz", kemik = "nose", ofs = {0, -2.02, -0.35}, taraf = -1},
          {id = "ifade", kart = "ifade", kemik = "nose", ofs = {-0.3, -2.08, 0.7}, yuzey = {1, 0, 0.4}, taraf = 1},
          {id = "ten", kart = "ten", kemik = "eye_left", ofs = {-0.2, -1.75, 0.65}, yuzey = {1, 0, 0.6}, taraf = 1},
          {id = "cene", kart = "cene", kemik = "nose", ofs = {-0.4, -3, 0}, taraf = 1},
     },
}
O.AynaIsaret = ISARET

-- Alt şerit: kartlara kısa yol (1-7). grup: şeridin parladığı kartlar; seviyeAktif: kart kapalıyken o seviyede
local SERIT = {
     {ad = "Cuerpo", ikon = "presets", kart = "beden", seviyeAktif = "govde", grup = {beden = true}},
     {ad = "Cuerpo", ikon = "vucut", kart = "vucut", grup = {vucut = true}},
     {ad = "Cara", ikon = "face", kart = "yuztipi", seviyeAktif = "yuz", grup = {yuztipi = true, burun = true, elmacik = true,
          cene = true, agiz = true, kulak = true, ifade = true}},
     {ad = "Piel", ikon = "skin", kart = "ten", grup = {ten = true}},
     {ad = "Pelo", ikon = "hair", kart = "sac", grup = {sac = true, kas = true}},
     {ad = "Ojos", ikon = "eye", kart = "goz", grup = {goz = true}},
     {ad = "Maquillaje", ikon = "makeup", kart = "makyaj", grup = {makyaj = true}},
     {ad = "Ropa", ikon = "outfit", kart = "ust", baslangic = true, grup = {ust = true, alt = true, ayakkabi = true}},
}

----------------------------------------------------------------------------------------
-- Yüz çerçevesi: baş kemiğinin dönüşünden ön / üst / sol yönleri. Başvuru: bekleme duruşu, yaw 0'da kemiğin açısı
-- (ön = modelin +X'i). Kemik matrisleri aynadaki boy ölçeğini de taşır.
----------------------------------------------------------------------------------------
local BAS_ACI = {m = Angle(-69.014, 1.975, 91.249), f = Angle(-77, 3.309, 89.829)}
local basYon = {}
for cins, a in pairs(BAS_ACI) do
     basYon[cins] = {
          (WorldToLocal(Vector(1, 0, 0), angle_zero, vector_origin, a)),
          (WorldToLocal(Vector(0, 0, 1), angle_zero, vector_origin, a)),
          (WorldToLocal(Vector(0, 1, 0), angle_zero, vector_origin, a)),
     }
end

local function kemikNo(e, ad)
     local t = e.sogKemikNo
     if not t then
          t = {}
          e.sogKemikNo = t
     end
     local id = t[ad]
     if id == nil then
          id = e:LookupBone(ad) or false
          t[ad] = id
     end
     return id or nil
end

local function kemikPos(e, kemik)
     if istable(kemik) then
          local a, b = kemikPos(e, kemik[1]), kemikPos(e, kemik[2])
          return a and b and (a + b) * 0.5 or nil
     end
     local id = kemikNo(e, kemik)
     local m = id and e:GetBoneMatrix(id)
     return m and m:GetTranslation() or nil
end

local function yuzCercevesi(e, cins)
     local id = kemikNo(e, BAS)
     local m = id and e:GetBoneMatrix(id)
     local y = basYon[cins]
     if not m or not y then
          local a = e:GetAngles()
          return a:Forward(), a:Up(), -a:Right()
     end
     local a = m:GetAngles()
     return (LocalToWorld(y[1], angle_zero, vector_origin, a)), (LocalToWorld(y[2], angle_zero, vector_origin, a)),
          (LocalToWorld(y[3], angle_zero, vector_origin, a))
end

local YUZEY_ON = {1, 0, 0}
local KOL_KEMIK = {"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_L_Forearm",
     "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand"}

-- İşaret noktası: ışıma, nabız atan halka, iç nokta; seçiliyken dönen kesik halka
local function isaretNoktasi(x, y, a, v, secili, oynanmis, zaman, faz)
     local radyal = O.Doku("radyal")
     if radyal then
          surface.SetMaterial(radyal)
          local b = S(34) + S(46) * v + (secili and S(36) or 0)
          surface.SetDrawColor(255, 200, 120, (36 + 70 * v + (secili and 60 or 0)) * a)
          surface.DrawTexturedRect(x - b / 2, y - b / 2, b, b)
     end
     local nabiz = math.sin(zaman * 2.4 + faz) * 0.5 + 0.5
     local r = S(6) + S(3) * v + (secili and S(3) or 0) + S(1.2) * nabiz * (1 - v)
     daire(x, y, r + S(2), Color(8, 10, 17, 140 * a))
     yay(x, y, r, S(1.5), renkA(R.parlak, (150 + 105 * math.max(v, secili and 1 or 0)) * a))
     daire(x, y, (oynanmis or secili) and S(3) or S(2), renkA((secili or v > 0.5) and R.parlak or R.altin, 255 * a))
     if secili then
          local t = zaman * 70
          for j = 0, 2 do
               yay(x, y, r + S(6), S(1.5), renkA(R.parlak, 210 * a), t + j * 120, t + j * 120 + 52, 6)
          end
     end
end

-- Kart: işaretin açtığı yüzen düzenleme kartı (yanında altın omurga, çizginin girdiği elmas, başlık, sekmeler,
-- kaydırılan içerik). Konumu ve boyu ayna belirler; içerik uzadıkça kart açılır.
local IKART = {}

function IKART:Init()
     self.acilis = 0
     self.ustH = S(104)
     self:SetAlpha(0)
end

function IKART:Kur(ayna, id)
     self.ayna, self.id = ayna, id
     local k = KARTLAR[id]
     self.k = k

     local kapat = self:Add("SOg.Yuvarlak")
     kapat:SetSize(S(32), S(32))
     kapat.ipucu = "Cerrar ficha"
     kapat.cizim = function(cx, cy, r, renk)
          kalinCizgi(cx - r * 0.34, cy - r * 0.34, cx + r * 0.34, cy + r * 0.34, S(2), renk)
          kalinCizgi(cx - r * 0.34, cy + r * 0.34, cx + r * 0.34, cy - r * 0.34, S(2), renk)
     end
     kapat.DoClick = function()
          ses("tik")
          ayna:KartKapat()
     end
     self.kapat = kapat

     if k.grup then
          local sf = self:Add("SOg.Yuvarlak")
          sf:SetSize(S(32), S(32))
          sf.ipucu = ayna:KartAdi(k) .. " resetear rasgos"
          sf.ikon = "sifirla"
          sf.etkin = function() return oynananHat(ayna.durum, kartGrubu(k, ayna.durum.gender)) > 0 end
          sf.DoClick = function()
               if not sf.etkin() then return end
               ayna:Degistir(function(t)
                    for _, it in ipairs(kartGrubu(k, t.gender) or {}) do t.flex[it[1]] = nil end
               end, "yuz")
               ayna:IcerikKur()
          end
          self.sifirla = sf
     end

     if not k.zarYok then
          local zar = self:Add("SOg.Yuvarlak")
          zar:SetSize(S(32), S(32))
          zar.ipucu = ayna:KartAdi(k) .. ": aleatorio"
          zar.ikon = "zar"
          zar.DoClick = function() ayna:KartZar(k) end
          self.zar = zar
     end

     self.sekme = self:Add("SOg.Sekmeler")
     self.sekme.secili = function() return ayna.bolum[id] end
     self.sekme.sec = function(b) ayna:BolumSec(b) end

     self.kaydir = self:Add("DScrollPanel")
     local bar = self.kaydir:GetVBar()
     bar:SetWide(S(4))
     bar:SetHideButtons(true)
     bar.Paint = function(_, bw, bh)
          surface.SetDrawColor(255, 255, 255, 8)
          surface.DrawRect(0, 0, bw, bh)
     end
     bar.btnGrip.Paint = function(_, gw, gh)
          draw.RoundedBox(gw / 2, 0, 0, gw, gh, R.soluk)
     end
end

function IKART:PerformLayout(w, h)
     if not self.kapat then return end
     self.kapat:SetPos(w - S(52), S(20))
     local x = w - S(92)
     if IsValid(self.sifirla) then
          self.sifirla:SetPos(x, S(20))
          x = x - S(40)
     end
     if IsValid(self.zar) then self.zar:SetPos(x, S(20)) end
     self.sekme:SetPos(S(24), S(100))
     self.sekme:SetSize(w - S(48), S(28))
     self.kaydir:SetPos(S(24), self.ustH)
     self.kaydir:SetSize(w - S(38), math.max(S(40), h - self.ustH - S(16)))
end

function IKART:Think()
     local a = self.ayna
     if not IsValid(a) then return end
     local dt = math.min(FrameTime(), 0.1)
     self.acilis = math.min(1, self.acilis + dt * 4)
     local e = 1 - (1 - self.acilis) ^ 3
     local W, H = a:GetWide(), a:GetTall()
     local cw = a.kartW
     local x = a.kartTaraf < 0 and a.kenarPay or (W - a.kenarPay - cw)
     local y = S(176)
     local enCok = H - y - S(158)
     local hedef = math.Clamp(self.ustH + self.kaydir:GetCanvas():GetTall() + S(20), S(190), enCok)
     self.boy = self.boy and Lerp(math.min(1, dt * 14), self.boy, hedef) or S(190)
     self:SetPos(math.floor(x + (1 - e) * S(26) * a.kartTaraf), y)
     self:SetSize(cw, math.floor(self.boy))
     self:SetAlpha(255 * e)
end

function IKART:Paint(w, h)
     local a, k = self.ayna, self.k
     cam(0, 0, w, h, S(14))
     -- modele bakan kenar: altın omurga, işaret çizgisinin girdiği elmas
     local sol = a.kartTaraf > 0
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 110)
     surface.DrawRect(sol and 0 or w - S(2), S(16), S(2), h - S(32))
     if a.kartGiris then
          local _, py = self:GetPos()
          local gy = math.Clamp(a.kartGiris - py, S(20), h - S(20))
          poly(elmas(sol and S(1) or w - S(1), gy, S(5)), R.parlak)
     end
     aralikli(k.ust or "APARIENCIA", "SOg.Ust", S(24), S(22), R.soluk, S(3))
     draw.SimpleText(a:KartAdi(k), "SOg.Kat", S(24), S(36), R.parlak, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     draw.SimpleText(k.aciklama or "", "SOg.Kucuk", S(24), S(74), R.gri, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

vgui.Register("SOg.IsaretKart", IKART, "EditablePanel")

-- Alt şerit
local SERITP = {}

function SERITP:Init()
     self:SetCursor("hand")
     self.vurgu = {}
     self.alan = {}
end

function SERITP:Paint(w, h)
     local a = self.ayna
     if not a or not a.secenek then return end
     local liste = a:SeritListe()
     draw.RoundedBox(h / 2, 0, 0, w, h, Color(8, 10, 17, 205))
     local mx = self:CursorPos()
     local bw = w / #liste
     self.alan = {}
     surface.SetFont("SOg.Bolum")
     for i, it in ipairs(liste) do
          local x0 = (i - 1) * bw
          local aktif = a:SeritAktif(it)
          local kilit = not a:KartIzinli(it.kart)
          local ustte = self:IsHovered() and mx >= x0 and mx < x0 + bw and not kilit
          self.vurgu[i] = Lerp(math.min(1, FrameTime() * 12), self.vurgu[i] or 0, (aktif or ustte) and 1 or 0)
          local v = self.vurgu[i]
          local tw = surface.GetTextSize(it.ad)
          local ib = S(18)
          local sx = x0 + bw / 2 - (ib + S(8) + tw) / 2
          ikon(it.ikon, sx, h / 2 - ib / 2, ib, aktif and R.parlak or renkA(R.altin, kilit and 50 or (120 + 135 * v)))
          draw.SimpleText(it.ad, "SOg.Bolum", sx + ib + S(8), h / 2, aktif and R.parlak or (kilit and R.sonuk or (v > 0.5 and R.metin or R.gri)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          if aktif then poly(elmas(x0 + bw / 2, h - S(7), S(3)), R.altin) end
          if i > 1 then
               surface.SetDrawColor(R.cizgi)
               surface.DrawRect(x0, S(14), 1, h - S(28))
          end
          self.alan[i] = {x0, x0 + bw, it}
     end
end

function SERITP:Think()
     local no
     if self:IsHovered() then
          local mx = self:CursorPos()
          for i, al in ipairs(self.alan) do
               if mx >= al[1] and mx < al[2] then no = i end
          end
     end
     if no ~= self.ustNo then
          self.ustNo = no
          if no then ses("ust") end
     end
end

function SERITP:OnMousePressed(k)
     if k ~= MOUSE_LEFT then return end
     local mx = self:CursorPos()
     for _, al in ipairs(self.alan) do
          if mx >= al[1] and mx < al[2] then
               self.ayna:SeritSec(al[3])
               return
          end
     end
end

vgui.Register("SOg.Serit", SERITP, "Panel")

----------------------------------------------------------------------------------------
-- Ana panel
----------------------------------------------------------------------------------------
local AYNA = {}

function AYNA:Init()
     self:SetSize(ScrW(), ScrH())
     self:SetPos(0, 0)
     self.sahne = O.SahneYarat()
     self.seviye = "govde"
     self.bolum = {}
     self.acilis = 0
     self.gecmis = {}
     self.surukle = nil
     self.isaretDurum = {}
     self.isaretHit = {}
     self.seviyeZaman = RealTime()
     self.kartTaraf = 1
     self.kartW = S(440)
     self.kenarPay = S(42)
     self.icerikW = self.kartW - S(48)
     self.merkezX = ScrW() / 2
     self.merkezHedef = self.merkezX
end

function AYNA:Kur(t)
     self.secenek = t
     local d = O.Temizle(t.durum or {}) or O.Varsayilan("m")
     if t.baslangic then d.kiyafet = O.BaslangicTemizle(d.gender, istable(t.durum) and t.durum.kiyafet) end
     self.durum = d
     -- kanon rolündeki karakterin düzenlemesi: yüz ve cinsiyet kilitli (sunucu da denetler, sv_1kayit.lua)
     self.kanon = t.kip == "duzenle" and O.KanonYuzMu and O.KanonYuzMu(d.gender, d.face) or nil
     self.ilk = table.Copy(d)
     self.hane = t.hane or 1
     self.giyili = t.giyili
     self:SahneGuncelle()
     self:Yerlesim()
     self:OdakGuncelle()
     local kip = self:KisitliKip()
     if kip then
          self:SeviyeSec("yuz")
          self:KartAc(kip.ilk)
     elseif t.kart then
          self:KartAc(t.kart)
     end
     self.sahne:Parilti("govde")
end

function AYNA:Giyili(d)
     d = d or self.durum
     if self.secenek.baslangic and d.kiyafet then return O.BaslangicGiyili(d.gender, d.kiyafet) end
     return self.giyili or {}
end

function AYNA:SahneGuncelle()
     local d = self.onceGoster and self.ilk or self.durum
     self.s = O.Ayarlar(d, self:Giyili(d), self.hane, false)
     self.sahne:Kur(self.s)
end

function AYNA:KartAdi(k)
     return k.adi and k.adi(self.durum) or k.ad
end

function AYNA:Yerlesim()
     local w, h = self:GetWide(), self:GetTall()
     local pad = self.kenarPay

     -- üst sağ: görünüm (tam boy / bel üstü / yüz haritası), döndür, duruş | geri al, rastgele, sıfırla (sağdan sola)
     local yb, ara, grup = S(42), S(8), S(24)
     local dugmeler = {
          {"cuerpo entero", "outfit", "Cuerpo entero", function() self:SeviyeSec("govde", false) end, nil, function() return self.seviye == "govde" and not self.belKamera end},
          {"belUstu", "chest", "Medio cuerpo", function() self:SeviyeSec("govde", true) end, nil, function() return self.seviye == "govde" and self.belKamera end},
          {"yuzSev", "face", "Mapa facial", function() self:SeviyeSec("yuz") end, nil, function() return self.seviye == "yuz" end},
          false,
          {"solaDon", "rot_left", "Girar a la izquierda", function() self.sahne:Dondur(-45) end},
          {"sagaDon", "rot_right", "Girar a la derecha", function() self.sahne:Dondur(45) end},
          {"pozD", nil, "Cambiar pose", function() self.sahne:Poz((self.sahne.poz or 1) + 1) end},
          false,
          {"isikD", nil, "Luz (estudio, día, vela, luna, mazmorra)", function() self:IsikSonraki() end},
          {"onceD", nil, "Mantén pulsado: aspecto inicial", function() end, nil, function() return self.onceGoster == true end},
          false,
          {"geriAl", nil, "Deshacer (Ctrl+Z)", function() self:GeriAl() end, function() return #self.gecmis > 0 end},
          {"rastgele", "zar", "Aspecto aleatorio", function() self:Rastgele() end},
          {"sifirla", "sifirla", "Volver al aspecto inicial", function() self:Sifirla() end},
          {"kayitD", "saveload", "Mis aspectos: guardar, cargar, compartir", function()
               if self.kart == "kayit" then self:KartKapat() else self:KartAc("kayit") end
          end, nil, function() return self.kart == "kayit" end},
     }
     local x = w - pad
     for i = #dugmeler, 1, -1 do
          local dg = dugmeler[i]
          if not dg then
               x = x - grup + ara
          else
               local b = self[dg[1]] or self:Add("SOg.Yuvarlak")
               self[dg[1]] = b
               b.ikon, b.ipucu = dg[2], dg[3]
               b.DoClick = function()
                    ses("tik")
                    dg[4]()
               end
               b.etkin, b.aktif = dg[5], dg[6]
               b:SetSize(yb, yb)
               x = x - yb
               b:SetPos(x, S(44))
               x = x - ara
          end
     end
     if self:KisitliKip() then
          self.rastgele.etkin = function() return false end
          self.kayitD.etkin = function() return false end
     end
     self.pozD.cizim = function(cx, cy, r, renk)
          siluet(cx, cy + r * 0.05, r * 1.25, self.durum.gender == "f", renk)
     end
     -- ışık: güneş (daire + ışınlar)
     self.isikD.cizim = function(cx, cy, r, renk)
          daire(cx, cy, r * 0.22, renk)
          for i = 0, 7 do
               local t = math.rad(i * 45)
               kalinCizgi(cx + math.cos(t) * r * 0.34, cy + math.sin(t) * r * 0.34, cx + math.cos(t) * r * 0.5, cy + math.sin(t) * r * 0.5, S(2), renk)
          end
     end
     -- önce/sonra: yarısı dolu daire; basılı tutulurken baştaki hâl
     self.onceD.cizim = function(cx, cy, r, renk)
          yay(cx, cy, r * 0.42, S(2), renk)
          local p = {}
          for i = 0, 12 do
               local t = math.rad(90 + i * 15)
               p[#p + 1] = {x = cx + math.cos(t) * r * 0.42, y = cy + math.sin(t) * r * 0.42}
          end
          poly(p, renk)
     end
     self.onceD.OnMousePressed = function(this, kod)
          if kod ~= MOUSE_LEFT then return end
          this:MouseCapture(true)
          ses("tik")
          self:OnceGoster(true)
     end
     self.onceD.OnMouseReleased = function(this)
          this:MouseCapture(false)
          self:OnceGoster(false)
     end
     -- geri al: üstten dönen yay, sol ucunda aşağı bakan ok başı
     self.geriAl.cizim = function(cx, cy, r, renk)
          local rr = r * 0.42
          local oy = cy + r * 0.12
          yay(cx, oy, rr + S(1), S(2), renk, 180, 360)
          local ax = cx - rr
          kalinCizgi(ax - rr * 0.42, oy - rr * 0.12, ax, oy + rr * 0.4, S(2), renk)
          kalinCizgi(ax, oy + rr * 0.4, ax + rr * 0.42, oy - rr * 0.12, S(2), renk)
     end

     -- alt: geri / devam, ortada şerit
     local kip = self.secenek and self.secenek.kip or "yarat"
     self.geri = self.geri or self:Add("SOg.Hayalet")
     self.geri.metin = kip == "yarat" and "ATRÁS" or "CANCELAR"
     self.geri:SetSize(S(200), S(52))
     self.geri:SetPos(pad, h - S(52) - S(41))
     self.geri.DoClick = function()
          ses("tik")
          if self.secenek.geri then self.secenek.geri(self) end
     end

     local dw = S(300)
     self.devam = self.devam or self:Add("SOg.Ana")
     self.devam.metin = kip == "yarat" and "CONTINUAR" or "GUARDAR"
     self.devam:SetSize(dw, S(54))
     self.devam:SetPos(w - pad - dw, h - S(54) - S(40))
     self.devam.DoClick = function()
          if self.secenek.tamam then self.secenek.tamam(self, table.Copy(self.durum)) end
     end

     self.serit = self.serit or self:Add("SOg.Serit")
     self.serit.ayna = self
     local sw = math.min(w - pad * 2 - S(200) - dw - S(80), S(860))
     self.serit:SetSize(sw, S(50))
     self.serit:SetPos(math.floor(w / 2 - sw / 2), h - S(50) - S(42))
end

function AYNA:SeritListe()
     local t = {}
     for _, it in ipairs(SERIT) do
          if not it.baslangic or self.secenek.baslangic then t[#t + 1] = it end
     end
     return t
end

function AYNA:SeritAktif(it)
     if self.kart then return it.grup[self.kart] == true end
     return it.seviyeAktif == self.seviye
end

function AYNA:SeritSec(it)
     if self.kart and it.grup[self.kart] then return end
     ses("tik")
     self:KartAc(it.kart)
end

-- seviye: "govde" (tam boy) ya da "yuz" (yüz haritası); bel: tam boy işaretleriyle bel üstü kamera. Açık kart kapanır
function AYNA:SeviyeSec(sev, bel)
     if bel ~= nil then self.belKamera = bel end
     if self.kart then self:KartKapat() end
     if self.seviye ~= sev then
          self.seviye = sev
          self.isaretDurum = {}
          self.seviyeZaman = RealTime()
     end
     self:OdakGuncelle()
end

-- kartın işareti şu an ekranın hangi tarafında (yoksa tanımdaki taraf)
function AYNA:KartTarafi(id)
     for _, def in ipairs(ISARET[KARTLAR[id].seviye] or {}) do
          if def.kart == id then
               local st = self.isaretDurum[def.id]
               return st and st.taraf or def.taraf
          end
     end
     return 1
end

-- kısıtlı ayna (yatakhane, berber, iksir, Metamorfmagus: _sh_7oyun.lua) yalnız kendi kartlarını açar
function AYNA:KisitliKip()
     return self.secenek and self.secenek.kisitli and O.KisitliKip and O.KisitliKip[self.secenek.kisitli]
end

function AYNA:KartIzinli(id)
     local kip = self:KisitliKip()
     return not kip or kip.kartlar[id] ~= nil
end

function AYNA:KartAc(id, taraf)
     local k = KARTLAR[id]
     if not k or (k.baslangic and not self.secenek.baslangic) then return end
     if not self:KartIzinli(id) then
          local kip = self:KisitliKip()
          self.bildirim, self.bildirimZaman = kip.ad .. ": aquí solo cambia " .. O.KisitliIzinMetni(self.secenek.kisitli) .. "", RealTime()
          ses("hata")
          return
     end
     if k.seviye and k.seviye ~= self.seviye then
          self.seviye = k.seviye
          self.isaretDurum = {}
          self.seviyeZaman = RealTime()
     end
     self.kart = id
     self.kartTaraf = taraf or self:KartTarafi(id)
     self.kartGiris = nil
     self:IfadeOnizle(nil)
     if k.bolumler and not self.bolum[id] then self.bolum[id] = k.bolumler[1].id end
     if IsValid(self.kartP) then self.kartP:Remove() end
     self.kartP = self:Add("SOg.IsaretKart")
     self.kartP:Kur(self, id)
     self:OdakGuncelle()
     self:IcerikKur(true)
end

function AYNA:KartZar(k)
     self:Degistir(function(t)
          local r = O.Rastgele(t.gender, t)
          if ZAR[k.id] then
               ZAR[k.id](t, r)
          else
               for _, it in ipairs(kartGrubu(k, t.gender) or {}) do t.flex[it[1]] = r.flex[it[1]] end
          end
     end, ZAR_PARILTI[k.id] or "yuz")
     self:IcerikKur()
end

-- basılı tutulurken baştaki hâl (yalnız görüntü; durum değişmez)
function AYNA:OnceGoster(acik)
     if self.onceGoster == acik then return end
     self.onceGoster = acik
     self:SahneGuncelle()
end

function AYNA:IsikSonraki()
     local L = O.SahneIsikBul[self.sahne.isik or "studyo"] or O.SahneIsik[1]
     local yeni = O.SahneIsik[L.no % #O.SahneIsik + 1]
     self.sahne.isik = yeni.id
     self.bildirim, self.bildirimZaman = "Luz: " .. yeni.ad, RealTime()
end

function AYNA:KartKapat()
     if IsValid(self.kartP) then self.kartP:Remove() end
     self.kartP, self.kart, self.kartGiris = nil, nil, nil
     self:IfadeOnizle(nil)
     self:OdakGuncelle()
end

function AYNA:BolumSec(id)
     if not self.kart then return end
     self.bolum[self.kart] = id
     self:IfadeOnizle(nil)
     self:OdakGuncelle()
     self:IcerikKur(true)
end

-- kartın bu cinsiyette görünen bölümleri; seçili bölüm görünmüyorsa ilkine geçer
function AYNA:Bolumler(k)
     local t = {}
     local kip = self:KisitliKip()
     local izin = kip and kip.kartlar[k.id]
     for _, b in ipairs(k.bolumler or {}) do
          if not (b.yalnizKiz and self.durum.gender ~= "f") and not (istable(izin) and not izin[b.id]) then t[#t + 1] = b end
     end
     if #t > 0 then
          local var = false
          for _, b in ipairs(t) do
               if b.id == self.bolum[k.id] then var = true end
          end
          if not var then self.bolum[k.id] = t[1].id end
     end
     return t
end

-- kamera: açık kartın (bölümünün) odağı, yoksa seviyenin; kart açıkken model karttan yana kayar
function AYNA:OdakGuncelle()
     local odak = self.seviye == "yuz" and "yuz" or (self.belKamera and "ust" or "govde")
     local k = self.kart and KARTLAR[self.kart]
     if k then
          odak = k.odak or odak
          for _, b in ipairs(k.bolumler or {}) do
               if b.id == self.bolum[k.id] and b.odak then odak = b.odak end
          end
     end
     self.sahne:Odak(odak)
     self.merkezHedef = self:GetWide() / 2 - (k and self.kartTaraf * S(150) or 0)
end

-- hazır ifadenin üstüne gelince aynada geçici önizleme (nil = kayıtlı ifade)
function AYNA:IfadeOnizle(t)
     local e = self.sahne and self.sahne.ent
     if IsValid(e) then e.sogIfadeOniz = t end
end

-- açık kartın içeriğini yeniden kur; bastan: kaydırmayı başa al (kart/bölüm değişti)
function AYNA:IcerikKur(bastan)
     local p = self.kartP
     if not IsValid(p) then return end
     local k = KARTLAR[self.kart]
     local kaydir = p.kaydir
     local kaydirma = bastan and 0 or kaydir:GetVBar():GetScroll()

     local liste = self:Bolumler(k)
     local sekmeVar = #liste > 1
     p.sekme:SetVisible(sekmeVar)
     p.sekme.liste = liste
     p.ustH = sekmeVar and S(142) or S(104)
     p:InvalidateLayout(true)

     self.icerikW = self.kartW - S(48)
     kaydir:Clear()
     if k.kur then k.kur(self, kaydir, self.bolum[k.id]) end
     kaydir:InvalidateLayout(true)
     timer.Simple(0, function()
          if IsValid(kaydir) then kaydir:GetVBar():SetScroll(kaydirma) end
     end)
end

function AYNA:GecmisKaydet()
     self.gecmis[#self.gecmis + 1] = table.Copy(self.durum)
     if #self.gecmis > 40 then table.remove(self.gecmis, 1) end
end

-- fn(durum) durumu değiştirir; bolge: parıltı yeri (nil = sessiz); surekli: sürüklenen kaydırıcı (geçmiş
-- sürükleme başında bir kez yazılır, ses/parıltı yok)
function AYNA:Degistir(fn, bolge, surekli)
     if not surekli then self:GecmisKaydet() end
     local eskiCins = self.durum.gender
     local once = self.kanon and table.Copy(self.durum)
     fn(self.durum)

     local kiyafet = self.durum.kiyafet
     local yeni = O.Temizle(self.durum)
     -- kanon: başka cinsiyete geçen değişiklik (yüklenen görünüm vb.) yok sayılır, yüz hep kanonun
     if yeni and self.kanon then
          if yeni.gender ~= self.kanon.cins then
               self.durum = once
               self.bildirim, self.bildirimZaman = self.kanon.ad .. " el género del canónico no cambia", RealTime()
               return
          end
          yeni.face, yeni.hair = self.kanon.yuz, ""
     end
     if yeni then
          if kiyafet then yeni.kiyafet = O.BaslangicTemizle(yeni.gender, kiyafet) end
          self.durum = yeni
     end

     self:SahneGuncelle()
     if not surekli then
          ses(bolge and "buyu" or "tik")
          self.sahne:Parilti(bolge or "govde")
     end
     if self.durum.gender ~= eskiCins then self:IcerikKur(true) end
end

function AYNA:CinsiyetSec(cins)
     if self.durum.gender == cins then return end
     if self.kanon then
          self.bildirim, self.bildirimZaman = self.kanon.ad .. " el género del canónico no cambia", RealTime()
          return
     end
     self:Degistir(function(d)
          local y = O.Varsayilan(cins)
          y.colors, y.height, y.eyes, y.vucut = d.colors, d.height, d.eyes, d.vucut
          if d.kiyafet then
               y.kiyafet = O.BaslangicTemizle(cins, {ust = d.kiyafet.ust})
          else
               y.kiyafet = nil
          end
          for k in pairs(d) do d[k] = nil end
          for k, v in pairs(y) do d[k] = v end
     end, "govde")
     self.sahne:Parilti("govde")
end

local function bildir(ayna, metin)
     ayna.bildirim, ayna.bildirimZaman = metin, RealTime()
end

function AYNA:GeriAl()
     local onceki = table.remove(self.gecmis)
     if not onceki then return end
     self.durum = onceki
     self:SahneGuncelle()
     self:IcerikKur()
     self.sahne:Parilti("govde")
     ses("tik")
     bildir(self, "Deshecho")
end

function AYNA:Rastgele()
     if self:KisitliKip() then return end
     self:GecmisKaydet()
     local yeni = O.Rastgele(self.durum.gender, self.durum)
     if not self.secenek.baslangic then yeni.kiyafet = nil end
     self.durum = yeni
     self:SahneGuncelle()
     self:IcerikKur()
     ses("buyu")
     self.sahne:Parilti("govde")
     bildir(self, "Aspecto aleatorio")
end

function AYNA:Sifirla()
     self:GecmisKaydet()
     self.durum = table.Copy(self.ilk)
     self.sahne:Sifirla()
     self:SahneGuncelle()
     self:IcerikKur()
     ses("buyu")
     self.sahne:Parilti("govde")
     bildir(self, "Vuelto al aspecto inicial")
end

function AYNA:IsaretTikla(def)
     ses("tik")
     if def.seviye then
          self:SeviyeSec(def.seviye)
          return
     end
     if self.kart == def.kart then
          self:KartKapat()
          return
     end
     local st = self.isaretDurum[def.id]
     self:KartAc(def.kart, st and st.taraf)
end

function AYNA:OnMousePressed(kod)
     if kod == MOUSE_LEFT and self.ustIsaret then
          self:IsaretTikla(self.ustIsaret)
          return
     end
     if kod == MOUSE_LEFT or kod == MOUSE_RIGHT then
          self.surukle = {kod = kod, x = gui.MouseX(), y = gui.MouseY()}
          self:MouseCapture(true)
     end
end

function AYNA:OnMouseReleased()
     self.surukle = nil
     self:MouseCapture(false)
end

function AYNA:OnMouseWheeled(d)
     self.sahne:Yakinlas(d)
end

function AYNA:Think()
     if self.onceGoster and not input.IsMouseDown(MOUSE_LEFT) then self:OnceGoster(false) end
     local kip = self:KisitliKip()
     if kip and kip.fiyat and (self.fiyatZaman or 0) < RealTime() then
          self.fiyatZaman = RealTime() + 0.25
          local fiyat = O.KisitliFiyat(self.secenek.kisitli, (O.GorunumFark(self.ilk, self.durum)))
          self.devam.metin = fiyat > 0 and ("GUARDAR · " .. fiyat .. " G") or "GUARDAR"
     end
     local s = self.surukle
     if s then
          local mx, my = gui.MouseX(), gui.MouseY()
          if s.kod == MOUSE_LEFT then
               self.sahne:Dondur((mx - s.x) * 0.45)
          else
               self.sahne.yukseklik = math.Clamp(self.sahne.yukseklik + (my - s.y) * 0.05, -30, 30)
          end
          s.x, s.y = mx, my
          if not input.IsMouseDown(s.kod) then self:OnMouseReleased() end
     end

     -- üzerine gelinen işaret (yalnız ayna kendisi fare altındayken; kartlar ve düğmeler öncelikli)
     local ust
     if not s and vgui.GetHoveredPanel() == self then
          local mx, my = self:CursorPos()
          for _, hit in ipairs(self.isaretHit) do
               if hit.r then
                    if (mx - hit.x) ^ 2 + (my - hit.y) ^ 2 <= hit.r * hit.r then
                         ust = hit.def
                         break
                    end
               elseif mx >= hit.x0 and mx <= hit.x1 and my >= hit.y0 and my <= hit.y1 then
                    ust = hit.def
                    break
               end
          end
     end
     if ust ~= self.ustIsaret then
          self.ustIsaret = ust
          if ust then ses("ust") end
          self:SetCursor(ust and "hand" or "arrow")
     end

     -- klavye (yazı kutusu odakta değilken): 1-7 şerit, Ctrl+Z geri al
     if IsValid(vgui.GetKeyboardFocus()) then return end
     for i, it in ipairs(self:SeritListe()) do
          local tus = KEY_1 + i - 1
          if input.IsKeyDown(tus) and not self["tus" .. i] then
               self["tus" .. i] = true
               self:SeritSec(it)
          elseif not input.IsKeyDown(tus) then
               self["tus" .. i] = nil
          end
     end
     local z = input.IsKeyDown(KEY_Z) and (input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL))
     if z and not self.tusZ then self:GeriAl() end
     self.tusZ = z
end

-- Seviyenin işaretlerinin bu karedeki ekran konumu, görünürlüğü ve tarafı (sahne çizildikten sonra: kemik
-- matrisleri o karenin)
function AYNA:IsaretHesapla(w, h)
     local liste = {}
     local e, g = self.sahne.ent, self.sahne.gorus
     if not IsValid(e) or not g then return liste end

     local olcek = e.HLHeight or 1
     local F, U, L = yuzCercevesi(e, self.durum.gender)
     local ang = e:GetAngles()
     local gF, gU, gL = ang:Forward(), Vector(0, 0, 1), -ang:Right()

     -- tarafı ayıran eksen: yüzde burun, tam boyda omurga
     local eksen = kemikPos(e, self.seviye == "yuz" and "nose" or "ValveBiped.Bip01_Spine2")
     local ex = eksen and self.sahne:Ekran(eksen) or w / 2

     for i, def in ipairs(ISARET[self.seviye] or {}) do
          local k = def.kart and KARTLAR[def.kart]
          local p = not (k and k.baslangic and not self.secenek.baslangic) and kemikPos(e, def.kemik)
          if p then
               local f, u, l = F, U, L
               if def.govde then f, u, l = gF, gU, gL end
               local o = def.ofs
               p = p + (f * o[1] + u * o[2] + l * o[3]) * olcek
               local x, y = self.sahne:Ekran(p)
               if x then
                    local yz = def.yuzey or YUZEY_ON
                    local n = f * yz[1] + u * yz[2] + l * yz[3]
                    n:Normalize()
                    local kam = g.pos - p
                    kam:Normalize()
                    local gor = def.hep and 1 or math.Clamp((n:Dot(kam) - 0.08) / 0.3, 0, 1)
                    -- ekran dışı ve alt şeridin hizası (orada tıklanamaz, etiketi sığmaz)
                    if x < S(12) or x > w - S(12) or y < S(40) or y > h - S(96) then gor = 0 end

                    local st = self.isaretDurum[def.id]
                    if not st then
                         st = {taraf = def.taraf}
                         self.isaretDurum[def.id] = st
                    end
                    -- eksene yakınken tanımdaki taraf, uzaklaşınca ekrandaki yeri
                    if math.abs(x - ex) < S(36) then
                         st.taraf = def.taraf
                    else
                         st.taraf = x < ex and -1 or 1
                    end
                    st.x, st.y, st.gor, st.no = x, y, gor, i
                    liste[#liste + 1] = {def = def, st = st, k = k}
               end
          end
     end

     -- modelin dış hattı (kollar, başın yanları): etiket sütunları bunun da dışında kalsın
     local sol, sag = math.huge, -math.huge
     local function hat(pw)
          local x = self.sahne:Ekran(pw)
          if x then sol, sag = math.min(sol, x), math.max(sag, x) end
     end
     if self.seviye == "yuz" then
          local bp = kemikPos(e, BAS)
          if bp then
               for _, yan in ipairs({-1, 1}) do
                    hat(bp + (F * 0.8 + U * 1.2 + L * 3.3 * yan) * olcek)
                    hat(bp + (F * 1.5 - U * 1.5 + L * 3 * yan) * olcek)
               end
          end
     else
          for _, ad in ipairs(KOL_KEMIK) do
               local bp = kemikPos(e, ad)
               if bp then hat(bp) end
          end
     end
     self.siluet = sol <= sag and {sol, sag} or nil
     return liste
end

-- İşaretler, yan sütunlardaki etiketler, çizgiler ve açık kartın çizgisi; tıklama alanları isaretHit'e
function AYNA:IsaretCiz(w, h)
     local hit = {}
     self.isaretHit = hit
     local liste = self:IsaretHesapla(w, h)
     if #liste == 0 then return end

     local dt = math.min(FrameTime(), 0.1)
     local f = math.min(1, dt * 10)
     local zaman = RealTime()
     local gecen = zaman - self.seviyeZaman
     local d = self.durum
     local acik = self.kart
     local ustD = self.ustIsaret

     -- sütunlar: görünen işaretlerin en solu / en sağı
     local enSol, enSag = math.huge, -math.huge
     for _, it in ipairs(liste) do
          if it.st.gor > 0.2 then
               enSol = math.min(enSol, it.st.x)
               enSag = math.max(enSag, it.st.x)
          end
     end
     if enSol > enSag then enSol, enSag = w / 2, w / 2 end
     if self.siluet then
          enSol = math.min(enSol, self.siluet[1] - S(34))
          enSag = math.max(enSag, self.siluet[2] + S(34))
     end
     local pay = S(190)
     local hedefL = math.max(self.kenarPay + pay, enSol - S(72))
     local hedefR = math.min(w - self.kenarPay - pay, enSag + S(72))
     self.sutunL = self.sutunL and Lerp(math.min(1, dt * 8), self.sutunL, hedefL) or hedefL
     self.sutunR = self.sutunR and Lerp(math.min(1, dt * 8), self.sutunR, hedefR) or hedefR

     -- etiket yükseklikleri: her tarafta işaretin y'sine göre, üst üste binmeden
     local ustSinir, altSinir, aralik = S(178), h - S(178), S(50)
     for _, taraf in ipairs({-1, 1}) do
          local yan = {}
          for _, it in ipairs(liste) do
               if it.st.taraf == taraf and it.st.gor > 0.05 then yan[#yan + 1] = it end
          end
          table.sort(yan, function(a, b) return a.st.y < b.st.y end)
          local y = ustSinir
          for _, it in ipairs(yan) do
               it.hy = math.max(it.st.y, y)
               y = it.hy + aralik
          end
          local sinir = altSinir
          for i = #yan, 1, -1 do
               local it = yan[i]
               it.hy = math.min(it.hy, sinir)
               sinir = it.hy - aralik
          end
     end

     -- durumlar: görünürlük, etiket görünürlüğü (kart açıkken onun tarafındakiler gizlenir), etiket y, vurgu
     for _, it in ipairs(liste) do
          local st, def = it.st, it.def
          it.secili = acik ~= nil and def.kart == acik
          it.giris = math.Clamp((gecen - 0.15 - st.no * 0.045) * 4, 0, 1)
          st.a = Lerp(f, st.a or 0, st.gor)
          local etiketVar = not (acik and (it.secili or st.taraf == self.kartTaraf))
          st.ea = Lerp(f, st.ea or 0, etiketVar and st.gor or 0)
          local hedefY = math.Clamp(it.hy or st.y, ustSinir, altSinir)
          st.ly = st.ly and Lerp(f, st.ly, hedefY) or hedefY
          st.v = Lerp(math.min(1, dt * 12), st.v or 0, ustD == def and 1 or 0)
          st.lx = st.taraf > 0 and self.sutunR or self.sutunL
     end

     -- etiket çizgileri: işaret -> dirsek -> etiket ucu (açılışta işaretten dışa uzar)
     for _, it in ipairs(liste) do
          local st = it.st
          local a = st.ea * it.giris
          if a > 0.01 then
               local dx = st.lx - st.taraf * S(24)
               local u = it.giris
               surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, (50 + 130 * st.v) * a)
               surface.DrawLine(st.x, st.y, st.x + (dx - st.x) * u, st.y + (st.ly - st.y) * u)
               if u >= 1 then surface.DrawLine(dx, st.ly, st.lx, st.ly) end
          end
     end

     -- açık kartın çizgisi: işaret -> dirsek -> kartın kenarı; üstünde gezen ışık
     self.kartGiris = nil
     local kp = self.kartP
     if acik and IsValid(kp) then
          for _, it in ipairs(liste) do
               local st = it.st
               if it.secili and st.a > 0.05 then
                    local kx, ky = kp:GetPos()
                    local kw, kh = kp:GetSize()
                    local kenar = self.kartTaraf > 0 and kx or kx + kw
                    local gy = math.Clamp(st.y, ky + S(44), ky + math.max(S(60), kh - S(30)))
                    local dirsek = kenar - self.kartTaraf * S(28)
                    local u = kp.acilis or 1
                    local a = st.a * u
                    local renk = renkA(R.parlak, 200 * a)
                    local x1, y1 = st.x + (dirsek - st.x) * u, st.y + (gy - st.y) * u
                    kalinCizgi(st.x, st.y, x1, y1, S(1.5), renk)
                    if u >= 1 then kalinCizgi(dirsek, gy, kenar, gy, S(1.5), renk) end
                    self.kartGiris = gy

                    local radyal = O.Doku("radyal")
                    if radyal and u >= 1 then
                         local t = (zaman * 0.55) % 1
                         local px, py = st.x + (dirsek - st.x) * t, st.y + (gy - st.y) * t
                         surface.SetMaterial(radyal)
                         surface.SetDrawColor(255, 226, 170, 150 * a)
                         surface.DrawTexturedRect(px - S(9), py - S(9), S(18), S(18))
                    end
               end
          end
     end

     -- noktalar ve etiketler
     for _, it in ipairs(liste) do
          local st, def, k = it.st, it.def, it.k
          local kilit = k and not self:KartIzinli(k.id)
          local a = st.a * it.giris * (kilit and 0.35 or 1)
          if a > 0.01 then
               local oynanmis = k and k.grup and oynananHat(d, kartGrubu(k, d.gender)) > 0
               isaretNoktasi(st.x, st.y, a, st.v, it.secili, oynanmis, zaman, st.no * 0.9)
               if a > 0.3 then hit[#hit + 1] = {def = def, x = st.x, y = st.y, r = S(16)} end
          end

          local ea = st.ea * it.giris * (kilit and 0.4 or 1)
          if ea > 0.01 then
               local ad, alt, renk
               if def.seviye then
                    ad, alt = def.ad, yuzAdi(d)
               elseif k then
                    ad = self:KartAdi(k)
                    if k.ozet then
                         alt = k.ozet(d)
                    elseif k.grup then
                         local n = oynananHat(d, kartGrubu(k, d.gender))
                         alt = n > 0 and (n .. " rasgos ajustados") or "natural"
                    end
                    renk = k.renk and k.renk(d)
                    if kilit then alt, renk = "aquí no cambia", nil end
               end
               local taraf, x, y, v = st.taraf, st.lx, st.ly, st.v
               local hiza = taraf > 0 and TEXT_ALIGN_LEFT or TEXT_ALIGN_RIGHT
               local tx = x + taraf * S(14)
               -- okunurluk: yakın planda etiket tenin üstüne düşer; yazının ardında yumuşak koyu gölge
               local radyal = O.Doku("radyal")
               if radyal then
                    surface.SetFont("SOg.Etk")
                    local gw = surface.GetTextSize(ad or "") + S(90)
                    surface.SetMaterial(radyal)
                    surface.SetDrawColor(0, 0, 0, 200 * ea)
                    surface.DrawTexturedRect(taraf > 0 and x - S(16) or x - gw + S(16), y - S(34), gw, S(86))
               end
               poly(elmas(x, y, S(3)), renkA(v > 0.5 and R.parlak or R.altin, 220 * ea))
               draw.SimpleText(ad or "", "SOg.Etk", tx, y - S(1), renkA(v > 0.5 and R.parlak or R.metin, 255 * ea), hiza, TEXT_ALIGN_CENTER)
               surface.SetFont("SOg.Etk")
               local genis = surface.GetTextSize(ad or "")
               local ay, ax = y + S(18), tx
               if renk then
                    local bx = ax + taraf * S(5)
                    daire(bx, ay, S(4.5), Color(renk.r, renk.g, renk.b, 255 * ea))
                    yay(bx, ay, S(5.5), 1, renkA(R.altin, 140 * ea))
                    ax = ax + taraf * S(15)
               end
               if alt and alt ~= "" then
                    draw.SimpleText(alt, "SOg.Kucuk", ax, ay, renkA(R.gri, 235 * ea), hiza, TEXT_ALIGN_CENTER)
                    surface.SetFont("SOg.Kucuk")
                    genis = math.max(genis, math.abs(ax - tx) + surface.GetTextSize(alt))
               end
               if ea > 0.35 then
                    local x0, x1 = x, x + taraf * (S(16) + genis)
                    hit[#hit + 1] = {def = def, x0 = math.min(x0, x1), x1 = math.max(x0, x1), y0 = y - S(14), y1 = y + S(28)}
               end
          end
     end
end

function AYNA:Paint(w, h)
     if not self.durum then return end
     local dt = math.min(FrameTime(), 0.1)
     self.acilis = math.min(1, self.acilis + dt * 1.6)
     local zaman = RealTime()
     local pad = self.kenarPay
     self.merkezX = Lerp(math.min(1, dt * 5), self.merkezX, self.merkezHedef or w / 2)
     local merkezX = self.merkezX

     -- zemin: koyu gece mavisi, karakterin arkasında sıcak ışık, sol üstten soğuk ışık huzmeleri
     surface.SetDrawColor(5, 7, 13, 255)
     surface.DrawRect(0, 0, w, h)

     local radyal = O.Doku("radyal")
     if radyal then
          local L = O.SahneIsikBul and O.SahneIsikBul[self.sahne.isik or "studyo"]
          local zc = L and L.zemin or Color(160, 112, 54)
          surface.SetMaterial(radyal)
          surface.SetDrawColor(zc.r, zc.g, zc.b, 70)
          surface.DrawTexturedRect(merkezX - h * 0.55, h * 0.02, h * 1.1, h * 1.1)
          surface.SetDrawColor(60, 86, 140, 40)
          surface.DrawTexturedRect(-h * 0.35, -h * 0.45, h * 1.1, h * 1.1)
     end

     surface.SetMaterial(gradU)
     for i = 0, 2 do
          local x = merkezX - h * 0.45 + i * h * 0.22 + math.sin(zaman * 0.21 + i) * S(18)
          surface.SetDrawColor(120, 150, 210, 10 + i * 3)
          surface.DrawTexturedRectRotated(x, h * 0.32, S(120), h * 0.95, -18)
     end

     self.sahne:Ciz(0, 0, w, h, merkezX)

     -- kenar kararması
     surface.SetDrawColor(0, 0, 0, 210)
     surface.SetMaterial(gradU)
     surface.DrawTexturedRect(0, 0, w, h * 0.22)
     surface.SetMaterial(gradD)
     surface.DrawTexturedRect(0, h * 0.74, w, h * 0.26)
     surface.SetMaterial(gradL)
     surface.DrawTexturedRect(0, 0, w * 0.2, h)
     surface.SetMaterial(gradR)
     surface.DrawTexturedRect(w * 0.8, 0, w * 0.2, h)

     -- başlık: üst etiket, ad, alt yazı, adım çizgisi
     local yarat = not self.secenek or self.secenek.kip ~= "duzenle"
     aralikli("HOGWARTS · REGISTRO DE ESTUDIANTE", "SOg.Ust", pad, S(42), R.soluk, S(3))
     draw.SimpleText("Espejo de apariencia", "SOg.Baslik", pad, S(58), R.parlak, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
     local kip = self:KisitliKip()
     local altYazi = yarat and "Toca las marcas del reflejo; el espejo moldeará esa parte." or "Vuelve a dar forma a tu reflejo: toca una marca."
     if kip then altYazi = kip.ad .. ": burada " .. O.KisitliIzinMetni(self.secenek.kisitli) .. " se puede cambiar." end
     draw.SimpleText(altYazi, "SOg.Inferior", pad, S(104), R.gri, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

     if yarat then
          local adimlar = {"CASA", "APARIENCIA", "IDENTIDAD"}
          local x = pad
          local y = S(144)
          for i, ad in ipairs(adimlar) do
               local aktif = i == 2
               local gecti = i < 2
               poly(elmas(x + S(5), y, S(aktif and 5 or 4)), aktif and R.parlak or (gecti and R.altin or R.sonuk))
               local tw = aralikli(ad, "SOg.Etiket", x + S(16), y - S(7), aktif and R.parlak or (gecti and R.altin or R.sonuk), S(2))
               x = x + S(16) + tw + S(14)
               if i < #adimlar then
                    surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, gecti and 120 or 40)
                    surface.DrawRect(x, y, S(28), 1)
                    x = x + S(28) + S(10)
               end
          end
     end

     self:IsaretCiz(w, h)

     if self.onceGoster then
          local bw = S(260)
          draw.RoundedBox(S(16), w / 2 - bw / 2, S(52), bw, S(34), Color(8, 10, 17, 230))
          aralikli("ASPECTO INICIAL", "SOg.Etiket", w / 2, S(62), R.parlak, S(4), TEXT_ALIGN_CENTER)
     end

     -- ipucu (şeridin altında)
     draw.SimpleText("Clic en marca: editar  ·  Arrastra: girar  ·  Clic der. arrastrar: altura  ·  Rueda: zoom", "SOg.Kucuk", w / 2, h - S(20), R.sonuk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

     if not O.Hazir() or not IsValid(self.sahne.ent) or not O.IcerikVar(O.Model(self.durum.gender, self.durum.face)) then
          draw.SimpleText("Los modelos de estudiante no están en este PC: hace falta el contenido St_oprop_1-4 de la colección.", "SOg.Metin", merkezX, h * 0.5, R.kirmizi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
end

function AYNA:PaintOver(w, h)
     -- üzerine gelinen ipuçlu öğenin yazısı (yuvarlak düğmeler, karolar, petekler)
     local p = vgui.GetHoveredPanel()
     if IsValid(p) and p.ipucu and p:IsVisible() then
          local px, py = p:LocalToScreen(0, 0)
          local ox, oy = self:LocalToScreen(0, 0)
          px, py = px - ox, py - oy
          surface.SetFont("SOg.Kucuk")
          local tw, th = surface.GetTextSize(p.ipucu)
          local bw, bh = tw + S(20), th + S(10)
          local x = math.Clamp(px + p:GetWide() / 2 - bw / 2, S(8), w - bw - S(8))
          local y = py - bh - S(8)
          if y < S(8) then y = py + p:GetTall() + S(8) end
          draw.RoundedBox(bh / 2, x, y, bw, bh, Color(8, 10, 17, 235))
          surface.SetDrawColor(R.soluk)
          draw.SimpleText(p.ipucu, "SOg.Kucuk", x + bw / 2, y + bh / 2, R.metin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end

     -- kısa bildirim (geri al, rastgele); uzun metin okunacak kadar kalır
     if self.bildirim then
          local t = RealTime() - self.bildirimZaman
          local sure = math.max(1.6, #self.bildirim / 26)
          if t > sure then
               self.bildirim = nil
          else
               local a = math.Clamp(math.min(t * 6, (sure - t) * 3), 0, 1)
               surface.SetFont("SOg.Etiket")
               local tw = surface.GetTextSize(self.bildirim)
               local bw, bh = tw + S(32), S(30)
               -- (sağ üst düğme sırasının altında; model kenara kayınca da ekranda kalsın)
               local x, y = math.Clamp((self.merkezX or w / 2) - bw / 2, S(20), w - bw - S(20)), S(112)
               draw.RoundedBox(bh / 2, x, y, bw, bh, Color(8, 10, 17, 220 * a))
               draw.SimpleText(self.bildirim, "SOg.Etiket", x + bw / 2, y + bh / 2, renkA(R.parlak, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
     end

     -- açılışta karanlıktan belirme
     if self.acilis < 1 then
          surface.SetDrawColor(0, 0, 0, 255 * (1 - self.acilis))
          surface.DrawRect(0, 0, w, h)
     end
end

function AYNA:OnRemove()
     self.sahne:Kaldir()
     if O.AynaPanel == self then O.AynaPanel = nil end
end

vgui.Register("SOg.Ayna", AYNA, "EditablePanel")

function O.AynaAc(t)
     if IsValid(O.AynaPanel) then O.AynaPanel:Remove() end
     local p = vgui.Create("SOg.Ayna", t.ebeveyn)
     O.AynaPanel = p
     if not t.ebeveyn then p:MakePopup() end
     p:Kur(t)
     return p
end

hook.Add("OnScreenSizeChanged", "SardonOgrenci.Ayna", function()
     local p = O.AynaPanel
     if IsValid(p) then
          local t = p.secenek
          t.durum = p.durum
          O.AynaAc(t)
     end
end)
