-- "addons\\sardonyaratik\\lua\\sardon_yaratik\\cl_3dunya.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: dünyada çizim (omuz, nadirlik parıltısı, bakım efektleri)

-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_40 = Vector(0, 0, 40)
local OPT_V_0_0_120 = Vector(0, 0, 120)
local OPT_V_0_0_23 = Vector(0, 0, 23)
local OPT_V_0_0_14 = Vector(0, 0, 14)
local OPT_V_0_0_18 = Vector(0, 0, 18)
local OPT_R_255_120_40_150 = Color(255, 120, 40, 150)
local OPT_R_255_235_180_255 = Color(255, 235, 180, 255)
local OPT_V_0_0_6 = Vector(0, 0, 6)
local OPT_V_0_0_8 = Vector(0, 0, 8)
local OPT_V_0_0_5 = Vector(0, 0, 5)
local OPT_V_0_0_20 = Vector(0, 0, 20)
local OPT_V_0_0_12 = Vector(0, 0, 12)
local OPT_V_0_0_0p7 = Vector(0, 0, 0.7)
local OPT_V_0_0_4 = Vector(0, 0, 4)
local OPT_R_255_215_110_235 = Color(255, 215, 110, 235)
local OPT_R_255_236_150_255 = Color(255, 236, 150, 255)
local OPT_R_255_200_90_90 = Color(255, 200, 90, 90)
local OPT_V_0_0_112 = Vector(0, 0, 112)
local Y = SardonYaratik
local A = Y.Ayar

------------------------------------------------------------------------ kuluçka sıcaklığı

-- varlığın son yazılan sıcaklığından şimdiki değer (sunucu formülüyle aynı soğuma)
function Y.KuluckaSicakNow(ent)
     local K = A.Kulucka
     local sure = math.max(ent:GetKSure(), 1)
     local d = (100 - K.taban) / (sure / K.sogumaPay)
     local gecen = math.max(0, CurTime() - ent:GetSicakT())
     return math.max(K.taban, ent:GetSicak() - d * gecen)
end

------------------------------------------------------------------------ parçacıklar

local yayici
local function Yayici(p)
     if not yayici or not yayici:IsValid() then yayici = ParticleEmitter(p, false) end
     yayici:SetPos(p)
     return yayici
end

local function Kivilcim(p, renk, adet, hiz, omur, boy, yukari)
     local e = Yayici(p)
     for _ = 1, adet do
          local q = e:Add(Y.MatNokta, p + VectorRand() * 6)
          if q then
               local v = VectorRand() * (hiz or 40)
               v.z = math.abs(v.z) * 0.5 + (yukari or 30)
               q:SetVelocity(v)
               q:SetDieTime(math.Rand((omur or 1) * 0.6, omur or 1))
               q:SetStartAlpha(230)
               q:SetEndAlpha(0)
               q:SetStartSize(boy or 3)
               q:SetEndSize(0)
               q:SetColor(renk.r, renk.g, renk.b)
               q:SetGravity(Vector(0, 0, -20))
               q:SetAirResistance(40)
          end
     end
end

local function Duman(p, renk, adet, boy)
     local e = Yayici(p)
     for _ = 1, adet do
          local q = e:Add("particle/smokesprites_000" .. math.random(1, 9), p + VectorRand() * 10)
          if q then
               local v = VectorRand() * 50
               v.z = math.abs(v.z) * 0.6 + 10
               q:SetVelocity(v)
               q:SetDieTime(math.Rand(0.8, 1.6))
               q:SetStartAlpha(140)
               q:SetEndAlpha(0)
               q:SetStartSize(boy or 10)
               q:SetEndSize((boy or 10) * 2.4)
               q:SetRoll(math.Rand(0, 360))
               q:SetRollDelta(math.Rand(-1, 1))
               q:SetColor(renk.r, renk.g, renk.b)
               q:SetAirResistance(60)
          end
     end
end

Y.Kivilcim, Y.Duman = Kivilcim, Duman

------------------------------------------------------------------------ 2B kalpler / yıldızlar

Y.Ucanlar = Y.Ucanlar or {}

local function Ucan(p, simge, renk, adet)
     for i = 1, adet do
          table.insert(Y.Ucanlar, {p = p + VectorRand() * 8, simge = simge, renk = renk, t = RealTime() + i * 0.12,
               sx = math.Rand(-20, 20), boy = math.Rand(0.8, 1.25)})
     end
end

local V2_IKON = {["♥"] = "heart", ["★"] = "star_spark", ["✦"] = "star_spark", ["✗"] = "close"}

hook.Add("HUDPaint", "SardonYaratik.Ucanlar", function()
     local liste = Y.Ucanlar
     if #liste == 0 then return end
     local simdi = RealTime()
     local s = math.max(ScrH() / 1080, 0.6)
     for i = #liste, 1, -1 do
          local u = liste[i]
          local g = simdi - u.t
          if g > 1.8 then
               table.remove(liste, i)
          elseif g >= 0 then
               local sc = (u.p + Vector(0, 0, 10 + g * 30)):ToScreen()
               if sc.visible then
                    local a = math.Clamp(math.min(g / 0.2, (1.8 - g) / 0.6), 0, 1)
                    -- V2 arayüzünün ikonları (yoksa yazı glifi)
                    local ikon = V2_IKON[u.simge]
                    local V = Y.V2
                    if ikon and V and V.Hazir(ikon) then
                         local b = 30 * s * u.boy
                         if ikon == "star_spark" then
                              V.DokuDon(ikon, sc.x + u.sx * g, sc.y, b * 0.8, b * 0.8, g * 90, nil, a)
                         else
                              V.Ikon(ikon, sc.x + u.sx * g, sc.y, b, u.renk, a)
                         end
                    else
                         draw.SimpleText(u.simge, Y.Font(26 * s * u.boy, 600), sc.x + u.sx * g, sc.y, Color(u.renk.r, u.renk.g, u.renk.b, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
               end
          end
     end
end)

------------------------------------------------------------------------ efektler

local function Ust(ent)
     local p = ent.CizimKonumu and ent:CizimKonumu() or ent:GetPos()
     local tur = ent.TurVeri and ent:TurVeri()
     local h = (tur and tur.kutu and tur.kutu[3] or 30) * (ent.Olcek and ent:Olcek() or 1)
     return p, p + Vector(0, 0, h * 0.6), h
end

local NADIR_RENK = {Color(200, 210, 190), Color(120, 180, 255), Color(255, 200, 90)}

local EFEKT = {}

EFEKT.besle = function(ent, d)
     local _, orta = Ust(ent)
     Kivilcim(orta, Color(220, 190, 120), 6, 20, 0.8, 2, 10)
     ent:EmitSound("npc/barnacle/barnacle_gulp1.wav", 55, math.random(130, 160), 0.4)
end

EFEKT.sev = function(ent, d)
     local _, orta = Ust(ent)
     Ucan(orta, "♥", Y.R.sevgi, d > 0 and 4 or 2)
end

EFEKT.firca = function(ent, d)
     local _, orta, h = Ust(ent)
     Duman(orta, Color(170, 150, 120), 5, 6 + h * 0.1)
     Kivilcim(orta, Color(240, 240, 255), math.Round(6 + 10 * d), 50, 1.2, 2.5, 25)
     ent:EmitSound("ambient/levels/canals/windchime2.wav", 55, 140, 0.35)
end

EFEKT.egit = function(ent, d)
     local _, orta = Ust(ent)
     Ucan(orta, d >= 0.7 and "★" or "✦", Y.R.uyari, d >= 0.7 and 3 or 1)
end

EFEKT.topla = function(ent)
     local _, orta = Ust(ent)
     Kivilcim(orta, Color(255, 210, 110), 18, 60, 1.2, 3, 40)
     ent:EmitSound("items/ammo_pickup.wav", 60, 110, 0.5)
end

EFEKT.tiksin = function(ent)
     local _, orta = Ust(ent)
     Duman(orta, Color(120, 160, 90), 4, 6)
     Ucan(orta, "✗", Y.R.hata, 1)
end

EFEKT.cisimlen = function(ent, d)
     local p, orta, h = Ust(ent)
     Duman(orta, Color(180, 180, 200), 10, 8 + h * 0.15)
     Kivilcim(orta, Color(200, 220, 255), 14, 90, 0.7, 3, 20)
     if d == 1 then sound.Play("ambient/energy/whiteflash.wav", p, 60, 160, 0.35) end
end

EFEKT.kulucka = function(ent)
     local p = Ust(ent)
     Kivilcim(p + Vector(0, 0, 4), Color(255, 220, 160), 12, 30, 1, 2.5, 30)
end

-- d: ısıtanın varlık numarası (asayla ısıttıysa alev asadan, yoksa yuvanın mangalından gelir)
EFEKT.isit = function(ent, d)
     local p = Ust(ent)
     local buyucu = d > 0 and Entity(math.Round(d))
     if IsValid(buyucu) and buyucu:IsPlayer() and Y.AsaAlevi then
          Y.AsaAlevi(buyucu, p + Vector(0, 0, 6))
     elseif Y.YuvaIsitEfekt then
          Y.YuvaIsitEfekt(p + Vector(0, 0, 6))
     end
     Kivilcim(p + Vector(0, 0, 4), Color(255, 150, 60), 14, 25, 1.1, 3, 35)
     ent:EmitSound("ambient/fire/mtov_flame2.wav", 50, 140, 0.25)
end

-- mangaldan alev alma (asa Accio çekişi; aktarım EFEKT.isit'te): d = büyücünün varlık numarası
EFEKT.isit_al = function(ent, d)
     local buyucu = d > 0 and Entity(math.Round(d))
     if IsValid(buyucu) and buyucu:IsPlayer() and Y.AsaAlevCek then Y.AsaAlevCek(buyucu, Ust(ent)) end
end

EFEKT.cevir = function(ent)
     local p = Ust(ent)
     Kivilcim(p + Vector(0, 0, 4), Color(230, 220, 200), 6, 20, 0.6, 2, 15)
     ent:EmitSound("physics/wood/wood_box_impact_soft1.wav", 50, 140, 0.4)
end

EFEKT.catla = function(ent, nadir)
     local p, orta = Ust(ent)
     local r = NADIR_RENK[math.Clamp(math.Round(nadir), 1, 3)]
     Kivilcim(p + Vector(0, 0, 6), Color(245, 235, 215), 16, 70, 0.8, 2.5, 50)
     Kivilcim(orta, r, nadir >= 2 and 40 or 20, 80, 1.6, 4, 60)
     ent:EmitSound("physics/plastic/plastic_box_break1.wav", 60, 130, 0.6)
     if nadir >= 2 then ent:EmitSound("ambient/levels/canals/windchime2.wav", 65, nadir >= 3 and 90 or 120, 0.7) end
end

EFEKT.buyu = function(ent)
     local _, orta = Ust(ent)
     Kivilcim(orta, Y.R.soluk, 26, 70, 1.4, 3.5, 50)
     ent:EmitSound("ambient/levels/canals/windchime2.wav", 60, 110, 0.5)
end

EFEKT.olum = function(ent)
     local _, orta, h = Ust(ent)
     Duman(orta, Color(60, 60, 70), 14, 10 + h * 0.2)
     Kivilcim(orta, Color(180, 190, 220), 16, 30, 2, 2.5, 25)
end

EFEKT.anka = function(ent)
     local p, orta, h = Ust(ent)
     Kivilcim(orta, Color(255, 140, 40), 50, 110, 1.6, 5, 70)
     Kivilcim(p, Color(255, 220, 120), 30, 60, 1.2, 4, 40)
     Duman(orta, Color(80, 60, 50), 8, 12)
     ent:EmitSound("ambient/fire/ignite.wav", 70, 100, 0.8)
end

-- Faz 3: yabani yaratık sersemledi / isabet aldı / yakalanıyor / yakalandı; eşleşme
EFEKT.sersem = function(ent)
     local p, orta, h = Ust(ent)
     Kivilcim(orta + Vector(0, 0, h * 0.3), Color(255, 240, 170), 22, 70, 0.9, 2.6, 35)
     Duman(p + Vector(0, 0, 4), Color(170, 160, 140), 4, 6)
     ent:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 60, 120, 0.5)
end

EFEKT.isabet = function(ent, d)
     local _, orta = Ust(ent)
     Kivilcim(orta, Color(255, 225, 150), math.Round(6 + 10 * d), 50, 0.6, 2, 20)
     Ucan(orta, "!", Y.R.uyari, 1)
     ent:EmitSound("ambient/energy/zap" .. math.random(1, 3) .. ".wav", 55, 130, 0.35)
end

EFEKT.yakala = function(ent, sure)
     local n = math.floor(math.max(sure, 0.5) / 0.12)
     local ad = "SardonYaratik.YakalaFx" .. ent:EntIndex()
     local i = 0
     timer.Create(ad, 0.12, n, function()
          if not IsValid(ent) then timer.Remove(ad) return end
          i = i + 1
          -- yaratığın çevresinde daralarak yükselen iki kollu altın girdap
          local p, _, h = Ust(ent)
          h = tonumber(h) or 30
          local r = math.max(h * 0.9, 14) * (1 - i / n * 0.65)
          for kol = 0, 1 do
               local a = i * 0.75 + kol * math.pi
               local q = p + Vector(math.cos(a) * r, math.sin(a) * r, h * (0.15 + 0.7 * i / n))
               Kivilcim(q, Color(255, 214, 140), 4, 12, 0.7, 3.4, 8)
          end
     end)
     ent:EmitSound("physics/cardboard/cardboard_box_shake" .. math.random(1, 3) .. ".wav", 55, 110, 0.5)
end

EFEKT.yakalandi = function(ent)
     local p, orta, h = Ust(ent)
     Kivilcim(orta, Color(255, 215, 120), 28, 90, 0.9, 3, 30)
     Duman(orta, Color(200, 180, 140), 8, 6 + h * 0.15)
     ent:EmitSound("items/ammo_pickup.wav", 60, 90, 0.6)
     sound.Play("ambient/levels/canals/windchime2.wav", p, 60, 130, 0.5)
end

EFEKT.ureme = function(ent)
     local _, orta = Ust(ent)
     Ucan(orta, "♥", Y.R.sevgi, 6)
     Kivilcim(orta, Color(240, 170, 200), 24, 60, 1.4, 3, 40)
     ent:EmitSound("ambient/levels/canals/windchime2.wav", 60, 110, 0.6)
end

function Y.EfektOynat(ad, ent, deger)
     if not IsValid(ent) then return end
     local f = EFEKT[ad]
     if f then f(ent, deger or 0) end
end

------------------------------------------------------------------------ nadirlik parıltısı

-- varlığın Draw'ı sonunda çağrılır
function Y.YaratikCizildi(ent, p, a, tur)
     local nadir = ent:GetNadir()
     if nadir < 2 or ent:GetEvre() == 0 then return end
     local simdi = CurTime()
     if (ent.YParT or 0) > simdi then return end
     ent.YParT = simdi + (nadir == 3 and 0.18 or 0.45)
     if EyePos():DistToSqr(p) > 1500 * 1500 then return end
     local h = (tur.kutu and tur.kutu[3] or 30) * ent:Olcek()
     local u = (tur.kutu and tur.kutu[1] or 30) * ent:Olcek() * 0.5
     local q = p + Vector(math.Rand(-u, u), math.Rand(-u, u), math.Rand(h * 0.2, h))
     local e = Yayici(q)
     local par = e:Add(Y.MatNokta, q)
     if par then
          local r = NADIR_RENK[nadir]
          par:SetVelocity(Vector(0, 0, math.Rand(6, 16)))
          par:SetDieTime(math.Rand(0.9, 1.6))
          par:SetStartAlpha(nadir == 3 and 220 or 150)
          par:SetEndAlpha(0)
          par:SetStartSize(nadir == 3 and 3 or 2)
          par:SetEndSize(0)
          par:SetColor(r.r, r.g, r.b)
     end
end

------------------------------------------------------------------------ omuz

local omuzlar = {}

local function OmuzCoz(kod)
     local p = string.Explode("|", kod)
     return tonumber(p[1]), p[2], tonumber(p[3]) or 0, tonumber(p[4]) or 1, tonumber(p[5]) or 1
end

local EVRE_OMUZ = {[1] = 0.7, [2] = 0.86, [3] = 1}

local function OmuzKur(ply, kod)
     local o = omuzlar[ply]
     if o and IsValid(o.mdl) then o.mdl:Remove() end
     omuzlar[ply] = nil

     local id, turId, bg, nadir, evre = OmuzCoz(kod)
     local tur = Y.Turler[turId]
     if not tur or not tur.omuz then return end
     if not file.Exists(tur.model, "GAME") then return end

     local mdl = ClientsideModel(tur.model, RENDERGROUP_OPAQUE)
     if not IsValid(mdl) then return end
     mdl:SetNoDraw(true)
     local grup = mdl:FindBodygroupByName("staylofft_color")
     if grup and grup >= 0 then mdl:SetBodygroup(grup, bg) end
     o = {kod = kod, mdl = mdl, tur = tur, turId = turId, nadir = nadir, evre = evre, son = RealTime(), durT = RealTime()}
     omuzlar[ply] = o
     return o
end

-- omuzdaki yaratığın animasyonu: çoğunlukla bekleme, arada tımar / kemirme; sahibi uzun süre
-- kıpırdamazsa uyur. Uçabilenler sahibi koşarken kanat açıp dengede durur (süzülme), zıplayınca /
-- düşerken kanat çırpar. Kabuluk üç bekleme animasyonu arasında gezinir.
local function OmuzAnimKur(o, ad)
     if o.anim == ad then return end
     local gercek = (o.tur.anim and o.tur.anim[ad]) or ad
     local seq = o.mdl:LookupSequence(gercek)
     if not seq or seq < 0 then
          seq = o.mdl:LookupSequence((o.tur.anim and o.tur.anim.idle) or "idle")
     end
     if not seq or seq < 0 then return end
     o.mdl:ResetSequence(seq)
     o.anim = ad
     o.animBas = RealTime()
     o.sure = math.max(o.mdl:SequenceDuration(seq), 0.1)
end

local function OmuzAnim(o, ply)
     local simdi = RealTime()
     local hiz = ply:GetVelocity():Length()
     if hiz > 15 then o.durT = simdi end
     local ucar = Y.Ucuslar and Y.Ucuslar[o.turId]
     local zorunlu
     if ucar and not ply:IsOnGround() and ply:GetMoveType() == MOVETYPE_WALK then
          zorunlu = "fly"
     elseif ucar and hiz > 220 then
          zorunlu = "glide"
     end
     if zorunlu then
          OmuzAnimKur(o, zorunlu)
          o.serbestBitis = nil
          return
     end
     if o.serbestBitis and simdi < o.serbestBitis then return end

     local kipirtisiz = simdi - o.durT
     local ad, tur = "idle", 1
     if o.tur.anim and o.tur.anim.idle2 then
          ad = ({"idle", "idle2", "idle3"})[math.random(3)]
     elseif kipirtisiz > 60 or (kipirtisiz > 25 and Y.Gece and Y.Gece()) then
          ad, tur = "sleep", 3
     else
          local r = math.random()
          if r < 0.22 then ad = "groom" elseif r < 0.3 then ad = "eat" end
     end
     o.anim = nil
     OmuzAnimKur(o, ad)
     o.serbestBitis = simdi + (o.sure or 4) * tur
end

local B_KOPRUCUK = "ValveBiped.Bip01_R_Clavicle"

hook.Add("PostPlayerDraw", "SardonYaratik.Omuz", function(ply)
     local kod = ply:GetNW2String("SYOmuz", "")
     local o = omuzlar[ply]
     if kod == "" then
          if o then
               if IsValid(o.mdl) then o.mdl:Remove() end
               omuzlar[ply] = nil
          end
          return
     end
     if not o or o.kod ~= kod or not IsValid(o.mdl) then o = OmuzKur(ply, kod) end
     if not o then return end

     local kemik = ply:LookupBone(B_KOPRUCUK)
     local m = kemik and ply:GetBoneMatrix(kemik)
     if not m then return end

     -- [vanity] accessories'in omuz ofsetiyle aynı: x omuz ucuna, -y yukarı
     local pos, ang = m:GetTranslation(), m:GetAngles()
     pos = pos + ang:Forward() * 4 + ang:Right() * -2.5
     local yeni = Angle(ang.p, ang.y, ang.r)
     yeni:RotateAroundAxis(yeni:Up(), 85)
     yeni:RotateAroundAxis(yeni:Right(), -85)
     yeni:RotateAroundAxis(yeni:Forward(), -20)

     local om = o.tur.omuz
     yeni:RotateAroundAxis(yeni:Up(), om.yaw or 0)
     pos = pos + yeni:Up() * (om.ust or 0) + yeni:Forward() * (om.ileri or 0) + yeni:Right() * (om.sag or 0)

     local mdl = o.mdl
     mdl:SetPos(pos)
     mdl:SetAngles(yeni)
     local olcek = (om.olcek or 0.5) * (EVRE_OMUZ[o.evre] or 1)
     if mdl:GetModelScale() ~= olcek then mdl:SetModelScale(olcek, 0) end
     OmuzAnim(o, ply)
     mdl:SetCycle(((RealTime() - (o.animBas or 0)) / (o.sure or 1)) % 1)
     mdl:SetupBones()
     mdl:DrawModel()
     o.son = RealTime()
end)

timer.Create("SardonYaratik.OmuzTemizle", 5, 0, function()
     local simdi = RealTime()
     for ply, o in pairs(omuzlar) do
          if not IsValid(ply) or simdi - o.son > 10 then
               if IsValid(o.mdl) then o.mdl:Remove() end
               omuzlar[ply] = nil
          end
     end
end)

------------------------------------------------------------------------ yemlik ve kuluçka yuvası

-- Katı parçalar (balya, sepet, mangal) sunucudan prop olarak gelir (sv_7yonetim.lua). Burada süsler
-- (kova, dökülmüş tohum, saman yatak), sepette herkesin KENDİ yemlik stoğu, mangal ateşi/ışığı/sesi,
-- kuluçkadaki yumurtanın sıcaklık parıltısı ve olay efektleri. Oyuncu vivaryuma yaklaşınca kurulur.

local YER_MESAFE = 1800        -- alanın bu kadar yakınında süsler kurulur
local ATES_MESAFE = 1100       -- mangal ateşi ve ışığı
local SES_MESAFE = 650         -- mangal çıtırtısı

-- canlı yenileme: önceki sürümün süsleri kalmasın
if Y.YerSus then
     for _, m in ipairs(Y.YerSus.modeller or {}) do if IsValid(m) then m:Remove() end end
     for _, m in ipairs(Y.YerSus.sepetModeller or {}) do if IsValid(m) then m:Remove() end end
     for _, m in ipairs(Y.YerSus.mangal or {}) do
          if m.ses then m.ses:Stop() end
          if m.e and m.e:IsValid() then m.e:Finish() end
     end
end
local sus = {imza = nil, modeller = {}, sepet = {}, mangal = {}, sepetModeller = {}, yumurtalar = {}, toplam = nil, agilKase = {}, agilTabela = {}}
Y.YerSus = sus

local function YerZemin(p)
     local tr = util.TraceLine({start = p + OPT_V_0_0_40, endpos = p - OPT_V_0_0_120, mask = MASK_SOLID_BRUSHONLY})
     return tr.Hit and tr.HitPos or p
end

-- zemine oturan süs modeli (olcek: Vector, yalnız görüntü)
local function SusModel(m, pos, ang, olcek)
     if not file.Exists(m, "GAME") then return end
     local e = ClientsideModel(m, RENDERGROUP_OPAQUE)
     if not IsValid(e) then return end
     local mn, mx = e:GetModelBounds()
     if olcek then
          local mt = Matrix()
          mt:Scale(olcek)
          e:EnableMatrix("RenderMultiply", mt)
          mn = Vector(mn.x * olcek.x, mn.y * olcek.y, mn.z * olcek.z)
          mx = Vector(mx.x * olcek.x, mx.y * olcek.y, mx.z * olcek.z)
          e:SetRenderBounds(mn, mx)
     end
     e:SetPos(pos - Vector(0, 0, mn.z))
     e:SetAngles(ang)
     return e
end

local function SusTemizle()
     for _, m in ipairs(sus.modeller) do if IsValid(m) then m:Remove() end end
     for _, m in ipairs(sus.sepetModeller) do if IsValid(m) then m:Remove() end end
     for _, m in ipairs(sus.mangal) do
          if m.ses then m.ses:Stop() end
          if m.e and m.e:IsValid() then m.e:Finish() end
     end
     sus.modeller, sus.sepetModeller, sus.sepet, sus.mangal = {}, {}, {}, {}
     sus.agilKase, sus.agilTabela = {}, {}
     sus.imza, sus.sepetImza = nil, nil
end

local function Imza()
     local t = {}
     for _, cesit in ipairs({"yemlik", "yuva", "agil"}) do
          for i, p in ipairs(Y.Alan[cesit] or {}) do
               t[#t + 1] = string.format("%s%.0f,%.0f,%.0f,%.0f", cesit, p.x, p.y, p.z, Y.YerYon(cesit, i))
          end
     end
     return table.concat(t, ";")
end

local function SusKur()
     SusTemizle()
     sus.imza = Imza()
     for _, cesit in ipairs({"yemlik", "yuva", "agil"}) do
          for i, p in ipairs(Y.Alan[cesit] or {}) do
               local yaw = Y.YerYon(cesit, i)
               for _, parca in ipairs(Y.YerDuzen[cesit]) do
                    local q = YerZemin(Y.YerKonum(p, yaw, parca.ileri, parca.sag))
                    if not parca.kati then
                         local e = SusModel(parca.m, q + Vector(0, 0, parca.ust or 0), Angle(0, yaw + (parca.yaw or 0), 0), parca.olcek)
                         if e then sus.modeller[#sus.modeller + 1] = e end
                         if parca.kase then sus.agilKase[i] = q end
                         if parca.tabela and e then sus.agilTabela[#sus.agilTabela + 1] = {e = e, i = i, p = q, yaw = yaw} end
                    elseif parca.sepet then
                         sus.sepet[i] = q
                    elseif parca.mangal then
                         sus.mangal[#sus.mangal + 1] = {p = q + OPT_V_0_0_23, yuva = i}
                    end
               end
          end
     end
end

-- sepetin içi: izleyenin kendi stoğu; en çok olan yem türleri, doluluğa göre 2-6 parça
local function SepetKur()
     for _, m in ipairs(sus.sepetModeller) do if IsValid(m) then m:Remove() end end
     sus.sepetModeller = {}
     local stok = (Y.Benim and Y.Benim.yemlik) or {}
     local turler, toplam = {}, 0
     for _, yem in ipairs(Y.YemSirasi) do
          local n = stok[yem] or 0
          if n > 0 and Y.Yemler[yem] then
               turler[#turler + 1] = {yem = yem, n = n}
               toplam = toplam + n
          end
     end
     table.sort(turler, function(a, b) return a.n > b.n end)
     local imza = sus.imza
     for _, t in ipairs(turler) do imza = imza .. "|" .. t.yem .. t.n end
     sus.sepetImza = imza
     if toplam <= 0 then return end
     local dolu = math.Clamp(toplam / A.YemlikSiniri, 0, 1)
     local adet = 2 + math.floor(4 * dolu)
     for i, q in pairs(sus.sepet) do
          local yaw = Y.YerYon("yemlik", i)
          local merkez = Y.YerKonum(q, yaw, 0, 0)
          for j = 1, adet do
               local yem = turler[(j - 1) % math.min(#turler, 2) + 1].yem
               local m = Y.Yemler[yem].model
               if file.Exists(m, "GAME") then
                    local e = ClientsideModel(m, RENDERGROUP_OPAQUE)
                    if IsValid(e) then
                         local mn, mx = e:GetModelBounds()
                         local boy = math.max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z, 1)
                         local olcek = 9 / boy
                         e:SetModelScale(olcek, 0)
                         local kat = math.floor((j - 1) / 3)
                         local a = yaw + j * 137
                         local r = kat == 0 and 4.5 or 2.5
                         local p = merkez + Angle(0, a, 0):Forward() * r + Vector(0, 0, 5 + 9 * dolu + kat * 5 - mn.z * olcek)
                         e:SetPos(p)
                         e:SetAngles(Angle(math.Rand(-20, 20), a * 1.7, math.Rand(-20, 20)))
                         sus.sepetModeller[#sus.sepetModeller + 1] = e
                    end
               end
          end
     end
end

local function EnYakinSepet(p, en)
     local bul, enD
     for _, q in pairs(sus.sepet) do
          local d = q:DistToSqr(p)
          if d < en * en and (not enD or d < enD) then bul, enD = q, d end
     end
     return bul
end

-- yem koyunca sepete tane yağar (yalnız koyan görür; stok kişiye özel)
hook.Add("SardonYaratikListe", "SardonYaratik.YemlikSus", function(veri)
     local toplam = 0
     for _, n in pairs(veri.yemlik or {}) do toplam = toplam + n end
     local once = sus.toplam
     sus.toplam = toplam
     if sus.imza then SepetKur() end
     if not once or toplam <= once then return end
     local q = EnYakinSepet(LocalPlayer():GetPos(), 300)
     if not q then return end
     local e = Yayici(q)
     for _ = 1, 26 do
          local par = e:Add(Y.MatNokta, q + Vector(math.Rand(-6, 6), math.Rand(-6, 6), math.Rand(34, 46)))
          if par then
               par:SetVelocity(Vector(math.Rand(-8, 8), math.Rand(-8, 8), math.Rand(-40, -10)))
               par:SetGravity(Vector(0, 0, -300))
               par:SetDieTime(math.Rand(0.5, 0.8))
               par:SetStartAlpha(240)
               par:SetEndAlpha(200)
               par:SetStartSize(math.Rand(1.2, 2.2))
               par:SetEndSize(1)
               par:SetColor(232, 200, 130)
          end
     end
     sound.Play("physics/surfaces/sand_impact_bullet" .. math.random(1, 4) .. ".wav", q, 60, 150, 0.5)
end)

-- mangal: alev, kor, duman (kendi yayıcısı)
local function Ates(m)
     if not (m.e and m.e:IsValid()) then m.e = ParticleEmitter(m.p, false) end
     local e = m.e
     local q = e:Add("particles/flamelet" .. math.random(1, 5), m.p + Vector(math.Rand(-7, 7), math.Rand(-7, 7), 0))
     if q then
          q:SetVelocity(Vector(math.Rand(-4, 4), math.Rand(-4, 4), math.Rand(26, 46)))
          q:SetDieTime(math.Rand(0.35, 0.6))
          q:SetStartAlpha(220)
          q:SetEndAlpha(0)
          q:SetStartSize(math.Rand(5, 8))
          q:SetEndSize(1.5)
          q:SetRoll(math.Rand(0, 360))
          q:SetRollDelta(math.Rand(-2, 2))
          q:SetColor(255, 215, 170)
     end
     if math.random() < 0.18 then
          local k = e:Add(Y.MatNokta, m.p + Vector(math.Rand(-8, 8), math.Rand(-8, 8), 2))
          if k then
               k:SetVelocity(Vector(math.Rand(-12, 12), math.Rand(-12, 12), math.Rand(40, 80)))
               k:SetDieTime(math.Rand(0.8, 1.5))
               k:SetStartAlpha(255)
               k:SetEndAlpha(0)
               k:SetStartSize(1.6)
               k:SetEndSize(0)
               k:SetColor(255, 150, 60)
               k:SetGravity(Vector(0, 0, -15))
               k:SetAirResistance(30)
          end
     end
     if math.random() < 0.07 then
          local d = e:Add("particle/smokesprites_000" .. math.random(1, 9), m.p + OPT_V_0_0_14)
          if d then
               d:SetVelocity(Vector(math.Rand(-5, 5), math.Rand(-5, 5), math.Rand(20, 35)))
               d:SetDieTime(math.Rand(1.6, 2.4))
               d:SetStartAlpha(50)
               d:SetEndAlpha(0)
               d:SetStartSize(6)
               d:SetEndSize(22)
               d:SetRoll(math.Rand(0, 360))
               d:SetRollDelta(math.Rand(-0.5, 0.5))
               d:SetColor(90, 85, 80)
          end
     end
end

-- mangalın prop'u (ses ona bağlanır); PVS'teyse bulunur
local function MangalVarlik(m)
     if IsValid(m.ent) then return m.ent end
     local ad = "yuva:" .. m.yuva .. ":mangal"
     for _, e in ipairs(ents.FindInSphere(m.p, 60)) do
          if e:GetNW2String("SYYer", "") == ad then m.ent = e return e end
     end
end

-- a'dan b'ye alev yayı: balistik parçacıklar (g: yerçekimi, sure: uçuş süresi aralığı); bas() her
-- parçacıkta başlangıcı verir (asa ucu karede değişir)
local function AlevYayi(bas, b, g, t0, t1, boy)
     for j = 1, 18 do
          timer.Simple(j * 0.022, function()
               local a = bas()
               if not a then return end
               local e = Yayici(a)
               local T = math.Rand(t0, t1)
               local q = e:Add(j % 3 == 0 and Y.MatNokta or ("particles/flamelet" .. math.random(1, 5)), a + VectorRand() * 1.5)
               if q then
                    q:SetVelocity((b - a) / T - g * (0.5 * T) + VectorRand() * 4)
                    q:SetGravity(g)
                    q:SetAirResistance(0)
                    q:SetDieTime(T)
                    q:SetStartAlpha(235)
                    q:SetEndAlpha(140)
                    q:SetStartSize(math.Rand(boy * 0.6, boy))
                    q:SetEndSize(1)
                    q:SetRoll(math.Rand(0, 360))
                    q:SetColor(255, 175, 95)
               end
          end)
     end
end

-- Isıt (asasız): en yakın mangaldan yumurtaya
function Y.YuvaIsitEfekt(hedef)
     local m, enD
     for _, x in ipairs(sus.mangal) do
          local d = x.p:DistToSqr(hedef)
          if d < 160 * 160 and (not enD or d < enD) then m, enD = x, d end
     end
     if not m then return end
     AlevYayi(function() return m.p end, hedef, Vector(0, 0, -260), 0.42, 0.55, 5)
     sound.Play("ambient/fire/ignite.wav", m.p, 58, 140, 0.35)
end

-- Isıt (asayla): sağ elden (asa ucu yönünde biraz ileride) yumurtaya, daha düz ve hızlı
local function AsaUcu(ply, hedef)
     if not IsValid(ply) then return end
     local kemik = ply:LookupBone("ValveBiped.Bip01_R_Hand")
     local el = kemik and ply:GetBonePosition(kemik)
     if not el or el == ply:GetPos() then el = ply:EyePos() - OPT_V_0_0_18 end
     return el + (hedef - el):GetNormalized() * 10
end

-- Alev alma: Accio çekişi süresince (1 sn) mangalın ateşinden asa ucuna alev akar, mangal canlanır,
-- uçta ateş topu büyür; top aktarıma (Y.AsaAlevi) kadar asanın ucunda kalır.
local toplar = {}       -- [oyuncu] = {t0, bitis, m (mangal), hedef (yumurta)}
local ALMA_SURE = 1.0

function Y.AsaAlevCek(ply, hedef)
     local m, enD
     for _, x in ipairs(sus.mangal) do
          local d = x.p:DistToSqr(hedef)
          if d < 160 * 160 and (not enD or d < enD) then m, enD = x, d end
     end
     if not m then return end
     local t0 = CurTime()
     toplar[ply] = {t0 = t0, bitis = t0 + ALMA_SURE + 1.6, m = m, hedef = hedef}
     local g = Vector(0, 0, 70) -- alev hafifçe yükselerek akar
     timer.Create("SardonYaratik.AlevCek" .. ply:EntIndex(), 0.03, math.floor(ALMA_SURE / 0.03), function()
          if not IsValid(ply) or not toplar[ply] then return end
          local uc = AsaUcu(ply, m.p)
          if not uc then return end
          local bas = m.p + Vector(math.Rand(-6, 6), math.Rand(-6, 6), math.Rand(0, 8))
          local e = Yayici(bas)
          local T = math.Rand(0.3, 0.42)
          local q = e:Add(math.random() < 0.3 and Y.MatNokta or ("particles/flamelet" .. math.random(1, 5)), bas)
          if q then
               q:SetVelocity((uc - bas) / T - g * (0.5 * T))
               q:SetGravity(g)
               q:SetAirResistance(0)
               q:SetDieTime(T)
               q:SetStartAlpha(230)
               q:SetEndAlpha(170)
               q:SetStartSize(math.Rand(4, 6))
               q:SetEndSize(1.5)
               q:SetRoll(math.Rand(0, 360))
               q:SetRollDelta(math.Rand(-3, 3))
               q:SetColor(255, 185, 105)
          end
          Ates(m)
     end)
     sound.Play("ambient/fire/ignite.wav", m.p, 62, 85, 0.45)
end

hook.Add("PostDrawTranslucentRenderables", "SardonYaratik.AsaTopu", function(derinlik, gok)
     if derinlik or gok or next(toplar) == nil then return end
     local simdi = CurTime()
     render.SetMaterial(Y.MatNokta)
     for ply, t in pairs(toplar) do
          if not IsValid(ply) or simdi > t.bitis then
               toplar[ply] = nil
          else
               local f = math.Clamp((simdi - t.t0) / ALMA_SURE, 0, 1)
               local uc = AsaUcu(ply, f < 1 and t.m.p or t.hedef)
               if uc then
                    local boy = (2 + 7 * f) * (0.88 + 0.12 * math.sin(simdi * 22))
                    render.DrawSprite(uc, boy * 2.6, boy * 2.6, OPT_R_255_120_40_150)
                    render.DrawSprite(uc, boy, boy, OPT_R_255_235_180_255)
                    t.uc = uc
               end
          end
     end
end)

hook.Add("Think", "SardonYaratik.AsaTopu", function()
     for ply, t in pairs(toplar) do
          if t.uc and IsValid(ply) then
               local dl = DynamicLight(53000 + ply:EntIndex())
               if dl then
                    local f = math.Clamp((CurTime() - t.t0) / ALMA_SURE, 0, 1)
                    dl.pos = t.uc
                    dl.r, dl.g, dl.b = 255, 150, 60
                    dl.brightness = 0.6 + 1.2 * f
                    dl.size = 60 + 70 * f
                    dl.decay = 800
                    dl.dietime = CurTime() + 0.15
               end
          end
     end
end)

function Y.AsaAlevi(ply, hedef)
     toplar[ply] = nil
     local a = AsaUcu(ply, hedef)
     if not a then return end
     AlevYayi(function() return AsaUcu(ply, hedef) end, hedef, Vector(0, 0, -120), 0.28, 0.36, 4)
     local e = Yayici(a)
     for _ = 1, 6 do
          local q = e:Add(Y.MatNokta, a)
          if q then
               q:SetVelocity(VectorRand() * 18)
               q:SetDieTime(0.35)
               q:SetStartAlpha(255)
               q:SetEndAlpha(0)
               q:SetStartSize(4)
               q:SetEndSize(0)
               q:SetColor(255, 200, 120)
          end
     end
     sound.Play("ambient/fire/ignite.wav", a, 58, 160, 0.3)
end

-- kuluçka sıcaklığının rengi: soğukta mavi, iyi aralıkta kehribar, fazla sıcakta kırmızı
local function SicakRenk(s)
     local K = A.Kulucka
     if s < K.iyiAlt then
          local f = math.Clamp((K.iyiAlt - s) / (K.iyiAlt - K.taban), 0, 1)
          return Lerp(f, 255, 110), Lerp(f, 185, 175), Lerp(f, 95, 255)
     elseif s > K.iyiUst then
          local f = math.Clamp((s - K.iyiUst) / (100 - K.iyiUst), 0, 1)
          return 255, Lerp(f, 160, 55), Lerp(f, 70, 30)
     end
     return 255, 178, 82
end

-- 4 Hz: yakındaki kuluçka yumurtaları, çevirme vakti, durum parçacıkları, yemlikte yeme kırıntısı
local function YumurtaGuncelle()
     local goz = EyePos()
     local liste = {}
     local K = A.Kulucka
     for _, ent in ipairs(Y.YaratikListe and Y.YaratikListe() or ents.FindByClass("sardon_yaratik")) do
          if IsValid(ent) and not ent:IsDormant() and ent.CizimKonumu and ent:GetPos():DistToSqr(goz) < 1000 * 1000 then
               if ent:GetEvre() == 0 and ent:GetDurum() == 3 then
                    liste[#liste + 1] = ent
                    local p = ent:CizimKonumu()
                    local s = Y.KuluckaSicakNow(ent)
                    if s < K.iyiAlt then
                         if math.random() < 0.3 then Duman(p + OPT_V_0_0_6, Color(195, 220, 255), 1, 2.5) end
                    elseif s > K.iyiUst then
                         if math.random() < 0.4 then Duman(p + OPT_V_0_0_8, Color(70, 66, 62), 1, 3) end
                         if math.random() < 0.3 then Kivilcim(p + OPT_V_0_0_5, Color(255, 80, 40), 1, 8, 0.8, 1.6, 16) end
                    elseif math.random() < 0.25 then
                         Kivilcim(p + OPT_V_0_0_5, Color(255, 190, 110), 1, 6, 0.9, 1.6, 14)
                    end
                    local ilerleme = (CurTime() - ent:GetKBas()) / math.max(ent:GetKSure(), 1)
                    if ilerleme > 0.9 and math.random() < 0.5 then Kivilcim(p + OPT_V_0_0_8, Color(255, 228, 160), 2, 12, 0.8, 2, 10) end
                    -- çevirme vakti (yalnız sahibi bilir)
                    ent.YCevirVakti = nil
                    local k = ent:GetSahip() == LocalPlayer() and Y.BenimKayit(ent:GetKimlik())
                    if k and k.ku and Y.EylemKalan and (k.ku.cevir or 0) < K.cevirSayisi then
                         ent.YCevirVakti = Y.EylemKalan(k, "cevir", math.floor(Y.CevirAraligi(k))) <= 0
                    end
               elseif ent:GetEvre() == 0 and ent:GetDurum() == Y.ENT_KASE then
                    -- ağıldaki saman sepetindeki yumurta: hafif sıcak parıltı
                    if math.random() < 0.25 then
                         Kivilcim(ent:CizimKonumu() + OPT_V_0_0_6, Color(255, 226, 160), 1, 7, 1, 1.5, 9)
                    end
               elseif ent:GetAnim() == "eat" and math.random() < 0.6 then
                    local p = ent:CizimKonumu()
                    local q = EnYakinSepet(p, 110)
                    if q then Kivilcim(q + OPT_V_0_0_20 + (p - q):GetNormalized() * 8, Color(205, 172, 112), 2, 14, 0.6, 1.5, 6) end
               end
          end
     end
     sus.yumurtalar = liste
end

hook.Add("Think", "SardonYaratik.YerSus", function()
     local simdi = RealTime()
     if simdi > (sus.denetimT or 0) then
          sus.denetimT = simdi + 1
          local ply = LocalPlayer()
          local yakin = IsValid(ply) and Y.AlanVar() and Y.AlanIcinde(ply:GetPos(), YER_MESAFE)
          if yakin then
               if sus.imza ~= Imza() then
                    SusKur()
                    SepetKur()
               end
          elseif sus.imza then
               SusTemizle()
          end
          -- mangal çıtırtısı: yakınken prop'a bağlı döngü
          for _, m in ipairs(sus.mangal) do
               local yakinSes = EyePos():DistToSqr(m.p) < SES_MESAFE * SES_MESAFE
               if yakinSes and not m.ses then
                    local e = MangalVarlik(m)
                    if e then
                         m.ses = CreateSound(e, "ambient/fire/fire_small_loop1.wav")
                         m.ses:SetSoundLevel(58)
                         m.ses:PlayEx(0.32, 100)
                    end
               elseif not yakinSes and m.ses then
                    m.ses:Stop()
                    m.ses = nil
               end
          end
     end
     if not sus.imza then return end
     if simdi > (sus.yumurtaT or 0) then
          sus.yumurtaT = simdi + 0.25
          YumurtaGuncelle()
     end
     local goz = EyePos()
     for j, m in ipairs(sus.mangal) do
          if goz:DistToSqr(m.p) < ATES_MESAFE * ATES_MESAFE then
               if simdi > (m.t or 0) then
                    m.t = simdi + 0.045
                    Ates(m)
               end
               local dl = DynamicLight(52000 + j)
               if dl then
                    dl.pos = m.p + OPT_V_0_0_12
                    dl.r, dl.g, dl.b = 255, 140, 60
                    dl.brightness = 1.5 + math.sin(simdi * 13 + j) * 0.2 + math.Rand(-0.12, 0.12)
                    dl.size = 200
                    dl.decay = 600
                    dl.dietime = CurTime() + 0.2
               end
          end
     end
end)

-- yumurtanın altında sıcaklık rengi parıltı (yatağa yayılır) + çevirme vakti halkası
hook.Add("PostDrawTranslucentRenderables", "SardonYaratik.Kulucka", function(derinlik, gok)
     if derinlik or gok or #sus.yumurtalar == 0 then return end
     local simdi = RealTime()
     render.SetMaterial(Y.MatNokta)
     for _, ent in ipairs(sus.yumurtalar) do
          if IsValid(ent) then
               local p = ent:CizimKonumu()
               local r, g, b = SicakRenk(Y.KuluckaSicakNow(ent))
               local nabiz = 0.85 + 0.15 * math.sin(simdi * 2.2 + ent:EntIndex())
               render.DrawQuadEasy(p + OPT_V_0_0_0p7, vector_up, 36 * nabiz, 36 * nabiz, Color(r, g, b, 110), 0)
               render.DrawSprite(p + OPT_V_0_0_4, 22 * nabiz, 16 * nabiz, Color(r, g, b, 120))
               if ent.YCevirVakti then
                    local u = p + Vector(0, 0, ent:Olcek() * 6 + 4)
                    for j = 0, 9 do
                         local a = simdi * 2.5 + j * math.pi / 5
                         render.DrawSprite(u + Vector(math.cos(a) * 7, math.sin(a) * 7, 0), 3.4, 3.4, OPT_R_255_215_110_235)
                    end
               end
          end
     end
end)

------------------------------------------------------------------------ sersem yabani: başında dönen yıldızlar

local sersemler = {}
hook.Add("Think", "SardonYaratik.SersemListe", function()
     if (sersemler.t or 0) > RealTime() then return end
     sersemler.t = RealTime() + 0.25
     local goz = EyePos()
     local l = {}
     for _, ent in ipairs(Y.YaratikListe and Y.YaratikListe() or ents.FindByClass("sardon_yaratik")) do
          if IsValid(ent) and not ent:IsDormant() and ent:GetDurum() == (Y.ENT_SERSEM or 5) and ent:GetPos():DistToSqr(goz) < 1600 * 1600 then
               l[#l + 1] = ent
          end
     end
     sersemler.l = l
end)

hook.Add("PostDrawTranslucentRenderables", "SardonYaratik.Sersem", function(derinlik, gok)
     if derinlik or gok or not sersemler.l or #sersemler.l == 0 then return end
     local simdi = RealTime()
     render.SetMaterial(Y.MatNokta)
     for _, ent in ipairs(sersemler.l) do
          if IsValid(ent) and ent.CizimKonumu and not (Y.CizimEngeli and Y.CizimEngeli(ent)) then
               local p = ent:CizimKonumu()
               local _, _, h = Y.VarlikKutu(ent)
               local merkez = p + Vector(0, 0, (h or 30) * 0.75 + 6)
               local r = math.Clamp((h or 30) * 0.3, 6, 22)
               for j = 0, 4 do
                    local a = simdi * 3 + j * math.pi * 0.4
                    local q = merkez + Vector(math.cos(a) * r, math.sin(a) * r, math.sin(simdi * 6 + j) * 2)
                    render.DrawSprite(q, 5, 5, OPT_R_255_236_150_255)
                    render.DrawSprite(q, 11, 11, OPT_R_255_200_90_90)
               end
          end
     end
end)

------------------------------------------------------------------------ Çiftleşme Ağılı: pano

-- sunucudan (sv_9ureme.lua Y.AgilYayinla): [anahtar] = {d = bos|kur|kase, tur, ad1, ad2, s1, s2, ilerleme, kalan, huzursuz}
Y.AgilDurumu = Y.AgilDurumu or {}
net.Receive(Y.NET.AGIL, function()
     local liste = net.ReadTable() or {}
     local t = {}
     for _, a in ipairs(liste) do
          a.alindi = RealTime()
          t[a.a] = a
     end
     Y.AgilDurumu = t
end)

local PANO_MESAFE = 700

local function PanoYazi(metin, font, x, y, renk, hiza)
     draw.SimpleText(metin, font, x, y, renk, hiza or TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

-- panonun önünde, giriş tarafına dönük yazı (0.1 ölçekli 3B2B; 560×340 birim = 56×34 dünya)
hook.Add("PostDrawTranslucentRenderables", "SardonYaratik.AgilPano", function(derinlik, gok)
     if derinlik or gok or #sus.agilTabela == 0 then return end
     local goz = EyePos()
     for _, t in ipairs(sus.agilTabela) do
          if goz:DistToSqr(t.p) < PANO_MESAFE * PANO_MESAFE then
               local p = Y.Alan.agil and Y.Alan.agil[t.i]
               local durum = p and Y.AgilDurumu[Y.AgilAnahtar(p)]
               local ang = Angle(0, t.yaw + 180, 0)
               -- panonun üst kirişinin üstünde, posterlerin hizasında (model ileri yönde ~51 birim derin)
               local merkez = t.p + OPT_V_0_0_112 + ang:Forward() * 28
               local cizim = Angle(0, ang.y + 90, 90)
               local R = Y.R
               cam.Start3D2D(merkez, cizim, 0.1)
                    local w, h = 560, 340
                    local x, y = -w / 2, -h / 2
                    surface.SetDrawColor(10, 20, 14, 225)
                    surface.DrawRect(x, y, w, h)
                    surface.SetDrawColor(R.altin.r, R.altin.g, R.altin.b, 255)
                    surface.DrawRect(x, y, w, 4)
                    surface.DrawOutlinedRect(x, y, w, h, 2)
                    PanoYazi("ÇİFTLEŞME AĞILI", Y.Font(40, "baslik"), 0, y + 18, R.altin)
                    local yy = y + 80
                    if not durum or durum.d == "bos" then
                         PanoYazi("Boş", Y.Font(44, "isim"), 0, yy, R.parlak)
                         PanoYazi("Yetişkin bir çifti E › Eşleştir ile getir", Y.Font(26, 400), 0, yy + 66, R.sonuk)
                         PanoYazi("huzurlu kaldıkça 1-2 günde yumurta", Y.Font(24, 400), 0, yy + 100, R.sonuk)
                    elseif durum.d == "kur" then
                         PanoYazi((durum.ad1 or "?") .. "  &  " .. (durum.ad2 or "?"), Y.Font(38, "isim"), 0, yy, R.parlak)
                         PanoYazi((durum.s1 or "?") .. (durum.s2 and durum.s2 ~= durum.s1 and ("  ·  " .. durum.s2) or ""), Y.Font(24, 400), 0, yy + 50, R.sonuk)
                         local bx, by, bw, bh = x + 40, yy + 92, w - 80, 22
                         surface.SetDrawColor(20, 36, 28, 255)
                         surface.DrawRect(bx, by, bw, bh)
                         local renk = durum.huzursuz and R.uyari or R.sevgi
                         surface.SetDrawColor(renk.r, renk.g, renk.b, 255)
                         surface.DrawRect(bx, by, bw * math.Clamp(durum.ilerleme or 0, 0, 1), bh)
                         PanoYazi("%" .. math.floor((durum.ilerleme or 0) * 100), Y.Font(22, 600), 0, by + 1, R.parlak)
                         if durum.huzursuz then
                              PanoYazi("Huzursuz: süre durdu — besle, sev, fırçala", Y.Font(26, 600), 0, by + 38, R.uyari)
                         else
                              local kalan = math.max(0, (durum.kalan or 0) - (RealTime() - (durum.alindi or RealTime())))
                              PanoYazi("Yumurtaya yaklaşık " .. Y.SureYazi(kalan), Y.Font(26, 600), 0, by + 38, R.tamam)
                         end
                    elseif durum.d == "kase" then
                         PanoYazi((durum.tur or "") .. " yumurtası sepette", Y.Font(38, "isim"), 0, yy, R.parlak)
                         PanoYazi((durum.s1 or "?") .. " alacak", Y.Font(26, 400), 0, yy + 54, R.sonuk)
                         local kalan = math.max(0, (durum.kalan or 0) - (RealTime() - (durum.alindi or RealTime())))
                         PanoYazi("Alınmazsa " .. Y.SureYazi(kalan) .. " sonra soğur", Y.Font(26, 600), 0, yy + 100, R.uyari)
                    end
               cam.End3D2D()
          end
     end
end)

------------------------------------------------------------------------ yetenekler (Faz 4): efektler

local function Taneler(p, renk, adet, hiz, omur, boy, yukari, yercekimi)
     local e = Yayici(p)
     for _ = 1, adet do
          local q = e:Add(Y.MatNokta, p + VectorRand() * 4)
          if q then
               local v = VectorRand() * hiz
               v.z = math.abs(v.z) + yukari
               q:SetVelocity(v)
               q:SetDieTime(math.Rand(omur * 0.6, omur))
               q:SetStartAlpha(240)
               q:SetEndAlpha(0)
               q:SetStartSize(boy)
               q:SetEndSize(boy * 0.5)
               q:SetColor(renk.r, renk.g, renk.b)
               q:SetGravity(Vector(0, 0, yercekimi or -300))
               q:SetCollide(true)
               q:SetBounce(0.2)
          end
     end
end

-- Burnuk bir şey kokladı: burnundan küçük toz bulutları
EFEKT.kokla = function(ent)
     for i = 0, 3 do
          timer.Simple(i * 0.35, function()
               if IsValid(ent) and ent.CizimKonumu then Duman(ent:CizimKonumu() + Vector(0, 0, 6), Color(190, 180, 160), 1, 3) end
          end)
     end
     ent:EmitSound("player/footsteps/dirt1.wav", 55, 170, 0.3)
end

-- Burnuk eşeliyor: toprak fışkırır
EFEKT.kaz = function(ent)
     local ad = "SardonYaratik.Kaz" .. ent:EntIndex()
     timer.Create(ad, 0.25, 14, function()
          if not IsValid(ent) or not ent.CizimKonumu then timer.Remove(ad) return end
          local p = ent:CizimKonumu()
          Taneler(p + Vector(0, 0, 2), Color(110, 84, 58), 4, 40, 0.8, 1.6, 90)
          if math.random() < 0.35 then
               sound.Play("physics/surfaces/sand_impact_bullet" .. math.random(1, 4) .. ".wav", p, 55, math.random(110, 140), 0.35)
          end
     end)
end

-- Ay Yavrusu dansından kalan gümüş iz: yarım dakika kıvılcımlanır
EFEKT.aygubre = function(ent)
     local p = ent:CizimKonumu() + Vector(0, 0, 2)
     sound.Play("ambient/levels/canals/windchime2.wav", p, 60, 120, 0.5)
     local ad = "SardonYaratik.AyGubre" .. ent:EntIndex() .. "." .. math.floor(RealTime())
     timer.Create(ad, 0.3, 100, function()
          if EyePos():DistToSqr(p) > 2000 * 2000 then return end
          Kivilcim(p + Vector(math.Rand(-14, 14), math.Rand(-14, 14), 0), Color(215, 225, 255), 1, 6, 1.4, 1.6, 10)
     end)
end

-- Fwooper ötüyor: rengârenk tüy kıvılcımları (şarkının sesi delilik mesajıyla gelir)
local FWOOPER_RENK = {Color(255, 120, 60), Color(120, 230, 90), Color(90, 170, 255), Color(255, 220, 70), Color(230, 90, 200)}
EFEKT.fwooper = function(ent)
     for i = 0, 5 do
          timer.Simple(i * 0.5, function()
               if not IsValid(ent) then return end
               local _, o = Ust(ent)
               Kivilcim(o, FWOOPER_RENK[math.random(#FWOOPER_RENK)], 3, 30, 1.2, 2.2, 25)
          end)
     end
end

-- Silencio: soğuk mavi halka
EFEKT.sustur = function(ent)
     local _, orta = Ust(ent)
     for j = 0, 15 do
          local a = j / 16 * math.pi * 2
          Kivilcim(orta + Vector(math.cos(a) * 14, math.sin(a) * 14, 0), Color(140, 190, 255), 1, 6, 1, 2.2, 4)
     end
     sound.Play("ambient/levels/labs/teleport_winddown1.wav", orta, 60, 150, 0.35)
end

------------------------------------------------------------------------ Fwooper deliliği (ekran)

local delilik = {bitis = 0, guc = 0, sure = 1, bas = 0}

-- veri: {sure, guc (0..1), p (şarkının geldiği yer)}
function Y.DelilikBaslat(veri)
     local simdi = RealTime()
     local sure = math.max(tonumber(veri.sure) or 0, 0.5)
     if simdi >= delilik.bitis then delilik.bas = simdi end
     delilik.guc = math.max(tonumber(veri.guc) or 0.5, simdi < delilik.bitis and delilik.guc or 0)
     delilik.bitis = math.max(delilik.bitis, simdi + sure)
     delilik.sure = math.max(delilik.bitis - delilik.bas, 0.5)
     if isvector(veri.p) then
          local p = veri.p
          sound.Play("ambient/levels/coast/coastbird" .. ({4, 6, 7})[math.random(3)] .. ".wav", p, 78, math.random(150, 175), 0.9)
          timer.Simple(1.3, function() sound.Play("ambient/levels/coast/coastbird4.wav", p, 78, math.random(175, 205), 0.8) end)
     end
     for i = 1, 2 do
          timer.Simple(i * 1.7, function()
               local ply = LocalPlayer()
               if RealTime() < delilik.bitis and IsValid(ply) then
                    ply:EmitSound("ambient/levels/citadel/strange_talk" .. math.random(1, 11) .. ".wav", 0, math.random(85, 115), 0.35 * delilik.guc)
               end
          end)
     end
end

hook.Add("RenderScreenspaceEffects", "SardonYaratik.Delilik", function()
     local simdi = RealTime()
     if simdi >= delilik.bitis then return end
     -- yumuşak giriş ve çıkış
     local f = math.Clamp(math.min((delilik.bitis - simdi) * 0.8, (simdi - delilik.bas) * 1.5, 1), 0, 1) * delilik.guc
     local t = simdi * 1.7
     DrawColorModify({
          ["$pp_colour_addr"] = 0.06 * f * (math.sin(t) + 1),
          ["$pp_colour_addg"] = 0.05 * f * (math.sin(t + 2.1) + 1),
          ["$pp_colour_addb"] = 0.06 * f * (math.sin(t + 4.2) + 1),
          ["$pp_colour_brightness"] = 0,
          ["$pp_colour_contrast"] = 1 + 0.15 * f,
          ["$pp_colour_colour"] = 1 + 0.9 * f,
          ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
     })
     DrawMotionBlur(0.12, 0.7 * f, 0.01)
     DrawSharpen(1.2 * f, 1.4)
end)
