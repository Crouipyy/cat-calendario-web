-- "addons\\sardonmatbaa\\lua\\entities\\ent_matbaa_print.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
AddCSLuaFile()

-- Yere bırakılmış basılı ürün (sh_items.lua'daki drop'un düşürdüğü entity). Üzerinde görsel
-- çizilir; E ile envantere geri alınır. Polaroid'in anıları gibi ent_polaroid_table /
-- ent_polaroid_projector'a atılınca görseli onlara yansıtır.
ENT.PrintName = "Producto impreso"
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Category = "!! Sardon"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "URL")
	self:NetworkVar("String", 1, "Format")
	self:NetworkVar("String", 2, "Printer")
end

if SERVER then
	function ENT:Initialize()
		local format = SardonMatbaa.GetFormat(self:GetFormat())

		self:SetModel(format and format.model or SardonMatbaa.Config.KagitModel)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)
	end

	function ENT:Use(activator)
		if !IsValid(activator) or !activator:IsPlayer() then return end
		if self.nextUse and self.nextUse > CurTime() then return end

		self.nextUse = CurTime() + 0.5
		SardonMatbaa.PickUpPrint(activator, self)
	end

	local projectTargets = { ent_polaroid_table = true, ent_polaroid_projector = true }

	function ENT:PhysicsCollide(data)
		local hit = data.HitEntity

		if IsValid(hit) and projectTargets[hit:GetClass()] and hit.SetImage then
			if hit.GetHidden and hit:GetHidden() then return end

			hit:SetImage(self:GetURL())
		end
	end
else
	function ENT:Draw()
		self:DrawModel()

		local mat = SardonMatbaa.GetMaterial and SardonMatbaa.GetMaterial(self:GetURL())
		if !mat then return end

		local format = SardonMatbaa.GetFormat(self:GetFormat())
		local mins, maxs = self:OBBMins(), self:OBBMaxs()
		local sx, sy = maxs.x - mins.x, maxs.y - mins.y

		-- Görseli modelin üst yüzeyine, formatın oranını koruyarak sığdır
		local fw, fh = format and format.genislik or 400, format and format.yukseklik or 600
		local scale = math.min(sy / fw, sx / fh)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(ang:Up(), 90)

		local center = self:LocalToWorld(Vector((mins.x + maxs.x) / 2, (mins.y + maxs.y) / 2, maxs.z + 0.1))

		cam.Start3D2D(center, ang, scale)
			SardonMatbaa.DrawFit(mat, -fw / 2, -fh / 2, fw, fh)
		cam.End3D2D()
	end
end
