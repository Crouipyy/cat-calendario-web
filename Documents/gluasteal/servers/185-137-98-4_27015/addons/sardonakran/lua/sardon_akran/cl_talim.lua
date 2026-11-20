-- "addons\\sardonakran\\lua\\sardon_akran\\cl_talim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Akran Yardımı :: talim (rün çizimi)
--
-- Flagrate gibi: asanın baktığı yer havada iz bırakır. Talim modunda oyuncunun önünde (110 birim)
-- görünmez bir düzlem kurulur, büyünün rünü bu düzlemde hayalet olarak parlar (başlangıç halkası +
-- yönü gösteren akan kıvılcım). Sol tık basılıyken bakış ışınının düzlemi kestiği nokta kaydedilir;
-- bırakınca noktalar sunucuya gider, puanı sunucu hesaplar (SA.Benzerlik). İstemcideki aynı hesap
-- yalnızca canlı iz rengi ve anlık önizleme içindir.
--
-- Çizerken: hareket ve asa ateşi kesilir, fare hassasiyeti düşer. Sağ tık / talim tuşu çıkar.

-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_R_255_214_140_70 = Color(255, 214, 140, 70)
local OPT_R_200_180_120_40 = Color(200, 180, 120, 40)
local OPT_R_255_225_170_70 = Color(255, 225, 170, 70)
local OPT_R_140_255_170_240 = Color(140, 255, 170, 240)
local OPT_R_140_255_170_220 = Color(140, 255, 170, 220)
local OPT_R_255_180_120_220 = Color(255, 180, 120, 220)
local OPT_V_0_0_n8 = Vector(0, 0, -8)
local SA = SardonAkran
local R = SA.R
local M3 = SA.M3

local MESAFE = 110 -- düzlemin gözden uzaklığı
local OLCEK = 34 -- rünün yarı boyu (birim)
local AZAMI = 250

SA.CizimModu = nil

local gosterilen = {} -- başkalarının (ve kendi) bitmiş çizimleri: havada solar
local hudP = SA.Parcacik()

local function Duzlem(T, x, y)
     return T.merkez + T.sag * x + T.yuk * y
end

local function AsaElde(ply)
     local w = ply:GetActiveWeapon()
     return IsValid(w) and string.find(w:GetClass(), "hpwr", 1, true) != nil
end

function SA.TalimBitir(sessiz)
     local T = SA.CizimModu
     if (!T) then return end
     if (T.em) then T.em:Finish() end
     SA.CizimModu = nil
     if (!sessiz) then surface.PlaySound("buttons/lightswitch2.wav") end
end

function SA.TalimBasla()
     local ply = LocalPlayer()
     local g = SA.Gorev
     if (!g or g.asama != 3) then return end
     if (SA.CizimModu) then return SA.TalimBitir() end

     if (!ply:Alive() or ply:InVehicle()) then return end
     if (!SA.AlandaMi(ply:GetPos())) then return SA.Serit("Talim alanında değilsin", "Kartındaki pusulayı takip et.", "kotu") end
     if (!AsaElde(ply)) then return SA.Serit("Asanı eline al", "Rün asayla çizilir.", "kotu") end

     local ea = ply:EyeAngles()
     local ang = Angle(math.Clamp(ea.p, -25, 25), ea.y, 0)

     SA.CizimModu = {
          ang = ang,
          fwd = ang:Forward(),
          sag = ang:Right(),
          yuk = ang:Up(),
          merkez = ply:EyePos() + ang:Forward() * MESAFE,
          noktalar = {},
          ciziyor = false,
          acilis = RealTime(),
          buyu = g.buyu,
          sonSkor = nil
     }

     SA.Ses("buyu")
     SA.Patlat3D(SA.CizimModu.merkez, Color(255, 220, 150), 40, 50)
end

-- tuş (TAB > Ayarlar > Tuş Atamaları: "[Akran Yardımı] Talime Başla / Bitir")
hook.Add("PlayerButtonDown", "SardonAkran.Talim", function(ply, tus)
     if (ply != LocalPlayer() or !IsFirstTimePredicted()) then return end
     local atanan = SardonConfig and SardonConfig.Options and SardonConfig.Options.akran_talim and SardonConfig:Get("akran_talim") or KEY_J
     if (tus != atanan) then return end
     if (vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or vgui.CursorVisible()) then return end
     if (!SA.Gorev or SA.Gorev.asama != 3) then return end
     SA.TalimBasla()
end)

concommand.Add("sardon_akran_talim", function() SA.TalimBasla() end, nil, "Akran Yardımı talim modunu açar / kapatır")

-- çizim modunda yürüme ve asa ateşi kapalı
hook.Add("CreateMove", "SardonAkran.Talim", function(cmd)
     if (!SA.CizimModu) then return end
     cmd:ClearMovement()
     cmd:RemoveKey(IN_ATTACK)
     cmd:RemoveKey(IN_ATTACK2)
     cmd:RemoveKey(IN_JUMP)
     cmd:RemoveKey(IN_RELOAD)
     cmd:RemoveKey(IN_USE)
     cmd:RemoveKey(IN_SPEED)
end)

hook.Add("AdjustMouseSensitivity", "SardonAkran.Talim", function()
     if (SA.CizimModu) then return 0.55 end
end)

hook.Add("HUDShouldDraw", "SardonAkran.Talim", function(ad)
     if (SA.CizimModu and ad == "CHudCrosshair") then return false end
end)

local function NisanNoktasi(T)
     local ply = LocalPlayer()
     local goz, yon = ply:EyePos(), ply:GetAimVector()
     local payda = yon:Dot(T.fwd)
     if (payda < 0.15) then return nil end
     local t = (T.merkez - goz):Dot(T.fwd) / payda
     local p = goz + yon * t
     local d = p - T.merkez
     return d:Dot(T.sag), d:Dot(T.yuk), p
end

local function Gonder(T, pts)
     local adim = math.max(1, math.ceil(#pts / 200))
     local secilen = {}
     for i = 1, #pts, adim do secilen[#secilen + 1] = pts[i] end
     if (secilen[#secilen] != pts[#pts]) then secilen[#secilen + 1] = pts[#pts] end
     while (#secilen > 200) do table.remove(secilen, #secilen - 1) end

     net.Start("SardonAkran.Cizim")
          net.WriteUInt(#secilen, 8)
          for _, p in ipairs(secilen) do
               net.WriteInt(math.Clamp(math.floor(p.x * 10), -32000, 32000), 16)
               net.WriteInt(math.Clamp(math.floor(p.y * 10), -32000, 32000), 16)
          end
          net.WriteVector(T.merkez)
          net.WriteAngle(T.ang)
     net.SendToServer()
end

local function CizimiBitir(T)
     T.ciziyor = false
     local pts = T.noktalar
     T.noktalar = {}

     if (#pts < 8 or SA.Uzunluk(pts) < 18) then
          SA.Serit("Çok kısa", "Rünü tek ve kesintisiz bir hareketle sonuna kadar çiz.", "kotu")
          return
     end

     local onizleme = SA.Benzerlik(pts, T.buyu)
     T.bekleyen = {pts = pts, skor = onizleme}
     T.bekliyorT = RealTime() + 3
     Gonder(T, pts)
end

hook.Add("Think", "SardonAkran.Talim", function()
     local T = SA.CizimModu
     if (!T) then return end
     local ply = LocalPlayer()
     local g = SA.Gorev

     if (!IsValid(ply) or !ply:Alive() or !g or (g.asama != 3 and !T.kapanis)) then return SA.TalimBitir(true) end
     if (!SA.AlandaMi(ply:GetPos())) then
          SA.TalimBitir(true)
          return SA.Serit("Talim alanından çıktın", "Talim modu kapandı.", "kotu")
     end
     if (T.kapanis and RealTime() > T.kapanis) then return SA.TalimBitir(true) end
     if (!AsaElde(ply)) then return SA.TalimBitir(true) end

     -- sağ tık: çık
     if (input.IsMouseDown(MOUSE_RIGHT) and !vgui.CursorVisible()) then return SA.TalimBitir() end

     local basili = input.IsMouseDown(MOUSE_LEFT) and !vgui.CursorVisible() and !T.kapanis
     if (T.bekliyorT and RealTime() < T.bekliyorT) then basili = false end

     -- sunucu cevap vermediyse beklemede kalma
     if (T.bekleyen and T.bekliyorT and RealTime() > T.bekliyorT + 2) then
          T.bekleyen, T.bekliyorT = nil, nil
          SA.Serit("Sunucu cevap vermedi", "Rünü yeniden çiz.", "kotu")
     end

     if (basili) then
          local x, y = NisanNoktasi(T)
          if (x) then
               if (!T.ciziyor) then
                    T.ciziyor = true
                    T.noktalar = {}
                    ply:EmitSound("weapons/physcannon/energy_sing_flyby1.wav", 60, 180, 0.2, CHAN_STATIC)
               end
               local son = T.noktalar[#T.noktalar]
               if (!son or (son.x - x) ^ 2 + (son.y - y) ^ 2 > 0.36) then
                    T.noktalar[#T.noktalar + 1] = {x = x, y = y}
               end
               if (#T.noktalar >= AZAMI) then CizimiBitir(T) end
          end
     elseif (T.ciziyor) then
          CizimiBitir(T)
     end
end)

-- sunucu sonucu
net.Receive("SardonAkran.CizimSonuc", function()
     local skor = net.ReadUInt(7) / 100
     local basari = net.ReadUInt(8)
     local hata = net.ReadString()
     local T = SA.CizimModu
     local g = SA.Gorev

     if (T) then T.bekliyorT = nil end
     if (hata != "") then
          SA.Serit("Rün sayılmadı", hata, "kotu")
          if (T) then T.bekleyen = nil end
          return
     end

     local basarili = skor * 100 >= SA.Ayar.esik
     if (g) then g.basari = basari end

     local kalite, renk = SA.Kalite(skor)
     if (T) then
          T.sonSkor = {skor = skor, kalite = kalite, renk = renk, t = RealTime(), basarili = basarili}
          if (T.bekleyen) then
               gosterilen[#gosterilen + 1] = {kendi = true, T = T, merkez = T.merkez, sag = T.sag, yuk = T.yuk, pts = T.bekleyen.pts, basarili = basarili, bas = RealTime()}
          end
          T.bekleyen = nil
     end

     local ply = LocalPlayer()
     if (basarili) then
          ply:EmitSound("ambient/energy/whiteflash.wav", 70, 160, 0.35, CHAN_STATIC)
          hudP:Patlama(ScrW() / 2, 120, R.altin, 40, 1.2)
          if (g and basari >= SA.Ayar.basariGerek and T) then
               T.kapanis = RealTime() + 2.2
               SA.Ses("iyi")
          end
     else
          ply:EmitSound("ambient/fire/ignite.wav", 60, 120, 0.3, CHAN_STATIC)
          hudP:Kul(ScrW() / 2, 120, Color(140, 130, 120), 30)
     end
end)

-- başkalarının çizimi (sunucudan PVS ile)
net.Receive("SardonAkran.CizimGoster", function()
     local ply = net.ReadEntity()
     local merkez = net.ReadVector()
     local ang = net.ReadAngle()
     local basarili = net.ReadBool()
     local n = net.ReadUInt(7)
     local pts = {}
     for i = 1, n do pts[i] = {x = net.ReadInt(16) / 10, y = net.ReadInt(16) / 10} end
     if (ply == LocalPlayer()) then return end

     gosterilen[#gosterilen + 1] = {merkez = merkez, sag = ang:Right(), yuk = ang:Up(), pts = pts, basarili = basarili, bas = RealTime()}
     if (#gosterilen > 12) then table.remove(gosterilen, 1) end
end)

/*
*   3B çizim
*/

local function Parlat(liste, renk, yercekimi, mat, sayi)
     if (#liste == 0) then return end
     local em = ParticleEmitter(liste[1], false)
     if (!em) then return end
     local adim = math.max(1, math.floor(#liste / (sayi or 40)))
     for i = 1, #liste, adim do
          local p = em:Add(mat or "sprites/light_glow02_add", liste[i])
          if (p) then
               p:SetVelocity(VectorRand() * (mat and 8 or 26))
               p:SetGravity(Vector(0, 0, yercekimi or 0))
               p:SetDieTime(math.Rand(0.7, 1.6))
               p:SetStartAlpha(mat and 120 or 255)
               p:SetEndAlpha(0)
               p:SetStartSize(mat and math.Rand(3, 5) or math.Rand(1.5, 3.5))
               p:SetEndSize(mat and math.Rand(8, 12) or 0)
               p:SetRoll(math.Rand(0, 360))
               p:SetColor(renk.r, renk.g, renk.b)
               p:SetAirResistance(40)
          end
     end
     em:Finish()
end

local function YolCiz(d, a)
     local n = #d.pts
     if (n < 2) then return end
     local renk = d.basarili and Color(255, 214, 140, 255 * a) or Color(220, 110, 90, 200 * a)
     render.SetMaterial(M3.iz)
     render.StartBeam(n)
     for i, p in ipairs(d.pts) do
          render.AddBeam(d.merkez + d.sag * p.x + d.yuk * p.y, d.basarili and 3.5 or 2.5, i / n * 3, renk)
     end
     render.EndBeam()
end

local function GosterilenCiz()
     local now = RealTime()
     for i = #gosterilen, 1, -1 do
          local d = gosterilen[i]
          local t = (now - d.bas) / 2.6
          if (t >= 1) then
               table.remove(gosterilen, i)
          else
               if (!d.patladi) then
                    d.patladi = true
                    local konum = {}
                    for _, p in ipairs(d.pts) do konum[#konum + 1] = d.merkez + d.sag * p.x + d.yuk * p.y end
                    if (d.basarili) then
                         Parlat(konum, Color(255, 220, 150), 20, nil, 50)
                    else
                         Parlat(konum, Color(120, 110, 100), -30, "particle/smokesprites_0001", 18)
                    end
               end
               local a = d.basarili and (1 - t) ^ 0.6 or (1 - t) ^ 2
               YolCiz(d, a)
               if (d.basarili and t < 0.3) then
                    local f = t / 0.3
                    render.SetMaterial(M3.dalga)
                    local nrm = d.sag:Cross(d.yuk)
                    render.DrawQuadEasy(d.merkez, -nrm, 40 + f * 140, 40 + f * 140, Color(255, 220, 160, 200 * (1 - f)), 0)
                    render.DrawQuadEasy(d.merkez, nrm, 40 + f * 140, 40 + f * 140, Color(255, 220, 160, 200 * (1 - f)), 0)
               end
          end
     end
end

local function KendiCiz(T)
     local now = RealTime()
     local sablon = SA.Sablon(T.buyu)
     if (!sablon) then return end
     local ham = sablon.ham
     local acilis = math.Clamp((now - T.acilis) / 0.6, 0, 1)
     local normal = -T.fwd

     -- arka plan: dönen rün çemberleri
     render.SetMaterial(M3.halka)
     render.DrawQuadEasy(T.merkez - T.fwd * 2, normal, OLCEK * 3.1 * acilis, OLCEK * 3.1 * acilis, OPT_R_255_214_140_70, now * 10 % 360)
     render.DrawQuadEasy(T.merkez - T.fwd * 2.5, normal, OLCEK * 2.6 * acilis, OLCEK * 2.6 * acilis, OPT_R_200_180_120_40, -now * 14 % 360)
     render.SetMaterial(M3.dalga)
     local d = (now * 0.5) % 1
     render.DrawQuadEasy(T.merkez - T.fwd * 3, normal, OLCEK * 3.2 * d, OLCEK * 3.2 * d, Color(255, 220, 160, 60 * (1 - d)), 0)

     -- hayalet rün (görünüş sırayla açılır)
     local gorunen = math.floor(#ham * acilis)
     -- ince sürekli kılavuz çizgi
     if (gorunen >= 2) then
          render.SetMaterial(M3.iz)
          render.StartBeam(gorunen)
          for i = 1, gorunen do
               local p = ham[i]
               render.AddBeam(Duzlem(T, p.x * OLCEK, p.y * OLCEK), 1.4, i / gorunen * 4, OPT_R_255_225_170_70)
          end
          render.EndBeam()
     end
     render.SetMaterial(M3.isik)
     for i = 1, gorunen, 2 do
          local p = ham[i]
          local nab = 0.6 + 0.4 * math.sin(now * 3 - i * 0.15)
          render.DrawSprite(Duzlem(T, p.x * OLCEK, p.y * OLCEK), 6.5, 6.5, Color(255, 225, 170, 170 * nab))
     end

     -- yönü gösteren akan kıvılcım (kuyruklu)
     local u = (now * 0.42) % 1
     local bi = math.max(1, math.floor(u * #ham))
     for k = 0, 9 do
          local p = ham[math.max(1, bi - k * 2)]
          render.DrawSprite(Duzlem(T, p.x * OLCEK, p.y * OLCEK), 14 - k, 14 - k, Color(255, 235, 190, 240 * (1 - k / 10)))
     end

     -- başlangıç halkası, bitiş yıldızı
     local b, s = ham[1], ham[#ham]
     render.SetMaterial(M3.keskin)
     local nab = 1 + math.sin(now * 5) * 0.15
     render.DrawQuadEasy(Duzlem(T, b.x * OLCEK, b.y * OLCEK), normal, 12 * nab, 12 * nab, OPT_R_140_255_170_240, 0)
     render.SetMaterial(M3.isik)
     render.DrawSprite(Duzlem(T, b.x * OLCEK, b.y * OLCEK), 16, 16, OPT_R_140_255_170_220)
     render.DrawSprite(Duzlem(T, s.x * OLCEK, s.y * OLCEK), 11, 11, OPT_R_255_180_120_220)

     -- canlı iz: şablona yakın kısımlar altın, uzak kısımlar kızıl
     local pts = T.noktalar
     if (#pts >= 2) then
          render.SetMaterial(M3.iz)
          render.StartBeam(#pts)
          for i, p in ipairs(pts) do
               p.yakin = p.yakin or SA.Yakinlik(ham, p.x / OLCEK, p.y / OLCEK, 0.28)
               local f = p.yakin
               local renk = Color(220 + 35 * f, 90 + 130 * f, 70 + 80 * f, 255)
               render.AddBeam(Duzlem(T, p.x, p.y), 2.6, i / #pts * 4 - now, renk)
          end
          render.EndBeam()
     end

     -- asanın ucu (nişan)
     local x, y, nokta = NisanNoktasi(T)
     if (nokta) then
          render.SetMaterial(M3.isik)
          local r = T.ciziyor and 12 or 8
          render.DrawSprite(nokta, r, r, T.ciziyor and Color(255, 230, 170) or Color(200, 220, 255, 180))
          render.SetMaterial(M3.parlak)
          render.DrawSprite(nokta, r * 0.4, r * 0.4, color_white)

          if (T.ciziyor and math.random() < 0.5) then
               T.em = T.em or ParticleEmitter(nokta, false)
               local pr = T.em and T.em:Add("sprites/light_glow02_add", nokta)
               if (pr) then
                    pr:SetVelocity(VectorRand() * 6 + OPT_V_0_0_n8)
                    pr:SetDieTime(math.Rand(0.4, 0.9))
                    pr:SetStartAlpha(255)
                    pr:SetEndAlpha(0)
                    pr:SetStartSize(math.Rand(0.8, 1.8))
                    pr:SetEndSize(0)
                    pr:SetColor(255, 220, 150)
                    pr:SetGravity(Vector(0, 0, -30))
               end
          end
     end
end

hook.Add("PostDrawTranslucentRenderables", "SardonAkran.Talim", function(derinlik, gokyuzu)
     if (gokyuzu) then return end
     if (SA.CizimModu) then KendiCiz(SA.CizimModu) end
     if (#gosterilen > 0) then GosterilenCiz() end
end)

/*
*   ekran (çizim modunda)
*/

hook.Add("HUDPaint", "SardonAkran.TalimEkran", function()
     local T = SA.CizimModu
     if (!T) then
          if (#hudP.liste > 0) then hudP:Ciz() end
          return
     end
     SA.Fontlar()
     local g = SA.Gorev
     local sablon = SA.Sablon(T.buyu)
     local W, H = 620, 152
     local x, y = ScrW() / 2 - W / 2, 40

     SA.Kart(x, y, W, H, 0.94, 22)
     SA.Metin("TALİM  ·  RÜNÜ ÇİZ", "ust", x + 20, y + 18, R.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     SA.Metin(T.buyu, "baslik", x + 20, y + 42, R.fildisi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

     -- başarı mühürleri
     local gerek = SA.Ayar.basariGerek
     local basari = g and g.basari or 0
     for i = 1, gerek do
          local cx = x + W - 24 - (gerek - i) * 26
          if (i <= basari) then
               SA.Isik(cx, y + 30, 14, R.altin, 160)
               SA.Yildiz(cx, y + 30, 8, R.altin, 255)
          else
               SA.Halka(cx, y + 30, 7, 1.2, R.sonuk, 160, 20)
          end
     end

     for i, satir in ipairs(SA.Sar(sablon and sablon.tarif or "", "kucuk", W - 40)) do
          if (i > 2) then break end
          SA.Metin(satir, "kucuk", x + 20, y + 60 + i * 19, R.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end

     -- son deneme: puan çubuğu + eşik çizgisi
     local by = y + H - 22
     local bx, bw = x + 20, W - 230
     surface.SetDrawColor(30, 36, 28, 230)
     draw.NoTexture()
     surface.DrawRect(bx, by, bw, 6)
     local esX = bx + bw * SA.Ayar.esik / 100
     surface.SetDrawColor(R.fildisi.r, R.fildisi.g, R.fildisi.b, 160)
     surface.DrawRect(esX, by - 3, 1, 12)

     local son = T.sonSkor
     if (son) then
          local anim = math.Clamp((RealTime() - son.t) / 0.5, 0, 1)
          local f = son.skor * (1 - (1 - anim) ^ 3)
          surface.SetDrawColor(son.renk.r, son.renk.g, son.renk.b, 255)
          surface.DrawRect(bx, by, bw * f, 6)
          SA.Isik(bx + bw * f, by + 3, 10, son.renk, 220)
          SA.Metin(son.kalite .. "  %" .. math.floor(son.skor * 100), "alt", x + W - 20, by + 3, son.renk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     elseif (T.bekleyen) then
          SA.Metin("Değerlendiriliyor...", "alt", x + W - 20, by + 3, R.soluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     else
          SA.Metin("eşik %" .. SA.Ayar.esik, "kucuk", x + W - 20, by + 3, R.sonuk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     end

     -- alt ipucu
     local tus = SardonConfig and SardonConfig.Options and SardonConfig.Options.akran_talim and input.GetKeyName(SardonConfig:Get("akran_talim")) or "J"
     local ipucu = T.kapanis and "Rün tamam! Öğretmeninin onayını bekle." or ("Sol tık basılı tut: çiz   ·   yeşil halkadan başla, kıvılcımı izle   ·   sağ tık / " .. string.upper(tus or "J") .. ": bitir")
     local iw = SA.MetinG(ipucu, "alt") + 40
     SA.Kart(ScrW() / 2 - iw / 2, ScrH() - 222, iw, 38, 0.85, false)
     SA.Metin(ipucu, "alt", ScrW() / 2, ScrH() - 203, T.kapanis and R.altin or R.fildisi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

     -- öğretmen durumu
     if (g) then
          local t = SA.CharOyuncu(g.ogretmen)
          local ok = IsValid(t) and t:Alive() and t:GetPos():Distance(LocalPlayer():GetPos()) <= SA.Ayar.ogretmenMesafe
          SA.Metin(ok and ("Öğretmenin " .. (g.ogretmenAd or "") .. " izliyor") or ("Öğretmenin " .. (g.ogretmenAd or "") .. " yakında değil, çizimler sayılmaz"), "kucuk", ScrW() / 2, y + H + 14, ok and R.adacayi or R.uyari, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end

     hudP:Ciz()
end)
