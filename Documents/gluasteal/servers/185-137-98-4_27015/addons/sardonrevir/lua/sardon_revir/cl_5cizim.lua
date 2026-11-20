-- "addons\\sardonrevir\\lua\\sardon_revir\\cl_5cizim.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Revir :: tedavi çizimi (Akran talim düzleminin revir hâli).
-- Hastanın üstüne bakarken asayla sol tık basılı çizilir; bırakınca noktalar sunucuya gider, puanı sunucu verir.
-- Büyüyü bilmiyorsan rün hayalet kılavuz olarak parlar (başlangıç halkası + akan kıvılcım); biliyorsan
-- yalnız başlangıç halkası görünür, rünü ezberden çizersin.

local R = SardonRevir
local SA = setmetatable({}, {__index = function(_, k) local A = SardonAkran return A and A[k] end}) -- akran sonradan yüklenebilir
local C = R.C

local MESAFE = 92
local EN_YAKIN = 30 -- düzlem engel yüzünden en çok buraya kadar yaklaşır
local OLCEK = 32
local AZAMI = 250
local KOSELER = {{0, 0}, {-0.9, 0.9}, {0.9, 0.9}, {-0.9, -0.9}, {0.9, -0.9}}

R.CizimModu = nil
local gosterilen = {}
local hudP
local BOS_P = {Patlama = function() end, Kul = function() end, Ciz = function() end, liste = {}}
local function HudP()
     if (!hudP and SardonAkran and SardonAkran.Parcacik) then hudP = SardonAkran.Parcacik() end
     return hudP or BOS_P
end

local M = {
     iz = Material("trails/laser"),
     isik = Material("sprites/light_glow02_add"),
     halka = Material("effects/select_ring"),
     dalga = Material("particle/particle_ring_wave_additive"),
     keskin = Material("particle/particle_ring_sharp"),
     parlak = Material("sprites/glow04_noz")
}

local function Duzlem(T, x, y) return T.merkez + T.sag * x + T.yuk * y end

local function AsaElde(ply)
     local w = ply:GetActiveWeapon()
     return IsValid(w) and string.find(w:GetClass(), "hpwr", 1, true) != nil
end

local function Tus()
     local O = SardonConfig and SardonConfig.Options
     if (O and O.revir_ciz) then return SardonConfig:Get("revir_ciz") end
     if (O and O.akran_talim) then return SardonConfig:Get("akran_talim") end
     return KEY_J
end

function R.CizimEsikC(h)
     local esik = R.Ayar.esik
     local t = h and h.teshis != "" and R.Hastalik(h.teshis)
     local char = LocalPlayer():GetCharacter()
     if (t and t.yol == "onarim") then esik = esik - 3 * R.Beceri(char, R.BECERI.NAZIK) end
     if (t and t.yol == "arindirma" and R.Beceri(char, R.BECERI.BERRAK) >= 2) then esik = esik - 3 end
     return math.max(40, esik)
end

function R.TutunmaC(buyu)
     local kademe = R.Ustalik(buyu)
     return math.Clamp(R.Ayar.tutunma + kademe * 12 + R.Beceri(LocalPlayer():GetCharacter(), R.BECERI.USTALIK) * 15, 0, 100)
end

function R.CizimBitir(sessiz)
     local T = R.CizimModu
     if (!T) then return end
     if (T.em) then T.em:Finish() end
     R.CizimModu = nil
     if (!sessiz) then surface.PlaySound("buttons/lightswitch2.wav") end
end

-- düzlem yatağa / duvara gömülmesin: merkez ve rün köşelerine ışın at, en yakın engelin önüne çek.
-- Yaklaşınca rün küçülür; kamera (thirdperson) gözün arkasında olduğundan ölçek kameradan aynı görünecek kadar.
local function DuzlemMesafe(ply, goz, ang)
     local fwd, sag, yuk = ang:Forward(), ang:Right(), ang:Up()
     local d = MESAFE
     for _, c in ipairs(KOSELER) do
          local tr = util.TraceLine({
               start = goz, endpos = goz + (fwd * MESAFE + sag * (c[1] * OLCEK) + yuk * (c[2] * OLCEK)) * 1.1,
               filter = ply, mask = MASK_SOLID_BRUSHONLY
          })
          if (tr.Hit and !tr.StartSolid) then d = math.min(d, MESAFE * 1.1 * tr.Fraction - 8) end
     end
     d = math.max(EN_YAKIN, d)
     local kam = 0
     if (ply.CanOverrideView and ply:CanOverrideView() and ix and ix.option) then kam = ix.option.Get("thirdpersonDistance", 50) end
     return d, (d + kam) / (MESAFE + kam)
end

function R.CizimBasla(id)
     local ply = LocalPlayer()
     local h = R.BenimHasta(id)
     if (!h or h.durum != "yatiyor") then return end
     local plan = R.PlanAdimC(h)
     if (!plan) then return R.Serit("Teşhis yok", "Önce masadaki Hastalık Defteri'nden teşhis koy.", "kotu") end
     if (plan[1] != "buyu") then return R.Serit("Sıradaki adım büyü değil", R.AdimYaz(plan), "kotu") end
     if (!AsaElde(ply)) then return R.Serit("Asanı eline al", "Rün asayla çizilir.", "kotu") end
     if (!ply:Alive() or ply:InVehicle()) then return end
     R.KartKapat()
     R.DiyalogKapat()

     local ea = ply:EyeAngles()
     local ang = Angle(math.Clamp(ea.p, -40, 30), ea.y, 0)
     local buyu = plan[2]
     R.Sablon(buyu)
     local mesafe, k = DuzlemMesafe(ply, ply:EyePos(), ang)
     R.CizimModu = {
          hasta = id, buyu = buyu, kilavuz = !R.Biliyor(buyu), esik = R.CizimEsikC(h),
          ang = ang, fwd = ang:Forward(), sag = ang:Right(), yuk = ang:Up(),
          merkez = ply:EyePos() + ang:Forward() * mesafe, k = k, olcek = OLCEK * k,
          noktalar = {}, ciziyor = false, acilis = RealTime(), renk = R.BuyuRenk(buyu)
     }
     if (SA and SA.Ses) then SA.Ses("buyu") end
     if (SA and SA.Patlat3D) then SA.Patlat3D(R.CizimModu.merkez, R.CizimModu.renk, 40, 50) end
end

-- tuş: bakılan / en yakın kendi hastan
hook.Add("PlayerButtonDown", "SardonRevir.Cizim", function(ply, tus)
     if (ply != LocalPlayer() or !IsFirstTimePredicted() or tus != Tus()) then return end
     if (!R.Nobet) then return end
     if (vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or vgui.CursorVisible()) then return end
     if (R.CizimModu) then return R.CizimBitir() end
     local b = R.Bakilan and R.Bakilan()
     local id = b and b.tur == "hasta" and b.id
     if (!id) then
          -- bakılmıyorsa yanındaki tek hasta
          local en, ed = nil, 200 * 200
          for _, h in ipairs(R.Nobet.hastalar) do
               local c = R.CA[h.id]
               if (h.durum == "yatiyor" and c and c.cizPos) then
                    local d = c.cizPos:DistToSqr(ply:GetPos())
                    if (d < ed) then en, ed = h.id, d end
               end
          end
          id = en
     end
     if (id) then R.CizimBasla(id) end
end)

hook.Add("CreateMove", "SardonRevir.Cizim", function(cmd)
     if (!R.CizimModu) then return end
     cmd:ClearMovement()
     cmd:RemoveKey(IN_ATTACK)
     cmd:RemoveKey(IN_ATTACK2)
     cmd:RemoveKey(IN_JUMP)
     cmd:RemoveKey(IN_RELOAD)
     cmd:RemoveKey(IN_USE)
     cmd:RemoveKey(IN_SPEED)
end)

hook.Add("AdjustMouseSensitivity", "SardonRevir.Cizim", function()
     if (R.CizimModu) then return 0.55 end
end)

hook.Add("HUDShouldDraw", "SardonRevir.Cizim", function(ad)
     if (R.CizimModu and ad == "CHudCrosshair") then return false end
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
     net.Start("SardonRevir.Cizim")
          net.WriteUInt(T.hasta, 16)
          net.WriteUInt(#secilen, 8)
          for _, p in ipairs(secilen) do
               net.WriteInt(math.Clamp(math.floor(p.x * 10), -32000, 32000), 16)
               net.WriteInt(math.Clamp(math.floor(p.y * 10), -32000, 32000), 16)
          end
          net.WriteVector(T.merkez)
          net.WriteAngle(T.ang)
     net.SendToServer()
end

local function CizimiTamamla(T)
     T.ciziyor = false
     local pts = T.noktalar
     T.noktalar = {}
     if (#pts < 8 or (SA and SA.Uzunluk and SA.Uzunluk(pts) < 18 * T.k)) then
          R.Serit("Çok kısa", "Rünü tek ve kesintisiz bir hareketle sonuna kadar çiz.", "kotu")
          return
     end
     T.bekleyen = {pts = pts}
     T.bekliyorT = RealTime() + 3
     Gonder(T, pts)
end

hook.Add("Think", "SardonRevir.Cizim", function()
     local T = R.CizimModu
     if (!T) then return end
     local ply = LocalPlayer()
     local h = R.BenimHasta(T.hasta)
     if (!IsValid(ply) or !ply:Alive() or !h or (h.durum != "yatiyor" and !T.kapanis)) then return R.CizimBitir(true) end
     if (T.kapanis and RealTime() > T.kapanis) then return R.CizimBitir(true) end
     if (!AsaElde(ply)) then return R.CizimBitir(true) end
     if (input.IsMouseDown(MOUSE_RIGHT) and !vgui.CursorVisible()) then return R.CizimBitir() end

     local basili = input.IsMouseDown(MOUSE_LEFT) and !vgui.CursorVisible() and !T.kapanis
     if (T.bekliyorT and RealTime() < T.bekliyorT) then basili = false end
     if (T.bekleyen and T.bekliyorT and RealTime() > T.bekliyorT + 2) then
          T.bekleyen, T.bekliyorT = nil, nil
          R.Serit("Sunucu cevap vermedi", "Rünü yeniden çiz.", "kotu")
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
               if (!son or (son.x - x) ^ 2 + (son.y - y) ^ 2 > 0.36 * T.k * T.k) then T.noktalar[#T.noktalar + 1] = {x = x, y = y} end
               if (#T.noktalar >= AZAMI) then CizimiTamamla(T) end
          end
     elseif (T.ciziyor) then
          CizimiTamamla(T)
     end
end)

net.Receive("SardonRevir.CizimSonuc", function()
     local skor = net.ReadUInt(7) / 100
     local sonuc = net.ReadString()
     local mesaj = net.ReadString()
     local esik = net.ReadUInt(7)
     local T = R.CizimModu
     if (T) then T.bekliyorT = nil end
     if (sonuc == "hata") then
          R.Serit("Rün sayılmadı", mesaj, "kotu")
          if (T) then T.bekleyen = nil end
          return
     end
     local kalite, renk = R.Kalite(skor, esik)
     if (T) then
          T.esik = esik
          T.sonSkor = {skor = skor, kalite = kalite, renk = renk, t = RealTime(), sonuc = sonuc, mesaj = mesaj}
          if (T.bekleyen) then
               gosterilen[#gosterilen + 1] = {merkez = T.merkez, sag = T.sag, yuk = T.yuk, pts = T.bekleyen.pts, basarili = sonuc == "uygulandi", renk = T.renk, bas = RealTime(), kendi = true, k = T.k}
          end
          T.bekleyen = nil
     end
     local ply = LocalPlayer()
     if (sonuc == "uygulandi") then
          ply:EmitSound("ambient/energy/whiteflash.wav", 70, 160, 0.35, CHAN_STATIC)
          HudP():Patlama(ScrW() / 2, 120, T and T.renk or C.altin, 40, 1.2)
          if (T) then T.kapanis = RealTime() + 1.3 end
     elseif (sonuc == "tutmadi") then
          ply:EmitSound("ambient/fire/ignite.wav", 60, 150, 0.3, CHAN_STATIC)
          HudP():Kul(ScrW() / 2, 120, Color(180, 170, 150), 26)
          R.Serit("Büyü tutunmadı", mesaj, "uyari")
     else
          ply:EmitSound("ambient/fire/ignite.wav", 60, 120, 0.3, CHAN_STATIC)
          HudP():Kul(ScrW() / 2, 120, Color(140, 130, 120), 30)
     end
end)

net.Receive("SardonRevir.CizimGoster", function()
     local merkez = net.ReadVector()
     local ang = net.ReadAngle()
     local basarili = net.ReadBool()
     local renk = net.ReadColor(false)
     local pts = {}
     for i = 1, net.ReadUInt(7) do pts[i] = {x = net.ReadInt(16) / 10, y = net.ReadInt(16) / 10} end
     gosterilen[#gosterilen + 1] = {merkez = merkez, sag = ang:Right(), yuk = ang:Up(), pts = pts, basarili = basarili, renk = renk, bas = RealTime()}
     if (#gosterilen > 12) then table.remove(gosterilen, 1) end
end)

--[[
*   3B
]]

local function YolCiz(d, a)
     local n = #d.pts
     if (n < 2) then return end
     local r = d.basarili and d.renk or Color(200, 110, 90)
     local k = d.k or 1
     render.SetMaterial(M.iz)
     render.StartBeam(n)
     for i, p in ipairs(d.pts) do
          render.AddBeam(d.merkez + d.sag * p.x + d.yuk * p.y, (d.basarili and 3.5 or 2.5) * k, i / n * 3, Color(r.r, r.g, r.b, 255 * a))
     end
     render.EndBeam()
end

local function GosterilenCiz()
     local now = RealTime()
     for i = #gosterilen, 1, -1 do
          local d = gosterilen[i]
          local t = (now - d.bas) / 2.4
          if (t >= 1) then
               table.remove(gosterilen, i)
          else
               -- kendi çizimin engelin / kendi gövdenin arkasında kalmasın
               if (d.kendi) then cam.IgnoreZ(true) end
               YolCiz(d, d.basarili and (1 - t) ^ 0.6 or (1 - t) ^ 2)
               if (d.basarili and t < 0.3) then
                    local f = t / 0.3
                    local b = (40 + f * 140) * (d.k or 1)
                    render.SetMaterial(M.dalga)
                    local nrm = d.sag:Cross(d.yuk)
                    render.DrawQuadEasy(d.merkez, -nrm, b, b, Color(d.renk.r, d.renk.g, d.renk.b, 200 * (1 - f)), 0)
                    render.DrawQuadEasy(d.merkez, nrm, b, b, Color(d.renk.r, d.renk.g, d.renk.b, 200 * (1 - f)), 0)
               end
               if (d.kendi) then cam.IgnoreZ(false) end
          end
     end
end

local function KendiCiz(T)
     local now = RealTime()
     local sablon = R.Sablon(T.buyu)
     if (!sablon) then return end
     local ham = sablon.ham
     local acilis = math.Clamp((now - T.acilis) / 0.6, 0, 1)
     local normal = -T.fwd
     local rk = T.renk
     local O, kat = T.olcek, T.k

     render.SetMaterial(M.halka)
     render.DrawQuadEasy(T.merkez - T.fwd * 2 * kat, normal, O * 3.1 * acilis, O * 3.1 * acilis, Color(rk.r, rk.g, rk.b, 70), now * 10 % 360)
     render.DrawQuadEasy(T.merkez - T.fwd * 2.5 * kat, normal, O * 2.6 * acilis, O * 2.6 * acilis, Color(rk.r, rk.g, rk.b, 40), -now * 14 % 360)
     render.SetMaterial(M.dalga)
     local d = (now * 0.5) % 1
     render.DrawQuadEasy(T.merkez - T.fwd * 3 * kat, normal, O * 3.2 * d, O * 3.2 * d, Color(rk.r, rk.g, rk.b, 60 * (1 - d)), 0)

     if (T.kilavuz) then
          local gorunen = math.floor(#ham * acilis)
          if (gorunen >= 2) then
               render.SetMaterial(M.iz)
               render.StartBeam(gorunen)
               for i = 1, gorunen do
                    local p = ham[i]
                    render.AddBeam(Duzlem(T, p.x * O, p.y * O), 1.4 * kat, i / gorunen * 4, Color(rk.r, rk.g, rk.b, 80))
               end
               render.EndBeam()
          end
          render.SetMaterial(M.isik)
          for i = 1, gorunen, 2 do
               local p = ham[i]
               local nab = 0.6 + 0.4 * math.sin(now * 3 - i * 0.15)
               render.DrawSprite(Duzlem(T, p.x * O, p.y * O), 6.5 * kat, 6.5 * kat, Color(rk.r, rk.g, rk.b, 170 * nab))
          end
          local u = (now * 0.42) % 1
          local bi = math.max(1, math.floor(u * #ham))
          for k = 0, 9 do
               local p = ham[math.max(1, bi - k * 2)]
               render.DrawSprite(Duzlem(T, p.x * O, p.y * O), (14 - k) * kat, (14 - k) * kat, Color(255, 245, 220, 240 * (1 - k / 10)))
          end
     end

     local b = ham[1]
     render.SetMaterial(M.keskin)
     local nab = 1 + math.sin(now * 5) * 0.15
     render.DrawQuadEasy(Duzlem(T, b.x * O, b.y * O), normal, 12 * nab * kat, 12 * nab * kat, Color(140, 255, 170, 240), 0)
     render.SetMaterial(M.isik)
     render.DrawSprite(Duzlem(T, b.x * O, b.y * O), 16 * kat, 16 * kat, Color(140, 255, 170, 220))
     if (T.kilavuz) then
          local s = ham[#ham]
          render.DrawSprite(Duzlem(T, s.x * O, s.y * O), 11 * kat, 11 * kat, Color(255, 180, 120, 220))
     end

     local pts = T.noktalar
     if (#pts >= 2) then
          render.SetMaterial(M.iz)
          render.StartBeam(#pts)
          for i, p in ipairs(pts) do
               local renk
               if (T.kilavuz and SA and SA.Yakinlik) then
                    p.yakin = p.yakin or SA.Yakinlik(ham, p.x / O, p.y / O, 0.28)
                    local f = p.yakin
                    renk = Color(220 + 35 * f, 90 + 130 * f, 70 + 80 * f, 255)
               else
                    renk = Color(rk.r, rk.g, rk.b, 255)
               end
               render.AddBeam(Duzlem(T, p.x, p.y), 2.6 * kat, i / #pts * 4 - now, renk)
          end
          render.EndBeam()
     end

     local _, _, nokta = NisanNoktasi(T)
     if (nokta) then
          render.SetMaterial(M.isik)
          local r = (T.ciziyor and 12 or 8) * kat
          render.DrawSprite(nokta, r, r, T.ciziyor and Color(rk.r, rk.g, rk.b) or Color(200, 220, 255, 180))
          render.SetMaterial(M.parlak)
          render.DrawSprite(nokta, r * 0.4, r * 0.4, color_white)
          if (T.ciziyor and math.random() < 0.5) then
               T.em = T.em or ParticleEmitter(nokta, false)
               if (T.em) then
                    T.em:SetPos(nokta)
                    local pr = T.em:Add("sprites/light_glow02_add", nokta)
                    if (pr) then
                         pr:SetVelocity(VectorRand() * 6 + Vector(0, 0, -8))
                         pr:SetDieTime(math.Rand(0.4, 0.9))
                         pr:SetStartAlpha(255)
                         pr:SetEndAlpha(0)
                         pr:SetStartSize(math.Rand(0.8, 1.8))
                         pr:SetEndSize(0)
                         pr:SetColor(rk.r, rk.g, rk.b)
                         pr:SetGravity(Vector(0, 0, -30))
                    end
               end
          end
     end
end

hook.Add("PostDrawTranslucentRenderables", "SardonRevir.Cizim", function(derinlik, gok)
     if (gok) then return end
     if (R.CizimModu) then
          cam.IgnoreZ(true) -- yatak, duvar ya da kendi gövden örtmesin
          ProtectedCall(KendiCiz, R.CizimModu)
          cam.IgnoreZ(false)
     end
     if (#gosterilen > 0) then GosterilenCiz() end
end)

--[[
*   ekran
]]

hook.Add("HUDPaint", "SardonRevir.CizimEkran", function()
     local T = R.CizimModu
     if (!T) then
          if (#HudP().liste > 0) then HudP():Ciz() end
          return
     end
     if (!SA or !SA.Kart) then return end
     R.Fontlar()
     local sablon = R.Sablon(T.buyu)
     local W, H = 640, T.kilavuz and 162 or 132
     local x, y = ScrW() / 2 - W / 2, 40
     SA.Kart(x, y, W, H, 0.94, 22)
     local h = R.BenimHasta(T.hasta)
     SA.Metin("TEDAVİ  ·  " .. string.upper(h and h.ad or ""), "ust", x + 20, y + 18, C.altinK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     SA.Metin(T.buyu, "baslik", x + 20, y + 42, T.renk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     local kademe = R.Ustalik(T.buyu)
     local sag = T.kilavuz and ("Bilmiyorsun · kılavuzu izle · tutunma %" .. R.TutunmaC(T.buyu)) or ("Biliyorsun · kılavuz yok · " .. R.UstalikAdlari[kademe])
     SA.Metin(sag, "kucuk", x + W - 20, y + 42, T.kilavuz and C.uyari or C.sifa, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     if (T.kilavuz) then
          for i, satir in ipairs(SA.Sar(sablon and sablon.tarif or "", "kucuk", W - 40)) do
               if (i > 2) then break end
               SA.Metin(satir, "kucuk", x + 20, y + 60 + i * 19, C.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
          end
     else
          SA.Metin("Rünü ezberden çiz: yeşil halkadan başla, tek hamlede bitir.", "kucuk", x + 20, y + 72, C.soluk, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
     end

     local by = y + H - 22
     local bx, bw = x + 20, W - 230
     surface.SetDrawColor(30, 36, 28, 230)
     draw.NoTexture()
     surface.DrawRect(bx, by, bw, 6)
     local esX = bx + bw * T.esik / 100
     surface.SetDrawColor(C.fildisi.r, C.fildisi.g, C.fildisi.b, 160)
     surface.DrawRect(esX, by - 3, 1, 12)
     local son = T.sonSkor
     if (son) then
          local anim = math.Clamp((RealTime() - son.t) / 0.5, 0, 1)
          local f = son.skor * (1 - (1 - anim) ^ 3)
          surface.SetDrawColor(son.renk.r, son.renk.g, son.renk.b, 255)
          surface.DrawRect(bx, by, bw * f, 6)
          SA.Isik(bx + bw * f, by + 3, 10, son.renk, 220)
          local yazi = son.sonuc == "tutmadi" and "Tutunmadı" or (son.sonuc == "uygulandi" and "Uygulandı" or son.kalite)
          SA.Metin(yazi .. "  %" .. math.floor(son.skor * 100), "alt", x + W - 20, by + 3, son.renk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     elseif (T.bekleyen) then
          SA.Metin("Değerlendiriliyor...", "alt", x + W - 20, by + 3, C.soluk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     else
          SA.Metin("eşik %" .. T.esik, "kucuk", x + W - 20, by + 3, C.sonuk, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
     end

     local tus = string.upper(input.GetKeyName(Tus()) or "J")
     local ipucu = T.kapanis and "Büyü uygulandı." or ("Sol tık basılı tut: çiz   ·   sağ tık / " .. tus .. ": bırak")
     local iw = SA.MetinG(ipucu, "alt") + 40
     SA.Kart(ScrW() / 2 - iw / 2, ScrH() - 222, iw, 38, 0.85, false)
     SA.Metin(ipucu, "alt", ScrW() / 2, ScrH() - 203, T.kapanis and C.altin or C.fildisi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     HudP():Ciz()
end)
