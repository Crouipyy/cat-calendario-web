-- "addons\\sardonpolaroid\\lua\\entities\\ent_polaroid_projector.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
AddCSLuaFile()
ENT.PrintName = "Proyector Polaroid"
ENT.Category = "!! Sardon"
ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
function ENT:Initialize()
     if CLIENT then
          local lamp = ProjectedTexture() -- Create a projected texture
          self.lamp = lamp -- Assign it to the entity table so it may be accessed later

          -- Set it all up
          lamp:SetTexture( "effects/flashlight001" )
          lamp:SetFarZ( 500 ) -- How far the light should shine

          lamp:SetPos( self:GetPos() ) -- Initial position and angles
          lamp:SetAngles( self:GetAngles() )
          lamp:SetEnableShadows(false)
          lamp:Update()
     else
          self:SetModel("models/props/cs_office/projector.mdl")
          self:PhysicsInit(SOLID_VPHYSICS)
          self:DrawShadow(false)
     end
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
     return ent
end

function ENT:SetupDataTables()
     self:NetworkVar("String", 0, "Image")
end

function ENT:Draw()
     self:DrawModel()

     local orgAng = self:GetAngles()
     local ang = self:GetAngles()
     ang:RotateAroundAxis(ang:Right(), 90)
     ang:RotateAroundAxis(ang:Up(), -90)
     -- cam.Start3D2D(self:GetPos() + orgAng:Up() * 90 + orgAng:Forward() * -12.9 + orgAng:Right() * -45.76, ang, 0.048)
     -- draw.RoundedBox(0, 0, 0, 1920, 1080, color_white)
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

          --XeninUI:DrawIcon(0, 0, 1920, 1080, self, color_white)
     end

     -- cam.End3D2D()
end

function ENT:OnRemove()
     if ( IsValid( self.lamp ) ) then
          self.lamp:Remove()
     end
end

function ENT:Think()
     if ( IsValid( self.lamp ) ) then
          local ang = self:GetAngles()
          ang:RotateAroundAxis(ang:Up(), -90)
          self.lamp:SetPos( self:GetPos() + ang:Up() * 20 + ang:Forward() * 20 )
          self.lamp:SetAngles( ang )
          if type(self.Icon) == "IMaterial" then
               self.lamp:SetTexture(self.Icon:GetTexture("$basetexture"))
          else
               self.lamp:SetTexture( "effects/flashlight001" )
          end
          self.lamp:Update()
     end
end