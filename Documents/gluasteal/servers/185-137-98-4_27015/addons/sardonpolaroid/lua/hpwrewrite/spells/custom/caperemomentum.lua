-- "addons\\sardonpolaroid\\lua\\hpwrewrite\\spells\\custom\\caperemomentum.lua"
-- Retrieved by https://github.com/lewisclark/glua-steal
do
	local Spell = {}
	Spell.Category = HpwRewrite.CategoryNames.Generic
	Spell.ApplyFireDelay = 0
	Spell.CanSelfCast = true
	Spell.ForceDelay = 0
	Spell.AccuracyDecreaseVal = 0
	Spell.NodeOffset = Vector(-791, -32, 0)
	-- Spell.SpriteColor = color_white
	-- Spell.DoSparks = true
	Spell.FlyEffect = "[8]frostbeam"
	Spell.IconMat = Material("caperemomentum.png")

	function Spell:PreFire()
		-- Seçim paneli açıkken tekrar atılamaz
		if SardonPolaroid and SardonPolaroid.HasPending and SardonPolaroid.HasPending(self.Owner) then return false end

		local ent = NULL
		for key, value in ipairs(ents.FindByClass("ent_polaroid_camera")) do
			if value:GetNWEntity("Owner") == self.Owner then
				ent = value
				break
			end
		end

		return not IsValid(ent)
	end
	function Spell:OnFire(wand)
		if HpwRewrite:IsHoldingSelfCast(self.Owner) then
			if CLIENT then return false end
			-- Kendine atıldığında kamera oyuncunun önünde süzülür
			SardonPolaroid.AskMode(self.Owner, nil)
			return false
		end
		return true
	end

	function Spell:OnCollide(spell, data)
		if CLIENT then return end
		SardonPolaroid.AskMode(self.Owner, data.HitPos)
	end

	function Spell:SpellThink(spell)
		if CLIENT then return end
		local dist = self.Owner:GetPos():DistToSqr(spell:GetPos())

		if dist >= 200 * 200 then
			self:OnCollide(spell, {
				HitPos = spell:GetPos()
			})
			spell:Remove()
		end
	end

	HpwRewrite:AddSpell("Capere Momentum", Spell)
end

if SERVER then
	for key, value in ipairs(ents.FindByClass("ent_polaroid_camera")) do
		value:Remove()
	end

	for key, value in ipairs(ents.FindByClass("entity_hpwand_flyingspell")) do
		value:Remove()
	end
end
