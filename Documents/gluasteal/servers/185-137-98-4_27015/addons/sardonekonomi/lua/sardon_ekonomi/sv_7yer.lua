-- Servidor :: colocación de entidades en mapa
if not SERVER then return end

local E = SardonEkonomi
if not E then return end

E._Yer = E._Yer or {}

local function MapDosya()
	return E.DATA .. "/yer/" .. game.GetMap() .. ".json"
end

function E.YerYukle()
	local yol = MapDosya()
	if E._YerMap ~= game.GetMap() then
		E._YerCache = E.OkuJSON(yol, {}) or {}
		E._YerMap = game.GetMap()
	end
	return E._YerCache
end

function E.YerKaydet()
	E.YazJSON(MapDosya(), E.YerYukle())
end

local function SpawnKayit(kayit)
	local cls = kayit.class or "ent_sardon_tuccar"
	local ent = ents.Create(cls)
	if not IsValid(ent) then return end
	ent:SetPos(Vector(kayit.x or 0, kayit.y or 0, kayit.z or 0))
	ent:SetAngles(Angle(kayit.p or 0, kayit.ya or 0, kayit.r or 0))
	if kayit.tur then ent:SetTur(kayit.tur) end
	if kayit.govde then ent:SetGovde(kayit.govde) end
	ent:Spawn()
	ent:Activate()
	return ent
end

local function YerleriYukle()
	for _, e in ipairs(ents.FindByClass("ent_sardon_tuccar")) do if not e._EkoKayit then e:Remove() end end
	for _, e in ipairs(ents.FindByClass("ent_sardon_pano")) do if not e._EkoKayit then e:Remove() end end
	for _, e in ipairs(ents.FindByClass("ent_sardon_tezgah")) do if not e._EkoKayit then e:Remove() end end
	for _, e in ipairs(ents.FindByClass("ent_sardon_bankamasa")) do if not e._EkoKayit then e:Remove() end end
	for i, kayit in ipairs(E.YerYukle()) do
		local ent = SpawnKayit(kayit)
		if IsValid(ent) then ent._EkoKayit = i end
	end
end

hook.Add("InitPostEntity", "SardonEkonomi.Yer", function()
	timer.Simple(1, YerleriYukle)
end)

local function TraceAim(ply)
	local tr = ply:GetEyeTrace()
	return tr
end

local function Koy(ply, args)
	if not ply:IsAdmin() then return end
	local tur = string.lower(args[1] or "")
	local tr = TraceAim(ply)
	local pos, ang = tr.HitPos + tr.HitNormal * 4, ply:EyeAngles()
	ang.p, ang.r = 0, 0
	local kayit, ent
	if tur == "pano" then
		ent = ents.Create("ent_sardon_pano")
	elseif tur == "tezgah" then
		ent = ents.Create("ent_sardon_tezgah")
	elseif tur == "bankamasa" then
		ent = ents.Create("ent_sardon_bankamasa")
	elseif tur == "gise" then
		ent = ents.Create("ent_sardon_bankamasa")
		ent:SetTur("gise")
	elseif E.Tuccar and E.Tuccar.Turler[tur] then
		ent = ents.Create("ent_sardon_tuccar")
		ent:SetTur(tur)
	else
		ply:ChatPrint("Uso: sardon_eko_koy tuccar <botanik|yaratik|iksir|balik|karaborsa|avci> | pano | tezgah | bankamasa | gise")
		return
	end
	if not IsValid(ent) then return end
	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent:Spawn()
	ent:Activate()
	kayit = {
		class = ent:GetClass(), tur = ent.GetTur and ent:GetTur() or nil,
		x = pos.x, y = pos.y, z = pos.z, p = ang.p, ya = ang.y, r = ang.r,
	}
	local liste = E.YerYukle()
	liste[#liste + 1] = kayit
	ent._EkoKayit = #liste
	E.YerKaydet()
	ply:ChatPrint("[Economía] Entidad colocada.")
end

local function Sil(ply)
	if not ply:IsAdmin() then return end
	local tr = TraceAim(ply)
	local ent = tr.Entity
	if not IsValid(ent) or not ent._EkoKayit then
		ply:ChatPrint("Mira una entidad de economía colocada.")
		return
	end
	local idx = ent._EkoKayit
	local liste = E.YerYukle()
	table.remove(liste, idx)
	for _, e in ipairs(ents.GetAll()) do
		if e._EkoKayit and e._EkoKayit > idx then e._EkoKayit = e._EkoKayit - 1 end
	end
	ent:Remove()
	E.YerKaydet()
	ply:ChatPrint("[Economía] Entidad eliminada.")
end

local function Bagla(ply, args)
	if not ply:IsAdmin() then return end
	local tur = string.lower(args[1] or "botanik")
	local tr = TraceAim(ply)
	local hedef = tr.Entity
	if not IsValid(hedef) or not hedef:GetModel() or hedef:GetModel() == "" then
		ply:ChatPrint("Mira un NPC del mapa.")
		return
	end
	local ent = ents.Create("ent_sardon_tuccar")
	ent:SetTur(tur)
	ent:SetGovde(hedef:GetModel())
	ent:SetPos(hedef:GetPos())
	ent:Spawn()
	local liste = E.YerYukle()
	liste[#liste + 1] = {
		class = "ent_sardon_tuccar", tur = tur, govde = hedef:GetModel(),
		x = hedef:GetPos().x, y = hedef:GetPos().y, z = hedef:GetPos().z, p = 0, ya = 0, r = 0,
	}
	ent._EkoKayit = #liste
	E.YerKaydet()
	ply:ChatPrint("[Economía] Comerciante vinculado (" .. tur .. ").")
end

concommand.Add("sardon_eko_koy", function(ply, _, args) if IsValid(ply) then Koy(ply, args) end end)
concommand.Add("sardon_eko_sil", function(ply) if IsValid(ply) then Sil(ply) end end)
concommand.Add("sardon_eko_kaydet", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	E.YerKaydet()
	if IsValid(ply) then ply:ChatPrint("[Economía] Posiciones guardadas.") end
end)
concommand.Add("sardon_eko_bagla", function(ply, _, args) if IsValid(ply) then Bagla(ply, args) end end)
concommand.Add("sardon_eko_gise", function(ply)
	if not IsValid(ply) or not ply:IsAdmin() then return end
	Koy(ply, {"gise"})
end)

concommand.Add("sardon_ekonomi_ozet", function(ply)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local msg = string.format("[Economía] Tesoro: %d G · Tope diario: %d · Impuesto: %.0f%%",
		E.HazineSaldo(), E.Ayar.tavan or 25, (E.Ayar.vergi or 0.05) * 100)
	if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

hook.Add("KeyPress", "SardonEkonomi.YerE", function(ply, key)
	if key ~= IN_USE then return end
	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 160)) do
		if ent:GetClass() == "ent_sardon_tuccar" and ent:Bagli() then
			local govde = ent:GetNWEntity("GovdeEnt")
			if IsValid(govde) and ply:GetPos():Distance(govde:GetPos()) < 120 and E.PencereGonder then
				E.PencereGonder(ply, "tuccar", ent)
				return
			end
		end
		if ent:GetClass() == "ent_sardon_bankamasa" and ent:Gise() and E.Masa and E.Masa.Kullan then
			if ply:GetPos():Distance(ent:GetPos()) < 100 then
				E.Masa.Kullan(ent, ply)
				return
			end
		end
	end
end)