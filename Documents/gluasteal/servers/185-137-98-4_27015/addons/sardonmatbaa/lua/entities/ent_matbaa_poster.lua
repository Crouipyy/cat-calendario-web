-- "addons\\sardonmatbaa\\lua\\entities\\ent_matbaa_poster.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
AddCSLuaFile()

-- Duvara asılmış poster. Açıları doğrudan 3D2D açısıdır (Up = duvarın normali, Right = aşağı;
-- bkz. sv_init.lua HangPoster). Fizik, formatın boyutunda ince bir kutu -- oyuncular içinden
-- geçer (COLLISION_GROUP_WEAPON) ama E ile bakılıp sökülebilir. Konumlar harita başına
-- data/sardon_matbaa/<harita>_posterler.json'a kaydedilir.
ENT.PrintName = "Poster"
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Category = "!! Sardon"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "URL")
	self:NetworkVar("String", 1, "Format")
	self:NetworkVar("String", 2, "Printer")
	self:NetworkVar("Int", 0, "OwnerChar")
end

-- Formatın dünya birimi cinsinden yarı boyutları
function ENT:GetHalfSize()
	local format = SardonMatbaa.GetFormat(self:GetFormat())
	local scale = SardonMatbaa.Config.Olcek
	local fw, fh = format and format.genislik or 400, format and format.yukseklik or 600

	return fw * scale / 2, fh * scale / 2
end

function ENT:SetupBounds()
	local hw, hh = self:GetHalfSize()
	-- Yerel eksenler: x = Forward (genişlik), y = Left (yukarı), z = Up (duvardan dışarı)
	local mins, maxs = Vector(-hw, -hh, -0.3), Vector(hw, hh, 0.3)

	-- İki realm'de de: istemcideki kutu, C + sağ tık menüsünün (properties) posteri bulabilmesi için
	self:PhysicsInitBox(mins, maxs)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_NONE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end

	if CLIENT then
		self:SetRenderBounds(mins, maxs)
	end

	self:SetCollisionBounds(mins, maxs)
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/hunter/plates/plate1x1.mdl")
		self:SetupBounds()
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)
	end

	function ENT:Use(activator)
		if !IsValid(activator) or !activator:IsPlayer() or !activator:GetCharacter() then return end
		if self.nextUse and self.nextUse > CurTime() then return end

		self.nextUse = CurTime() + 0.5

		if !SardonMatbaa.Config.PosteriHerkesSokebilir and self:GetOwnerChar() != activator:GetCharacter():GetID() then
			activator:Notify("Solo quien colgó el póster puede retirarlo.")
			return
		end

		SardonMatbaa.PickUpPrint(activator, self)
	end
else
	local col_paper = Color(232, 222, 198)
	local col_shadow = Color(0, 0, 0, 90)

	-- NetworkVar'lar Initialize'dan sonra gelebilir; format değişince sınırları yenile
	function ENT:Think()
		if self.boundsFormat != self:GetFormat() then
			self.boundsFormat = self:GetFormat()
			self:SetupBounds()
		end
	end

	function ENT:Draw()
		if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 2000 * 2000 then return end

		local format = SardonMatbaa.GetFormat(self:GetFormat())
		local fw, fh = format and format.genislik or 400, format and format.yukseklik or 600
		local scale = SardonMatbaa.Config.Olcek
		local hw, hh = fw * scale / 2, fh * scale / 2

		-- Sol üst köşe: x = -genişlik/2, y (Left) = +yükseklik/2
		cam.Start3D2D(self:LocalToWorld(Vector(-hw, hh, 0.05)), self:GetAngles(), scale)
			surface.SetDrawColor(col_shadow)
			surface.DrawRect(6, 6, fw, fh)
			surface.SetDrawColor(col_paper)
			surface.DrawRect(0, 0, fw, fh)

			local mat = SardonMatbaa.GetMaterial and SardonMatbaa.GetMaterial(self:GetURL())

			if mat then
				SardonMatbaa.DrawFit(mat, 8, 8, fw - 16, fh - 16)
			end
		cam.End3D2D()
	end
end

-- Superadmin: C basılı + posterin üstüne sağ tık -> "Posteri Kaldır" (polaroid masasındaki
-- "Gizli" / "Boyutu Degistir" ile aynı properties menüsü). Poster envantere dönmez, silinir.
properties.Add("matbaaPosterKaldir", {
	MenuLabel = "Posteri Kaldır",
	Order = 1,
	MenuIcon = "icon16/picture_delete.png",
	Filter = function(self, ent, ply)
		return IsValid(ent) and ent:GetClass() == "ent_matbaa_poster" and ply:IsSuperAdmin()
	end,
	Action = function(self, ent)
		self:MsgStart()
			net.WriteEntity(ent)
		self:MsgEnd()
	end,
	Receive = function(self, length, ply)
		local ent = net.ReadEntity()

		if !self:Filter(ent, ply) then return end

		ix.log.AddRaw(string.format("%s (%s) bir posteri kaldırdı: %s (basan: %s)", ply:Name(), ply:SteamID(), ent:GetURL(), ent:GetPrinter()))
		SafeRemoveEntity(ent)
		SardonMatbaa.SavePosters()
		ply:Notify("Poster kaldırıldı.")
	end
})
