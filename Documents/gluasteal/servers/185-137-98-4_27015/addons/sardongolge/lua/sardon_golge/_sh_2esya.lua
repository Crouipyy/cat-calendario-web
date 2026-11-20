-- Sardon Sombra :: ítem Helix «Cuchillo de la Realidad»
local S = SardonGolge

local ITEM = ix.item.Register(S.ESYA, nil, false, nil, true)
ITEM.name = "Cuchillo de la Realidad"
ITEM.description = "Empuñadura negra, hoja fina y helada."
ITEM.model = "models/weapons/w_knife_t.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "NUEVO · Mercado negro"
ITEM.noBusiness = true

function ITEM:GetAdet()
	return math.max(1, math.floor(tonumber(self:GetData("adet", 1)) or 1))
end

function ITEM:GetName()
	local n = self:GetAdet()
	return n > 1 and ("Cuchillo de la Realidad (" .. n .. ")") or "Cuchillo de la Realidad"
end

function ITEM:GetDescription()
	return "Empuñadura negra, hoja fina y helada. Al clavarlo, absorbe el aspecto del blanco; su dueño puede adoptarlo."
		.. "\nRestantes: " .. self:GetAdet()
		.. "\nEquipar: clic izquierdo clava, clic derecho abre el menú de disfraz."
end

if CLIENT then
	function ITEM:PaintOver(item, w, h)
		local n = item.GetAdet and item:GetAdet() or 1
		if n > 1 then draw.SimpleTextOutlined(n, "DermaDefaultBold", w - 4, h - 4, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black) end
	end
end

ITEM.functions.EleAl = {
	name = "Equipar",
	icon = "icon16/bullet_black.png",
	OnRun = function(item)
		local ply = item.player
		if SERVER and IsValid(ply) and ply:Alive() then
			if not ply:HasWeapon(S.SILAH) then ply:Give(S.SILAH) end
			ply:SelectWeapon(S.SILAH)
		end
		return false
	end,
	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player) and item.player:Alive()
	end
}

ITEM.functions.Ayir = {
	name = "Separar uno",
	icon = "icon16/arrow_divide.png",
	OnRun = function(item)
		if SERVER and S.HancerAyir then S.HancerAyir(item) end
		return false
	end,
	OnCanRun = function(item)
		return not IsValid(item.entity) and item:GetAdet() > 1
	end
}