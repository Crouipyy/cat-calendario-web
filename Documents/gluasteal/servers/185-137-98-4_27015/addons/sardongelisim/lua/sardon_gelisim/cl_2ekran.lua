-- "addons\\sardongelisim\\lua\\sardon_gelisim\\cl_2ekran.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gelişim :: TAB > Karakter Gelişimi (SHINE / Celestial).
-- Görsel hedef: addons/SHINE-Celestial-Paketi/ONIZLEME.html (preview/ui.css + runtime.js).
-- Tek tasarım alanı 1600x900; ölçek = min(W/1600, H/900), alan ortalanır. Bütün koordinatlar
-- CSS'teki değerlerdir. Öğrenme isteği sunucuda doğrulanır (sv_ogren.lua).

local G = SardonGelisim

local TW, TH = 1600, 900
local KAT_KONUM = {{720, 205}, {925, 285}, {1010, 470}, {925, 660}, {720, 730}, {515, 660}, {430, 470}, {515, 285}}
local AGAC_KONUM = {{680, 306}, {410, 462}, {680, 462}, {950, 462}, {410, 617}, {680, 617}, {950, 617}, {680, 740}}
-- Kategoriye özel ağaç düzeni (2026-11-10): SYB'nin 9. becerisi (Vivaryum Anahtarı, kayıtta dizinin sonu) 2. ile 3.
-- sıranın arasında, ortada; beş sıra sığsın diye bu düzende yazılar düğüme yakın (ad +50, kademe +68), tıklama alanı
-- kısa. yol["u>i"]: bağın ara noktaları; 1→9 ve 3→6 bağları ortadaki düğümün içinden geçmesin diye yandan dolanır.
local AGAC_DUZEN = {
     syb = {
          konum = {{680, 284}, {410, 398}, {680, 398}, {950, 398}, {410, 626}, {680, 626}, {950, 626}, {680, 740}, {680, 512}},
          ad = 50, kademe = 68, alan = 110,
          yol = {["1>9"] = {{545, 398}}, ["3>6"] = {{815, 512}}},
     },
}
local DUZEN_VARSAYILAN = {konum = AGAC_KONUM, ad = 56, kademe = 79, alan = 130, yol = {}}
local function Duzen(kat) return (kat and AGAC_DUZEN[kat.id]) or DUZEN_VARSAYILAN end
local MERKEZ_X, MERKEZ_Y = 720, 465

local function Renk(hex, a)
     hex = hex:gsub("#", "")
     local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
     local al = #hex >= 8 and tonumber(hex:sub(7, 8), 16) or 255
     return Color(r, g, b, a and math.Round(a * 255) or al)
end

-- ui.css "Celestial edition" renkleri
local R = {
     soluk = Renk("#e8dbb6"), altin = Renk("#bea268"),
     ust = Renk("#bba679"), baslikCizgi = Renk("#c4a15c"), cizgiBaklava = Renk("#bca26a"),
     puanCizgi = Renk("#bca16a"), puanGlif = Renk("#cbb079"), puanYazi = Renk("#b5b4a0"),
     muhur = Renk("#b79553"), muhurSecili = Renk("#e0c280"), halkaSecili = Renk("#c7a363"),
     ilerleme = Renk("#ceb475"), katAd = Renk("#e8dbb6"), katAdSecili = Renk("#f2e0b3"),
     sayi = Renk("#aaaf99"), sayiSecili = Renk("#d3c59c"),
     kimlikAlt = Renk("#c0bea5"), kucukYildiz = Renk("#d6b875"),
     ayrUst = Renk("#c4ac7a"), ayrSira = Renk("#929b87"), ayrAciklama = Renk("#bec2b0"),
     ayrBaslikAlt = Renk("#aeb599"), ayrBaslikDeger = Renk("#d7d5c5"),
     izBos = Renk("#bbaa77", 0.14), izSol = Renk("#8c753f"), izSag = Renk("#d4b97b"),
     dal = Renk("#b5bba0"), buton = Renk("#bea268"), butonYazi = Renk("#e8d4a4"),
     butonUzerinde = Renk("#dfc180"), butonKapali = Renk("#8e967e"), butonKapaliCizgi = Renk("#8a906b"),
     butonKapaliKose = Renk("#657476"), ayak = Renk("#88987f"),
     geri = Renk("#b0bba0"), sekme = Renk("#a2ad94"), sekmeSecili = Renk("#e4ce9a"), sekmeBaklava = Renk("#d1b374"),
     becAd = Renk("#c1c9b4"), becAdSecili = Renk("#efdbad"), becKademe = Renk("#adb697"), becKilitli = Renk("#8a977d"),
     kademeYazi = Renk("#b8c2a4"), etki = Renk("#d7ccaa"), onKosul = Renk("#9ba98b"),
     onKosulBtn = Renk("#a1b08f"), onKosulTamam = Renk("#d2caa4"),
     isaret = Renk("#172a1b"), isaretCizgi = Renk("#9c9f71"), isaretYazi = Renk("#ddd1a5"), kilit = Renk("#71868b"),
     lejant = Renk("#99a88b"), lejantBaklava = Renk("#c2ad75"),
     ayakYazi = Renk("#afb59a"), ayakNot = Renk("#98a183"), tusCizgi = Renk("#a59a67"), tusYazi = Renk("#d3c49a"),
     hareket = Renk("#a4b08f"), hareketUzerinde = Renk("#d4d6c5"), bildirim = Renk("#e7d6a5")
}

----------------------------------------------------------------------------------------
-- Ölçek ve yardımcılar (tasarım px -> ekran px)
----------------------------------------------------------------------------------------
local S, OX, OY = 1, 0, 0
local function X(x) return OX + x * S end
local function Y(y) return OY + y * S end

local sakin = cookie.GetNumber("sardon_gelisim_sakin", 0) == 1
local function Zaman() return sakin and 0 or RealTime() end

local function Kolay(t) t = math.Clamp(t, 0, 1) return 1 - (1 - t) ^ 3 end

local function Ton(c, a)
     surface.SetDrawColor(c.r, c.g, c.b, (a or 1) * c.a)
end

-- Bütün yazıların büyütme katsayısı (HTML boyutlarına göre); satır aralıkları da bununla büyür
local YAZI_OLCEK = 1.15

local fontlar = {}
-- 700: düz gövde metni (Zihin Sanatları); küçük boyda Montserrat karışık görünüyordu
local AILE = {[400] = "Montserrat Medium", [500] = "Montserrat Medium", [600] = "Montserrat SemiBold", [700] = "Arial"}
local function Font(boy, kalin)
     kalin = kalin or 400
     local px = math.max(9, math.Round(boy * S * YAZI_OLCEK))
     local ad = "SardonGelisimC_" .. px .. "_" .. kalin
     if (!fontlar[ad]) then
          surface.CreateFont(ad, {font = AILE[kalin] or AILE[400], size = px, weight = kalin, antialias = true, extended = true})
          fontlar[ad] = true
     end
     return ad
end

-- Türkçe büyük harf (toLocaleUpperCase('tr'))
local BUYUK = {["i"] = "İ", ["ı"] = "I", ["ç"] = "Ç", ["ş"] = "Ş", ["ğ"] = "Ğ", ["ü"] = "Ü", ["ö"] = "Ö"}
local function Buyuk(s)
     s = s:gsub("[%z\1-\127\194-\244][\128-\191]*", function(c) return BUYUK[c] or c end)
     return s:upper()
end

-- Harf aralıklı genişlik (tasarım px). aralik ekranda tam sayıya yuvarlanır.
local function Olc(metin, boy, kalin, aralik)
     surface.SetFont(Font(boy, kalin))
     local w = surface.GetTextSize(metin)
     if (aralik and aralik > 0) then
          w = w + math.Round(aralik * S) * math.max(0, utf8.len(metin) - 1)
     end
     return w / S
end

-- hiza: 0 sol, 1 orta, 2 sağ; y = satır merkezi
local function Yazi(metin, boy, kalin, x, y, renk, hiza, aralik, alfa)
     metin = tostring(metin)
     local f = Font(boy, kalin)
     surface.SetFont(f)
     surface.SetTextColor(renk.r, renk.g, renk.b, (alfa or 1) * renk.a)
     local _, th = surface.GetTextSize("A")
     local py = math.Round(Y(y) - th / 2)

     if (!aralik or aralik <= 0) then
          local w = surface.GetTextSize(metin)
          surface.SetTextPos(math.Round(X(x) - (hiza == 1 and w / 2 or (hiza == 2 and w or 0))), py)
          surface.DrawText(metin)
          return
     end

     local w = Olc(metin, boy, kalin, aralik)
     surface.SetFont(f)
     local px = X(x) - (hiza == 1 and w * S / 2 or (hiza == 2 and w * S or 0))
     local ara = math.Round(aralik * S)
     for _, kod in utf8.codes(metin) do
          local c = utf8.char(kod)
          surface.SetTextPos(math.Round(px), py)
          surface.DrawText(c)
          px = px + surface.GetTextSize(c) + ara
     end
end

-- Kelime kaydırma (önbellekli); genislik tasarım px
local sarCache = {}
local function Sar(metin, boy, kalin, genislik)
     local anahtar = metin .. "\0" .. boy .. kalin .. genislik .. S
     local c = sarCache[anahtar]
     if (c) then return c end
     surface.SetFont(Font(boy, kalin))
     local satirlar, cur = {}, ""
     for kelime in metin:gmatch("%S+") do
          local aday = cur == "" and kelime or (cur .. " " .. kelime)
          if (cur != "" and surface.GetTextSize(aday) > genislik * S) then
               satirlar[#satirlar + 1] = cur
               cur = kelime
          else
               cur = aday
          end
     end
     if (cur != "") then satirlar[#satirlar + 1] = cur end
     sarCache[anahtar] = satirlar
     return satirlar
end

hook.Add("OnScreenSizeChanged", "SardonGelisim.Font", function() fontlar, sarCache = {}, {} end)

----------------------------------------------------------------------------------------
-- Çizim temelleri
----------------------------------------------------------------------------------------
local function Cizgi(x1, y1, x2, y2)
     surface.DrawLine(X(x1), Y(y1), X(x2), Y(y2))
end

local function Dikdortgen(x, y, w, h)
     surface.DrawRect(X(x), Y(y), math.max(1, w * S), math.max(1, h * S))
end

local function Parca(r) return math.Clamp(math.ceil(r * S * 0.6), 16, 160) end

local function Yay(cx, cy, r, a0, a1)
     local n = math.max(2, math.ceil(Parca(r) * math.abs(a1 - a0) / (2 * math.pi)))
     local px, py = X(cx + math.cos(a0) * r), Y(cy + math.sin(a0) * r)
     for i = 1, n do
          local a = a0 + (a1 - a0) * i / n
          local nx, ny = X(cx + math.cos(a) * r), Y(cy + math.sin(a) * r)
          surface.DrawLine(px, py, nx, ny)
          px, py = nx, ny
     end
end

local function Cember(cx, cy, r) Yay(cx, cy, r, 0, 2 * math.pi) end

local diskPoly = {}
local function Disk(cx, cy, r)
     local n = math.Clamp(math.ceil(r * S * 0.8), 8, 96)
     for i = 1, n do
          local a = (i - 1) / n * 2 * math.pi
          local p = diskPoly[i] or {}
          diskPoly[i] = p
          p.x, p.y = X(cx + math.cos(a) * r), Y(cy + math.sin(a) * r)
     end
     for i = n + 1, #diskPoly do diskPoly[i] = nil end
     draw.NoTexture()
     surface.DrawPoly(diskPoly)
end

-- Kalınlığı olan yay (ilerleme halkası): r merkez yarıçap, k kalınlık
local seritPoly = {{}, {}, {}, {}}
local function KalinYay(cx, cy, r, k, a0, a1)
     if (a1 <= a0) then return end
     draw.NoTexture()
     local n = math.max(2, math.ceil(Parca(r) * (a1 - a0) / (2 * math.pi)))
     local ri, rd = r - k / 2, r + k / 2
     for i = 1, n do
          local b0, b1 = a0 + (a1 - a0) * (i - 1) / n, a0 + (a1 - a0) * i / n
          local c0, s0, c1, s1 = math.cos(b0), math.sin(b0), math.cos(b1), math.sin(b1)
          local p = seritPoly
          p[1].x, p[1].y = X(cx + c0 * rd), Y(cy + s0 * rd)
          p[2].x, p[2].y = X(cx + c1 * rd), Y(cy + s1 * rd)
          p[3].x, p[3].y = X(cx + c1 * ri), Y(cy + s1 * ri)
          p[4].x, p[4].y = X(cx + c0 * ri), Y(cy + s0 * ri)
          surface.DrawPoly(p)
     end
end

-- 45° döndürülmüş kare; h = yarı köşegen
local baklavaPoly = {{}, {}, {}, {}}
local function Baklava(cx, cy, h)
     local p = baklavaPoly
     p[1].x, p[1].y = X(cx), Y(cy - h)
     p[2].x, p[2].y = X(cx + h), Y(cy)
     p[3].x, p[3].y = X(cx), Y(cy + h)
     p[4].x, p[4].y = X(cx - h), Y(cy)
     draw.NoTexture()
     surface.DrawPoly(p)
end

local function BaklavaCizgi(cx, cy, h)
     Cizgi(cx, cy - h, cx + h, cy) Cizgi(cx + h, cy, cx, cy + h)
     Cizgi(cx, cy + h, cx - h, cy) Cizgi(cx - h, cy, cx, cy - h)
end

local matParilti = Material("sprites/glow04_noz", "smooth")
local function Parilti(cx, cy, boy, c, a)
     surface.SetMaterial(matParilti)
     surface.SetDrawColor(c.r, c.g, c.b, a)
     surface.DrawTexturedRect(X(cx - boy / 2), Y(cy - boy / 2), boy * S, boy * S)
     draw.NoTexture()
end

local gradL, gradR = Material("vgui/gradient-l"), Material("vgui/gradient-r")
local gradU, gradD = Material("vgui/gradient-u"), Material("vgui/gradient-d")

-- Yatay iki renkli çizgi (CSS linear-gradient 90deg)
local function YatayGecis(x, y, w, h, c1, a1, c2, a2)
     draw.NoTexture()
     surface.SetDrawColor(c1.r, c1.g, c1.b, a1)
     surface.SetMaterial(gradL)
     surface.DrawTexturedRect(X(x), Y(y), w * S, math.max(1, h * S))
     surface.SetDrawColor(c2.r, c2.g, c2.b, a2)
     surface.SetMaterial(gradR)
     surface.DrawTexturedRect(X(x), Y(y), w * S, math.max(1, h * S))
     draw.NoTexture()
end

-- Radyal dolgu (CSS radial-gradient yaklaşığı): merkezden dışa renk geçişi
local function RadyalDisk(cx, cy, r, ic, dis, dur)
     Ton(dis) Disk(cx, cy, r)
     local adim = 6
     for i = adim, 1, -1 do
          local f = i / adim
          local k = 1 - f
          surface.SetDrawColor(Lerp(k, dis.r, ic.r), Lerp(k, dis.g, ic.g), Lerp(k, dis.b, ic.b), 255)
          Disk(cx, cy, r * dur * f)
     end
end

-- Küçük yıldız (runtime.js star()): üç katmanlı yuvarlak ışık noktası
local YILDIZ = Color(208, 184, 130)
local function Yildiz(x, y, r, alfa, t)
     local nefes = sakin and 1 or 0.84 + 0.16 * math.sin(t * 0.7 + x * 0.1)
     local cekirdek = math.Clamp(r * 0.16, 0.75, 1.6)
     for _, k in ipairs({{3, 0.07}, {1.8, 0.15}, {1, 0.82}}) do
          surface.SetDrawColor(YILDIZ.r, YILDIZ.g, YILDIZ.b, 255 * alfa * k[2] * nefes)
          Disk(x, y, math.max(0.5, cekirdek * k[1]))
     end
end

-- ✦ (kimlik üstündeki küçük yıldız) — dört uçlu küçük işaret
local function MiniYildiz(cx, cy, r)
     draw.NoTexture()
     local i = r * 0.28
     surface.DrawPoly({
          {x = X(cx), y = Y(cy - r)}, {x = X(cx + i), y = Y(cy - i)}, {x = X(cx + r), y = Y(cy)}, {x = X(cx + i), y = Y(cy + i)},
          {x = X(cx), y = Y(cy + r)}, {x = X(cx - i), y = Y(cy + i)}, {x = X(cx - r), y = Y(cy)}, {x = X(cx - i), y = Y(cy - i)}
     })
end

-- ← ok (geri butonu); x sol uç
local function SolOk(x, y, w)
     Cizgi(x, y, x + w, y)
     Cizgi(x, y, x + w * 0.32, y - w * 0.32)
     Cizgi(x, y, x + w * 0.32, y + w * 0.32)
end

local function SagOk(x, y, w)
     Cizgi(x - w, y, x, y)
     Cizgi(x, y, x - w * 0.32, y - w * 0.32)
     Cizgi(x, y, x - w * 0.32, y + w * 0.32)
end

----------------------------------------------------------------------------------------
-- Veri kısayolları
----------------------------------------------------------------------------------------
local function Karakter()
     local ply = LocalPlayer()
     return IsValid(ply) and ply.GetCharacter and ply:GetCharacter() or nil
end

local function Iki(n) return n < 10 and ("0" .. n) or tostring(n) end

----------------------------------------------------------------------------------------
-- Portre (oyuncu modeli, daire maskeli)
----------------------------------------------------------------------------------------
local PORTRE = {}

function PORTRE:Init()
     self:SetMouseInputEnabled(false)
     self:SetKeyboardInputEnabled(false)
     self:SetFOV(36)
     self:SetAmbientLight(Color(94, 108, 98))
     self:SetDirectionalLight(BOX_FRONT, Color(222, 205, 161))
     self:SetDirectionalLight(BOX_RIGHT, Color(91, 126, 110))
     self:Esitle(true)
end

function PORTRE:Esitle(zorla)
     local ply = LocalPlayer()
     if (!IsValid(ply)) then return end
     local imza = ply:GetModel() .. ply:GetSkin()
     for _, bg in ipairs(ply:GetBodyGroups() or {}) do imza = imza .. ply:GetBodygroup(bg.id) end
     if (!zorla and imza == self.imza) then return end
     self.imza = imza

     if (!IsValid(self.Entity) or self.Entity:GetModel() != ply:GetModel()) then
          self:SetModel(ply:GetModel())
          self.kameraTamam = false
          local ent = self.Entity
          if (IsValid(ent)) then
               for _, ad in ipairs({"idle_all_01", "idle_all_02", "idle_subtle", "idle"}) do
                    local seq = ent:LookupSequence(ad)
                    if (seq and seq > 0) then ent:ResetSequence(seq) break end
               end
          end
     end

     local ent = self.Entity
     if (!IsValid(ent)) then return end
     ent:SetSkin(ply:GetSkin())
     for _, bg in ipairs(ply:GetBodyGroups() or {}) do ent:SetBodygroup(bg.id, ply:GetBodygroup(bg.id)) end
     ent.GetPlayerColor = function() return IsValid(LocalPlayer()) and LocalPlayer():GetPlayerColor() or Vector(1, 1, 1) end

     -- kemik konumu ilk çizimden sonra kesinleşir; o zamana kadar sınırlardan tahmin
     local mins, maxs = ent:GetRenderBounds()
     self:Kamera(Vector(0, 0, mins.z + (maxs.z - mins.z) * 0.86))
end

function PORTRE:Kamera(bas)
     local bak = bas - Vector(0, 0, 9)
     self:SetLookAt(bak)
     self:SetCamPos(bak + Vector(53, 6, 2))
end

function PORTRE:LayoutEntity(ent)
     ent:SetAngles(Angle(0, 0, 0))
     self:RunAnimation()

     if (!self.kameraTamam) then
          local kemik = ent:LookupBone("ValveBiped.Bip01_Head1")
          local pos = kemik and ent:GetBonePosition(kemik)
          if (pos and pos != ent:GetPos()) then
               self:Kamera(pos - ent:GetPos())
               self.kameraTamam = true
          end
     end
end

function PORTRE:PostDrawModel(ent)
     if (SH_ACC and SH_ACC.DrawAccessories) then
          SH_ACC:DrawAccessories(ent, LocalPlayer())
     end
end

function PORTRE:Think()
     if ((self.sonEsitle or 0) < RealTime()) then
          self.sonEsitle = RealTime() + 0.5
          self:Esitle()
     end
end

local maskePoly = {}
function PORTRE:Paint(w, h)
     local r = w / 2
     for i = 1, 80 do
          local a = (i - 1) / 80 * 2 * math.pi
          maskePoly[i] = maskePoly[i] or {}
          maskePoly[i].x, maskePoly[i].y = r + math.cos(a) * r, r + math.sin(a) * r
     end

     render.ClearStencil()
     render.SetStencilEnable(true)
     render.SetStencilWriteMask(255)
     render.SetStencilTestMask(255)
     render.SetStencilReferenceValue(1)
     render.SetStencilCompareFunction(STENCIL_ALWAYS)
     render.SetStencilPassOperation(STENCIL_REPLACE)
     render.SetStencilFailOperation(STENCIL_KEEP)
     render.SetStencilZFailOperation(STENCIL_KEEP)

     render.OverrideColorWriteEnable(true, false)
     draw.NoTexture()
     surface.SetDrawColor(255, 255, 255)
     surface.DrawPoly(maskePoly)
     render.OverrideColorWriteEnable(false, false)

     render.SetStencilCompareFunction(STENCIL_EQUAL)
     render.SetStencilPassOperation(STENCIL_KEEP)

     -- .portrait: #16211c zemin
     surface.SetDrawColor(22, 33, 28)
     surface.DrawRect(0, 0, w, h)

     baseclass.Get("DModelPanel").Paint(self, w, h)

     -- .portrait:after: transparent 47% -> #0c18117d 73% -> #0c1811 99%
     surface.SetMaterial(gradD)
     surface.SetDrawColor(12, 24, 17, 255)
     surface.DrawTexturedRect(0, h * 0.47, w, h * 0.53)
     draw.NoTexture()

     render.SetStencilEnable(false)
end

vgui.Register("SardonGelisim.Portre", PORTRE, "DModelPanel")

----------------------------------------------------------------------------------------
-- Ekran
----------------------------------------------------------------------------------------
local PANEL = {}

function PANEL:Init()
     self.mod = "ana"
     self.kat = G.SonSecim or 3
     self.dugum = 1
     self.gorunumAn = RealTime()
     self.ayrintiAn = RealTime()
     self.acilisAn = RealTime()
     self.uzerinde = {}
     self.tiklama = {}
     self.tuslar = {}
     self.ogrenAn, self.sonOgrenilen = -10, nil
     self.puanAn = -10

     self.portre = self:Add("SardonGelisim.Portre")
     self:SetMouseInputEnabled(true)
end

function PANEL:PerformLayout(w, h)
     self.s = math.min(w / TW, h / TH)
     self.ox = math.floor((w - TW * self.s) / 2)
     self.oy = math.floor((h - TH * self.s) / 2)
     fontlar, sarCache = fontlar, {}

     local s = self.s
     -- .portrait: #character (584,329,272) içinde 6 px içeride -> r = 130
     self.portre:SetPos(self.ox + (MERKEZ_X - 130) * s, self.oy + (MERKEZ_Y - 130) * s)
     self.portre:SetSize(260 * s, 260 * s)
end

function PANEL:Olcekle()
     S, OX, OY = self.s or 1, self.ox or 0, self.oy or 0
end

-- Menüde seçili sekme bu mu
function PANEL:Etkin()
     local menu = ix.gui.menu
     if (!IsValid(menu) or !menu.GetActiveSubpanel) then return false end
     return menu:GetActiveSubpanel() == self:GetParent()
end

-- Ekran bu sekmede görünüyor mu (tuş dinleme ve Esc için)
function PANEL:Aktif()
     return self:IsVisible() and self:Etkin() and !ix.gui.menu.bClosing
end

function PANEL:TasarimFare()
     local mx, my = self:CursorPos()
     return (mx - (self.ox or 0)) / (self.s or 1), (my - (self.oy or 0)) / (self.s or 1)
end

local function Icinde(r, x, y)
     return r and x >= r[1] and y >= r[2] and x <= r[1] + r[3] and y <= r[2] + r[4]
end

-- Fare altındaki tıklanabilir öğe (bu karede kaydedilen alanlardan)
function PANEL:AlanBul(x, y)
     for i = #self.tiklama, 1, -1 do
          local a = self.tiklama[i]
          if (Icinde(a, x, y)) then return a end
     end
end

function PANEL:Alan(x, y, w, h, anahtar, islev, kapali)
     self.yeniTiklama[#self.yeniTiklama + 1] = {x, y, w, h, anahtar = anahtar, islev = islev, kapali = kapali}
end

-- 0..1 üzerine gelme geçişi (CSS transition .3s)
function PANEL:Uzerinde(anahtar)
     return self.uzerinde[anahtar] or 0
end

function PANEL:Ses()
     surface.PlaySound("buttons/lightswitch2.wav")
end

function PANEL:AyrintiYenile()
     self.ayrintiAn = RealTime()
end

function PANEL:AgacAc(i)
     local char = Karakter()
     local kat = G.Kategoriler[i]
     if (!kat) then return end
     self.kat = i
     G.SonSecim = i
     self.dugum = 1
     for j in ipairs(kat.beceriler) do
          if (char and G.Durum(char, kat, j) == "acilabilir") then self.dugum = j break end
     end
     self.sonOgrenilen = nil
     self.mod = "agac"
     self.gorunumAn = RealTime()
     self:AyrintiYenile()
     self:Ses()
end

function PANEL:Geri()
     if (self.mod == "ana") then return end
     self.mod = "ana"
     self.gorunumAn = RealTime()
     self:AyrintiYenile()
     self:Ses()
end

function PANEL:KategoriSec(i)
     if (self.kat == i) then return end
     self.kat = i
     G.SonSecim = i
     self:AyrintiYenile()
end

function PANEL:DugumSec(i)
     if (self.dugum == i) then return end
     self.dugum = i
     self:AyrintiYenile()
end

function PANEL:Ogren()
     local char = Karakter()
     local kat = G.Kategoriler[self.kat]
     if (!char or !kat or self.mod != "agac") then return end
     if (self.bekliyor and self.bekliyor > RealTime()) then return end

     local izin, sebep = G.OgrenebilirMi(char, kat.id, self.dugum)
     if (!izin) then self:Bildirim(sebep) return end

     self.bekliyor = RealTime() + 2
     self.bekleyen = {self.kat, self.dugum}
     net.Start("SardonGelisim.Ogren")
          net.WriteUInt(char:GetID(), 32)
          net.WriteUInt(self.kat, 4)
          net.WriteUInt(self.dugum, 4)
     net.SendToServer()
end

function PANEL:Sonuc(metin, basarili)
     local b = self.bekleyen
     self.bekliyor, self.bekleyen = nil, nil
     if (basarili and b) then
          self.sonOgrenilen = b[1] == self.kat and b[2] or nil
          self.ogrenAn = RealTime()
          self.puanAn = RealTime()
          self:Ses()
     end
     self:Bildirim(metin)
end

function PANEL:Bildirim(metin)
     if (!metin or metin == "") then return end
     self.bildirim, self.bildirimAn = metin, RealTime()
end

function PANEL:SakinDegistir()
     sakin = !sakin
     cookie.Set("sardon_gelisim_sakin", sakin and 1 or 0)
end

----------------------------------------------------------------------------------------
-- Girdi
----------------------------------------------------------------------------------------
local TUSLAR = {KEY_F, KEY_ENTER, KEY_PAD_ENTER, KEY_LEFT, KEY_RIGHT, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8}
local SAYI = {[KEY_1] = 1, [KEY_2] = 2, [KEY_3] = 3, [KEY_4] = 4, [KEY_5] = 5, [KEY_6] = 6, [KEY_7] = 7, [KEY_8] = 8}

function PANEL:TusBasildi(tus)
     if (self.mod == "zihin") then return end
     local n = #G.Kategoriler
     if (tus == KEY_F or tus == KEY_ENTER or tus == KEY_PAD_ENTER) then
          if (self.mod == "agac") then
               if (tus == KEY_F) then self:Ogren() end
          else
               self:AgacAc(self.kat)
          end
     elseif (SAYI[tus]) then
          self:AgacAc(SAYI[tus])
     elseif (tus == KEY_LEFT or tus == KEY_RIGHT) then
          local i = (self.kat - 1 + (tus == KEY_LEFT and -1 or 1)) % n + 1
          if (self.mod == "agac") then self:AgacAc(i) else self:KategoriSec(i) end
     end
end

function PANEL:Think()
     local dt = RealFrameTime()
     local aktif = self:Aktif()

     -- tuşlar: menü klavye odağını kendinde tuttuğu için basışlar burada yakalanır
     local odak = vgui.GetKeyboardFocus()
     local yaziyor = IsValid(odak) and odak:GetClassName() == "TextEntry"
     for _, tus in ipairs(TUSLAR) do
          local basili = input.IsKeyDown(tus)
          if (basili and !self.tuslar[tus] and aktif and !yaziyor) then self:TusBasildi(tus) end
          self.tuslar[tus] = basili
     end

     if (self.bekliyor and self.bekliyor < RealTime()) then
          self.bekliyor, self.bekleyen = nil, nil
     end

     -- üzerine gelme
     local x, y = self:TasarimFare()
     local alan = self:IsHovered() and self:AlanBul(x, y) or nil
     self.fareAlan = alan
     local hedef = alan and alan.anahtar
     for anahtar, v in pairs(self.uzerinde) do
          local h = anahtar == hedef and 1 or 0
          v = math.Approach(v, h, dt / 0.3)
          self.uzerinde[anahtar] = v > 0 and v or nil
     end
     if (hedef and !self.uzerinde[hedef]) then self.uzerinde[hedef] = math.min(1, dt / 0.3) end
     self:SetCursor(alan and !alan.kapali and "hand" or "arrow")

     -- HTML: genel ekranda üzerine gelinen yetkinlik seçilir
     if (self.mod == "ana" and alan and alan.kat) then self:KategoriSec(alan.kat) end

     -- portre yalnız genel ekranda
     local g = Kolay((RealTime() - self.gorunumAn) / 0.8)
     self.portre:SetVisible(self.mod == "ana" and Karakter() != nil)
     self.portre:SetAlpha(255 * (sakin and 1 or g))
end

function PANEL:OnMousePressed(kod)
     local x, y = self:TasarimFare()
     if (kod == MOUSE_RIGHT) then
          self:Geri()
          return
     end
     if (kod != MOUSE_LEFT) then return end
     local alan = self:AlanBul(x, y)
     if (alan and alan.islev and !alan.kapali) then alan.islev() end
end

-- Esc: ağaçtayken menüyü kapatmak yerine genel ekrana döner
hook.Add("OnPauseMenuShow", "SardonGelisim.Geri", function()
     local ekran = SardonGelisim.Ekran
     if (IsValid(ekran) and ekran.mod != "ana" and ekran:Aktif()) then
          ekran:Geri()
          return false
     end
end)

net.Receive("SardonGelisim.Bildirim", function()
     local metin, basarili = net.ReadString(), net.ReadBool()
     local ekran = SardonGelisim.Ekran
     if (IsValid(ekran)) then ekran:Sonuc(metin, basarili) end
end)

----------------------------------------------------------------------------------------
-- Arka plan, gök haritası, bağlantılar (runtime.js paint())
----------------------------------------------------------------------------------------
-- Tılsımlar ekranı gibi yalnızca sekme alanında kalır; kenarları menü zeminine yumuşakça karışır.
-- Görsel alanı "cover" ile doldurur; kenar bantları ince hücrelerle saydamlaşır.
local KENAR, KENAR_ADIM = 56, 10

local function Yumusak(f)
     f = math.Clamp(f, 0, 1)
     return f * f * (3 - 2 * f)
end

local function KenarSinirlari(uz, bant)
     local s = {0}
     for i = 1, KENAR_ADIM do s[#s + 1] = bant * i / KENAR_ADIM end
     for i = KENAR_ADIM - 1, 0, -1 do s[#s + 1] = uz - bant * i / KENAR_ADIM end
     return s
end

function PANEL:ArkaPlan(w, h)
     local arka = G.Doku("background")
     if (!arka) then return end

     local iw, ih = G.DokuOlcu("background")
     local k = math.max(w / iw, h / ih)
     local dw, dh = iw * k, ih * k
     local bx, by = (w - dw) / 2, (h - dh) / 2
     local bant = math.min(KENAR * S, w / 4, h / 4)

     if (self.kenarW != w or self.kenarH != h) then
          self.kenarW, self.kenarH = w, h
          self.sutunlar, self.satirlar = KenarSinirlari(w, bant), KenarSinirlari(h, bant)
     end

     surface.SetMaterial(arka)
     local sut, sat = self.sutunlar, self.satirlar
     for j = 1, #sat - 1 do
          local y0, y1 = sat[j], sat[j + 1]
          local fy = Yumusak(math.min((y0 + y1) / 2, h - (y0 + y1) / 2) / bant)
          for i = 1, #sut - 1 do
               local x0, x1 = sut[i], sut[i + 1]
               local fx = Yumusak(math.min((x0 + x1) / 2, w - (x0 + x1) / 2) / bant)
               surface.SetDrawColor(255, 255, 255, 255 * fx * fy)
               surface.DrawTexturedRectUV(x0, y0, x1 - x0, y1 - y0,
                    (x0 - bx) / dw, (y0 - by) / dh, (x1 - bx) / dw, (y1 - by) / dh)
          end
     end
     draw.NoTexture()
end

-- Çok hafif bulanıklık (yalnızca bu panelin alanında)
local matBulanik = Material("pp/blurscreen")
function PANEL:Bulanik(w, h)
     local sx, sy = self:LocalToScreen(0, 0)
     surface.SetMaterial(matBulanik)
     surface.SetDrawColor(255, 255, 255, 255)
     for i = 1, 2 do
          matBulanik:SetFloat("$blur", i * 0.6)
          matBulanik:Recompute()
          render.UpdateScreenEffectTexture()
          surface.DrawTexturedRect(-sx, -sy, ScrW(), ScrH())
     end
     draw.NoTexture()
end

function PANEL:Paint(w, h)
     if (!self.s) then return end
     self:Olcekle()
     self.yeniTiklama = {}

     -- .backdrop (+ görsele işlenmiş .shade) ve arka planla öğeler arasında hafif bulanıklık
     self:ArkaPlan(w, h)
     self:Bulanik(w, h)

     local char = Karakter()
     if (!char) then return end

     local t = Zaman()
     self:GokSusleri(t)

     if (self.mod == "zihin") then
          self:GokHaritasi(MERKEZ_X, 480, true, t)
     elseif (self.mod == "ana") then
          self:GokHaritasi(MERKEZ_X, MERKEZ_Y, false, t)
          for i, kat in ipairs(G.Kategoriler) do
               local p = KAT_KONUM[i]
               if (p) then
                    local n = G.KategoriToplam(char, kat)
                    self:Baglanti(MERKEZ_X, MERKEZ_Y, p[1], p[2], 148, 50, n > 0, t, (i - 1) * 0.9, i == self.kat)
               end
          end
     else
          self:GokHaritasi(680, 500, true, t)
          local kat = G.Kategoriler[self.kat]
          if (kat) then
               self:EtiketAlanlari(kat)
               local dz = Duzen(kat)
               for i, b in ipairs(kat.beceriler) do
                    for _, u in ipairs(b.gerek) do
                         local a, c = dz.konum[u], dz.konum[i]
                         if (a and c) then
                              local etkin, faz, sec = G.Kademe(char, kat.id, i) > 0, (i - 1) * 0.9, i == self.dugum
                              local yol = dz.yol[u .. ">" .. i]
                              if (yol) then
                                   local px, py, ra = a[1], a[2], 38
                                   for _, n in ipairs(yol) do
                                        self:Baglanti(px, py, n[1], n[2], ra, 0, etkin, t, faz, sec, true)
                                        px, py, ra = n[1], n[2], 0
                                   end
                                   self:Baglanti(px, py, c[1], c[2], 0, 38, etkin, t, faz, sec, true)
                              else
                                   self:Baglanti(a[1], a[2], c[1], c[2], 38, 38, etkin, t, faz, sec, true)
                              end
                         end
                    end
               end

               -- geliştirme halkası (1.2 sn)
               local gecen = RealTime() - self.ogrenAn
               if (!sakin and self.sonOgrenilen and gecen < 1.2) then
                    local f = gecen / 1.2
                    local p = Duzen(kat).konum[self.sonOgrenilen]
                    surface.SetDrawColor(218, 218, 178, 255 * (1 - f) * 0.45)
                    Cember(p[1], p[2], 35 + f * 31)
               end
          end
     end

     -- uçuşan altın toz
     if (!sakin) then
          for i = 0, 15 do
               local x = 300 + (i * 193.71) % 820 + math.sin(t * 0.09 + i) * 8
               local y = 185 + (i * 87.13 - t * (2 + i % 3)) % 600
               surface.SetDrawColor(203, 177, 112, 255 * (0.1 + 0.12 * (1 + math.sin(t * 0.5 + i)) / 2))
               Disk(x, y, 0.65 + (i % 3) * 0.2)
          end
     end
end

-- skyOrnaments(): yıldızlar, hilal, gezegen
function PANEL:GokSusleri(t)
     for _, p in ipairs({{226, 235, 8, 0.46}, {1138, 190, 5, 0.4}, {1120, 744, 8, 0.48}, {268, 757, 4, 0.45}, {1160, 369, 4, 0.32}, {185, 667, 6, 0.38}}) do
          Yildiz(p[1], p[2], p[3], p[4], t)
     end
     surface.SetDrawColor(193, 162, 98, 255 * 0.37)
     Yay(292, 595, 11, 0.3, math.pi * 1.7)
     Yay(298, 592, 10, 0.7, math.pi * 1.6)
     Cember(211, 384, 12)
     Cizgi(203, 375, 218, 393)
     Cizgi(199, 384, 223, 384)
end

-- celestial(): gök haritası halkaları
function PANEL:GokHaritasi(cx, cy, agac, t)
     local kazanc = (agac and 0.28 or 1) * 0.8 -- 0.7 px çizgiler 1 px çizildiği için hafifletildi
     local don = sakin and 0 or t * 0.014

     for _, h in ipairs({{188, 0.22}, {196, 0.11}, {250, 0.17}, {309, 0.29}, {316, 0.44}, {349, 0.13}}) do
          surface.SetDrawColor(182, 147, 80, 255 * h[2] * kazanc)
          Cember(cx, cy, h[1])
     end

     surface.SetDrawColor(192, 157, 88, 255 * 0.46 * kazanc)
     for i = 0, 95 do
          local a = i * math.pi / 48 + don
          local uz = (i % 8 == 0) and 10 or 3
          local c, s = math.cos(a), math.sin(a)
          Cizgi(cx + c * 316, cy + s * 316, cx + c * (316 + uz), cy + s * (316 + uz))
     end

     for i = 0, 71 do
          local a = i * math.pi / 36 - don * 0.3
          local buyuk = i % 6 == 0
          surface.SetDrawColor(206, 174, 104, 255 * (buyuk and 0.6 or 0.25) * kazanc)
          Disk(cx + math.cos(a) * 239, cy + math.sin(a) * 239, buyuk and 1.4 or 0.6)
     end

     surface.SetDrawColor(205, 175, 109, 255 * 0.32 * kazanc)
     for i = 0, 3 do
          local a = i * math.pi / 2 + don
          Yay(cx, cy, 349, a + 0.15, a + 0.52)
     end

     if (!agac) then
          surface.SetDrawColor(191, 158, 87, 255 * 0.33 * 0.8)
          Cizgi(cx - 360, cy, cx - 327, cy)
          Cizgi(cx + 327, cy, cx + 366, cy)
          Yildiz(cx - 363, cy, 7, 0.55, t)
          Yildiz(cx + 363, cy, 7, 0.55, t)
          Yildiz(cx, cy - 314, 7, 0.5, t)
          surface.SetDrawColor(191, 158, 87, 255 * 0.33 * 0.8)
          Cember(cx, cy, 154)
     end
end

-- Ağaçta isim ve kademe yazılarının altından bağlantı geçmez (canvas clearRect karşılığı)
function PANEL:EtiketAlanlari(kat)
     local alanlar = {}
     local dz = Duzen(kat)
     for i, b in ipairs(kat.beceriler) do
          local p = dz.konum[i]
          if (p) then
               local w = Olc(b.ad, 13, 500) + 16
               alanlar[#alanlar + 1] = {p[1] - w / 2, p[2] + dz.ad - 12, p[1] + w / 2, p[2] + dz.ad + 9}
               alanlar[#alanlar + 1] = {p[1] - 22, p[2] + dz.kademe - 7, p[1] + 22, p[2] + dz.kademe + 7}
          end
     end
     self.etiketAlan = alanlar
end

function PANEL:EtiketIcinde(x, y)
     for _, r in ipairs(self.etiketAlan or {}) do
          if (x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4]) then return true end
     end
     return false
end

-- wave(): iki ucu sabit, dik yönde 1.6 px sinüs; etkin bağlantıda tek ışık noktası
function PANEL:Baglanti(ax, ay, bx, by, ra, rb, etkin, t, faz, secili, agac)
     local dx, dy = bx - ax, by - ay
     local l = math.sqrt(dx * dx + dy * dy)
     if (l <= ra + rb) then return end
     local x1, y1 = ax + dx / l * ra, ay + dy / l * ra
     local x2, y2 = bx - dx / l * rb, by - dy / l * rb
     dx, dy = x2 - x1, y2 - y1
     local uz = math.sqrt(dx * dx + dy * dy)
     local nx, ny = -dy / uz, dx / uz
     local adim = math.max(12, math.ceil(uz / 9))
     local dalga = etkin and !sakin

     local function Nokta(f)
          local o = dalga and math.sin(math.pi * f) * math.sin(f * math.pi * 3 - t * 1.25 + faz) * 1.6 or 0
          return x1 + dx * f + nx * o, y1 + dy * f + ny * o
     end

     local c, a
     if (etkin) then
          c, a = secili and {215, 199, 151} or {182, 172, 139}, secili and 0.85 or 0.43
     else
          c, a = {149, 145, 108}, 0.24
     end

     local px, py = Nokta(0)
     for i = 1, adim do
          local qx, qy = Nokta(i / adim)
          if (!agac or !self:EtiketIcinde((px + qx) / 2, (py + qy) / 2)) then
               if (etkin) then
                    -- shadowBlur karşılığı: iki yanda soluk çizgi
                    surface.SetDrawColor(199, 183, 131, secili and 40 or 16)
                    Cizgi(px + nx, py + ny, qx + nx, qy + ny)
                    Cizgi(px - nx, py - ny, qx - nx, qy - ny)
               end
               surface.SetDrawColor(c[1], c[2], c[3], 255 * a)
               Cizgi(px, py, qx, qy)
          end
          px, py = qx, qy
     end

     if (dalga) then
          local f = (t * 0.085 + faz * 0.12) % 1
          local x, y = Nokta(f)
          if (!agac or !self:EtiketIcinde(x, y)) then
               local sol = math.sin(f * math.pi)
               surface.SetDrawColor(226, 212, 162, 255 * 0.12 * sol)
               Disk(x, y, 4)
               surface.SetDrawColor(235, 226, 189, 255 * 0.65 * sol)
               Disk(x, y, 1.3)
          end
     end
end

----------------------------------------------------------------------------------------
-- Ön katman: düğmeler, portre çerçevesi, bilgi paneli, başlık, alt çizgi
----------------------------------------------------------------------------------------
function PANEL:PaintOver(w, h)
     if (!self.s) then return end
     self:Olcekle()
     self.yeniTiklama = self.yeniTiklama or {}

     local char = Karakter()
     if (char) then
          if (self.mod == "zihin") then
               self:ZihinCiz(char)
          else
               if (self.mod == "ana") then
                    self:AnaCiz(char)
               else
                    self:AgacCiz(char)
               end
               self:DalUyari(char)
               self:ZihinDugme()
          end
     end

     self:BaslikCiz(char)
     self:AyakCiz()

     -- #notice
     if (self.bildirim) then
          local gecen = RealTime() - self.bildirimAn
          local a = math.Clamp(gecen / 0.4, 0, 1) * math.Clamp((2.6 - gecen) / 0.4, 0, 1)
          if (gecen > 2.6) then self.bildirim = nil else Yazi(self.bildirim, 11, 400, 800, 122, R.bildirim, 1, 0.5, a) end
     end

     self.tiklama = self.yeniTiklama
     self.yeniTiklama = nil
end

-- Giriş geçişi (node-enter): saydamlık + aşağıdan yukarı kayma
function PANEL:Giris(sira, adimMs, sure, kayma)
     if (sakin) then return 1, 0 end
     local f = Kolay((RealTime() - self.gorunumAn - sira * adimMs / 1000) / sure)
     return f, (1 - f) * (kayma or 9)
end

function PANEL:BaslikCiz(char)
     -- .brand-crest: (57,25) 96x105, object-fit contain
     local arma = G.Doku("crest")
     if (arma) then
          local iw, ih = G.DokuOlcu("crest")
          local k = math.min(96 / iw, 105 / ih)
          local dw, dh = iw * k, ih * k
          local x, y = 57 + (96 - dw) / 2, 25 + (105 - dh) / 2
          surface.SetMaterial(arma)
          surface.SetDrawColor(0, 0, 0, 110)
          surface.DrawTexturedRect(X(x), Y(y + 2), dw * S, dh * S)
          surface.SetDrawColor(255, 255, 255)
          surface.DrawTexturedRect(X(x), Y(y), dw * S, dh * S)
          draw.NoTexture()
     end

     -- .eyebrow: SHINE / PERSONAJE
     local ex = 165
     Yazi("SHINE", 10, 500, ex, 54, R.ust, 0, 3)
     ex = ex + Olc("SHINE", 10, 500, 3) + 3 + 15
     Yazi("/", 14, 400, ex, 54, R.ust, 0, 0, 0.4)
     ex = ex + Olc("/", 14, 400) + 15
     Yazi("PERSONAJE", 10, 500, ex, 54, R.ust, 0, 3)

     -- h1
     local kat = G.Kategoriler[self.kat]
     local baslik = self.mod == "zihin" and "Artes Mentales" or (self.mod == "agac" and kat and kat.ad or "Habilidades")
     Yazi(baslik, 34, 500, 165, 100, R.soluk, 0, 1.5)

     -- .header-line (72..1528, y 147) + uç baklavaları
     local c = R.baslikCizgi
     local ortaX = 72 + 1456 * 0.64
     YatayGecis(72, 147, ortaX - 72, 1, c, 102, c, 25)
     YatayGecis(ortaX, 147, 1528 - ortaX, 1, c, 25, c, 85)
     Ton(R.cizgiBaklava)
     Baklava(72, 147.5, 3.5)
     Baklava(1528, 147.5, 3.5)

     -- .points: sağ üst, 225x75
     local px, py, pw, ph = 1303, 47, 225, 75
     surface.SetDrawColor(24, 32, 20, 119)
     surface.SetMaterial(gradR)
     surface.DrawTexturedRect(X(px), Y(py), pw / 2 * S, ph * S)
     surface.SetMaterial(gradL)
     surface.DrawTexturedRect(X(px + pw / 2), Y(py), pw / 2 * S, ph * S)
     draw.NoTexture()
     Ton(R.puanCizgi, 0.47) Dikdortgen(px, py, pw, 1)
     Ton(R.puanCizgi, 0.33) Dikdortgen(px, py + ph - 1, pw, 1)
     Ton(R.puanCizgi)
     BaklavaCizgi(px, 83.5, 3.5)
     BaklavaCizgi(px + pw, 83.5, 3.5)

     local parla = sakin and 0 or math.max(0, 1 - math.abs((RealTime() - self.puanAn) / 0.7 - 0.25) / 0.75)
     if (RealTime() - self.puanAn > 0.7) then parla = 0 end
     local gx = 1339
     Parilti(gx, 84, 46, R.puanGlif, 40 + 60 * parla)
     Ton(R.puanGlif)
     BaklavaCizgi(gx, 84, 10)
     BaklavaCizgi(gx, 84, 9)

     -- [11-09] ağaçta o dalın puanı (dal seviyesi + ek − açılan kademe), ana ekranda bütün dalların toplamı
     local agacKat = self.mod == "agac" and G.Kategoriler[self.kat]
     local puan = char and (agacKat and G.DalHak(char, agacKat.id) or G.Puan(char)) or 0
     local pc = R.soluk
     if (parla > 0) then pc = Color(math.min(255, pc.r + 40 * parla), math.min(255, pc.g + 40 * parla), math.min(255, pc.b + 50 * parla)) end
     local sx = gx + 11 + 17
     local puanYazi = tostring(puan)
     Yazi(puanYazi, 32, 500, sx, 84, pc, 0)
     local lx = sx + math.max(20, Olc(puanYazi, 32, 500)) + 17
     Yazi(agacKat and "RAMA" or "HABILIDAD", 9, 500, lx, 77, R.puanYazi, 0, 1.2)
     Yazi("PUNTOS", 9, 500, lx, 92, R.puanYazi, 0, 1.2)

     -- ağaçta dalın seviyesi ve unvanı
     if (char and agacKat) then
          local sv = G.DalSeviye(char, agacKat.id)
          local rol = G.EtkinRol(char, agacKat.id)
          Yazi("NV " .. sv .. "  ·  " .. Buyuk(G.Unvan(sv, rol)), 8, 500, px + pw / 2, 112, R.puanGlif, 1, 1.2)
     end
end

-- footer: not / tuşlar / hareket anahtarı
function PANEL:AyakCiz()
     Ton(R.puanCizgi, 0.27) Dikdortgen(72, 843, 1456, 1)
     local y = 871.5

     local kat = G.Kategoriler[self.kat]
     local not_ = self.mod == "zihin" and "DESARROLLO / ARTES MENTALES"
          or (self.mod == "agac" and kat and ("COMPETENCIAS / " .. Buyuk(kat.ad)) or "DESARROLLO")
     local notW = Olc(not_, 8, 400, 1.7)
     Yazi(not_, 8, 400, 72, y, R.ayakNot, 0, 1.7)

     local tuslar = {{"enter", "Elegir"}, {"F", self.mod == "agac" and "Mejorar" or "Ver"}, {"Esc", "Atrás"}}
     local function TusGenislik(t)
          return math.max(21, (t == "enter" and 12 or Olc(t, 9, 400)) + 8)
     end
     local tusW = 0
     for i, k in ipairs(tuslar) do
          tusW = tusW + TusGenislik(k[1]) + 10 + Olc(k[2], 10, 400) + (i > 1 and 30 or 0)
     end

     local hareket = sakin and "Modo tranquilo" or "Animaciones activas"
     local harW = 15 + 10 + 9 + Olc(hareket, 10, 400)
     local bosluk = (1456 - notW - tusW - harW) / 2

     local x = 72 + notW + bosluk
     for _, k in ipairs(tuslar) do
          local kw = TusGenislik(k[1])
          Ton(R.tusCizgi, 0.44)
          surface.DrawOutlinedRect(X(x), Y(y - 10.5), kw * S, 21 * S, 1)
          Ton(R.tusYazi)
          if (k[1] == "enter") then
               -- ↵
               local cx = x + kw / 2
               Cizgi(cx + 4, y - 4, cx + 4, y + 2)
               Cizgi(cx + 4, y + 2, cx - 4, y + 2)
               Cizgi(cx - 4, y + 2, cx - 1.5, y - 0.5)
               Cizgi(cx - 4, y + 2, cx - 1.5, y + 4.5)
          else
               Yazi(k[1], 9, 400, x + kw / 2, y, R.tusYazi, 1)
          end
          x = x + kw + 10
          Yazi(k[2], 10, 400, x, y, R.ayakYazi, 0)
          x = x + Olc(k[2], 10, 400) + 30
     end

     -- #motion
     local hx = 1528 - harW
     local u = self:Uzerinde("hareket")
     local hc = Color(Lerp(u, R.hareket.r, R.hareketUzerinde.r), Lerp(u, R.hareket.g, R.hareketUzerinde.g), Lerp(u, R.hareket.b, R.hareketUzerinde.b))
     surface.SetDrawColor(hc.r, hc.g, hc.b, 255)
     for i = 0, 7 do -- ◌
          local a = i / 8 * 2 * math.pi
          Disk(hx + 15 + 5 + math.cos(a) * 4, y + math.sin(a) * 4, 0.6)
     end
     Yazi(hareket, 10, 400, hx + 15 + 10 + 9, y, hc, 0)
     self:Alan(hx, y - 20, harW, 40, "hareket", function() self:SakinDegistir() end)
end

-- .action düğmesi
function PANEL:Dugme(x, y, w, h, etiket, acik, anahtar, islev, ok)
     local u = acik and self:Uzerinde(anahtar) or 0
     if (acik) then
          surface.SetDrawColor(169, 144, 78, Lerp(u, 0.06, 0.14) * 255)
          surface.SetMaterial(gradR)
          surface.DrawTexturedRect(X(x), Y(y), w / 2 * S, h * S)
          surface.SetMaterial(gradL)
          surface.DrawTexturedRect(X(x + w / 2), Y(y), w / 2 * S, h * S)
          draw.NoTexture()
          surface.SetDrawColor(169, 144, 78, Lerp(u, 0.035, 0.11) * 255)
          Dikdortgen(x, y, w, h)
          if (u > 0) then Parilti(x + w / 2, y + h / 2, w * 0.9, R.buton, 14 * u) end
     end

     local cr = acik and Color(Lerp(u, R.buton.r, R.butonUzerinde.r), Lerp(u, R.buton.g, R.butonUzerinde.g), Lerp(u, R.buton.b, R.butonUzerinde.b), Lerp(u, 138, 255))
          or Color(R.butonKapaliCizgi.r, R.butonKapaliCizgi.g, R.butonKapaliCizgi.b, 85)
     surface.SetDrawColor(cr)
     surface.DrawOutlinedRect(X(x), Y(y), w * S, h * S, 1)
     Ton(acik and R.altin or R.butonKapaliKose)
     Dikdortgen(x - 2, y - 2, 3, 3)
     Dikdortgen(x + w - 1, y - 2, 3, 3)

     local renk = acik and R.butonYazi or R.butonKapali
     local tw = Olc(etiket, 10, 600, 1.1)
     local toplam = tw + (ok and (12 + 14) or 0)
     local bx = x + (w - toplam) / 2
     Yazi(etiket, 10, 600, bx, y + h / 2, renk, 0, 1.1)
     if (ok) then
          surface.SetDrawColor(renk)
          SagOk(bx + tw + 12 + 13, y + h / 2, 13)
     end

     self:Alan(x, y, w, h, anahtar, islev, !acik)
end

-- .inspector çerçevesi: üst çizgi, sol dolu baklava, sağ boş baklava, soluk zemin
function PANEL:AyrintiCerceve(x, y, a)
     surface.SetDrawColor(16, 27, 18, 51 * a)
     surface.SetMaterial(gradU)
     surface.DrawTexturedRect(X(x), Y(y), 306 * S, 390 * S)
     draw.NoTexture()
     Ton(R.altin, 0.45 * a) Dikdortgen(x, y, 306, 1)
     Ton(R.altin, a) Baklava(x + 2.5, y + 0.5, 3.5)
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 136 * a)
     BaklavaCizgi(x + 306 - 6.5, y + 0.5, 6.4)
end

----------------------------------------------------------------------------------------
-- Sol uyarı: dal sınırı (2 ana dal tam + 1 yan dal yarıya kadar)
----------------------------------------------------------------------------------------
local DAL_X, DAL_Y, DAL_W = 72, 340, 222

local DAL_METIN = {
     "Cada rama se llena con su propia actividad: al preparar pociones avanza Pociones; al cosechar, Herbología. Cada nivel de rama abre 1 rango en esa rama.",
     "Las 2 primeras ramas en las que abras un rango son ramas principales y avanzan a velocidad plena hasta Maestro (nivel 16). La 3.ª es rama secundaria: al 60 % hasta el nivel 10.",
     "El trabajo en otras ramas no se pierde: al 25 %, hasta el nivel 3. Cada mañana se renueva la Inspiración; tras 1000 XP diarios empiezas a fatigarte."
}

-- sol kutu zemini (inspector dili); yükseklik h
local function SolKutu(x, y, w, h, baslik, ikon)
     surface.SetDrawColor(9, 17, 12, 150)
     Dikdortgen(x, y, w, h)
     surface.SetDrawColor(16, 27, 18, 90)
     surface.SetMaterial(gradU)
     surface.DrawTexturedRect(X(x), Y(y), w * S, h * S)
     draw.NoTexture()
     Ton(R.altin, 0.45) Dikdortgen(x, y, w, 1)
     Ton(R.altin, 0.18) Dikdortgen(x, y + h - 1, w, 1)
     Ton(R.altin) Baklava(x + 2.5, y + 0.5, 3.5)
     Ton(R.altin, 0.55) BaklavaCizgi(x + w - 4, y + 0.5, 3.5)

     local yy = y + 14
     if (ikon) then
          surface.SetMaterial(ikon)
          surface.SetDrawColor(250, 238, 212, 235)
          surface.DrawTexturedRect(X(x + 8), Y(yy), 32 * S, 32 * S)
          draw.NoTexture()
     else
          Ton(R.puanGlif) BaklavaCizgi(x + 24, yy + 16, 16)
          Ton(R.puanGlif, 0.35) BaklavaCizgi(x + 24, yy + 16, 13)
          Yazi("!", 20, 600, x + 24, yy + 16, R.puanGlif, 1)
     end
     Yazi(baslik, 10, 500, x + 52, yy + 16, R.ayrUst, 0, 2)
     return yy + 32 + 14
end

-- ince ilerleme çubuğu
local function Iz(x, y, w, f, kalin)
     kalin = kalin or 1
     surface.SetDrawColor(R.izBos) Dikdortgen(x, y, w, kalin)
     local dolu = w * math.Clamp(f or 0, 0, 1)
     if (dolu > 0) then YatayGecis(x, y, dolu, kalin, R.izSol, 255, R.izSag, 255) end
end

local function Noktali(n)
     n = math.floor(tonumber(n) or 0)
     local s_ = tostring(n)
     local out = s_:reverse():gsub("(%d%d%d)", "%1."):reverse()
     return (out:gsub("^%.", ""))
end

-- dalın Usta'ya (rol tavanına) göre toplam ilerlemesi
local function GenelOran(char, katId)
     local tavan = G.DalTavan(char, katId)
     local hedef = G.SeviyeToplam(tavan)
     if (hedef <= 0) then return 0 end
     return math.Clamp(G.DalXP(char, katId) / hedef, 0, 1)
end

function PANEL:DalUyari(char)
     if (self.mod == "agac") then return self:DalDurum(char, G.Kategoriler[self.kat]) end
     local a = sakin and 1 or Kolay((RealTime() - self.gorunumAn) / 0.6)
     local x, y, w = DAL_X - (1 - a) * 10, DAL_Y, DAL_W
     surface.SetAlphaMultiplier(a)

     local paragraflar, satirSay = {}, 0
     for i, m in ipairs(DAL_METIN) do
          paragraflar[i] = Sar(m, 11, 400, w - 16)
          satirSay = satirSay + #paragraflar[i]
     end
     local alt = "Velocidad: principal ×1 · secundaria ×0,6 · otras ×0,25"
     local altSatir = Sar(alt, 11, 500, w - 16)
     local satirH, paraAra, slotH = 20 * YAZI_OLCEK, 7, 34
     local slotSay = G.AnaDalSayisi + 1
     local h = 14 + 32 + 14 + satirSay * satirH + (#paragraflar - 1) * paraAra + 14 + slotSay * slotH + 10 + #altSatir * 19 * YAZI_OLCEK + 14

     local yy = SolKutu(x, y, w, h, "RAMAS")

     for p, satirlar in ipairs(paragraflar) do
          for i, sat in ipairs(satirlar) do
               Yazi(sat, 11, 400, x + 8, yy + (i - 0.5) * satirH, R.ayrAciklama, 0)
          end
          yy = yy + #satirlar * satirH + (p < #paragraflar and paraAra or 0)
     end
     yy = yy + 8
     Ton(R.altin, 0.2) Dikdortgen(x + 8, yy, w - 16, 1)
     yy = yy + 6

     -- seçilen dallar: seviye ve Usta'ya (yan dalda Sv 10'a) ilerleme
     local d = G.Dallar(char)
     local slotlar = {}
     for i = 1, G.AnaDalSayisi do slotlar[i] = {"RAMA PRINCIPAL", d.a[i]} end
     slotlar[#slotlar + 1] = {"RAMA SECUNDARIA", d.y}
     for _, sl in ipairs(slotlar) do
          local cy = yy + slotH / 2
          local kat = sl[2] and G.KategoriBul(sl[2])
          Yazi(sl[1], 8, 500, x + 8, cy - 7, R.onKosul, 0, 1.4)
          if (kat) then
               local sv = G.DalSeviye(char, kat.id)
               local tavan = G.DalTavan(char, kat.id)
               local tamam = sv >= tavan
               Yazi(kat.ad, 11, 500, x + 8, cy + 7, tamam and R.onKosulTamam or R.soluk, 0)
               Yazi("Nv " .. sv .. " / " .. tavan, 9, 400, x + w - 8, cy + 7, tamam and R.onKosulTamam or R.ayrBaslikDeger, 2, 1)
               Iz(x + 8, cy + 15, w - 16, GenelOran(char, kat.id))
          else
               Yazi("Sin elegir", 11, 400, x + 8, cy + 7, R.becKilitli, 0, 0, 0.8)
          end
          yy = yy + slotH
     end

     yy = yy + 10
     for i, sat in ipairs(altSatir) do
          Yazi(sat, 11, 500, x + 8, yy + (i - 0.5) * 19 * YAZI_OLCEK, R.ayrBaslikDeger, 0, 0.3)
     end
     surface.SetAlphaMultiplier(1)
end

-- Ağaçta sol kutu: seçili dalın seviyesi, XP'si, İlham, bugünkü yorgunluk, kaynaklar
function PANEL:DalDurum(char, kat)
     if (!kat) then return end
     local a = sakin and 1 or Kolay((RealTime() - self.gorunumAn) / 0.6)
     local x, y, w = DAL_X - (1 - a) * 10, DAL_Y - 40, DAL_W
     surface.SetAlphaMultiplier(a)

     local rol = G.EtkinRol(char, kat.id)
     local rb = G.Roller[rol] or G.Roller.rolsuz
     local atanmis = G.DalRolu(char, kat.id)
     local sv, ic, gerek = G.DalSeviye(char, kat.id)
     local kaynak = G.DalKaynaklari and G.DalKaynaklari[kat.id] or {}
     local il = G.IlhamKalan(char, kat.id)
     local bugun = G.BugunHam(char, kat.id)
     local yc, yEsik = G.YorgunlukDurum(bugun)

     local rolYazi
     if (atanmis) then
          rolYazi = (atanmis == "ana" and "RAMA PRINCIPAL · VELOCIDAD PLENA" or "RAMA SECUNDARIA · 60 % · HASTA NV 10")
     elseif (rol == "rolsuz") then
          rolYazi = "OTRA RAMA · 25 % · HASTA NV 3"
     else
          rolYazi = "CON EL PRIMER RANGO SERÁ TU RAMA " .. (rol == "ana" and "PRINCIPAL" or "SECUNDARIA")
     end

     local kaySat = Sar("Principal: " .. (kaynak.yuksek or "-"), 10, 400, w - 16)
     local kaySat2 = Sar("Auxiliar: " .. (kaynak.dusuk or "-"), 10, 400, w - 16)
     local satirH = 18 * YAZI_OLCEK
     local h = 14 + 32 + 14 + 40 + 16 + 22 + 18 + 26 + 26 + 10 + (#kaySat + #kaySat2) * satirH + 14
     local yy = SolKutu(x, y, w, h, "ESTADO DE RAMA", G.Doku(kat.ikon))

     -- seviye
     Yazi("Nv " .. sv, 26, 500, x + 8, yy + 14, R.soluk, 0, 0.5)
     local svW = Olc("Nv " .. sv, 26, 500, 0.5)
     Yazi(Buyuk(G.Unvan(sv, rol)), 10, 500, x + 8 + svW + 10, yy + 9, R.puanGlif, 0, 1.6)
     Yazi("/ " .. rb.tavan, 10, 400, x + 8 + svW + 10, yy + 23, R.ayrSira, 0, 1)
     yy = yy + 40

     -- seviye içi XP
     if (gerek > 0) then
          Iz(x + 8, yy, w - 16, ic / gerek, 2)
          Yazi(Noktali(ic) .. " / " .. Noktali(gerek) .. " XP", 9, 400, x + 8, yy + 13, R.ayrBaslikDeger, 0, 0.8)
          local is = G.KalanIsYazi and G.KalanIsYazi(char, kat.id)
          if (is) then Yazi(is, 9, 400, x + w - 8, yy + 13, R.puanGlif, 2, 0.8) end
     else
          Iz(x + 8, yy, w - 16, 1, 2)
          Yazi(sv >= G.SvUst and "MAESTRÍA COMPLETA" or "TOPE DE ROL", 9, 500, x + 8, yy + 13, R.onKosulTamam, 0, 1.2)
     end
     yy = yy + 16 + 22

     Yazi(rolYazi, 8, 500, x + 8, yy, atanmis and R.onKosulTamam or R.ayrBaslikDeger, 0, 1.2)
     yy = yy + 18

     -- İlham ve yorgunluk
     Yazi("INSPIRACIÓN", 8, 500, x + 8, yy, R.onKosul, 0, 1.4)
     if (rol == "rolsuz") then
          Yazi("ninguna (otra rama)", 9, 400, x + w - 8, yy, R.becKilitli, 2)
     else
          Yazi(Noktali(il) .. " / " .. Noktali(G.Ilham.ust) .. " · ×2", 9, 400, x + w - 8, yy, il > 0 and R.puanGlif or R.ayrSira, 2, 0.6)
     end
     yy = yy + 26
     Yazi("HOY", 8, 500, x + 8, yy, R.onKosul, 0, 1.4)
     local yorgunYazi = Noktali(bugun) .. " XP · " .. (yc >= 1 and "velocidad plena" or ("×" .. string.gsub(tostring(yc), "%.", ",")))
     Yazi(yorgunYazi, 9, 400, x + w - 8, yy, yc >= 1 and R.ayrBaslikDeger or R.butonKapali, 2, 0.6)
     yy = yy + 26

     Ton(R.altin, 0.2) Dikdortgen(x + 8, yy - 6, w - 16, 1)
     yy = yy + 4
     for i, m in ipairs(kaySat) do Yazi(m, 10, 400, x + 8, yy + (i - 0.5) * satirH, R.ayrAciklama, 0) end
     yy = yy + #kaySat * satirH
     for i, m in ipairs(kaySat2) do Yazi(m, 10, 400, x + 8, yy + (i - 0.5) * satirH, R.ayrSira, 0) end
     surface.SetAlphaMultiplier(1)
end

----------------------------------------------------------------------------------------
-- Genel ekran
----------------------------------------------------------------------------------------
function PANEL:AnaCiz(char)
     local t = Zaman()

     -- #character çerçevesi (portre çocuk panelde çizildi)
     local g = sakin and 1 or Kolay((RealTime() - self.gorunumAn) / 0.8)
     surface.SetAlphaMultiplier(g)
     surface.SetDrawColor(172, 138, 70, 22)
     Cember(MERKEZ_X, MERKEZ_Y, 137) Cember(MERKEZ_X, MERKEZ_Y, 138)
     Ton(R.muhur, 0.49) Cember(MERKEZ_X, MERKEZ_Y, 136)
     Ton(R.muhur, 0.25) Cember(MERKEZ_X, MERKEZ_Y, 145)
     Ton(R.altin) Baklava(MERKEZ_X, MERKEZ_Y - 145, 3.5)
     Ton(R.altin, 0.6) Baklava(MERKEZ_X, MERKEZ_Y + 145, 3.5)

     -- .identity
     Ton(R.kucukYildiz) MiniYildiz(MERKEZ_X, 528, 5)
     local ad = char:GetName()
     Yazi(ad, 23, 500, MERKEZ_X, 556.5, Color(5, 11, 17), 1, 0.2, 0.55)
     Yazi(ad, 23, 500, MERKEZ_X, 555, R.soluk, 1, 0.2)

     local lvl = G.Seviye(char)
     local yil = math.floor(lvl / 5) + 1
     local sol = yil >= 9 and "GRADUADO" or (yil .. ". CURSO")
     local sag = "NIVEL " .. lvl
     local w1, w2, wn = Olc(sol, 9, 400, 1.4), Olc(sag, 9, 400, 1.4), Olc("·", 9, 400)
     local bx = MERKEZ_X - (w1 + 8 + wn + 8 + w2) / 2
     Yazi(sol, 9, 400, bx, 585, R.kimlikAlt, 0, 1.4)
     Yazi("·", 9, 400, bx + w1 + 8, 585, R.kimlikAlt, 0, 0, 0.6)
     Yazi(sag, 9, 400, bx + w1 + 8 + wn + 8, 585, R.kimlikAlt, 0, 1.4)
     surface.SetAlphaMultiplier(1)

     -- .category
     local kirpik = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * math.pi / 2 - math.pi / 2))
     for i, kat in ipairs(G.Kategoriler) do
          local p = KAT_KONUM[i]
          if (p) then
               local a, kay = self:Giris(i - 1, 35, 0.65, 9)
               local anahtar = "kat" .. i
               local u = self:Uzerinde(anahtar)
               local secili = i == self.kat
               local vurgu = secili and 1 or u
               local cx, cy = p[1], p[2] + kay - 2 * u
               local n, ust = G.KategoriToplam(char, kat)

               surface.SetAlphaMultiplier(a)
               if (vurgu > 0) then Parilti(cx, cy, 150, Color(196, 161, 92), 34 * vurgu) end
               RadyalDisk(cx, cy, 44,
                    Color(Lerp(vurgu, 35, 56), Lerp(vurgu, 49, 67), Lerp(vurgu, 36, 41)),
                    Color(Lerp(vurgu, 16, 21), Lerp(vurgu, 28, 34), Lerp(vurgu, 23, 25)), vurgu > 0 and 0.85 or 0.82)
               surface.SetDrawColor(Lerp(vurgu, R.muhur.r, R.muhurSecili.r), Lerp(vurgu, R.muhur.g, R.muhurSecili.g), Lerp(vurgu, R.muhur.b, R.muhurSecili.b), Lerp(vurgu, 110, 255))
               Cember(cx, cy, 44)
               if (secili) then surface.SetDrawColor(188, 171, 130, 51) else Ton(R.muhur, 0.15) end
               Cember(cx, cy, 38)
               if (secili) then
                    Ton(R.halkaSecili, 0.4 * (sakin and 1 or kirpik))
                    Cember(cx, cy, 50)
               end
               if (ust > 0 and n > 0) then
                    Ton(R.ilerleme, 0.85)
                    KalinYay(cx, cy, 44, 1.5, -math.pi / 2, -math.pi / 2 + 2 * math.pi * math.Clamp(n / ust, 0, 1))
               end

               local ikon = G.Doku(kat.ikon)
               if (ikon) then
                    local ia = vurgu > 0 and Lerp(vurgu, 0.82, 1) or 0.82
                    surface.SetMaterial(ikon)
                    surface.SetDrawColor(250, 238, 212, 255 * ia)
                    surface.DrawTexturedRect(X(cx - 32), Y(cy - 32 - vurgu), 64 * S, 64 * S)
                    draw.NoTexture()
               end

               local adRenk = Color(Lerp(vurgu, R.katAd.r, R.katAdSecili.r), Lerp(vurgu, R.katAd.g, R.katAdSecili.g), Lerp(vurgu, R.katAd.b, R.katAdSecili.b))
               Yazi(kat.ad, 15, 500, p[1], p[2] + kay + 69, adRenk, 1, 0.15)

               local sr = secili and R.sayiSecili or R.sayi
               local s1, s2 = tostring(n), tostring(ust)
               local w1_, ws, w2_ = Olc(s1, 10, 400, 1.6), Olc(" / ", 10, 400, 1.6), Olc(s2, 10, 400, 1.6)
               local sx = p[1] - (w1_ + ws + w2_ + 3.2) / 2
               Yazi(s1, 10, 400, sx, p[2] + kay + 93, sr, 0, 1.6)
               Yazi(" / ", 10, 400, sx + w1_ + 1.6, p[2] + kay + 93, sr, 0, 1.6, 0.45)
               Yazi(s2, 10, 400, sx + w1_ + ws + 3.2, p[2] + kay + 93, sr, 0, 1.6)
               surface.SetAlphaMultiplier(1)

               local alan = {p[1] - 92, p[2] - 44, 184, 150}
               self.yeniTiklama[#self.yeniTiklama + 1] = {alan[1], alan[2], alan[3], alan[4], anahtar = anahtar, kat = i, islev = function() self:AgacAc(i) end}
          end
     end

     self:AnaAyrinti(char)
end

-- #overview-detail
function PANEL:AnaAyrinti(char)
     local kat = G.Kategoriler[self.kat]
     if (!kat) then return end
     local a = sakin and 1 or Kolay((RealTime() - self.ayrintiAn) / 0.45)
     local x, y = 1210 + (1 - a) * 12, 286
     surface.SetAlphaMultiplier(a)
     self:AyrintiCerceve(x, y, 1)

     local yy = y + 26 + 6
     Yazi("ARTES MÁGICAS", 9, 500, x, yy, R.ayrUst, 0, 2)
     Yazi(Iki(self.kat) .. " / 08", 9, 500, x + 306, yy, R.ayrSira, 2, 1)

     yy = y + 26 + 12 + 20
     local satirlar = Sar(kat.ad, 29, 500, 306)
     for i, s in ipairs(satirlar) do Yazi(s, 29, 500, x, yy + (i - 0.5) * 39.15 * YAZI_OLCEK, R.soluk, 0, 0.1) end
     yy = yy + #satirlar * 39.15 * YAZI_OLCEK + 20

     satirlar = Sar(kat.aciklama, 13, 400, 295)
     for i, s in ipairs(satirlar) do Yazi(s, 13, 400, x, yy + (i - 0.5) * 23.4 * YAZI_OLCEK, R.ayrAciklama, 0) end
     yy = yy + #satirlar * 23.4 * YAZI_OLCEK + 25

     -- [11-09] dal seviyesi (dal XP'si) ve seviye içi ilerleme
     local n, ust = G.KategoriToplam(char, kat)
     local dsv, dic, dgerek = G.DalSeviye(char, kat.id)
     local drol = G.EtkinRol(char, kat.id)
     Yazi("NIVEL DE RAMA", 9, 400, x, yy + 5.5, R.ayrBaslikAlt, 0, 1.2)
     Yazi("NV " .. dsv .. " / " .. G.DalTavan(char, kat.id) .. "  ·  " .. Buyuk(G.Unvan(dsv, drol)), 9, 400, x + 306, yy + 5.5, R.ayrBaslikDeger, 2, 1.2)
     yy = yy + 11 + 12

     surface.SetDrawColor(R.izBos) Dikdortgen(x, yy, 306, 2)
     local dolu = 306 * (dgerek > 0 and dic / dgerek or 1)
     if (dolu > 0) then
          YatayGecis(x, yy, dolu, 2, R.izSol, 255, R.izSag, 255)
          Parilti(x + dolu, yy + 1, 18, R.izSag, 30)
     end
     yy = yy + 2 + 24

     local dx = x
     for i, d in ipairs(kat.dallar) do
          Yazi(d, 10, 400, dx, yy + 8.5, R.dal, 0)
          dx = dx + Olc(d, 10, 400)
          if (i < #kat.dallar) then
               Yazi("·", 10, 400, dx + 8, yy + 8.5, R.dal, 0, 0, 0.4)
               dx = dx + 8 + Olc("·", 10, 400) + 8
          end
     end
     yy = yy + 17 + 31

     self:Dugme(x, yy, 306, 49, "VER COMPETENCIAS", true, "agacAc", function() self:AgacAc(self.kat) end, true)
     yy = yy + 49 + 12

     -- dalın rolü (ilk kademe açılan 2 dal ana, 3. dal yan dal olur)
     local rol = G.DalRolu(char, kat.id)
     local sira = !rol and G.SiradakiRol(char)
     local m, c
     if (rol) then
          m, c = (rol == "ana" and "RAMA PRINCIPAL  ·  VELOCIDAD PLENA" or "RAMA SECUNDARIA  ·  60 %  ·  NV 10"), R.onKosulTamam
     elseif (sira) then
          m, c = "CON EL PRIMER RANGO SERÁ TU RAMA " .. (sira == "ana" and "PRINCIPAL" or "SECUNDARIA"), R.ayrBaslikDeger
     else
          m, c = "OTRA RAMA  ·  25 %  ·  NV 3", R.ayak
     end
     Yazi(m, 9, 500, x + 153, yy + 8, c, 1, 1)
     yy = yy + 16 + 12

     local kaynak = G.DalKaynaklari and G.DalKaynaklari[kat.id]
     Yazi(kaynak and ("XP: " .. Buyuk(kaynak.yuksek)) or (n .. " / " .. ust .. " RANGOS"), 9, 400, x + 153, yy + 5.5, R.ayak, 1, 1)
     surface.SetAlphaMultiplier(1)
end

----------------------------------------------------------------------------------------
-- Beceri ağacı
----------------------------------------------------------------------------------------
function PANEL:AgacCiz(char)
     local kat = G.Kategoriler[self.kat]
     if (!kat) then return end
     local t = Zaman()
     local g = sakin and 1 or Kolay((RealTime() - self.gorunumAn) / 0.45)

     -- .back
     surface.SetAlphaMultiplier(g)
     local u = self:Uzerinde("geri")
     local gr = Color(Lerp(u, R.geri.r, R.soluk.r), Lerp(u, R.geri.g, R.soluk.g), Lerp(u, R.geri.b, R.soluk.b))
     surface.SetDrawColor(gr)
     SolOk(72, 200, 14)
     Yazi("Todas las competencias", 11, 400, 72 + 14 + 12, 200, gr, 0)
     self:Alan(72, 182, 26 + Olc("Todas las competencias", 11, 400), 36, "geri", function() self:Geri() end)

     -- #tabs
     for i, k in ipairs(G.Kategoriler) do
          local tx = 292 + (i - 1) * 110
          local anahtar = "sekme" .. i
          local su = self:Uzerinde(anahtar)
          local secili = i == self.kat
          local v = secili and 1 or su
          local ikon = G.Doku(k.ikon)
          if (ikon) then
               surface.SetMaterial(ikon)
               surface.SetDrawColor(250, 238, 212, 255 * Lerp(v, 0.6, 1))
               surface.DrawTexturedRect(X(tx + 33), Y(168 - 2 * v), 32 * S, 32 * S)
               draw.NoTexture()
          end
          local c = secili and R.sekmeSecili or R.sekme
          Yazi(k.ad, 9, 500, tx + 49, 215, c, 1, 0.1)
          if (secili) then Ton(R.sekmeBaklava) Baklava(tx + 49, 241, 2.8) end
          self:Alan(tx, 168, 98, 66, anahtar, function() if (i != self.kat) then self:AgacAc(i) end end)
     end
     surface.SetAlphaMultiplier(1)

     -- .skill
     local nefes = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * math.pi / 2 - math.pi / 2))
     local dz = Duzen(kat)
     for i, b in ipairs(kat.beceriler) do
          local p = dz.konum[i] or AGAC_KONUM[1]
          local a, kay = self:Giris(i - 1, 28, 0.45, 9)
          local anahtar = "bec" .. i
          local su = self:Uzerinde(anahtar)
          local secili = i == self.dugum
          local durum = G.Durum(char, kat, i)
          local kademe = G.Kademe(char, kat.id, i)
          local cx, cy = p[1], p[2] + kay - 2 * su

          surface.SetAlphaMultiplier(a)
          if (secili) then Parilti(cx, cy, 120, Color(196, 164, 92), 30) end

          local zemin = durum == "ogrenildi" and Color(34, 53, 34) or (durum == "kilitli" and Color(17, 30, 23) or Color(21, 36, 27))
          surface.SetDrawColor(zemin) Disk(cx, cy, 32)

          local cerceve
          if (secili) then cerceve = Color(219, 187, 118)
          elseif (durum == "ogrenildi") then cerceve = Color(190, 165, 102)
          elseif (durum == "kilitli") then cerceve = Color(116, 128, 93, 102)
          else cerceve = Color(196, 164, 95, 186) end
          if (su > 0) then
               cerceve = Color(Lerp(su, cerceve.r, 218), Lerp(su, cerceve.g, 198), Lerp(su, cerceve.b, 151), Lerp(su, cerceve.a, 255))
          end
          surface.SetDrawColor(cerceve) Cember(cx, cy, 32)
          Ton(R.muhur, 0.15) Cember(cx, cy, 27)

          if (durum == "acilabilir") then
               surface.SetDrawColor(195, 177, 125, (secili and 61 or 32) * (sakin and 1 or nefes))
               Cember(cx, cy, 38)
          elseif (secili) then
               surface.SetDrawColor(195, 177, 125, 61)
               Cember(cx, cy, 38)
          end

          -- just-learned: dışa açılan halka
          local gecen = RealTime() - self.ogrenAn
          if (!sakin and self.sonOgrenilen == i and gecen < 1.2) then
               local f = gecen / 1.2
               surface.SetDrawColor(238, 225, 176, 255 * (1 - f))
               Cember(cx, cy, 38 * Lerp(f, 0.95, 1.6))
          end

          local ikon = G.Doku(kat.ikon)
          if (ikon) then
               local ia = durum == "ogrenildi" and 0.92 or (durum == "kilitli" and 0.28 or 0.72)
               local flas = (!sakin and self.sonOgrenilen == i and gecen < 1) and math.max(0, 1 - math.abs(gecen - 0.25) / 0.75) or 0
               surface.SetMaterial(ikon)
               surface.SetDrawColor(250, 238, 212, 255 * math.min(1, ia + flas * 0.4))
               surface.DrawTexturedRect(X(cx - 20), Y(cy - 20), 40 * S, 40 * S)
               draw.NoTexture()
          end

          -- .state-mark
          if (durum == "ogrenildi") then
               local mx, my = cx + 30, cy + 22
               Ton(R.isaret) Disk(mx, my, 7)
               Ton(R.isaretCizgi) Cember(mx, my, 7)
               Ton(R.isaretYazi)
               Cizgi(mx - 3, my, mx - 1, my + 2.5) Cizgi(mx - 1, my + 2.5, mx + 3.2, my - 2.5)
          elseif (durum == "kilitli") then
               local lx, ly = cx + 24, cy + 19
               Ton(R.isaret) Dikdortgen(lx, ly, 11, 9)
               Ton(R.kilit)
               surface.DrawOutlinedRect(X(lx), Y(ly), 11 * S, 9 * S, 1)
               Yay(lx + 5.5, ly - 0.5, 3.2, math.pi, 2 * math.pi)
               Cizgi(lx + 2.3, ly - 0.5, lx + 2.3, ly) Cizgi(lx + 8.7, ly - 0.5, lx + 8.7, ly)
          end

          local kilitli = durum == "kilitli"
          local adR = kilitli and R.becKilitli or (secili and R.becAdSecili or R.becAd)
          Yazi(b.ad, 13, 500, p[1], p[2] + kay + dz.ad, adR, 1)
          local kr = kilitli and R.becKilitli or R.becKademe
          Yazi(kademe .. " / " .. b.enfazla, 9, 400, p[1], p[2] + kay + dz.kademe, kr, 1, 2)
          surface.SetAlphaMultiplier(1)

          self:Alan(p[1] - 102, p[2] - 32, 204, dz.alan, anahtar, function() self:DugumSec(i) end)
     end

     -- .tree-legend
     surface.SetAlphaMultiplier(g)
     local lx = 330
     for _, l in ipairs({{"Aprendido", true}, {"Disponible"}, {"Bloqueado"}}) do
          Ton(R.lejantBaklava)
          if (l[2]) then Baklava(lx + 3.5, 821, 3.5) else BaklavaCizgi(lx + 3.5, 821, 3.5) end
          Yazi(l[1], 9, 400, lx + 7 + 8, 821, R.lejant, 0, 0.5)
          lx = lx + 7 + 8 + Olc(l[1], 9, 400, 0.5) + 24
     end
     surface.SetAlphaMultiplier(1)

     self:AgacAyrinti(char, kat)
end

-- #skill-detail
function PANEL:AgacAyrinti(char, kat)
     local b = kat.beceriler[self.dugum]
     if (!b) then return end
     local a = sakin and 1 or Kolay((RealTime() - self.ayrintiAn) / 0.45)
     local x, y = 1210 + (1 - a) * 12, 291
     surface.SetAlphaMultiplier(a)
     self:AyrintiCerceve(x, y, 1)

     local yy = y + 26 + 6
     Yazi(Buyuk(kat.ad), 9, 500, x, yy, R.ayrUst, 0, 2)
     Yazi(Iki(self.dugum) .. " / " .. Iki(#kat.beceriler), 9, 500, x + 306, yy, R.ayrSira, 2, 1)

     yy = y + 26 + 12 + 19
     local satirlar = Sar(b.ad, 26, 500, 306)
     for i, s in ipairs(satirlar) do Yazi(s, 26, 500, x, yy + (i - 0.5) * 36.4 * YAZI_OLCEK, R.soluk, 0, 0.1) end
     yy = yy + #satirlar * 36.4 * YAZI_OLCEK + 17

     local kademe = G.Kademe(char, kat.id, self.dugum)
     local k1 = "RANGO " .. kademe
     local kw = Olc(k1, 9, 400, 1.8)
     Yazi(k1, 9, 400, x, yy + 5.5, R.kademeYazi, 0, 1.8)
     Yazi(" /", 9, 400, x + kw + 1.8, yy + 5.5, R.kademeYazi, 0, 1.8, 0.4)
     Yazi(" " .. b.enfazla, 9, 400, x + kw + 1.8 + Olc(" /", 9, 400, 1.8) + 1.8, yy + 5.5, R.kademeYazi, 0, 1.8)
     yy = yy + 11 + 24

     satirlar = Sar(b.aciklama, 13, 400, 295)
     for i, s in ipairs(satirlar) do Yazi(s, 13, 400, x, yy + (i - 0.5) * 23.4 * YAZI_OLCEK, R.ayrAciklama, 0) end
     yy = yy + #satirlar * 23.4 * YAZI_OLCEK + 25

     -- .detail-effect
     Ton(R.altin, 0.22) Dikdortgen(x, yy, 306, 1)
     yy = yy + 1 + 17
     satirlar = Sar(b.etki, 12, 400, 306)
     for i, s in ipairs(satirlar) do Yazi(s, 12, 400, x, yy + (i - 0.5) * 21.6 * YAZI_OLCEK, R.etki, 0) end
     yy = yy + #satirlar * 21.6 * YAZI_OLCEK + 17
     Ton(R.altin, 0.22) Dikdortgen(x, yy, 306, 1)
     yy = yy + 1 + 20

     -- .requirements
     local basY = yy
     Yazi(#b.gerek > 0 and "REQUISITOS PREVIOS" or "COMPETENCIA INICIAL", 8, 400, x, yy + 5, R.onKosul, 0, 1.6)
     yy = yy + 10 + 7
     local rx, ry = x, yy
     for j, u in ipairs(b.gerek) do
          local ub = kat.beceriler[u]
          local uk = G.Kademe(char, kat.id, u)
          local ad, sayi = ub.ad .. " ", uk .. "/" .. ub.enfazla
          local w = Olc(ad, 10, 400) + Olc(sayi, 10, 400)
          if (rx > x and rx + w > x + 306) then rx, ry = x, ry + 18 * YAZI_OLCEK end
          local tamam = uk >= ub.enfazla
          local anahtar = "gerek" .. u
          local c = tamam and R.onKosulTamam or R.onKosulBtn
          Yazi(ad, 10, 400, rx, ry + 9, c, 0)
          Yazi(sayi, 10, 400, rx + Olc(ad, 10, 400), ry + 9, c, 0, 0, 0.65)
          if (self:Uzerinde(anahtar) > 0.5) then
               surface.SetDrawColor(c.r, c.g, c.b, 160)
               Dikdortgen(rx, ry + 9 + 7, w, 1)
          end
          self:Alan(rx, ry, w, 18, anahtar, function() self:DugumSec(u) end)
          rx = rx + w
          if (j < #b.gerek) then
               Yazi("·", 10, 400, rx + 7, ry + 9, R.onKosul, 0, 0, 0.4)
               rx = rx + 7 + Olc("·", 10, 400) + 7
          end
     end
     yy = math.max(basY + 58, ry + (#b.gerek > 0 and 18 * YAZI_OLCEK or 0)) + 19

     -- #learn
     local durum = G.Durum(char, kat, self.dugum)
     local puan = G.DalHak(char, kat.id)
     local etiket, acik
     if (self.bekliyor) then etiket, acik = "PROCESANDO…", false
     elseif (durum == "ogrenildi") then etiket, acik = "COMPLETADO", false
     elseif (durum == "kilitli") then etiket, acik = "REQUISITOS PREVIOS", false
     elseif (puan < 1) then
          local sv, tavan = G.DalSeviye(char, kat.id), G.DalTavan(char, kat.id)
          if (sv >= tavan) then etiket = "TOPE DE ROL  ·  NV " .. tavan
          else etiket = "ESPERA EL SIGUIENTE NIVEL  ·  NV " .. (sv + 1) end
          acik = false
     else
          etiket, acik = "MEJORAR  ·  1 PUNTO DE " .. Buyuk(kat.ad), true
     end
     self:Dugme(x, yy, 306, 49, etiket, acik, "ogren", function() self:Ogren() end)
     surface.SetAlphaMultiplier(1)
end

----------------------------------------------------------------------------------------
-- Zihin Sanatları ([sardon] zihin): F (Zihnifend) — B (Zihnibend) ekseni
----------------------------------------------------------------------------------------
local ZR = {
     fend = Color(150, 96, 222), bend = Color(206, 70, 100), nokta = Color(255, 240, 255),
     kayitIyi = Color(196, 214, 170), kayitKotu = Color(214, 150, 150)
}
local ZF_X, ZB_X, Z_Y, Z_R = 440, 1000, 480, 92

local ZIHIN_METIN = {
     "Entrar en una mente con Legilimens te acerca a la Legilimencia (F).",
     "Rechazar una intrusión te empuja hacia la Oclumancia (B).",
     "Solo cuenta el primer éxito del día; la maestría tarda unos 3 meses.",
     "Cambiar de bando es deshacer el camino que ya has recorrido."
}

local KAYIT = {
     giris = {"Entraste en su mente", true}, girildi = {"Entraron en tu mente", false},
     savundu = {"Lo rechazaste", true}, itildi = {"Te rechazaron", false}
}

local function Once(t)
     local d = math.max(0, os.time() - (tonumber(t) or 0))
     if (d < 3600) then return "hace " .. math.max(1, math.floor(d / 60)) .. " min" end
     if (d < 86400) then return "hace " .. math.floor(d / 3600) .. " h" end
     return "hace " .. math.floor(d / 86400) .. " d"
end

function PANEL:ZihinAc()
     if (!SardonZihin) then return end
     self.mod = "zihin"
     self.gorunumAn = RealTime()
     self:AyrintiYenile()
     self:Ses()
end

-- ana ekran ve ağaçta sağ üstte: canlı göz ikonu, mor→kızıl geçiş, sis + yükselen ışık zerreleri,
-- altta minyatür F—B ipliği (karakterin konumu). Yalnız oyunla gelen materyaller (dağıtım yok).
local matZerre = Material("sprites/light_glow02_add")
local matSis = Material("particle/smokesprites_0001")
local ZD_X, ZD_Y, ZD_W, ZD_H = 1210, 198, 306, 76

-- Badem göz: üst/alt kapak eğrisi, iris, göz bebeği; kirp 0..1 kapağı kapatır
local function ZihinGoz(cx, cy, w, h, kirp, bakX, bakY, renk, u)
     local hh = h * (1 - kirp)
     local n = 18
     local ux, uy, ax, ay
     for i = 0, n do
          local f = i / n * 2 - 1
          local x = cx + f * w
          local k = 1 - f * f
          local nux, nuy, nax, nay = x, cy - hh * k, x, cy + hh * k * 0.8
          if (ux) then
               Cizgi(ux, uy, nux, nuy) Cizgi(ax, ay, nax, nay)
          end
          ux, uy, ax, ay = nux, nuy, nax, nay
     end
     if (hh > 1.5) then
          local ix, iy = cx + bakX * w * 0.28, cy + bakY * hh * 0.25
          local ir = math.min(h * 0.62, hh * 0.9)
          surface.SetDrawColor(renk.r, renk.g, renk.b, 235) Disk(ix, iy, ir)
          surface.SetDrawColor(14, 8, 22, 255) Disk(ix, iy, ir * (0.45 - 0.12 * u))
          surface.SetDrawColor(255, 245, 255, 220) Disk(ix - ir * 0.32, iy - ir * 0.32, math.max(0.8, ir * 0.18))
     end
end

function PANEL:ZihinDugme()
     local Zh = SardonZihin
     if (!Zh) then return end
     local x, y, w, h = ZD_X, ZD_Y, ZD_W, ZD_H
     local t = Zaman()
     local u = self:Uzerinde("zihinAc")
     local char = Karakter()
     local z = char and Zh.Deger(char) or 0
     local g = sakin and 1 or Kolay((RealTime() - self.gorunumAn) / 0.7)
     surface.SetAlphaMultiplier(g)

     -- zemin: koyu mor, solda Zihnifend morluğu sağda Zihnibend kızıllığı
     surface.SetDrawColor(14, 9, 22, 225)
     Dikdortgen(x, y, w, h)
     surface.SetDrawColor(ZR.fend.r, ZR.fend.g, ZR.fend.b, Lerp(u, 46, 86))
     surface.SetMaterial(gradL) surface.DrawTexturedRect(X(x), Y(y), w * 0.7 * S, h * S)
     surface.SetDrawColor(ZR.bend.r, ZR.bend.g, ZR.bend.b, Lerp(u, 30, 64))
     surface.SetMaterial(gradR) surface.DrawTexturedRect(X(x + w * 0.3), Y(y), w * 0.7 * S, h * S)
     draw.NoTexture()

     -- parçacıklar kartın içinde kalsın
     local sx1, sy1 = math.floor(X(x)), math.floor(Y(y))
     render.SetScissorRect(sx1, sy1, math.ceil(X(x + w)), math.ceil(Y(y + h)), true)

     -- süzülen sis
     surface.SetMaterial(matSis)
     for i = 1, 4 do
          local f = ((sakin and 0 or t) * 0.025 + i * 0.27) % 1
          local mx = x + (f * 1.3 - 0.15) * w
          local my = y + h * 0.5 + math.sin(t * 0.4 + i * 1.7) * h * 0.25
          local c = i % 2 == 0 and ZR.bend or ZR.fend
          local boy = 120 + 30 * math.sin(i * 2.1)
          surface.SetDrawColor(c.r, c.g, c.b, Lerp(u, 16, 34))
          surface.DrawTexturedRectRotated(X(mx), Y(my), boy * S, boy * S, (sakin and 0 or t) * (i % 2 == 0 and 9 or -7) + i * 60)
     end

     -- yükselen ışık zerreleri (hover'da çoğalır ve hızlanır)
     surface.SetMaterial(matZerre)
     local adet = 14 + math.floor(10 * u)
     for i = 1, adet do
          local hiz = 0.12 + (i * 0.618 % 1) * 0.16 + 0.2 * u
          local f = ((sakin and 0.5 or t) * hiz + i * 0.381) % 1
          local px = x + 70 + ((i * 0.7548) % 1) * (w - 80) + math.sin(t * 1.3 + i) * 6
          local py = y + h + 4 - f * (h + 12)
          local a = math.sin(f * math.pi) * Lerp(u, 150, 235)
          local c = px < x + w * (0.5 + z / 200) and ZR.fend or ZR.bend
          local boy = 7 + (i * 0.33 % 1) * 9
          surface.SetDrawColor(c.r, c.g, c.b, a)
          surface.DrawTexturedRect(X(px - boy / 2), Y(py - boy / 2), boy * S, boy * S)
     end
     draw.NoTexture()

     -- minyatür F—B ipliği ve karakterin noktası
     local ix1, ix2, iy = x + 82, x + w - 46, y + h - 15
     local noktaX = (ix1 + ix2) / 2 + z / 100 * (ix2 - ix1) / 2
     local function MiniDalga(f) return iy + math.sin(f * math.pi * 6 - t * 2.2) * 2.2 * math.sin(math.pi * f) end
     local ppx, ppy
     for i = 0, 40 do
          local f = i / 40
          local lx, ly = Lerp(f, ix1, ix2), MiniDalga(f)
          if (ppx) then
               local c = lx <= noktaX and ZR.fend or ZR.bend
               surface.SetDrawColor(c.r, c.g, c.b, Lerp(u, 120, 200)) Cizgi(ppx, ppy, lx, ly)
          end
          ppx, ppy = lx, ly
     end
     Yazi("F", 8, 600, ix1 - 8, iy, ZR.fend, 1)
     Yazi("B", 8, 600, ix2 + 8, iy, ZR.bend, 1)
     local ny = MiniDalga((noktaX - ix1) / (ix2 - ix1))
     Parilti(noktaX, ny, 26, ZR.nokta, 70 + 50 * u)
     surface.SetDrawColor(ZR.nokta) Disk(noktaX, ny, 2.6)

     render.SetScissorRect(0, 0, 0, 0, false)

     -- ikon madalyonu: dönen yörünge halkası + canlı göz
     local mx, my, mr = x + 40, y + h / 2, 25
     Parilti(mx, my, 110, ZR.fend, Lerp(u, 50, 110) + 15 * math.sin(t * 2))
     RadyalDisk(mx, my, mr, Color(56, 34, 86), Color(12, 8, 20), 0.9)
     surface.SetDrawColor(ZR.fend.r, ZR.fend.g, ZR.fend.b, 200) Cember(mx, my, mr)
     local don = (sakin and 0 or t) * Lerp(u, 0.9, 2.4)
     surface.SetDrawColor(ZR.bend.r, ZR.bend.g, ZR.bend.b, 230)
     KalinYay(mx, my, mr + 5, 1.8, don, don + math.pi * 0.55)
     surface.SetDrawColor(ZR.fend.r, ZR.fend.g, ZR.fend.b, 230)
     KalinYay(mx, my, mr + 5, 1.8, don + math.pi, don + math.pi * 1.55)
     for k = 0, 1 do
          local a = don + math.pi * 0.55 + k * math.pi
          Parilti(mx + math.cos(a) * (mr + 5), my + math.sin(a) * (mr + 5), 16, ZR.nokta, 200)
     end
     -- göz: ~5 sn'de bir kırpar, bebek yavaşça gezinir, hover'da fareye bakıp büyür
     local kirp = 0
     if (!sakin) then
          local d = (t % 5.3) / 0.22
          if (d < 1) then kirp = math.sin(d * math.pi) end
     end
     local bakX, bakY = math.sin(t * 0.7) * 0.6, math.sin(t * 0.53) * 0.4
     if (u > 0) then
          local fx, fy = self:CursorPos()
          local dx, dy = (fx - X(mx)) / (60 * S), (fy - Y(my)) / (60 * S)
          bakX, bakY = Lerp(u, bakX, math.Clamp(dx, -1, 1)), Lerp(u, bakY, math.Clamp(dy, -1, 1))
     end
     surface.SetDrawColor(R.soluk.r, R.soluk.g, R.soluk.b, 235)
     ZihinGoz(mx, my, 15, 8.5 + 1.5 * u, kirp, bakX, bakY, Color(Lerp(u, ZR.fend.r, ZR.bend.r), Lerp(u, ZR.fend.g, ZR.bend.g), Lerp(u, ZR.fend.b, ZR.bend.b)), u)

     -- yazılar
     Yazi("ARTES MENTALES", 12, 600, x + 82, y + 22, Color(Lerp(u, R.butonYazi.r, 255), Lerp(u, R.butonYazi.g, 244), Lerp(u, R.butonYazi.b, 255)), 0, 1.6)
     Yazi(Zh.Unvan(z) .. "  ·  " .. (z > 0 and "+" or "") .. string.format("%.1f", z), 9, 400, x + 82, y + 41, R.ayrBaslikAlt, 0, 0.6)
     surface.SetDrawColor(Lerp(u, R.buton.r, 255), Lerp(u, R.buton.g, 240), Lerp(u, R.buton.b, 255), Lerp(u, 170, 255))
     SagOk(x + w - 14 + 4 * u, y + 28, 12)

     -- çerçeve + köşe süsleri
     surface.SetDrawColor(Lerp(u, R.altin.r, ZR.nokta.r), Lerp(u, R.altin.g, ZR.nokta.g), Lerp(u, R.altin.b, ZR.nokta.b), Lerp(u, 120, 220))
     surface.DrawOutlinedRect(X(x), Y(y), w * S, h * S, 1)
     Ton(R.altin) Baklava(x, y, 3.5) Baklava(x + w, y, 3.5)
     Ton(R.altin, 0.6) Baklava(x, y + h, 2.5) Baklava(x + w, y + h, 2.5)
     surface.SetAlphaMultiplier(1)

     self:Alan(x, y, w, h, "zihinAc", function() self:ZihinAc() end)
end

-- Sol bilgi kutusu (DalUyari ile aynı dil)
function PANEL:ZihinBilgi()
     local a = sakin and 1 or Kolay((RealTime() - self.gorunumAn) / 0.6)
     local x, y, w = DAL_X - (1 - a) * 10, 300, DAL_W
     surface.SetAlphaMultiplier(a)

     local paragraflar, satirSay = {}, 0
     for i, m in ipairs(ZIHIN_METIN) do
          paragraflar[i] = Sar(m, 13, 700, w - 30)
          satirSay = satirSay + #paragraflar[i]
     end
     local satirH, paraAra = 17 * YAZI_OLCEK, 14
     local h = 14 + 32 + 14 + satirSay * satirH + (#paragraflar - 1) * paraAra + 16

     surface.SetDrawColor(9, 17, 12, 225)
     Dikdortgen(x, y, w, h)
     surface.SetDrawColor(16, 27, 18, 90)
     surface.SetMaterial(gradU)
     surface.DrawTexturedRect(X(x), Y(y), w * S, h * S)
     draw.NoTexture()
     Ton(R.altin, 0.45) Dikdortgen(x, y, w, 1)
     Ton(R.altin, 0.18) Dikdortgen(x, y + h - 1, w, 1)
     Ton(R.altin) Baklava(x + 2.5, y + 0.5, 3.5)

     local yy = y + 14
     Ton(ZR.fend) BaklavaCizgi(x + 24, yy + 16, 16)
     Ton(ZR.fend, 0.35) BaklavaCizgi(x + 24, yy + 16, 13)
     Yazi("?", 20, 600, x + 24, yy + 16, R.puanGlif, 1)
     Yazi("CÓMO PROGRESAS", 12, 600, x + 52, yy + 16, R.ayrUst, 0, 2)
     yy = yy + 32 + 14

     for p, satirlar in ipairs(paragraflar) do
          -- madde imi: ilk satırın hizasında küçük baklava, metin asılı girintiyle
          Ton(R.altin, 0.8) Baklava(x + 12, yy + 0.5 * satirH, 3)
          for i, sat in ipairs(satirlar) do
               Yazi(sat, 13, 700, x + 24, yy + (i - 0.5) * satirH, R.ayrBaslikDeger, 0)
          end
          yy = yy + #satirlar * satirH + (p < #paragraflar and paraAra or 0)
     end
     surface.SetAlphaMultiplier(1)
end

function PANEL:ZihinCiz(char)
     local Zh = SardonZihin
     if (!Zh) then return end
     local t = Zaman()
     local g = sakin and 1 or Kolay((RealTime() - self.gorunumAn) / 0.6)
     local z = Zh.Deger(char)

     -- .back
     surface.SetAlphaMultiplier(g)
     local u = self:Uzerinde("geri")
     local gr = Color(Lerp(u, R.geri.r, R.soluk.r), Lerp(u, R.geri.g, R.soluk.g), Lerp(u, R.geri.b, R.soluk.b))
     surface.SetDrawColor(gr)
     SolOk(72, 200, 14)
     Yazi("Desarrollo", 13, 700, 72 + 14 + 12, 200, gr, 0)
     self:Alan(72, 182, 26 + Olc("Desarrollo", 13, 700), 36, "geri", function() self:Geri() end)

     -- iplik: F kenarından B kenarına, noktanın solu Zihnifend renginde, sağı Zihnibend
     local x1, x2 = ZF_X + Z_R + 6, ZB_X - Z_R - 6
     local ortaX = (x1 + x2) / 2
     local yari = (x2 - x1) / 2
     local noktaX = ortaX + z / 100 * yari
     local function DalgaY(f)
          return Z_Y + math.sin(f * math.pi * 4 - t * 1.6) * 5 * math.sin(math.pi * f)
     end
     local px, py
     local n = 72
     for i = 0, n do
          local f = i / n
          local x = Lerp(f, x1, x2)
          local y = DalgaY(f)
          if (px) then
               local c = x <= noktaX and ZR.fend or ZR.bend
               surface.SetDrawColor(c.r, c.g, c.b, 60) Cizgi(px, py - 1, x, y - 1) Cizgi(px, py + 1, x, y + 1)
               surface.SetDrawColor(c.r, c.g, c.b, 210) Cizgi(px, py, x, y)
          end
          px, py = x, y
     end

     -- ölçek: -100 .. 100
     for i = -4, 4 do
          local x = ortaX + i / 4 * yari
          Ton(R.altin, i == 0 and 0.7 or 0.3)
          Dikdortgen(x, Z_Y + 18, 1, i == 0 and 12 or 7)
          if (i % 2 == 0) then
               Yazi(tostring(math.abs(i * 25)), 10, 600, x, Z_Y + 40, R.ayak, 1, 1)
          end
     end

     -- madalyonlar
     local function Madalyon(cx, harf, ad, renk, guc, aktif)
          Parilti(cx, Z_Y, Z_R * 3.2, renk, 26 + 30 * guc / 100)
          RadyalDisk(cx, Z_Y, Z_R, Color(renk.r * 0.32, renk.g * 0.28, renk.b * 0.36), Color(12, 10, 20), 0.85)
          surface.SetDrawColor(renk.r, renk.g, renk.b, 230) Cember(cx, Z_Y, Z_R) Cember(cx, Z_Y, Z_R - 0.6)
          surface.SetDrawColor(renk.r, renk.g, renk.b, 70) Cember(cx, Z_Y, Z_R - 9)
          -- güç halkası
          if (guc > 0) then
               surface.SetDrawColor(renk.r, renk.g, renk.b, 255)
               KalinYay(cx, Z_Y, Z_R + 7, 2.5, -math.pi / 2, -math.pi / 2 + 2 * math.pi * guc / 100)
          end
          surface.SetDrawColor(renk.r, renk.g, renk.b, 40) Cember(cx, Z_Y, Z_R + 7)
          Yazi(harf, 64, 600, cx, Z_Y - 2, R.soluk, 1)
          Yazi(ad, 15, 600, cx, Z_Y + Z_R + 34, aktif and R.soluk or R.ayrBaslikAlt, 1, 2.5)
          Yazi(math.floor(guc + 0.5) .. " / 100", 12, 600, cx, Z_Y + Z_R + 58, R.ayrBaslikDeger, 1, 1.4)
     end
     -- F = ataque mental (Legilimencia), B = defensa (Oclumancia)
     Madalyon(ZF_X, "F", "LEGILIMENCIA", ZR.fend, math.max(0, -z), z < 0)
     Madalyon(ZB_X, "B", "OCLUMANCIA", ZR.bend, math.max(0, z), z > 0)

     -- nokta ve unvan
     -- nokta ipliğin üzerinde, dalgayla birlikte iner-çıkar
     local nabiz = sakin and 0 or (0.5 + 0.5 * math.sin(t * 2.4))
     local noktaY = DalgaY((noktaX - x1) / (x2 - x1))
     Parilti(noktaX, noktaY, 70, ZR.nokta, 40 + 30 * nabiz)
     surface.SetDrawColor(ZR.nokta) Disk(noktaX, noktaY, 6.5)
     Ton(R.altin) Cember(noktaX, noktaY, 10 + 2 * nabiz)
     local unvan = Zh.Unvan(z)
     Yazi(unvan, 17, 500, noktaX, Z_Y - 56, R.soluk, 1, 0.3)
     Yazi((z > 0 and "+" or "") .. string.format("%.2f", z), 12, 600, noktaX, Z_Y - 32, R.ayrBaslikDeger, 1, 1.2)
     surface.SetAlphaMultiplier(1)

     self:ZihinBilgi()
     self:ZihinAyrinti(char, z)
end

-- sağ panel: durum + son karşılaşmalar
function PANEL:ZihinAyrinti(char, z)
     local Zh = SardonZihin
     local a = sakin and 1 or Kolay((RealTime() - self.ayrintiAn) / 0.45)
     local x, y = 1210 + (1 - a) * 12, 236
     surface.SetAlphaMultiplier(a)
     self:AyrintiCerceve(x, y, 1)

     local yy = y + 32
     Yazi("ARTES MENTALES", 11, 600, x, yy, R.ayrUst, 0, 2)
     yy = yy + 34
     local satirlar = Sar(Zh.Unvan(z), 24, 500, 306)
     for i, s in ipairs(satirlar) do Yazi(s, 24, 500, x, yy + (i - 0.5) * 33 * YAZI_OLCEK, R.soluk, 0, 0.1) end
     yy = yy + #satirlar * 33 * YAZI_OLCEK + 18

     local function Satir(etiket, deger, renk)
          Yazi(etiket, 11, 600, x, yy + 5.5, R.ayrBaslikAlt, 0, 1.2)
          Yazi(deger, 12, 700, x + 306, yy + 5.5, renk or R.ayrBaslikDeger, 2)
          yy = yy + 27
     end
     local kazandi = Zh.BugunKazandi(char)
     Satir("PROGRESO DE HOY", kazandi and "Obtenido" or "Pendiente", kazandi and R.onKosulTamam or R.etki)
     local kilit = Zh.KilitKalan(char)
     Satir("LEGILIMENS", kilit > 0 and ("Sin punto · " .. Zh.SureYazi(kilit)) or "Listo", kilit > 0 and ZR.kayitKotu or R.onKosulTamam)
     Satir("GANANCIA DIARIA", "+" .. Zh.Kazanim .. " pts")

     yy = yy + 8
     Ton(R.altin, 0.22) Dikdortgen(x, yy, 306, 1)
     yy = yy + 20
     Yazi("ÚLTIMOS ENCUENTROS", 10, 600, x, yy, R.onKosul, 0, 1.6)
     yy = yy + 20

     local log = Zh.Veri(char).log
     if (!istable(log) or #log == 0) then
          Yazi("Aún no hay encuentros mentales.", 13, 700, x, yy + 8, R.becKilitli, 0)
     else
          for i = 1, math.min(#log, 5) do
               local k = log[i]
               local tur = KAYIT[k.tur] or {k.tur or "?", true}
               Yazi(tur[1] .. ": " .. (k.ad or "?"), 13, 700, x, yy + 8, tur[2] and ZR.kayitIyi or ZR.kayitKotu, 0)
               Yazi(Once(k.t), 11, 700, x + 306, yy + 8, R.ayak, 2)
               yy = yy + 27
          end
     end
     surface.SetAlphaMultiplier(1)
end

function PANEL:OnRemove()
     if (SardonGelisim.Ekran == self) then SardonGelisim.Ekran = nil end
end

vgui.Register("SardonGelisim.Ekran", PANEL, "EditablePanel")

----------------------------------------------------------------------------------------
-- TAB menü sekmesi
----------------------------------------------------------------------------------------
hook.Add("CreateMenuButtons", "SardonGelisim", function(tabs)
     tabs["gelisim"] = {
          hoswarsIcon = "icon_skills",
          bHideBackground = true,
          Create = function(info, container)
               local ekran = container:Add("SardonGelisim.Ekran")
               ekran:SetSize(container:GetSize())
               container.sardonGelisim = ekran
               SardonGelisim.Ekran = ekran
          end
     }
end)

-- sekme adı
local function DilEkle()
     for dil in pairs(ix.lang.stored or {}) do
          ix.lang.AddTable(dil, {gelisim = "Desarrollo del personaje"})
     end
end
DilEkle()
hook.Add("InitPostEntity", "SardonGelisim.Dil", DilEkle)
