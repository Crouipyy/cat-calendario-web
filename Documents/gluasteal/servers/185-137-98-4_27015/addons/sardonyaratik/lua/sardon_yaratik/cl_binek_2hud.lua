-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_binek_2hud.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: binek HUD'u (V2 "kanat şeridi")
--
-- Yalnız alt ortada ince bir kanat şeridi: solda Can, sağda Kanat gücü (Graphorn'da Hücum dolumu),
-- ortada küçük tür glifi ve adı, altında Bağ. Hemen üstünde o anın bağlamına göre tek satır tuş
-- ipuçları (yerde / havada / suda; tuşlar oyuncunun gerçek bağlarından). Hız, irtifa, binicinin canı
-- ve "binici hazır" duyurusu çizilmez (uçuş fiziği o değerleri kullanmaya devam eder). Kalkış dolumu
-- SPACE kapağının içinde, tutunma kaybı Pike ipucunda, sersemlik ipucu satırının başında görünür.
-- Kısa olaylar parçacıkla: biniş (şeritte kıvılcım), kanat çırpışı (kanat uçlarından), hasar (can
-- çizgisinden kor), büyü sekmesi (kalkan glifi). Diğer HUD'lar binerken gizlenir (SardonHUDGizle).

local Y = SardonYaratik
local V = Y.V2
local R = V.R

local math_max, math_min, math_floor, math_Clamp = math.max, math.min, math.floor, math.Clamp

local BIRIM_M = 52.49 -- 1 m ≈ 52.5 birim

local function Mesafe(birim)
     local m = birim / BIRIM_M
     if m >= 1000 then return string.format("%.1f km", m / 1000) end
     return math.Round(m) .. " m"
end
Y.BinekMesafe = Mesafe

-- türün şerit glifi: hipogrif kendi glifi; Thestral kanat; Graphorn (büyü sektiren derisi) kalkan
local GLIF = {hippogriff = "hippogriff", thestral = "wing", graphorn = "shield"}

------------------------------------------------------------------------ durum

local H = {giris = nil, canOnce = nil, cirpisOnce = nil, bagOnce = nil, ucuyorOnce = nil, sekme = nil, acildi = false}

function Y.BinekBindi(kod)
     H.giris = RealTime()
     H.acildi = false
     H.canOnce, H.cirpisOnce, H.bagOnce, H.ucuyorOnce, H.sekme = nil, nil, nil, nil, nil
end

function Y.BinekIndi()
     H.giris = nil
     if IsValid(Y.YonPaneli) then Y.YonPaneli:Remove() end
end

function Y.BinekOlayHUD(kim, ad, p, deger)
     if kim ~= LocalPlayer() then return end
     if ad == "sekme" then H.sekme = RealTime() end
end

------------------------------------------------------------------------ ipuçları

local function Bekleme(hazir, now)
     if hazir > now then return math.ceil(hazir - now) end
end

-- {tus, yazi, kapali, aktif, dolum, renk} listesi; tus nil ise kapaksız durum yazısı
local function Ipuclari(ply, w, b, ucuyor, suda, now)
     local out = {}
     local tZipla = V.TusAdi("+jump", "SPACE")
     local tHiz = V.TusAdi("+speed", "SHIFT")
     local tCok = V.TusAdi("+duck", "CTRL")
     local tSaldir = V.TusAdi("+attack", "SOL TIK")
     local tIleri = V.TusAdi("+forward", "W")
     local tIn = V.KodAdi(Y.BinekInTusu and Y.BinekInTusu(), "G")

     if now < w:GetSendele() then out[#out + 1] = {yazi = "Sersemledi", renk = R.altin} end

     if b.ucar and ucuyor then
          local c = b.hava.cirpis
          local guc = w:GetEnerji()
          out[#out + 1] = {tus = tZipla, yazi = guc < c.maliyet and (guc < 2 and "Kanat çırp · güç yok" or "Kanat çırp · güç az") or "Kanat çırp",
               kapali = guc < c.maliyet}
          local V2 = ply:GetVelocity():Length()
          local tutunma = V2 < b.hava.asgari and not w:GetOtopilot()
          out[#out + 1] = {tus = tCok, yazi = tutunma and "Pike · burnunu indir" or "Pike", aktif = w:GetPike(), renk = tutunma and R.can or nil}
     elseif suda then
          out[#out + 1] = {tus = tHiz, yazi = "Hızlı yüz · " .. tIleri .. " ile", aktif = ply:KeyDown(IN_SPEED)}
     elseif b.ucar then
          local kb = w:GetKalkisBas()
          local izin = w:GetBinicilik() >= 1
          out[#out + 1] = {tus = tZipla, yazi = izin and "Kalkış · basılı tut" or "Kalkış · Binicilik gerekli", kapali = not izin,
               dolum = kb > 0 and math_Clamp((now - kb) / b.hava.kalkis.sure, 0, 1) or nil}
          out[#out + 1] = {tus = tHiz, yazi = "Dörtnala · " .. tIleri .. " ile", aktif = ply:KeyDown(IN_SPEED)}
     end
     if b.hucum and not suda then
          local hc = b.hucum
          local hucumda = now < w:GetHucumBas() + hc.sure
          local kal = not hucumda and Bekleme(w:GetHucumHazir(), now)
          out[#out + 1] = {tus = tHiz, yazi = hucumda and "Hücumda" or (kal and ("Hücum · " .. kal .. " sn") or ("Hücum · " .. tIleri .. " ile")),
               aktif = hucumda, kapali = kal ~= nil and kal ~= false}
          local kv = Bekleme(w:GetVurusHazir(), now)
          out[#out + 1] = {tus = tZipla, yazi = kv and ("Yere vur · " .. kv .. " sn") or "Yere vur", kapali = kv ~= nil}
     end
     local kc = Bekleme(w:GetCiglikHazir(), now)
     local cAd = b.hucum and "Kükreme" or "Çığlık"
     out[#out + 1] = {tus = tSaldir, yazi = kc and (cAd .. " · " .. kc .. " sn") or cAd, kapali = kc ~= nil}
     if b.otopilot then
          local tR = V.TusAdi("+reload", "R")
          if w:GetOtopilot() then
               local rota = ply.YB_Rota
               local son = rota and rota[#rota]
               local yer = (Y.BinekOtoAd or "yolda") .. (son and (" · " .. Mesafe(son.p:Distance(ply:GetPos()))) or "")
               out[#out + 1] = {tus = tR, yazi = "Dizginleri al · " .. yer, aktif = true,
                    ilerleme = rota and (w:GetRotaNo() - 1) / math_max(#rota, 1) or nil}
          else
               out[#out + 1] = {tus = tR, yazi = "Yön Duygusu"}
          end
     end
     -- havada G spiral iniştir; yerde/suda iner. Havada "İn" gösterilmez.
     if ucuyor then
          out[#out + 1] = {tus = tIn, yazi = w:GetInis() and "İnişi iptal" or "Spiral iniş", aktif = w:GetInis()}
     else
          out[#out + 1] = {tus = tIn, yazi = "İn"}
     end
     return out
end

local function IpucuSatiri(liste, cx, cy, s, a)
     -- genişlik ölçümü
     local fT, fY = V.Font("govde", 12, s), V.Font("govde", 14, s)
     local ARA = 13 * s
     local toplam = 0
     for i, ip in ipairs(liste) do
          local w = 0
          if ip.tus then w = math_max(25 * s, V.Olcu(ip.tus, fT) + 16 * s) + 9 * s end
          w = w + V.Olcu(ip.yazi, fY)
          ip.w = w
          toplam = toplam + w + (i > 1 and ARA * 2 or 0)
     end
     V.Doku("key_veil", cx - 400 * s, cy - 32 * s, 800 * s, 64 * s, nil, a)
     local x = cx - toplam / 2
     for i, ip in ipairs(liste) do
          if i > 1 then
               V.Baklava(x + ARA, cy, 2.5 * s, R.sonuk, a, false)
               x = x + ARA * 2
          end
          local renk = ip.renk or (ip.aktif and R.altin or R.yazi)
          if ip.tus then
               V.Ipucu(ip.tus, ip.yazi, x, cy, s, a, renk, ip.dolum, ip.kapali)
               if ip.aktif then
                    -- etkin ipucunun kapağının altında ince altın çizgi
                    local tw = math_max(25 * s, V.Olcu(ip.tus, fT) + 16 * s)
                    surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 200 * a)
                    surface.DrawRect(x + 3 * s, cy + 13 * s, tw - 6 * s, 1)
               end
               if ip.ilerleme then
                    V.Cubuk(x, cy + 16 * s, ip.w, math_max(1, 2 * s), ip.ilerleme, R.enerji, a, R.iz)
               end
          else
               V.Yazi(ip.yazi, fY, x, cy + 5 * s, renk, a, 0)
          end
          x = x + ip.w
     end
end

------------------------------------------------------------------------ şerit

local function Gosterge(x, y, s, a, ad, deger, oran, renk, kritik)
     local f = V.Font("govde", 14, s)
     V.Yazi(ad, f, x, y, kritik and R.can or R.ikincil, a, 0)
     V.Yazi(deger, f, x + 209 * s, y, kritik and R.can or R.yazi, a, 2)
     V.Cubuk(x, y + 11 * s, 209 * s, math_max(2, 4 * s), oran, renk, a)
     return x + 209 * s * math_Clamp(oran, 0, 1), y + 13 * s
end

local function Serit(ply, w, b, tur, a, now, s)
     local cx = ScrW() / 2
     local rx, ry = cx - 420 * s, ScrH() - 168 * s

     -- yerel örtü (yalnız şeridin arkası) ve şerit
     V.Doku("key_veil", cx - 510 * s, ry - 4 * s, 1020 * s, 82 * s, nil, a * 0.9)
     if not V.Doku("wing_ribbon", rx, ry, 840 * s, 120 * s, nil, a) then
          draw.NoTexture()
          surface.SetDrawColor(R.zemin.r, R.zemin.g, R.zemin.b, 220 * a)
          V.Dort(rx + 8 * s, ry + 31 * s, cx, ry + 5 * s, rx + 832 * s, ry + 31 * s, cx, ry + 117 * s)
     end

     -- orta: glif, ad, bağ
     V.Ikon(GLIF[w:GetTur()] or "feather", cx, ry + 40 * s, 52 * s, R.altin, a)
     local k = Y.BenimKayit and Y.BenimKayit(w:GetKimlik())
     local ad = (k and k.ad) or (tur and tur.ad) or "Binek"
     local fAd = V.Font("baslik", 17, s)
     V.Yazi(V.Kisalt(ad, fAd, 150 * s), fAd, cx, ry + 95 * s, R.yazi, a, 1)

     local bag = math.Round(w:GetBag())
     local fB = V.Font("govde", 13, s)
     local bYazi = "Bağ %" .. bag .. (bag < 40 and " · komutlara geç uyar" or "")
     local bw = V.Olcu(bYazi, fB) + 24 * s
     local bx = cx - bw / 2
     -- bağ satırı şeridin altında kalıyor: açık renkli bineğin üstünde okunsun diye kendi küçük örtüsü
     V.Doku("key_veil", cx - (bw + 60 * s) / 2, ry + 111 * s, bw + 60 * s, (bw + 60 * s) * 0.08, nil, a)
     V.Doku("bond_rhombus", bx, ry + 116 * s, 17 * s, 17 * s, nil, a)
     V.Yazi(bYazi, fB, bx + 24 * s, ry + 129 * s, R.bag, a, 0)

     -- can (sol)
     local can, canMax = w:GetCan(), math_max(w:GetCanMax(), 1)
     local cx1, cy1 = Gosterge(rx + 126 * s, ry + 61 * s, s, a, "Can", math.ceil(can) .. " / " .. math.Round(canMax), can / canMax, R.can, can / canMax < 0.25)

     -- sağ: kanat gücü ya da hücum dolumu
     local ex, ey
     if b.ucar then
          local oran = w:GetEnerjiMax() > 0 and w:GetEnerji() / w:GetEnerjiMax() or 0
          ex, ey = Gosterge(rx + 505 * s, ry + 61 * s, s, a, "Kanat gücü", "%" .. math.Round(oran * 100), oran, R.enerji, oran < 0.2)
     elseif b.hucum then
          local hc = b.hucum
          local hazir = w:GetHucumHazir()
          local hucumda = now < w:GetHucumBas() + hc.sure
          local oran = hazir > now and 1 - (hazir - now) / (hc.sure + hc.bekleme) or 1
          ex, ey = Gosterge(rx + 505 * s, ry + 61 * s, s, a, "Hücum", hucumda and "Hücumda" or (oran >= 1 and "Hazır" or ("%" .. math_floor(oran * 100))), oran, R.altin)
     end
     return {can = {cx1, cy1}, enerji = ex and {ex, ey}, rx = rx, ry = ry, cx = cx, bag = {bx + 8 * s, ry + 124 * s}}
end

------------------------------------------------------------------------ olay parçacıkları

local function Olaylar(ply, w, b, now, s, yer)
     if V.Sade() then return end
     local rx, ry, cx = yer.rx, yer.ry, yer.cx

     -- biniş: iki kanat çizgisi boyunca dışa akan altın kıvılcımlar
     if not H.acildi then
          H.acildi = true
          for i = 1, 16 do
               local yon = i % 2 == 0 and 1 or -1
               local t = (i / 16)
               V.Parcacik("hud", {x = cx + yon * 380 * s * t * 0.3, y = ry + 12 * s + 18 * s * t, vx = yon * (220 + 160 * t) * s, vy = 28 * s,
                    omur = 0.6 + 0.3 * t, boy = 13 * s, boy2 = 0, renk = R.altin, a = 0.9, tur = i % 3 == 0 and "isik" or "yildiz", don = 120, sur = 2.4})
          end
     end

     -- kalkış / iniş anı
     local ucuyor = w:GetUcuyor()
     if H.ucuyorOnce ~= nil and ucuyor ~= H.ucuyorOnce then
          if ucuyor then
               V.Kivilcim("hud", rx + 30 * s, ry + 31 * s, R.enerji, 6, 120, 0.8, 14, s, math.pi * 1.15, 0.8)
               V.Kivilcim("hud", rx + 810 * s, ry + 31 * s, R.enerji, 6, 120, 0.8, 14, s, -math.pi * 0.15, 0.8)
          else
               V.Kivilcim("hud", cx, ry + 112 * s, R.altin, 8, 60, 0.7, 12, s, math.pi / 2, 2.4)
          end
     end
     H.ucuyorOnce = ucuyor

     -- kanat çırpışı: kanat uçlarından birkaç kıvılcım, kanat gücü çizgisinin ucundan da
     local ct = w:GetCirpisT()
     if H.cirpisOnce and ct > H.cirpisOnce + 0.01 then
          V.Kivilcim("hud", rx + 20 * s, ry + 30 * s, R.enerji, 3, 90, 0.6, 12, s, math.pi * 1.1, 0.7)
          V.Kivilcim("hud", rx + 820 * s, ry + 30 * s, R.enerji, 3, 90, 0.6, 12, s, -math.pi * 0.1, 0.7)
          if yer.enerji then V.Kivilcim("hud", yer.enerji[1], yer.enerji[2], R.enerji, 3, 40, 0.5, 10, s, -math.pi / 2, 1.2) end
     end
     H.cirpisOnce = ct

     -- hasar: can çizgisinin ucundan kor (ekran parlaması yok)
     local can = w:GetCan()
     if H.canOnce and can < H.canOnce - 0.5 then
          V.Kivilcim("hud", yer.can[1], yer.can[2], R.can, math_min(14, 5 + math_floor((H.canOnce - can) / 8)), 70, 0.9, 13, s, -math.pi / 2, 1.8)
     end
     H.canOnce = can

     -- bağ artışı
     local bag = w:GetBag()
     if H.bagOnce and bag > H.bagOnce + 0.5 then V.Kivilcim("hud", yer.bag[1], yer.bag[2], R.bag, 8, 50, 0.8, 12, s, -math.pi / 2, 1.6) end
     H.bagOnce = bag
end

-- Graphorn derisinden seken büyü: şeridin üstünde kısa süre kalkan glifi
local function Sekme(s, yer, a)
     if not H.sekme then return end
     local g = (RealTime() - H.sekme) / 1.2
     if g >= 1 then H.sekme = nil return end
     local cx, y = yer.cx, yer.ry - 96 * s
     if g < 0.02 and not V.Sade() then V.Kivilcim("hud", cx, y, R.enerji, 12, 110, 0.7, 14, s) end
     local al = a * (g < 0.15 and g / 0.15 or (1 - g) / 0.85)
     V.Doku("seal_veil", cx - 70 * s, y - 52 * s, 140 * s, 140 * s, nil, al)
     V.Ikon("shield", cx, y, 40 * s, R.enerji, al)
     V.Yazi("Büyü sekti", V.Font("govde", 13, s), cx, y + 34 * s, R.enerji, al, 1)
end

------------------------------------------------------------------------ ana çizim

hook.Add("HUDPaint", "SardonYaratik.BinekHUD", function()
     local ply = LocalPlayer()
     if not IsValid(ply) or not ply:Alive() then return end
     local w = Y.BinekSilah(ply)
     local b = w and Y.Binekler[w:GetTur()]
     if not b then return end
     local tur = Y.Turler[w:GetTur()]
     local now = CurTime()
     local s = math_max(V.Olcek(), 0.7)
     local a = V.Sade() and 1 or V.Yumusak((now - w:GetBinisT()) / 0.3)

     local yer = Serit(ply, w, b, tur, a, now, s)
     local suda = not w:GetUcuyor() and Y.BinekSuda and Y.BinekSuda(ply:GetPos(), b) ~= nil
     IpucuSatiri(Ipuclari(ply, w, b, w:GetUcuyor(), suda, now), yer.cx, yer.ry - 22 * s, s, a)
     Olaylar(ply, w, b, now, s, yer)
     Sekme(s, yer, a)
end)

-- 11-13 opt: diğer HUD'lar bu kancayı karede ~7 kez soruyor (her biri LocalPlayer + IsValid + __index + NW2).
-- Biniş yalnız sunucunun NW2 "SYBinek"inden; ağ güncellemesi karenin başında işlenir, HUD çağrıları arasında
-- değişmez: sonuç karede bir kez hesaplanır (cl_huds.lua H.Gizli ile aynı yol). Kare, hesap bitince yazılır:
-- Y.Biniyor hata verirse her çağrıda eskisi gibi hata verir.
local binekKare, binekSonuc = -1, false
hook.Add("SardonHUDGizle", "SardonYaratik.Binek", function()
     local f = FrameNumber()
     if f ~= binekKare then
          binekSonuc = Y.Biniyor(LocalPlayer()) and true or false
          binekKare = f
     end
     if binekSonuc then return true end
end)

hook.Add("HUDShouldDraw", "SardonYaratik.Binek", function(ad)
     if (ad == "CHudCrosshair" or ad == "CHudHealth" or ad == "CHudBattery") and IsValid(LocalPlayer()) and Y.Biniyor(LocalPlayer()) then
          return false
     end
end)

------------------------------------------------------------------------ Yön Duygusu listesi (Thestral)

local PANEL = {}

function PANEL:Init()
     local s = math_max(V.Olcek(), 0.8)
     self.s = s
     self:SetSize(440 * s, math_min(620 * s, ScrH() * 0.8))
     self:SetPos(ScrW() - self:GetWide() - V.Guvenli() - 40 * s, ScrH() / 2 - self:GetTall() / 2)
     self:MakePopup()
     self:SetKeyboardInputEnabled(false)
     self.liste = {}

     self.kaydir = vgui.Create("DScrollPanel", self)
     self.kaydir:Dock(FILL)
     self.kaydir:DockMargin(14 * s, 84 * s, 14 * s, 44 * s)
     local cubuk = self.kaydir:GetVBar()
     cubuk:SetWide(4 * s)
     cubuk.Paint = function(_, w, h) surface.SetDrawColor(R.iz) surface.DrawRect(0, 0, w, h) end
     cubuk.btnGrip.Paint = function(_, w, h) surface.SetDrawColor(R.sonuk) surface.DrawRect(0, 0, w, h) end
     cubuk.btnUp.Paint = function() end
     cubuk.btnDown.Paint = function() end
     surface.PlaySound("ui/buttonrollover.wav")
end

function PANEL:Kur(liste)
     local s = self.s
     self.liste = liste
     self.kaydir:Clear()
     if #liste == 0 then
          local bos = self.kaydir:Add("DLabel")
          bos:Dock(TOP)
          bos:SetTall(40 * s)
          bos:SetFont(V.Font("govde", 14, s))
          bos:SetTextColor(R.ikincil)
          bos:SetText("Thestral buradan hiçbir açık havaya yol sezemiyor.")
          bos:SetContentAlignment(5)
          return
     end
     for _, h in ipairs(liste) do
          local d = self.kaydir:Add("DButton")
          d:Dock(TOP)
          d:DockMargin(0, 0, 6 * s, 2 * s)
          d:SetTall(38 * s)
          d:SetText("")
          d.Paint = function(btn, w, hh)
               local ust = btn:IsHovered()
               if ust then
                    surface.SetDrawColor(R.ideal.r, R.ideal.g, R.ideal.b, 120)
                    surface.DrawRect(0, 0, w, hh)
               end
               surface.SetDrawColor(R.iz)
               surface.DrawRect(10 * s, hh - 1, w - 20 * s, 1)
               V.Baklava(16 * s, hh / 2, 3.5 * s, ust and R.altin or R.sonuk, 1, ust)
               V.Yazi(V.Kisalt(h.ad, V.Font("baslik", 17, s), w - 120 * s), V.Font("baslik", 17, s), 30 * s, hh / 2 + 6 * s, ust and R.yazi or R.yazi, 1, 0)
               V.Yazi(Mesafe(h.d), V.Font("govde", 13, s), w - 12 * s, hh / 2 + 5 * s, R.ikincil, 1, 2)
          end
          d.DoClick = function()
               surface.PlaySound("ui/buttonclickrelease.wav")
               Y.YonDuygusuSec(h.ad)
               self:Remove()
          end
     end
end

function PANEL:Paint(w, h)
     local s = self.s
     draw.NoTexture()
     surface.SetDrawColor(R.zemin.r, R.zemin.g, R.zemin.b, 245)
     surface.DrawRect(0, 0, w, h)
     surface.SetDrawColor(R.sonuk.r, R.sonuk.g, R.sonuk.b, 255)
     surface.DrawOutlinedRect(0, 0, w, h, 1)
     V.Ikon("wing", 30 * s, 34 * s, 28 * s, R.altin, 1)
     V.Aralikli("YÖN DUYGUSU", V.Font("govde", 12, s), 54 * s, 28 * s, R.altin, 1, 3 * s, 0)
     V.Yazi("Thestral seni nereye uçursun?", V.Font("baslik", 20, s), 54 * s, 56 * s, R.yazi, 1, 0)
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 90)
     surface.DrawRect(14 * s, 74 * s, w - 28 * s, 1)
     local f = V.Font("govde", 12, s)
     local x = 14 * s
     x = x + V.Ipucu("SOL TIK", "Seç", x, h - 22 * s, s, 1, R.ikincil) + 16 * s
     V.Ipucu("ESC", "Kapat", x, h - 22 * s, s, 1, R.ikincil)
end

function PANEL:OnMousePressed(kod)
     if kod == MOUSE_RIGHT then self:Remove() end
end

function PANEL:Think()
     if input.IsKeyDown(KEY_ESCAPE) then
          if gui.IsGameUIVisible() then gui.HideGameUI() end
          self:Remove()
          return
     end
     if not Y.Biniyor(LocalPlayer()) then self:Remove() end
end

function PANEL:OnRemove()
     if Y.YonPaneli == self then Y.YonPaneli = nil end
end

vgui.Register("SardonYaratik.YonDuygusu", PANEL, "EditablePanel")

function Y.YonDuygusuAc(liste)
     if IsValid(Y.YonPaneli) then Y.YonPaneli:Remove() end
     local p = vgui.Create("SardonYaratik.YonDuygusu")
     p:Kur(liste)
     Y.YonPaneli = p
end
