-- "addons\\sardonpolaroid\\lua\\entities\\ent_polaroid_camera.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
AddCSLuaFile()

ENT.PrintName = "Cámara Polaroid"
ENT.Category = "!! Sardon"
ENT.Base = "base_ai"
ENT.Type = "ai"

function ENT:Initialize()
	self:SetModel("models/maxofs2d/camera.mdl")
	self:SetModelScale(3)

	if SERVER then
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
	end
end

function ENT:Draw()
     if self:GetNWEntity("Owner") != LocalPlayer() then
          self:DrawModel()
     elseif ix.option.Get("thirdpersonEnabled", false) then
          ix.option.Set("thirdpersonEnabled", false)
     end

     if self:GetNWBool("Flashed") then
          self.FlashStart = self.FlashStart or CurTime()

          if (CurTime() - self.FlashStart) < .2 then
               DrawColorModify({
                    ["$pp_colour_brightness"] = 1
               })
          end
     end
end