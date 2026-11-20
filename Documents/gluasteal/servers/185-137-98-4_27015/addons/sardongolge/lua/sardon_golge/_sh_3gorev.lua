-- Condiciones golge_* para el editor de misiones (lógica real en sv_3golge.lua)
local S = SardonGolge

local function SemaKaydet()
	local G = SardonGorev
	if not (G and G.Sema and G.Sema.Kosul and G.SemaSira and G.SemaSira.Kosul) then return false end

	local function K(id, t)
		t.id = id
		t.alanlar = t.alanlar or {}
		t.alanlar[#t.alanlar + 1] = { k = "tersi", ad = "Negar (si no)", tip = "bool", v = false }
		G.Sema.Kosul[id] = t
		if not table.HasValue(G.SemaSira.Kosul, id) then table.insert(G.SemaSira.Kosul, id) end
	end

	K("golge_tanis", { ad = "Sombra: ya se conocieron", ozet = function() return "Conoció a Sombra" end })
	K("golge_grup", { ad = "Sombra: grupo de diálogo", alanlar = {
		{ k = "deger", ad = "Grupo", tip = "secim", v = "snatcher", secenekler = {
			{ id = "snatcher", ad = "Snatcher" }, { id = "ogrenci", ad = "Estudiante" }, { id = "profesor", ad = "Profesor / personal Hogwarts" },
			{ id = "bakanlik", ad = "Ministerio / Auror" }, { id = "karanlik", ad = "Mago oscuro" }, { id = "diger", ad = "Otro" } } },
	}, ozet = function(e) return "Grupo Sombra: " .. tostring(e.deger or "?") end })
	K("golge_alabilir", { ad = "Sombra: puede comprar esta semana (cupo + dinero)", ozet = function() return "Puede comprar a Sombra" end })
	K("golge_bakanlik_yakala", { ad = "Sombra: Ministerio detecta la mentira (%50)", ozet = function() return "Mentira detectada por Ministerio" end })
	K("golge_mal_var", { ad = "Sombra: hay mercancía para él en el mostrador", ozet = function() return "Hay mercancía de Sombra" end })
	return true
end

if not SemaKaydet() then
	timer.Create("SardonGolge.Sema", 1, 60, function()
		if SemaKaydet() then timer.Remove("SardonGolge.Sema") end
	end)
end
