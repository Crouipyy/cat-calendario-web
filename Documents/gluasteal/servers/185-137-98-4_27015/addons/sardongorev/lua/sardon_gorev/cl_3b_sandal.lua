-- "addons\\sardongorev\\lua\\sardon_gorev\\cl_3b_sandal.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
/*
*   Sandal yolculuğu (istemci): sunucunun duyurduğu sandalları çizer. Konum _sh_4sandal.lua'daki
*   eğriden her karede hesaplanır; sandalın üstünde fener, kıçında küçük dümen suyu.
*
*   Başkasının sandalı ara değerleme gecikmesi kadar geriden çizilir: o oyuncunun modeli de
*   ağdan o kadar geride geldiği için ikisi üst üste oturur. Kendi sandalımız tahminle aynı anda.
*/
-- 11-13 opt (kodmod): kare başı kurulan sabitler dosya yereline alındı
local OPT_V_0_0_2 = Vector(0, 0, 2)
local OPT_R_255_190_110_200 = Color(255, 190, 110, 200)
local OPT_R_255_170_90_40 = Color(255, 170, 90, 40)
local G = SardonGorev

local FENER = "models/props/cs_italy/it_lantern1.mdl"
local FENER_YER = Vector(96, 0, 22)
local matIsik = Material("sprites/light_glow02_add")
local cvInterp, cvOran, cvGuncelleme = GetConVar("cl_interp"), GetConVar("cl_interp_ratio"), GetConVar("cl_updaterate")

function G.SandalZaman(s)
     if s.ply == LocalPlayer():EntIndex() then return CurTime() end
     local oran = (cvOran and cvOran:GetFloat() or 2) / math.max(1, cvGuncelleme and cvGuncelleme:GetFloat() or 16)
     return CurTime() - math.Clamp(math.max(cvInterp and cvInterp:GetFloat() or 0.1, oran), 0, 0.5)
end

local function ModelSec(m)
     if isstring(m) and m ~= "" and file.Exists(m, "GAME") then return m end
     if file.Exists(G.SANDAL.model, "GAME") then return G.SANDAL.model end
     return G.SANDAL.yedekModel
end

local function Sil(s)
     if IsValid(s.ent) then s.ent:Remove() end
     if IsValid(s.fener) then s.fener:Remove() end
     G.Sandallar[s.no] = nil
end

net.Receive("SardonGorev.Sandal", function()
     if not net.ReadBool() then
          local s = G.Sandallar[net.ReadUInt(16)]
          if s then Sil(s) end
          return
     end
     local s = { no = net.ReadUInt(16), t0 = net.ReadDouble(), hiz = net.ReadFloat(), ivme = net.ReadFloat(), model = net.ReadString(), ply = net.ReadUInt(16), noktalar = {} }
     for i = 1, net.ReadUInt(8) do s.noktalar[i] = net.ReadVector() end
     if #s.noktalar < 2 then return end
     local eski = G.Sandallar[s.no]
     if eski then Sil(eski) end
     G.SandalHazirla(s)
     G.Sandallar[s.no] = s
end)

local function Kur(s)
     local ent = ClientsideModel(ModelSec(s.model), RENDERGROUP_OPAQUE)
     if not IsValid(ent) then return end
     s.ent = ent
     local fener = ClientsideModel(FENER, RENDERGROUP_OPAQUE)
     if IsValid(fener) then s.fener = fener end
end

local function Guncelle(s, t, simdi)
     if not IsValid(s.ent) then Kur(s) if not IsValid(s.ent) then return end end
     local pos, yaw = G.SandalDurum(s, t)
     -- su üstünde hafif yalpalama (yalnız görüntü; koltuklar düz kalır)
     local ang = Angle(math.sin(t * 1.1) * 1.2, yaw, math.sin(t * 0.9) * 2.2)
     s.ent:SetPos(pos)
     s.ent:SetAngles(Angle(ang.p, yaw + (s.ent:GetModel() == G.SANDAL.model and G.SANDAL.modelYaw or 0), ang.r))

     local fpos = LocalToWorld(FENER_YER, angle_zero, pos, ang)
     s.fenerPos = fpos
     if IsValid(s.fener) then
          s.fener:SetPos(fpos)
          s.fener:SetAngles(Angle(0, yaw, 0))
     end

     local d = DynamicLight(40000 + s.no % 1000)
     if d then
          d.pos = fpos + Vector(0, 0, 6)
          d.r, d.g, d.b = 255, 196, 120
          d.brightness = 2
          d.size = 300 + math.sin(simdi * 7) * 12
          d.decay = 900
          d.dietime = simdi + 0.2
     end

     -- dümen suyu: giderken kıçtan köpük
     local gidiyor = t > s.t0 and t < s.t0 + s.sure
     if gidiyor and simdi > (s.sonKopuk or 0) then
          s.sonKopuk = simdi + 0.12
          local em = ParticleEmitter(pos, false)
          if em then
               local kic = LocalToWorld(Vector(-100, math.Rand(-18, 18), -G.SANDAL.su - 1), angle_zero, pos, Angle(0, yaw, 0))
               local p = em:Add("particle/smokesprites_000" .. math.random(1, 9), kic)
               if p then
                    p:SetVelocity(Angle(0, yaw, 0):Forward() * -20 + Vector(math.Rand(-8, 8), math.Rand(-8, 8), 0))
                    p:SetDieTime(math.Rand(1.6, 2.6))
                    p:SetStartAlpha(36)
                    p:SetEndAlpha(0)
                    p:SetStartSize(math.Rand(6, 10))
                    p:SetEndSize(math.Rand(26, 40))
                    p:SetRoll(math.Rand(0, 360))
                    p:SetColor(220, 230, 235)
                    p:SetAirResistance(30)
               end
               em:Finish()
          end
     end
end

hook.Add("Think", "SardonGorev.Sandal", function()
     if next(G.Sandallar) == nil then return end
     local lp = LocalPlayer()
     if not IsValid(lp) then return end
     local simdi = CurTime()
     local goz = lp:EyePos()
     for _, s in pairs(G.Sandallar) do
          if s.yol then
               local t = G.SandalZaman(s)
               local yakin = goz:DistToSqr(G.SandalDurum(s, t)) < 9000 * 9000
               if yakin then
                    local ok, hata = pcall(Guncelle, s, t, simdi)
                    if not ok then
                         ErrorNoHalt("[Sardon Görev] sandal: " .. tostring(hata) .. "\n")
                         Sil(s)
                    end
               end
               if IsValid(s.ent) then s.ent:SetNoDraw(not yakin) end
               if IsValid(s.fener) then s.fener:SetNoDraw(not yakin) end
          end
     end
end)

-- Fenerin ışıltısı
hook.Add("PostDrawTranslucentRenderables", "SardonGorev.Sandal", function(derinlik, gok)
     if gok or next(G.Sandallar) == nil then return end
     local simdi = CurTime()
     render.SetMaterial(matIsik)
     for _, s in pairs(G.Sandallar) do
          if s.fenerPos and IsValid(s.ent) and not s.ent:GetNoDraw() then
               local boy = 34 + math.sin(simdi * 6 + s.no) * 3
               render.DrawSprite(s.fenerPos + OPT_V_0_0_2, boy, boy, OPT_R_255_190_110_200)
               render.DrawSprite(s.fenerPos + OPT_V_0_0_2, boy * 2.6, boy * 2.6, OPT_R_255_170_90_40)
          end
     end
end)

-- Sandaldaki aktörle "E ile konuş" istemi çıkmasın (yolculukta konuşmalar kendiliğinden)
hook.Add("SardonGorevKonusGizle", "SardonGorev.Sandal", function(c)
     if c and c.binis then return true end
end)
