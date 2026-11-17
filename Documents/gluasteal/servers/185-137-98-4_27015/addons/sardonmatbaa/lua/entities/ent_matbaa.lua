-- "addons\\sardonmatbaa\\lua\\entities\\ent_matbaa.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
AddCSLuaFile()

-- Baskı makinesi. E ile panel açılır (sardon_matbaa/cl_menu.lua); mürekkep ve boş kağıt
-- itemleri makineye atılınca da (Think'teki kutu taraması) bırakan karakterin stoğuna geçer.
-- Aynı anda tek iş basar; iş bilgisi NetworkVar'larda, üstteki 3D2D levhada gösterilir.
ENT.PrintName = "Baskı Makinesi"
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Category = "!! Sardon"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "JobStart")
	self:NetworkVar("Float", 1, "JobEnd")
	self:NetworkVar("String", 0, "JobOwner")
	self:NetworkVar("String", 1, "JobFormat")
	self:NetworkVar("Int", 0, "JobCopies")
end

function ENT:IsBusy()
	return self:GetJobEnd() > 0
end

if SERVER then
	function ENT:SpawnFunction(client, tr, className)
		if !tr.Hit then return end

		local ent = ents.Create(className)
		local ang = client:EyeAngles()
		ent:SetPos(tr.HitPos + tr.HitNormal * 16)
		ent:SetAngles(Angle(0, ang.y + 180, 0))
		ent:Spawn()

		return ent
	end

	function ENT:Initialize()
		self:SetModel(SardonMatbaa and SardonMatbaa.Config.MakineModel or "models/props_c17/TrapPropeller_Engine.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end

	function ENT:Use(activator, caller)
		local client = IsValid(caller) and caller:IsPlayer() and caller or activator

		if !IsValid(client) or !client:IsPlayer() then return end
		if self.nextUse and self.nextUse > CurTime() then return end

		self.nextUse = CurTime() + 1

		if SardonMatbaa and SardonMatbaa.OpenMenu then
			SardonMatbaa.OpenMenu(client, self)
		end
	end

	local SCAN_PAD = Vector(6, 6, 6)

	function ENT:Think()
		if !SardonMatbaa then return end

		-- Makineye atılan hammadde
		local mins, maxs = self:WorldSpaceAABB()

		for _, ent in ipairs(ents.FindInBox(mins - SCAN_PAD, maxs + SCAN_PAD)) do
			if ent:GetClass() == "ix_item" then
				SardonMatbaa.AbsorbItem(self, ent)
			end
		end

		-- Baskı işi
		if self.matbaaJob then
			if CurTime() >= self:GetJobEnd() then
				SardonMatbaa.FinishJob(self)
			elseif (self.nextClank or 0) < CurTime() then
				self.nextClank = CurTime() + 1.1
				self:EmitSound("physics/metal/metal_box_impact_soft" .. math.random(1, 3) .. ".wav", 60, math.random(70, 85), 0.6)
			end
		end

		self:NextThink(CurTime() + 0.25)

		return true
	end

	function ENT:OnRemove()
		if SardonMatbaa and SardonMatbaa.CancelJob and !ix.shuttingDown then
			SardonMatbaa.CancelJob(self)
		end
	end
else
	surface.CreateFont("SardonMatbaa.Sign", { font = "Georgia", size = 44, weight = 700, extended = true })
	surface.CreateFont("SardonMatbaa.SignSmall", { font = "Georgia", size = 26, weight = 500, extended = true })

	local col_bg = Color(22, 18, 14, 230)
	local col_gold = Color(214, 176, 104)
	local col_text = Color(236, 226, 205)
	local col_muted = Color(160, 148, 128)
	local col_barBg = Color(50, 42, 32)

	function ENT:Draw()
		self:DrawModel()

		if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 600 * 600 then return end

		local top = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 14))
		local ang = (LocalPlayer():EyePos() - top):Angle()
		ang = Angle(0, ang.y + 90, 90)

		local w, h = 520, 150

		cam.Start3D2D(top, ang, 0.08)
			draw.RoundedBox(8, -w / 2, -h, w, h, col_bg)
			surface.SetDrawColor(col_gold)
			surface.DrawOutlinedRect(-w / 2, -h, w, h, 2)

			draw.SimpleText("MATBAA", "SardonMatbaa.Sign", 0, -h + 14, col_gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			if self:IsBusy() then
				local total = math.max(0.01, self:GetJobEnd() - self:GetJobStart())
				local frac = math.Clamp((CurTime() - self:GetJobStart()) / total, 0, 1)
				local left = math.max(0, math.ceil(self:GetJobEnd() - CurTime()))

				draw.SimpleText(string.format("%s • %dx %s • %02d:%02d", self:GetJobOwner(), self:GetJobCopies(), self:GetJobFormat(), math.floor(left / 60), left % 60),
					"SardonMatbaa.SignSmall", 0, -h + 66, col_text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

				local bw = w - 40
				draw.RoundedBox(4, -bw / 2, -30, bw, 14, col_barBg)
				draw.RoundedBox(4, -bw / 2, -30, bw * frac, 14, col_gold)
			else
				draw.SimpleText("Lista — pulsa E", "SardonMatbaa.SignSmall", 0, -h + 76, col_muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end
		cam.End3D2D()
	end
end
