-- "addons\\sardongolge\\lua\\sardon_golge\\cl_1kopya.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Gölge :: istemci — ağ (saplama jesti + öz akışı, kurbanın sızısı, dönüşüm dumanı, durum, kayıtlar,
-- bildirim), hançer silahının HUD'u ve dünya modelinin parıltısı.
-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_24 = Vector(0, 0, 24)
local S = SardonGolge

S.Durum = S.Durum or { aktif = false, kalan = 0, bekle = 0, sapla = 0, an = 0 }
S.Kayitlar = S.Kayitlar or {}

surface.CreateFont("SardonGolge.Baslik", { font = "Montserrat SemiBold", size = 20, weight = 600, extended = true })
surface.CreateFont("SardonGolge.Yazi", { font = "Montserrat Medium", size = 16, weight = 500, extended = true })
surface.CreateFont("SardonGolge.Kucuk", { font = "Montserrat Medium", size = 14, weight = 500, extended = true })

S.Renk = {
     zemin = Color(16, 13, 20, 228),
     zeminAcik = Color(30, 25, 36, 240),
     cerceve = Color(150, 124, 82),
     altin = Color(206, 172, 108),
     kagit = Color(234, 226, 210),
     soluk = Color(170, 160, 176),
     mor = Color(150, 110, 230),
     kirmizi = Color(214, 96, 86),
     yesil = Color(132, 196, 128),
}
local R = S.Renk

----------------------------------------------------------------------------------------
-- Efektler
----------------------------------------------------------------------------------------
local DUMAN = "particle/particle_smokegrenade"
local ISIK = "sprites/light_glow02_add"

local function Jest(p, slot, act, yedek)
     if not IsValid(p) then return end
     if (p:SelectWeightedSequence(act) or -1) <= 0 and yedek then act = yedek end
     p:AnimRestartGesture(slot, act, true)
end

local function ElKonumu(p)
     local k = p:LookupBone("ValveBiped.Bip01_R_Hand")
     local pos = k and p:GetBonePosition(k)
     return pos or p:WorldSpaceCenter()
end

-- kurbanın göğsünden saplayanın eline koyu öz zerreleri
local function OzAkisi(h, ply)
     local bas = h:WorldSpaceCenter() + Vector(0, 0, 8)
     local hedef = ElKonumu(ply)
     local em = ParticleEmitter(bas)
     if not em then return end
     local yon = hedef - bas
     for _ = 1, 24 do
          local p = em:Add(DUMAN, bas + VectorRand() * 5)
          if p then
               local t = math.Rand(0.45, 0.8)
               p:SetVelocity(yon / t + VectorRand() * 14)
               p:SetDieTime(t)
               p:SetStartAlpha(150)
               p:SetEndAlpha(0)
               p:SetStartSize(math.Rand(2, 4))
               p:SetEndSize(math.Rand(6, 10))
               p:SetColor(36, 18, 54)
               p:SetRoll(math.Rand(0, 360))
               p:SetRollDelta(math.Rand(-2, 2))
               p:SetAirResistance(10)
          end
     end
     for _ = 1, 12 do
          local p = em:Add(ISIK, bas + VectorRand() * 3)
          if p then
               local t = math.Rand(0.35, 0.65)
               p:SetVelocity(yon / t + VectorRand() * 10)
               p:SetDieTime(t)
               p:SetStartAlpha(220)
               p:SetEndAlpha(0)
               p:SetStartSize(math.Rand(2, 4))
               p:SetEndSize(0.5)
               p:SetColor(R.mor.r, R.mor.g, R.mor.b)
          end
     end
     em:Finish()
end

local function Duman(pos, giris)
     local em = ParticleEmitter(pos)
     if not em then return end
     for _ = 1, 30 do
          local p = em:Add(DUMAN, pos + VectorRand() * 14)
          if p then
               p:SetVelocity(VectorRand() * 40 + Vector(0, 0, math.Rand(10, 50)))
               p:SetDieTime(math.Rand(0.9, 1.6))
               p:SetStartAlpha(giris and 190 or 160)
               p:SetEndAlpha(0)
               p:SetStartSize(math.Rand(8, 14))
               p:SetEndSize(math.Rand(26, 40))
               p:SetColor(28, 16, 40)
               p:SetRoll(math.Rand(0, 360))
               p:SetRollDelta(math.Rand(-1, 1))
               p:SetAirResistance(60)
          end
     end
     for _ = 1, 16 do
          local p = em:Add(ISIK, pos + VectorRand() * 18)
          if p then
               p:SetVelocity(VectorRand() * 60)
               p:SetDieTime(math.Rand(0.4, 0.9))
               p:SetStartAlpha(200)
               p:SetEndAlpha(0)
               p:SetStartSize(math.Rand(3, 6))
               p:SetEndSize(0)
               p:SetColor(R.mor.r, R.mor.g, R.mor.b)
          end
     end
     em:Finish()
     sound.Play("ambient/levels/citadel/weapon_disintegrate" .. math.random(1, 4) .. ".wav", pos, 62, giris and 120 or 90, 0.45)
end

-- kurbanın ekranı: kısa kızıl kenar + sarsıntı
local siziBitis = 0
hook.Add("HUDPaint", "SardonGolge.Sizi", function()
     local kalan = siziBitis - RealTime()
     if kalan <= 0 then return end
     local a = math.Clamp(kalan / 0.8, 0, 1) * 150
     local w, h = ScrW(), ScrH()
     surface.SetDrawColor(140, 20, 24, a)
     local kalin = math.floor(h * 0.06)
     surface.DrawRect(0, 0, w, kalin)
     surface.DrawRect(0, h - kalin, w, kalin)
     surface.DrawRect(0, kalin, kalin, h - kalin * 2)
     surface.DrawRect(w - kalin, kalin, kalin, h - kalin * 2)
end)

local function Bildir(metin, hata)
     if metin == "" then return end
     if ix and ix.util and ix.util.Notify then
          ix.util.Notify(metin)
     else
          chat.AddText(hata and R.kirmizi or R.altin, "[Sombra] ", color_white, metin)
     end
end
S.Bildir = Bildir

----------------------------------------------------------------------------------------
-- Ağ
----------------------------------------------------------------------------------------
net.Receive(S.NET, function()
     local op = net.ReadUInt(S.OP_BIT)
     if op == S.OP.SAPLA then
          local ply, h = net.ReadEntity(), net.ReadEntity()
          if not IsValid(ply) then return end
          Jest(ply, GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE, ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE)
          sound.Play("weapons/iceaxe/iceaxe_swing1.wav", ply:GetShootPos(), 60, math.random(115, 130), 0.6)
          if IsValid(h) then
               timer.Simple(0.16, function()
                    if not (IsValid(h) and IsValid(ply)) then return end
                    Jest(h, GESTURE_SLOT_FLINCH, ACT_FLINCH_STOMACH, ACT_FLINCH_PHYSICS)
                    sound.Play("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav", h:WorldSpaceCenter(), 62, 100, 0.7)
                    sound.Play("ambient/levels/citadel/portal_beam_shoot" .. math.random(1, 6) .. ".wav", h:WorldSpaceCenter(), 55, 160, 0.25)
                    OzAkisi(h, ply)
               end)
          end
     elseif op == S.OP.SIZI then
          siziBitis = RealTime() + 0.8
          util.ScreenShake(LocalPlayer():GetPos(), 6, 12, 0.6, 64)
          Bildir("¡Un dolor agudo! Algo te ha atravesado la piel.", true)
     elseif op == S.OP.DUMAN then
          Duman(net.ReadVector(), net.ReadBool())
     elseif op == S.OP.DURUM then
          S.Durum = { aktif = net.ReadBool(), kalan = net.ReadFloat(), bekle = net.ReadFloat(), sapla = net.ReadFloat(), an = RealTime() }
          hook.Run("SardonGolgeDurum", S.Durum)
     elseif op == S.OP.KAYIT then
          local n = net.ReadUInt(32)
          local veri = n > 0 and net.ReadData(n) or ""
          S.Kayitlar = util.JSONToTable(util.Decompress(veri) or "") or {}
          local ctx = ShineAdmin and ShineAdmin.ActiveCtx and ShineAdmin:ActiveCtx("golge")
          if ctx and ctx.Yenile then ctx.Yenile() end
     elseif op == S.OP.BILDIR then
          local metin, hata = net.ReadString(), net.ReadBool()
          Bildir(metin, hata)
     end
end)

function S.Iste(istek, f)
     net.Start(S.NET)
     net.WriteUInt(S.OP.ISTEK, S.OP_BIT)
     net.WriteUInt(istek, S.ISTEK_BIT)
     if f then f() end
     net.SendToServer()
end

-- durumdaki geri sayımlar (sunucu gönderdiğinden beri geçen süreyle)
function S.Kalan(alan)
     local d = S.Durum
     return math.max(0, (d[alan] or 0) - (RealTime() - (d.an or 0)))
end

----------------------------------------------------------------------------------------
-- Hançer silahı: HUD ve dünya modeli parıltısı (weapons/gerceklikhanceri çağırır)
----------------------------------------------------------------------------------------
local function Kutu(x, y, w, h)
     draw.RoundedBox(6, x, y, w, h, R.zemin)
     surface.SetDrawColor(R.cerceve.r, R.cerceve.g, R.cerceve.b, 160)
     surface.DrawOutlinedRect(x, y, w, h, 1)
end

function S.SilahHUD(wep)
     local ply = LocalPlayer()
     local char = ply:GetCharacter()
     if not char then return end
     local n = S.HancerSay(char)
     local k = char:GetData("gerceklik")
     k = istable(k) and k or nil
     local d = S.Durum

     local satirlar = {}
     satirlar[#satirlar + 1] = { "Cuchillo de la Realidad  ·  " .. n, "SardonGolge.Baslik", n > 0 and R.altin or R.kirmizi }
     satirlar[#satirlar + 1] = { k and ("Aspecto: " .. (k.ad or "?")) or "Sin aspecto en el cuchillo", "SardonGolge.Yazi", k and R.kagit or R.soluk }
     local durum
     if d.aktif and ply:GetNW2Bool("GolgeKilik", false) then
          durum = { "Disfrazado  ·  quedan " .. S.Sure(S.Kalan("kalan")), R.mor }
     elseif S.Kalan("bekle") > 0 then
          durum = { "El cuchillo se recarga  ·  " .. S.Sure(S.Kalan("bekle")), R.soluk }
     elseif S.Kalan("sapla") > 0 then
          durum = { "El cuchillo se enfría  ·  " .. math.ceil(S.Kalan("sapla")) .. " s", R.soluk }
     else
          durum = { "Clic izq.: clavar   ·   Clic der.: menú de disfraz", R.soluk }
     end
     satirlar[#satirlar + 1] = { durum[1], "SardonGolge.Kucuk", durum[2] }

     local w = 0
     for _, s in ipairs(satirlar) do
          surface.SetFont(s[2])
          w = math.max(w, (surface.GetTextSize(s[1])))
     end
     w = w + 32
     local h = 18 + #satirlar * 22
     local x, y = math.floor(ScrW() / 2 - w / 2), ScrH() - h - 190
     Kutu(x, y, w, h)
     for i, s in ipairs(satirlar) do
          draw.SimpleText(s[1], s[2], x + w / 2, y + 9 + (i - 1) * 22 + 11, s[3], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     end
end

local isik = Material(ISIK)
function S.SilahParilti(wep)
     local owner = wep:GetOwner()
     if not IsValid(owner) or not owner:GetNW2Bool("GolgeKopyaVar", false) then return end
     local nabiz = 0.6 + 0.4 * math.sin(RealTime() * 3)
     render.SetMaterial(isik)
     render.DrawSprite(wep:WorldSpaceCenter(), 7 + nabiz * 3, 7 + nabiz * 3, Color(R.mor.r, R.mor.g, R.mor.b, 90 + nabiz * 70))
end

-- silah eline geçince güncel durum
hook.Add("PlayerSwitchWeapon", "SardonGolge", function(ply, _, yeni)
     if ply == LocalPlayer() and IsValid(yeni) and yeni:GetClass() == S.SILAH and IsFirstTimePredicted() then
          S.Iste(S.ISTEK.DURUM)
     end
end)

----------------------------------------------------------------------------------------
-- Gölge'nin çevresi: bel hizasından dışarı yayılan hafif siyah duman, bedene sarılı karanlık tül (aura) ve
-- yakındayken seyrek siyah zerreler. Görev sisteminin istemci aktörü (SardonGorev.Aktorler, veri.id == "golge").
-- Yalnız 1600 birim içinde; saniyede ~20 duman (FPS Boost açıkken yarısı), tek kalıcı yayıcı. İsim etiketi de
-- burada (görev sisteminin etiketi kapalı, isimGoster = false): siyah ad + beyaz kenar, beyaz unvan + siyah kenar.
----------------------------------------------------------------------------------------
local golgeC, golgeAra, golgeSonraki, golgeEm = nil, 0, 0, nil

local function GolgeAktoru()
     local G = SardonGorev
     for _, c in pairs(G and G.Aktorler or {}) do
          if c.veri and c.veri.id == S.AKTOR then return c end
     end
end

hook.Add("Think", "SardonGolge.Aura", function()
     local simdi = RealTime()
     if simdi >= golgeAra then
          golgeAra = simdi + 1
          golgeC = GolgeAktoru()
     end
     local ent = golgeC and golgeC.ent
     if not IsValid(ent) or ent:GetNoDraw() then
          if golgeEm then golgeEm:Finish() golgeEm = nil end
          return
     end
     if simdi < golgeSonraki then return end

     local merkez = ent:GetPos()
     local uz2 = EyePos():DistToSqr(merkez)
     if uz2 > 1600 * 1600 then return end
     local dusuk = SardonFPSBoost == true
     golgeSonraki = simdi + (dusuk and 0.1 or 0.05)

     if not golgeEm then golgeEm = ParticleEmitter(merkez, false) end
     if not golgeEm then return end
     golgeEm:SetPos(merkez)
     local olcek = ent:GetModelScale() or 1
     local bel = merkez + Vector(0, 0, 36 * olcek)

     -- yayılan duman: bedenin çevresinden dışarı, bel hizasında yatay; yavaşlayıp asılı kalır, genişleyip söner
     local a = math.Rand(0, math.pi * 2)
     local yon = Vector(math.cos(a), math.sin(a), 0)
     local p = golgeEm:Add(DUMAN, bel + yon * math.Rand(8, 16) + Vector(0, 0, math.Rand(-6, 5)))
     if p then
          p:SetVelocity(yon * math.Rand(14, 32) + Vector(0, 0, math.Rand(-2, 2)))
          p:SetAirResistance(16)
          p:SetGravity(Vector(0, 0, math.Rand(-1, 1)))
          p:SetDieTime(math.Rand(3.2, 4.8))
          p:SetStartAlpha(math.Rand(65, 100))
          p:SetEndAlpha(0)
          p:SetStartSize(math.Rand(8, 12))
          p:SetEndSize(math.Rand(34, 52))
          p:SetRoll(math.Rand(0, 360))
          p:SetRollDelta(math.Rand(-0.4, 0.4))
          local k = math.random(8, 18)
          p:SetColor(k, math.floor(k * 0.8), math.floor(k * 1.25))   -- siyaha yakın, hafif mor
     end

     -- aura: bel bandında (yüz ve maske açık kalsın) bedene sarılı, yavaşça dönen hafif koyu tül
     if math.random() < 0.5 then
          local b = math.Rand(0, math.pi * 2)
          local yer = Vector(math.cos(b), math.sin(b), 0)
          local q = golgeEm:Add(DUMAN, merkez + yer * math.Rand(8, 14) + Vector(0, 0, math.Rand(24, 46) * olcek))
          if q then
               q:SetVelocity(Vector(-yer.y, yer.x, 0) * math.Rand(6, 12) + Vector(0, 0, math.Rand(0, 3)))
               q:SetAirResistance(30)
               q:SetDieTime(math.Rand(1.4, 2.2))
               q:SetStartAlpha(math.Rand(45, 75))
               q:SetEndAlpha(0)
               q:SetStartSize(math.Rand(5, 8))
               q:SetEndSize(math.Rand(14, 22))
               q:SetRoll(math.Rand(0, 360))
               q:SetRollDelta(math.Rand(-1, 1))
               q:SetColor(6, 4, 10)
          end
     end

     -- yakındayken seyrek siyah zerreler (bel çevresinde süzülür; toplamalı parıltı siyah çizemez → duman dokusu)
     if uz2 < 700 * 700 and math.random() < (dusuk and 0.08 or 0.18) then
          local r = golgeEm:Add(DUMAN, bel + VectorRand() * 16)
          if r then
               r:SetVelocity(VectorRand() * 6 + Vector(0, 0, math.Rand(3, 8)))
               r:SetAirResistance(20)
               r:SetDieTime(math.Rand(1.2, 2))
               r:SetStartAlpha(0)
               r:SetEndAlpha(0)
               r:SetStartSize(math.Rand(2, 3.5))
               r:SetEndSize(1)
               r:SetColor(0, 0, 0)
               r:SetNextThink(CurTime())
               r:SetThinkFunction(function(z)
                    local t = z:GetLifeTime() / math.max(0.01, z:GetDieTime())
                    z:SetStartAlpha(math.sin(t * math.pi) * 230)
                    z:SetNextThink(CurTime())
               end)
          end
     end
end)

-- Gölge'nin isim etiketi (görev sisteminin [cl_3aktor BasNoktasi: baş + 12, ölçek 0.06] yerine): siyah ad + beyaz
-- kenar, beyaz unvan + siyah kenar, %25 büyük (0.075), başın 24 birim üstünde; 700 birim içinde, sinematikte gizli
local ETIKET_SIYAH = Color(6, 5, 8)
local ETIKET_BEYAZ = Color(238, 236, 232)
hook.Add("PostDrawTranslucentRenderables", "SardonGolge.Isim", function(_, gok)
     if gok then return end
     local c = golgeC
     local ent = c and c.ent
     if not IsValid(ent) or not c.cizPos or (c.alfa or 0) <= 0.05 then return end
     local G = SardonGorev
     if G and G.Sinematik and G.Sinematik() then return end
     local goz = EyePos()
     local d = goz:Distance(c.cizPos)
     if d >= 700 then return end
     local v = c.veri or {}

     local bas
     local kemik = ent:LookupBone("ValveBiped.Bip01_Head1")
     local m = kemik and ent:GetBoneMatrix(kemik)
     bas = m and (m:GetTranslation() + OPT_V_0_0_24) or (c.cizPos + Vector(0, 0, 88 * (tonumber(v.boy) or 1)))
     local alfa = math.Clamp((1100 - d) / 300, 0, 1) * c.alfa

     cam.Start3D2D(bas, Angle(0, EyeAngles().y - 90, 90), 0.075)
          draw.SimpleTextOutlined(v.ad or "Sombra", "SardonGorev.D_Ad", 0, 0, Color(ETIKET_SIYAH.r, ETIKET_SIYAH.g, ETIKET_SIYAH.b, 255 * alfa),
               TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, Color(ETIKET_BEYAZ.r, ETIKET_BEYAZ.g, ETIKET_BEYAZ.b, 210 * alfa))
          if v.unvan and v.unvan ~= "" then
               draw.SimpleTextOutlined(G and G.Buyuk and G.Buyuk(v.unvan) or v.unvan, "SardonGorev.D_Unvan", 0, 4, Color(ETIKET_BEYAZ.r, ETIKET_BEYAZ.g, ETIKET_BEYAZ.b, 245 * alfa),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(ETIKET_SIYAH.r, ETIKET_SIYAH.g, ETIKET_SIYAH.b, 230 * alfa))
          end
     cam.End3D2D()
end)
