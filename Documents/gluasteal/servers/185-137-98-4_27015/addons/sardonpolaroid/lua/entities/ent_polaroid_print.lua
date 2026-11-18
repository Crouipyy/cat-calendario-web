-- "addons\\sardonpolaroid\\lua\\entities\\ent_polaroid_print.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
AddCSLuaFile()

ENT.PrintName = "Impresión Polaroid"
ENT.Category = "!! Sardon"
ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
     self.holdable = true
     self.SpawnedAt = CurTime()

     if CLIENT then return end
     self:SetModel("models/props_junk/garbage_newspaper001a.mdl")
     self:PhysicsInit(SOLID_VPHYSICS)
     self:DrawShadow(false)
     self:SetUseType(SIMPLE_USE)
end

function ENT:OnPopulateEntityInfo(panel)
     if self:GetImage() == "" then return false end

     local name = panel:AddRow("name")
     name:SetImportant()
     name:SetBackgroundColor(Color(218, 34, 187))
     name:SetText("Recuerdo capturado")
     name:SizeToContents()

     panel:SizeToContents()
end

function ENT:SetupDataTables()
     self:NetworkVar( "String", 0, "Image" )
end

function ENT:Use(activator)
     if activator:GetCharacter():GetInventory():FindEmptySlot(1, 1) == nil then return end

     activator:GetCharacter():GetInventory():Add("PolaroidPhoto", 1, { Image = self:GetImage() })
     activator:EmitSound("npc/zombie/foot_slide" .. math.random(1, 3) .. ".wav", 75, math.random(90, 120), 1)
     SafeRemoveEntity(self)
end

function ENT:PhysicsCollide(data, phys)
     if IsValid(data.HitEntity) and (data.HitEntity:GetClass() == "ent_polaroid_table" or data.HitEntity:GetClass() == "ent_polaroid_projector") then
          if data.HitEntity.GetHidden and data.HitEntity:GetHidden() then return end
          data.HitEntity:SetImage(self:GetImage())
     end
end

function ENT:Draw()
     local ang = self:GetAngles()
     ang:RotateAroundAxis(ang:Up(), 90)

     cam.Start3D2D(self:GetPos() + ang:Right() * -9 + ang:Forward() * -13, ang, 0.04)
     local w = 600
     draw.RoundedBox(0, 0, 0, w, w * 12 / 16, color_white)
     draw.RoundedBox(0, w * .05, w * .05, w * .9, (w * .9) * 9 / 16, color_black)

     if self:GetImage() != "" then
          if self.IconPath != self:GetImage() then
               self.IconPath = self:GetImage()
               XeninUI:DownloadIcon(self, {{ id = self.IconPath, url = "https://proxy.duckduckgo.com/iu/?u=https://iili.io" }})
          end

          if type(self.Icon) != "IMaterial" then
               self.SpawnedAt = CurTime()
          else
               XeninUI:DrawIcon(w * .05, w * .05, w * .9, (w * .9) * 9 / 16, self, self:GetNWBool("IsFresh", false) and ColorAlpha(color_white, 255 * (CurTime() - self.SpawnedAt) / 12) or color_white)
          end
     end
     cam.End3D2D()
end