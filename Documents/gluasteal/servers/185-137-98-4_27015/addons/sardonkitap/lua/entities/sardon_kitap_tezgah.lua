-- "addons\\sardonkitap\\lua\\entities\\sardon_kitap_tezgah.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
-- Sardon Kitap :: kitapçı tezgâhı (kalıcı dükkân). Konumlar Shine › Kitaplar › Kitapçı'dan;
-- açılışta ve harita temizlenince sardon_kitap/sv_7kitapci.lua SK.TezgahlariKur ile yeniden konur.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Kitapçı Tezgâhı"
ENT.Category = "Sardon Kitap"
ENT.Spawnable = false

function ENT:Initialize()
     self:SetModel((SardonKitap and SardonKitap.TEZGAH_MODEL) or "models/hpwrewrite/books/books1.mdl")
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
          if not IsValid(ply) or not ply:IsPlayer() then return end
          if (ply.SKTezgahSon or 0) > CurTime() then return end
          ply.SKTezgahSon = CurTime() + 1
          if SardonKitap and SardonKitap.DukkanAc then SardonKitap.DukkanAc(ply, self) end
     end
end

if CLIENT then
     local isik = Material("sprites/light_glow02_add")

     function ENT:Draw()
          self:DrawModel()
          local pos = self:GetPos() + Vector(0, 0, 30)
          if pos:DistToSqr(EyePos()) > 600 * 600 then return end
          render.SetMaterial(isik)
          render.DrawSprite(pos, 28, 28, Color(240, 214, 150, 50 + math.sin(CurTime() * 1.6) * 20))
     end
end
