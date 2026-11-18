-- "addons\\sardonbakanlik\\lua\\entities\\sardon_sinsioskop.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sinsioskop: Seherbazların sahaya kurduğu Karanlık Dedektörü. Menzilinde karanlık büyü
-- yapılınca hızla döner, ıslık çalar ve Bakanlığa haber verir (sv_7iz.lua). Görünür ve
-- kırılabilir: karanlık taraf fark ederse büyüyle susturabilir; susması da ihbar olur.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Sinsioscopio"
ENT.Author = "Sardon"
ENT.Category = "Sardon"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

local MODEL = "models/maxofs2d/hover_rings.mdl"

if SERVER then
     function ENT:Initialize()
          self:SetModel(MODEL)
          self:SetModelScale(0.75, 0)
          self:PhysicsInit(SOLID_VPHYSICS)
          -- modelin çarpışma kabuğu yoksa büyüler içinden geçer: kutu kabuk
          if not IsValid(self:GetPhysicsObject()) then self:PhysicsInitBox(Vector(-9, -9, -9), Vector(9, 9, 9)) end
          self:SetMoveType(MOVETYPE_NONE)
          self:SetSolid(SOLID_VPHYSICS)
          self:SetUseType(SIMPLE_USE)
          self:SetColor(Color(214, 178, 96))
          self:SetMaterial("models/shiny")

          local fizik = self:GetPhysicsObject()
          if IsValid(fizik) then fizik:EnableMotion(false) end

          local can = SardonBakanlik and SardonBakanlik.Ayar.SinsioskopCan or 60
          self:SetMaxHealth(can)
          self:SetHealth(can)
     end

     function ENT:OnTakeDamage(hasar)
          if self.SBKirildi then return end
          self:SetHealth(self:Health() - hasar:GetDamage())
          self:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1, 5) .. ".wav", 70, 140)

          if self:Health() <= 0 then
               self.SBKirildi = true
               local saldiran = hasar:GetAttacker()

               local efekt = EffectData()
               efekt:SetOrigin(self:GetPos())
               efekt:SetMagnitude(2)
               efekt:SetScale(1)
               util.Effect("cball_explode", efekt)
               self:EmitSound("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", 80, 130)

               if SardonBakanlik and SardonBakanlik.SinsioskopKirildi then SardonBakanlik.SinsioskopKirildi(self, saldiran) end
               self:Remove()
          end
     end

     function ENT:Use(kullanan)
          if IsValid(kullanan) and kullanan:IsPlayer() and SardonBakanlik and SardonBakanlik.SinsioskopKullan then
               SardonBakanlik.SinsioskopKullan(self, kullanan)
          end
     end

     return
end

local matIsik = Material("sprites/light_glow02_add")
local ALTIN = Color(232, 196, 110)
local KIZIL = Color(255, 96, 70)

function ENT:Initialize()
     self.aci = math.Rand(0, 360)
     self.hiz = 40
end

function ENT:Draw()
     local alarm = self:GetNW2Float("Alarm", 0) > CurTime()
     local hedefHiz = alarm and 1400 or 40
     self.hiz = Lerp(math.min(1, FrameTime() * 3), self.hiz or 40, hedefHiz)
     self.aci = ((self.aci or 0) + self.hiz * FrameTime()) % 360

     -- topaç: kendi ekseninde döner, hafifçe yalpalar
     local t = CurTime()
     local yalpa = alarm and 14 or 5
     local aci = Angle(math.sin(t * 2.3) * yalpa, self.aci, math.cos(t * 1.9) * yalpa)
     self:SetRenderAngles(aci)
     self:SetRenderOrigin(self:GetPos() + Vector(0, 0, math.sin(t * 1.7) * 1.5))
     self:DrawModel()
     self:SetRenderAngles()
     self:SetRenderOrigin()
end

function ENT:DrawTranslucent()
     local alarm = self:GetNW2Float("Alarm", 0) > CurTime()
     local pos = self:GetPos() + Vector(0, 0, 2)
     local c = alarm and KIZIL or ALTIN
     local boy = alarm and (46 + math.sin(CurTime() * 22) * 14) or (16 + math.sin(CurTime() * 2) * 3)

     render.SetMaterial(matIsik)
     render.DrawSprite(pos, boy, boy, Color(c.r, c.g, c.b, alarm and 255 or 150))

     if alarm then
          local isik = DynamicLight(self:EntIndex())
          if isik then
               isik.pos = pos
               isik.r, isik.g, isik.b = c.r, c.g, c.b
               isik.brightness = 2
               isik.Decay = 600
               isik.Size = 180
               isik.DieTime = CurTime() + 0.2
          end
     end
end
