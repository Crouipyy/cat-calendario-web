-- "addons\\sardonekonomi\\lua\\entities\\ent_sardon_tezgah.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- [sardon] ekonomi: İlan tezgâhı. E ile oyuncular arası alım satım.
AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.PrintName = "İlan Tezgâhı"
ENT.Category = "!! Sardon"
ENT.Spawnable = false
ENT.Model = "models/props_c17/FurnitureTable001a.mdl"

function ENT:SetupDataTables()
     self:NetworkVar("String", 0, "Tur")
end

if SERVER then
     function ENT:Initialize()
          self:SetModel(util.IsValidModel(self.Model) and self.Model or "models/props_c17/FurnitureShelf001b.mdl")
          self:PhysicsInit(SOLID_VPHYSICS)
          self:SetMoveType(MOVETYPE_VPHYSICS)
          self:SetSolid(SOLID_VPHYSICS)
          self:SetUseType(SIMPLE_USE)
          local f = self:GetPhysicsObject()
          if IsValid(f) then f:EnableMotion(false) end
     end

     function ENT:Use(ply)
          if IsValid(ply) and ply:IsPlayer() and SardonEkonomi.PencereGonder then
               SardonEkonomi.PencereGonder(ply, "tezgah", self)
          end
     end
     return
end

function ENT:Draw()
     self:DrawModel()
     local lp = LocalPlayer()
     if not IsValid(lp) or lp:GetPos():DistToSqr(self:GetPos()) > 600 * 600 then return end
     local mins, maxs = self:OBBMins(), self:OBBMaxs()
     local pos = self:LocalToWorld(Vector((mins.x + maxs.x) / 2, (mins.y + maxs.y) / 2, maxs.z + 14))
     local ang = Angle(0, (lp:EyePos() - pos):Angle().y + 90, 90)
     cam.Start3D2D(pos, ang, 0.08)
          draw.RoundedBox(8, -150, -6, 300, 70, Color(20, 16, 12, 215))
          draw.SimpleText("İlan Tezgâhı", "SardonEko.Etiket", 0, 2, Color(232, 204, 140), TEXT_ALIGN_CENTER)
          draw.SimpleText("Oyuncular arası alım satım", "SardonEko.EtiketKucuk", 0, 36, Color(206, 196, 176), TEXT_ALIGN_CENTER)
     cam.End3D2D()
end
