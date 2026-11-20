-- "addons\\sardonyaratik\\lua\\entities\\sardon_viv_cikis.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] yaratik :: kişisel vivaryumun çıkışı (bahçede, bütün dünyalarda ortak; sv_9vivaryum.lua Y.CikisKur)
-- Görüntü: yerde ağzı açık, büyümüş bir Yakalama Çantası ve ağzından yükselen ışık sütunu. E: dışarıdaki çantadan çık.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Vivaryum Çıkışı"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

local MODEL = "models/staylofft/hogwarts_props/staylofft_gladstone_bag.mdl"
local OLCEK = 3.2
local KUTU = {Vector(-44, -44, 0), Vector(44, 44, 64)}

function ENT:Initialize()
     self:SetModel(MODEL)
     if SERVER then
          self:SetMoveType(MOVETYPE_NONE)
          self:SetSolid(SOLID_BBOX)
          self:SetCollisionBounds(KUTU[1], KUTU[2])
          self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
          self:SetUseType(SIMPLE_USE)
          self:DrawShadow(false)
     else
          self:SetRenderBounds(Vector(-80, -80, 0), Vector(80, 80, 260))
     end
end

if SERVER then
     function ENT:Use(ply)
          local Y = SardonYaratik
          if IsValid(ply) and ply:IsPlayer() and Y and Y.VivCik then Y.VivCik(ply) end
     end
     function ENT:OnTakeDamage() end
     hook.Add("PhysgunPickup", "SardonYaratik.VivCikis", function(_, e)
          if IsValid(e) and e:GetClass() == "sardon_viv_cikis" then return false end
     end)
     hook.Add("CanTool", "SardonYaratik.VivCikis", function(_, tr)
          if tr and IsValid(tr.Entity) and tr.Entity:GetClass() == "sardon_viv_cikis" then return false end
     end)
     return
end

local PARILTI = Material("sprites/light_glow02_add")
local SUTUN = Material("sprites/light_glow02_add")

function ENT:Draw()
     if not self.olcekli then
          self:SetModelScale(OLCEK, 0)
          local bg = self:FindBodygroupByName("state")
          if bg and bg >= 0 then self:SetBodygroup(bg, 1) end
          self.olcekli = true
     end
     self:DrawModel()
end

function ENT:Think()
     local goz = EyePos()
     local p = self:GetPos()
     if goz:DistToSqr(p) > 1800 * 1800 then return end
     local dl = DynamicLight(self:EntIndex())
     if dl then
          dl.pos = p + Vector(0, 0, 40)
          dl.r, dl.g, dl.b = 255, 214, 150
          dl.brightness = 1.4 + math.sin(CurTime() * 2) * 0.2
          dl.size = 220
          dl.decay = 500
          dl.dietime = CurTime() + 0.3
     end
     -- ağızdan yükselen kıvılcımlar
     if (self.kivT or 0) < CurTime() then
          self.kivT = CurTime() + 0.08
          self.em = self.em or ParticleEmitter(p, false)
          local q = p + Vector(math.Rand(-18, 18), math.Rand(-18, 18), 40)
          local part = self.em:Add("sprites/light_glow02_add", q)
          if part then
               part:SetVelocity(Vector(math.Rand(-6, 6), math.Rand(-6, 6), math.Rand(40, 80)))
               part:SetDieTime(math.Rand(1.2, 2))
               part:SetStartAlpha(220)
               part:SetEndAlpha(0)
               part:SetStartSize(math.Rand(2, 4))
               part:SetEndSize(0)
               part:SetColor(255, math.random(200, 235), 150)
               part:SetGravity(Vector(0, 0, 8))
          end
     end
end

function ENT:OnRemove()
     if self.em then self.em:Finish() self.em = nil end
end

function ENT:DrawTranslucent()
     self:Draw()
     local p = self:GetPos()
     local goz = EyePos()
     local t = CurTime()
     -- ışık sütunu
     render.SetMaterial(SUTUN)
     for i = 0, 6 do
          local z = 40 + i * 28
          local a = 150 * (1 - i / 7) * (0.8 + 0.2 * math.sin(t * 2 + i))
          render.DrawSprite(p + Vector(0, 0, z), 70 - i * 6, 70 - i * 6, Color(255, 220, 160, a))
     end
     render.SetMaterial(PARILTI)
     render.DrawSprite(p + Vector(0, 0, 42), 120, 60, Color(255, 230, 180, 180))

     if goz:DistToSqr(p) > 260 * 260 then return end
     local Y = SardonYaratik
     local q = p + Vector(0, 0, 110)
     local ang = (goz - q):Angle()
     ang = Angle(0, ang.y + 90, 90)
     local f1 = Y and Y.Font and Y.Font(34, "baslik") or "DermaLarge"
     local f2 = Y and Y.Font and Y.Font(24, 600) or "DermaDefault"
     cam.Start3D2D(q, ang, 0.08)
          surface.SetDrawColor(10, 20, 14, 225)
          surface.DrawRect(-180, -40, 360, 80)
          surface.SetDrawColor(196, 164, 92, 255)
          surface.DrawRect(-180, -40, 360, 3)
          draw.SimpleText("ÇANTANIN AĞZI", f1, 0, -18, Color(236, 220, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          draw.SimpleText("E: dışarı çık", f2, 0, 16, Color(190, 200, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
     cam.End3D2D()
end
