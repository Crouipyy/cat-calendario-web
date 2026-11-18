-- "addons\\sardonpolaroid\\lua\\entities\\ent_polaroid_table.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
AddCSLuaFile()
ENT.PrintName = "Mesa Polaroid"
ENT.Category = "!! Sardon"
ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
function ENT:Initialize()
     self:SetModel("models/props_c17/FurnitureTable001a.mdl")
     self:PhysicsInit(SOLID_VPHYSICS)
end

function ENT:SpawnFunction(ply, tr, ClassName)
     if not tr.Hit then return end
     local SpawnPos = tr.HitPos + tr.HitNormal * 16
     local SpawnAng = ply:EyeAngles()
     SpawnAng.p = 0
     SpawnAng.y = SpawnAng.y + 180
     SpawnAng:RotateAroundAxis(SpawnAng:Up(), 180)

     local ent = ents.Create(ClassName)
     ent:SetPos(SpawnPos)
     ent:SetAngles(SpawnAng)
     ent:Spawn()
     ent:GetPhysicsObject():Wake()
     ent:SetSize(1)
     return ent
end

function ENT:SetupDataTables()
     self:NetworkVar("String", 0, "Image")
     self:NetworkVar("Bool", 1, "Hidden")
     self:NetworkVar("Float", 2, "Size")
end

function ENT:Draw()
     if not self:GetHidden() then
          self:DrawModel()
          self:DrawShadow(true)
     else
          self:DrawShadow(false )
     end

     local orgAng = self:GetAngles()
     local ang = self:GetAngles()
     ang:RotateAroundAxis(ang:Right(), 90)
     ang:RotateAroundAxis(ang:Up(), -90)
     cam.Start3D2D(self:GetPos() + orgAng:Up() * 90 + orgAng:Forward() * -12.9 + orgAng:Right() * -45.76, ang, 0.048)

     if self:GetImage() ~= "" then
          -- Matbaa baskıları tam https bağlantısı taşır (bkz. [sardon] matbaa, ent_matbaa_print)
          if self:GetImage():sub(1, 8) == "https://" and SardonMatbaa and SardonMatbaa.ApplyIcon then
               self.IconPath = self:GetImage()
               SardonMatbaa.ApplyIcon(self, self.IconPath)
          elseif self.IconPath ~= self:GetImage() then
               self.IconPath = self:GetImage()
               XeninUI:DownloadIcon(self, {
                    {
                         id = self.IconPath,
                         url = "https://proxy.duckduckgo.com/iu/?u=https://iili.io"
                    }
               })
          end

          XeninUI:DrawIcon(0, 0, 1920 * self:GetSize(), 1080 * self:GetSize(), self, color_white)
     else
          draw.RoundedBox(0, 0, 0, 1920 * self:GetSize(), 1080 * self:GetSize(), color_white)
     end

     cam.End3D2D()
end

properties.Add("setHidden", {
     MenuLabel = "Oculto",
     Order = 1,
     MenuIcon = "icon16/eye.png",
     Filter = function( self, ent, ply )
          if not IsValid( ent ) then return false end
          self.ent = ent
          return ent:GetClass() == "ent_polaroid_table" and (ply:IsAdmin() or ply:IsSuperAdmin())
     end,
     Checked = function(self, ent)
          return ent:GetHidden()
     end,
     Action = function( self, ent ) -- The action to perform upon using the property ( Clientside )

		self:MsgStart()
			net.WriteEntity( ent )
		self:MsgEnd()

	end,
     Receive  = function( self, ent, ply )
		local ent = net.ReadEntity()

		if ( !properties.CanBeTargeted( ent, ply ) ) then return end
		if ( !self:Filter( ent, ply ) ) then return end

          ent:SetHidden(!ent:GetHidden())
     end
})

properties.Add("updateSize", {
     MenuLabel = "Cambiar tamaño",
     Order = 2,
     MenuIcon = "icon16/arrow_inout.png",
     Filter = function( self, ent, ply )
          if not IsValid( ent ) then return false end
          self.ent = ent
          return ent:GetClass() == "ent_polaroid_table" and (ply:IsAdmin() or ply:IsSuperAdmin())
     end,
     Action = function( self, ent ) -- The action to perform upon using the property ( Clientside )

		self:MsgStart()
			net.WriteEntity( ent )
		self:MsgEnd()

	end,
     Receive  = function( self, ent, ply )
		local ent = net.ReadEntity()

		if ( !properties.CanBeTargeted( ent, ply ) ) then return end
		if ( !self:Filter( ent, ply ) ) then return end


          print(ply)


          ply:RequestString("Introduce el tamaño", "Introduce un número", function(text)
               num = tonumber(text)
               if (num != num) then ply:Notify("Introduce un número válido") end
               ent:SetSize(math.max(num, 0.1))
          end, tostring(ent:GetSize()))
     end
})