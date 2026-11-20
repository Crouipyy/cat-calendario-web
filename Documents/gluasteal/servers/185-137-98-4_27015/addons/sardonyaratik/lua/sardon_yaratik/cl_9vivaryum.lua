-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_9vivaryum.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: kişisel vivaryum — istemci (2026-11-10; sunucu sv_9vivaryum.lua, ortak _sh_7dunya.lua)
--
-- Ev gizleme: göz vivaryum bahçesindeyken evin (statik prop) malzemelerine $flags NO_DRAW; çıkınca geri.
-- Giriş: sahibin elinde Yakalama Çantası açılır (iki elin arası, bodygroup açık), yere koyma jestiyle zemine
-- iner; sonra kişi bir adım atar ve çantanın ağzına doğru dönerek çekilir (kemik dönüşümü, girdap parıltısı,
-- ışık, ses); çanta kapanır, ekran kararır. İçeride çıkış sütunundan, dışarıda çantanın ağzından aynı efektin
-- tersiyle belirilir. Ziyaret isteği paneli ve sahibin yemlik/yuva yerleştirme önizlemesi de burada.

local Y = SardonYaratik
local A = Y.Ayar
local V = A.Viv
local R = Y.R

local YUKARI = Vector(0, 0, 1)
local math_Clamp, CurTime = math.Clamp, CurTime

local function Yumusak(x) x = math_Clamp(x, 0, 1) return x * x * (3 - 2 * x) end

------------------------------------------------------------------------ bahçedeki evi gizle

local evGizli = false
local evMalz

local function EvMalzemeleri()
     if evMalz then return evMalz end
     evMalz = {}
     for _, ad in ipairs(Y.EvMalzeme or {}) do
          local m = Material(ad)
          if m and not m:IsError() then evMalz[#evMalz + 1] = m end
     end
     return evMalz
end

local function EvGizle(gizle)
     evGizli = gizle
     for _, m in ipairs(EvMalzemeleri()) do
          local f = m:GetInt("$flags") or 0
          if gizle then m:SetInt("$flags", bit.bor(f, 4)) else m:SetInt("$flags", bit.band(f, bit.bnot(4))) end
     end
end
Y.VivEvGizle = EvGizle

hook.Add("PreRender", "SardonYaratik.VivEv", function()
     local ic = Y.AlanVar() and Y.AlanIcinde(EyePos(), 300) or false
     if ic ~= evGizli then EvGizle(ic) end
end)

------------------------------------------------------------------------ çekilme / belirme (kemik dönüşümü)

local DONUS = math.pi * 2.6     -- gövdenin çanta ağzı çevresinde dönüşü (hızlanarak)
local BURGU = math.pi * 1.2     -- ayakla baş arasındaki burulma
local BW = Matrix()

Y.VivCek = Y.VivCek or {}       -- [oyuncu] = {B, t0, dur, ters, taban, boy, parcaCb}

local function Uygula(ent, s, liste)
     local p = math_Clamp((CurTime() - s.t0) / s.dur, 0, 1)
     if s.ters then p = 1 - p end
     if p <= 0.001 then return end
     local e = Yumusak(p)
     local B = s.B
     local bx, by, bz = B.x, B.y, B.z
     local donus = DONUS * p * p
     local n = liste and #liste or ent:GetBoneCount()
     for k = 1, n do
          local i = liste and liste[k] or (k - 1)
          local m = ent:GetBoneMatrix(i)
          if m then
               local h = math_Clamp((m:GetTranslation().z - s.taban) / s.boy, 0, 1)
               -- ayaklar önce girer, baş biraz geriden gelir
               local f = math_Clamp(e * (1.3 - 0.4 * h), 0, 1)
               local sq = 1 - 0.985 * f
               local sz = 1 - 0.985 * math.min(1, f * 1.08)
               local a = donus + BURGU * h * f
               local c, sn = math.cos(a) * sq, math.sin(a) * sq
               BW:SetUnpacked(
                    c, -sn, 0, bx - (c * bx - sn * by),
                    sn, c, 0, by - (sn * bx + c * by),
                    0, 0, sz, bz - sz * bz,
                    0, 0, 0, 1)
               ent:SetBoneMatrix(i, BW * m)
          end
     end
end

-- oyuncunun geri çağrısı kalıcı (bir kez eklenir), iş Y.VivCekUygula'da: canlı yenilemede yeni kod geçer
function Y.VivCekUygula(ent)
     local s = Y.VivCek[ent]
     if s then Uygula(ent, s) end
end

function Y.VivCekParca(ent, ply, liste)
     local s = Y.VivCek[ply]
     if s and IsValid(ply) then Uygula(ent, s, liste) end
end

local function ParcalariBagla(ply, s)
     s.parcaCb = {}
     for _, e in ipairs(ply:GetChildren()) do
          if IsValid(e) and e:IsEffectActive(EF_BONEMERGE) then
               local liste = {}
               for b = 0, e:GetBoneCount() - 1 do
                    local ad = e:GetBoneName(b)
                    if ad and ad ~= "__INVALIDBONE__" and not ply:LookupBone(ad) then liste[#liste + 1] = b end
               end
               if #liste > 0 then
                    s.parcaCb[e] = e:AddCallback("BuildBonePositions", function(ce) Y.VivCekParca(ce, ply, liste) end)
               end
          end
     end
end

local function CekBitir(ply)
     local s = Y.VivCek[ply]
     if not s then return end
     for e, id in pairs(s.parcaCb or {}) do
          if IsValid(e) then e:RemoveCallback("BuildBonePositions", id) end
     end
     Y.VivCek[ply] = nil
end

local function CekBasla(ply, B, t0, dur, ters)
     if not IsValid(ply) then return end
     CekBitir(ply)
     if not ply.YVivCb then
          ply.YVivCb = ply:AddCallback("BuildBonePositions", function(ent) if Y.VivCekUygula then Y.VivCekUygula(ent) end end)
     end
     local s = {B = B, t0 = t0, dur = math.max(dur, 0.1), ters = ters, taban = ply:GetPos().z, boy = 72 * math.max(ply:GetModelScale(), 0.5)}
     Y.VivCek[ply] = s
     ParcalariBagla(ply, s)
end

------------------------------------------------------------------------ parçacık, ışık, ses

Y.VivEfekt = Y.VivEfekt or {}    -- {B, bas, son, ters, renk}

local function EfektEkle(B, bas, son, ters)
     table.insert(Y.VivEfekt, {B = B, bas = bas, son = son, ters = ters})
end

local em
local function Emitter(p)
     if not em or not em:IsValid() then em = ParticleEmitter(p, false) end
     em:SetPos(p)
     return em
end

local function Girdap(f, simdi)
     local B = f.B
     local e = Emitter(B)
     local yogun = Yumusak((simdi - f.bas) / 0.35) * (1 - Yumusak((simdi - f.son + 0.25) / 0.25))
     for _ = 1, math.ceil(4 * yogun) do
          local aci = math.Rand(0, math.pi * 2)
          local r = math.Rand(30, 110)
          local ofs = Vector(math.cos(aci) * r, math.sin(aci) * r, math.Rand(-8, 70))
          local icerik = -ofs:GetNormalized()
          local teget = Vector(-math.sin(aci), math.cos(aci), 0)
          local p = f.ters and (B + ofs * 0.12) or (B + ofs)
          local hiz = f.ters and (-icerik * r * 2.2 + teget * 90) or (icerik * r * 2.4 + teget * 110)
          local part = e:Add("sprites/light_glow02_add", p)
          if part then
               part:SetVelocity(hiz)
               part:SetDieTime(math.Rand(0.35, 0.55))
               part:SetStartAlpha(230)
               part:SetEndAlpha(0)
               part:SetStartSize(math.Rand(2.5, 6))
               part:SetEndSize(0.5)
               if math.random() < 0.65 then part:SetColor(255, math.random(200, 230), 140) else part:SetColor(170, 235, 160) end
               part:SetAirResistance(20)
          end
          -- toz ve kuru yaprak kırıntısı
          if math.random() < 0.25 then
               local d = e:Add("particle/particle_smokegrenade", B + Vector(ofs.x, ofs.y, math.Rand(0, 12)) * (f.ters and 0.2 or 1))
               if d then
                    d:SetVelocity(f.ters and (-icerik * 120 + YUKARI * 20) or (icerik * 140 + teget * 60))
                    d:SetDieTime(0.6)
                    d:SetStartAlpha(50)
                    d:SetEndAlpha(0)
                    d:SetStartSize(8)
                    d:SetEndSize(2)
                    d:SetColor(150, 130, 100)
                    d:SetRoll(math.Rand(0, 360))
               end
          end
     end
end

hook.Add("Think", "SardonYaratik.VivEfekt", function()
     if #Y.VivEfekt == 0 then return end
     local simdi = CurTime()
     local goz = EyePos()
     for i = #Y.VivEfekt, 1, -1 do
          local f = Y.VivEfekt[i]
          if simdi > f.son then
               table.remove(Y.VivEfekt, i)
          elseif simdi >= f.bas and goz:DistToSqr(f.B) < 2500 * 2500 then
               if not f.ses then
                    f.ses = true
                    sound.Play("ambient/wind/wind_snippet2.wav", f.B, 68, f.ters and 150 or 135, 0.55)
               end
               Girdap(f, simdi)
               local dl = DynamicLight(53200 + i)
               if dl then
                    dl.pos = f.B + YUKARI * 8
                    dl.r, dl.g, dl.b = 255, 214, 150
                    dl.brightness = 2.2 * (1 - Yumusak((simdi - f.son + 0.3) / 0.3))
                    dl.size = 180
                    dl.decay = 800
                    dl.dietime = simdi + 0.15
               end
          end
     end
end)

-- çanta ağzına doğru dönerek daralan ışık sarmalı + ağızda çekirdek ışıltısı (parçacıklar parlak ortamda seçilmiyor)
local PARILTI = Material("sprites/light_glow02_add")
local SARMAL_RENK = Color(255, 222, 150)
local SARMAL_YESIL = Color(180, 240, 170)

hook.Add("PostDrawTranslucentRenderables", "SardonYaratik.VivSarmal", function(derinlik, gok)
     if derinlik or gok or #Y.VivEfekt == 0 then return end
     local simdi = CurTime()
     local goz = EyePos()
     render.SetMaterial(PARILTI)
     for _, f in ipairs(Y.VivEfekt) do
          if simdi >= f.bas and simdi <= f.son and goz:DistToSqr(f.B) < 2500 * 2500 then
               local u = math_Clamp((simdi - f.bas) / math.max(f.son - f.bas, 0.1), 0, 1)
               local guc = Yumusak(u / 0.2) * (1 - Yumusak((u - 0.85) / 0.15))
               local B = f.B
               -- üç kollu sarmal: kollar dışarıdan ağza (tersinde ağızdan dışarı) akar
               for kol = 0, 2 do
                    for j = 0, 9 do
                         local q = ((simdi * 1.6 + j / 10 + kol / 3) % 1)
                         local d = f.ters and q or (1 - q)
                         local r = 8 + d * 95
                         local a = kol * 2.094 + d * 5.5 + simdi * 7
                         local z = d * 75
                         local p = B + Vector(math.cos(a) * r, math.sin(a) * r, z)
                         local boy = (3 + (1 - d) * 7) * guc
                         local renk = (j % 3 == 0) and SARMAL_YESIL or SARMAL_RENK
                         render.DrawSprite(p, boy, boy, Color(renk.r, renk.g, renk.b, 230 * guc * (0.4 + 0.6 * (1 - d))))
                    end
               end
               local cek = 26 + 14 * math.sin(simdi * 18)
               render.DrawSprite(B, cek * guc * 2, cek * guc, Color(255, 236, 190, 210 * guc))
               render.DrawSprite(B + YUKARI * 4, 70 * guc, 22 * guc, Color(255, 210, 140, 120 * guc))
          end
     end
end)

local function Puf(p)
     local e = Emitter(p)
     for _ = 1, 14 do
          local d = e:Add("particle/particle_smokegrenade", p + VectorRand() * 6)
          if d then
               local v = VectorRand()
               v.z = math.abs(v.z) * 0.5
               d:SetVelocity(v * math.Rand(40, 90))
               d:SetDieTime(math.Rand(0.6, 1.1))
               d:SetStartAlpha(70)
               d:SetEndAlpha(0)
               d:SetStartSize(6)
               d:SetEndSize(18)
               d:SetColor(170, 150, 120)
               d:SetRoll(math.Rand(0, 360))
               d:SetAirResistance(80)
          end
     end
     for _ = 1, 8 do
          local s = e:Add("sprites/light_glow02_add", p + VectorRand() * 4)
          if s then
               s:SetVelocity(VectorRand() * 70)
               s:SetDieTime(0.5)
               s:SetStartAlpha(220)
               s:SetEndAlpha(0)
               s:SetStartSize(4)
               s:SetEndSize(0)
               s:SetColor(255, 220, 150)
          end
     end
end

------------------------------------------------------------------------ elde çanta (sahibin girişi)

Y.VivElde = Y.VivElde or {}      -- [oyuncu] = {t0, p, yaw, ent}

local function EldeBitir(ply)
     local s = Y.VivElde[ply]
     if s and IsValid(s.ent) then s.ent:Remove() end
     Y.VivElde[ply] = nil
end

hook.Add("PostPlayerDraw", "SardonYaratik.VivElde", function(ply)
     local s = Y.VivElde[ply]
     if not s then return end
     local t = CurTime() - s.t0
     if t > V.T.birak + 0.1 or not ply:Alive() then EldeBitir(ply) return end
     if not IsValid(s.ent) then
          s.ent = ClientsideModel(A.CuvalModel, RENDERGROUP_OPAQUE)
          if not IsValid(s.ent) then Y.VivElde[ply] = nil return end
          s.ent:SetNoDraw(true)
          s.bg = s.ent:FindBodygroupByName("state")
     end
     local ent = s.ent
     local E = SardonEylem
     if E and E.Tutuslar and not E.Tutuslar.vivcanta then E.Tutuslar.vivcanta = {ikiEl = true, boy = 22} end
     if s.bg and s.bg >= 0 then ent:SetBodygroup(s.bg, t >= V.T.ac and 1 or 0) end
     if t < V.T.koy then
          if not (E and E.EsyaYerlestir and E.EsyaYerlestir(ply, ent, "vivcanta")) then
               local p = ply:GetPos() + ply:GetForward() * 18 + YUKARI * 40
               ent:SetPos(p)
               ent:SetAngles(Angle(0, ply:EyeAngles().y + 90, 0))
          end
          s.elPos, s.elAci, s.elOlcek = ent:GetPos(), ent:GetAngles(), ent:GetModelScale()
     else
          -- yere koyma jestiyle zemine iner
          local f = Yumusak((t - V.T.koy) / (V.T.birak - V.T.koy))
          local hedefAci = Angle(0, s.yaw + 90, 0)
          ent:SetModelScale(Lerp(f, s.elOlcek or 1, 1), 0)
          ent:SetPos(LerpVector(f, s.elPos or s.p, s.p))
          ent:SetAngles(LerpAngle(f, s.elAci or hedefAci, hedefAci))
          ent:SetupBones()
     end
     ent:DrawModel()
     -- açılırken ağzından ışıltı
     if t >= V.T.ac and not s.acildi then
          s.acildi = true
          sound.Play("items/ammocrate_open.wav", ent:GetPos(), 60, 130, 0.5)
          Puf(ent:GetPos() + YUKARI * 8)
     end
end)

------------------------------------------------------------------------ kararma

local karar = {t0 = 0, sure = 0}

hook.Add("HUDPaint", "SardonYaratik.VivKarar", function()
     local t = CurTime() - karar.t0
     local top = karar.sure * 2 + 0.5
     if t > top or karar.sure <= 0 then return end
     local a
     if t < karar.sure then a = t / karar.sure
     elseif t < karar.sure + 0.5 then a = 1
     else a = 1 - (t - karar.sure - 0.5) / karar.sure end
     surface.SetDrawColor(0, 0, 0, math_Clamp(a, 0, 1) * 255)
     surface.DrawRect(0, 0, ScrW(), ScrH())
end)

------------------------------------------------------------------------ ziyaret isteği paneli

local ISTEK = {}

function ISTEK:Init()
     local s = math.max(ScrH() / 1080, 0.6)
     self.s = s
     self:SetSize(520 * s, 168 * s)
     self:SetPos((ScrW() - self:GetWide()) / 2, ScrH() * 0.62)
     self:MakePopup()
     self:SetKeyboardInputEnabled(false)
     self.acilis = RealTime()
     local function Dugme(yazi, x, op, renk)
          local b = self:Add("DButton")
          b:SetText("")
          b:SetSize(160 * s, 38 * s)
          b:SetPos(x, self:GetTall() - 52 * s)
          b.Paint = function(d, w, h)
               local ust = d:IsHovered()
               surface.SetDrawColor(ust and 34 or 16, ust and 44 or 30, ust and 30 or 24, 250)
               surface.DrawRect(0, 0, w, h)
               surface.SetDrawColor(renk.r, renk.g, renk.b, 255)
               surface.DrawOutlinedRect(0, 0, w, h, 1)
               draw.SimpleText(yazi, Y.Font(16 * s, "baslik"), w / 2, h / 2, ust and R.parlak or renk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
          b.DoClick = function()
               surface.PlaySound("ui/buttonclickrelease.wav")
               Y.Islem("viv_cevap", 0, op)
               self:Remove()
          end
     end
     Dugme("İÇERİ AL", self:GetWide() / 2 - 170 * s, "kabul", R.altin)
     Dugme("GERİ ÇEVİR", self:GetWide() / 2 + 10 * s, "red", R.hata)
end

function ISTEK:Think()
     if RealTime() - self.acilis > (self.sure or 60) then self:Remove() end
end

function ISTEK:Paint(w, h)
     local s = self.s
     surface.SetDrawColor(7, 18, 13, 245)
     surface.DrawRect(0, 0, w, h)
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 255)
     surface.DrawRect(0, 0, w, 2 * s)
     surface.SetDrawColor(58, 70, 52, 255)
     surface.DrawOutlinedRect(0, 0, w, h, 1)
     draw.SimpleText("ÇANTANIN KAPAĞI ÇALINIYOR", Y.Font(17 * s, "baslik"), 16 * s, 12 * s, R.altin)
     local kalan = math.max(0, math.ceil((self.sure or 60) - (RealTime() - self.acilis)))
     draw.SimpleText(kalan .. " sn", Y.Font(16 * s, 400), w - 16 * s, 13 * s, R.sonuk, TEXT_ALIGN_RIGHT)
     draw.SimpleText((self.kimden or "?") .. " vivaryumuna girmek istiyor.", Y.Font(17 * s, 600), 16 * s, 46 * s, R.parlak)
     draw.SimpleText("İçeri alırsan çantadan çekilip yanına gelir.", Y.Font(16 * s, 400), 16 * s, 74 * s, R.sonuk)
end

vgui.Register("SardonYaratik.VivIstek", ISTEK, "EditablePanel")

------------------------------------------------------------------------ olaylar

Y.VivCantaSars = Y.VivCantaSars or {}

local OLAY = {}

OLAY.gir = function(ply, v)
     if not IsValid(ply) then return end
     local T = V.T
     local t0 = tonumber(v.t0) or CurTime()
     local p = v.p
     if not isvector(p) then return end
     if not v.ziyaret then
          Y.VivElde[ply] = {t0 = t0, p = p, yaw = tonumber(v.yaw) or 0}
     end
     local B = p + YUKARI * V.AgizYuksek
     EfektEkle(B, t0 + T.cekil - 0.45, t0 + T.cekil + T.cekilSure + 0.1, false)
     -- çekilme jestin sonunda başlar: zamanı gelince kur (oyuncunun konumu adımdan sonra)
     timer.Simple(math.max(t0 + T.cekil - CurTime(), 0), function()
          if not IsValid(ply) then return end
          CekBasla(ply, B, t0 + T.cekil, T.cekilSure, false)
          timer.Simple(T.cekilSure + 0.3, function() if IsValid(ply) then CekBitir(ply) end end)
     end)
     timer.Simple(math.max(t0 + T.kapan - CurTime(), 0), function() Puf(p + YUKARI * 6) end)
end

-- içeride (çıkış sütunundan) ya da dışarıda (çantanın ağzından) belirme: çekilmenin tersi
OLAY.belir = function(ply, v)
     if not IsValid(ply) or not isvector(v.B) then return end
     local t0, sure = tonumber(v.t0) or CurTime(), tonumber(v.sure) or 0.9
     CekBasla(ply, v.B, t0, sure, true)
     EfektEkle(v.B, t0 - 0.1, t0 + sure, true)
     timer.Simple(math.max(t0 + sure - CurTime(), 0) + 0.1, function() if IsValid(ply) then CekBitir(ply) end end)
end

-- içeride çıkış sütununa çekilme
OLAY.cik = function(ply, v)
     if not IsValid(ply) or not isvector(v.B) then return end
     local t0, sure = tonumber(v.t0) or CurTime(), tonumber(v.sure) or 0.9
     CekBasla(ply, v.B, t0, sure, false)
     EfektEkle(v.B, t0 - 0.2, t0 + sure, false)
     timer.Simple(math.max(t0 + sure - CurTime(), 0) + 0.3, function() if IsValid(ply) then CekBitir(ply) end end)
end

OLAY.karar = function(_, v)
     karar.t0, karar.sure = CurTime(), tonumber(v.sure) or 0.35
end

OLAY.puf = function(_, v)
     if isvector(v.p) then Puf(v.p) end
end

OLAY.sars = function(_, v)
     if tonumber(v.e) then Y.VivCantaSars[tonumber(v.e)] = CurTime() + 0.5 end
end

OLAY.istek = function(_, v)
     if IsValid(Y.VivIstekPanel) then Y.VivIstekPanel:Remove() end
     local p = vgui.Create("SardonYaratik.VivIstek")
     p.kimden, p.sure = v.ad, tonumber(v.sure) or 60
     Y.VivIstekPanel = p
     surface.PlaySound("physics/wood/wood_box_impact_soft1.wav")
     surface.PlaySound("ambient/levels/canals/windchime2.wav")
end

net.Receive(Y.NET.VIV, function()
     local op = net.ReadString()
     local ply = net.ReadEntity()
     local veri = net.ReadTable() or {}
     local f = OLAY[op]
     if not f then return end
     -- başka bir dünyadaki oyuncunun olayı (varlığı bu istemcide yok ya da uyuyor)
     if IsValid(ply) and ply:IsDormant() then return end
     local ok, hata = pcall(f, ply, veri)
     if not ok then ErrorNoHalt("[Sardon Yaratık] vivaryum olayı " .. op .. ": " .. tostring(hata) .. "\n") end
end)

------------------------------------------------------------------------ yemlik / yuva yerleştirme (sahip)

Y.VivYer = nil -- {cesit, yaw, p, uygun, neden, modeller}

local function YerBitir()
     local s = Y.VivYer
     if s then
          for _, m in pairs(s.modeller or {}) do if IsValid(m) then m:Remove() end end
     end
     Y.VivYer = nil
end

function Y.VivYerlestirBasla(cesit)
     YerBitir()
     if not Y.KendiDunyasinda(LocalPlayer()) then
          Y.Bildirim("Yemliğini ve yuvanı kendi vivaryumunda taşıyabilirsin (Yakalama Çantası › Vivaryuma Gir).", "hata")
          return
     end
     Y.VivYer = {cesit = cesit, yaw = math.NormalizeAngle(LocalPlayer():EyeAngles().y + 180), modeller = {}}
     if IsValid(ix and ix.gui and ix.gui.menu) then ix.gui.menu:Remove() end
     surface.PlaySound("ui/buttonclick.wav")
end

hook.Add("Think", "SardonYaratik.VivYer", function()
     local s = Y.VivYer
     if not s then return end
     local ply = LocalPlayer()
     if not IsValid(ply) or not ply:Alive() or not Y.KendiDunyasinda(ply) then YerBitir() return end
     local tr = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * 520, filter = ply, mask = MASK_PLAYERSOLID_BRUSHONLY})
     if tr.Hit and tr.HitNormal.z > 0.7 then
          s.p = tr.HitPos
          s.uygun, s.neden = Y.VivYerUygun(s.cesit, s.p, s.yaw, Y.Alan)
     else
          s.p, s.uygun, s.neden = nil, false, "Zemine bak."
     end
end)

hook.Add("PostDrawTranslucentRenderables", "SardonYaratik.VivYer", function(derinlik, gok)
     local s = Y.VivYer
     if derinlik or gok or not s or not s.p then return end
     local duzen = Y.YerDuzen[s.cesit] or {}
     if s.uygun then render.SetColorModulation(0.55, 1, 0.55) else render.SetColorModulation(1, 0.45, 0.4) end
     render.SetBlend(0.55)
     for j, parca in ipairs(duzen) do
          local m = s.modeller[j]
          if not IsValid(m) then
               m = ClientsideModel(parca.m, RENDERGROUP_TRANSLUCENT)
               if IsValid(m) then
                    m:SetNoDraw(true)
                    if parca.olcek then
                         local mt = Matrix()
                         mt:Scale(parca.olcek)
                         m:EnableMatrix("RenderMultiply", mt)
                    end
               end
               s.modeller[j] = m
          end
          if IsValid(m) then
               local q = Y.YerKonum(s.p, s.yaw, parca.ileri, parca.sag)
               m:SetPos(q - Vector(0, 0, m:OBBMins().z * (parca.olcek and parca.olcek.z or 1)))
               m:SetAngles(Angle(0, s.yaw + (parca.yaw or 0), 0))
               m:SetupBones()
               m:DrawModel()
          end
     end
     render.SetBlend(1)
     render.SetColorModulation(1, 1, 1)
end)

hook.Add("PlayerBindPress", "SardonYaratik.VivYer", function(_, bind, basildi)
     local s = Y.VivYer
     if not s or not basildi then return end
     if bind:find("+attack2", 1, true) then
          s.yaw = math.NormalizeAngle(s.yaw + 22.5)
          return true
     elseif bind:find("+attack", 1, true) then
          if not s.p or not s.uygun then
               Y.Bildirim(s.neden or "Buraya konmaz.", "hata")
               return true
          end
          Y.Islem("viv_yer", 0, util.TableToJSON({cesit = s.cesit, x = s.p.x, y = s.p.y, z = s.p.z, yaw = s.yaw}))
          YerBitir()
          return true
     elseif bind:find("+reload", 1, true) then
          YerBitir()
          return true
     end
end)

hook.Add("HUDPaint", "SardonYaratik.VivYer", function()
     local s = Y.VivYer
     if not s then return end
     local sc = math.max(ScrH() / 1080, 0.7)
     local ad = s.cesit == "yemlik" and "YEMLİĞİ TAŞI" or "KULUÇKA YUVASINI TAŞI"
     local alt = s.uygun and "Sol tık: buraya koy   ·   Sağ tık: döndür   ·   R: vazgeç" or ((s.neden or "Buraya konmaz.") .. "   ·   R: vazgeç")
     local w, h = 620 * sc, 70 * sc
     local x, y = (ScrW() - w) / 2, ScrH() * 0.8
     surface.SetDrawColor(7, 18, 13, 230)
     surface.DrawRect(x, y, w, h)
     surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 255)
     surface.DrawRect(x, y, w, 2 * sc)
     draw.SimpleText(ad, Y.Font(16 * sc, "baslik"), x + w / 2, y + 20 * sc, R.altin, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     draw.SimpleText(alt, Y.Font(16 * sc, 600), x + w / 2, y + 48 * sc, s.uygun and R.parlak or R.hata, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

------------------------------------------------------------------------ temizlik

hook.Add("EntityRemoved", "SardonYaratik.Viv", function(ent)
     if ent:IsPlayer() then
          CekBitir(ent)
          EldeBitir(ent)
     end
end)
