-- "addons\\sardonkitap\\lua\\entities\\sardon_kitap_kazan.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: kurulan okul kazanı (yalnız sahibi kullanır; mantık sardon_kitap/sv_9kazan.lua)
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Okul Kazanı"
ENT.Category = "Sardon Kitap"
ENT.Spawnable = false

function ENT:SetupDataTables()
     self:NetworkVar("Entity", 0, "Sahip")
     self:NetworkVar("String", 0, "SahipAd")
end

function ENT:Initialize()
     self:SetModel((SardonKitap and SardonKitap.KAZAN_MODEL) or "models/props_c17/metalPot001a.mdl")
     if SERVER then
          self:PhysicsInit(SOLID_VPHYSICS)
          self:SetMoveType(MOVETYPE_NONE)
          self:SetSolid(SOLID_VPHYSICS)
          self:SetUseType(SIMPLE_USE)
          local phys = self:GetPhysicsObject()
          if IsValid(phys) then phys:EnableMotion(false) end
     end
end

if SERVER then
     function ENT:Use(ply)
          if IsValid(ply) and ply:IsPlayer() and SardonKitap and SardonKitap.KazanKullan then
               SardonKitap.KazanKullan(ply, self)
          end
     end
end

if CLIENT then
     local isik = Material("sprites/light_glow02_add")

     -- yanında Presto Tarif Kitabı (St_prop3, 11-05; yalnız görüntü)
     local TARIF = "models/staylofft/hogwarts_books/staylofft_presto_recipe_book.mdl"
     function ENT:OnRemove()
          if IsValid(self.tarif) then self.tarif:Remove() end
     end

     function ENT:Draw()
          self:DrawModel()
          if not IsValid(self.tarif) then
               self.tarif = ClientsideModel(TARIF, RENDERGROUP_OPAQUE)
               if IsValid(self.tarif) then self.tarif:SetNoDraw(true) end
          end
          if IsValid(self.tarif) then
               local p, a = LocalToWorld(Vector(8, 30, 0.3), Angle(0, -28, 0), self:GetPos(), Angle(0, self:GetAngles().y, 0))
               self.tarif:SetPos(p)
               self.tarif:SetAngles(a)
               self.tarif:DrawModel()
          end
          -- kazanın üstünde soluk bir buhar parıltısı
          local pos = self:GetPos() + Vector(0, 0, 26)
          render.SetMaterial(isik)
          local a = 40 + math.sin(CurTime() * 2) * 15
          render.DrawSprite(pos, 34, 34, Color(150, 220, 160, a))
     end

     function ENT:GetEntityMenu() return nil end
end
