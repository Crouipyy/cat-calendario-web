-- Sardon Çığırtkan :: administración
local C = SardonCigirtkan
local A = C.Ayar
local Z = C.Z

local function IsSuper(ply)
	return IsValid(ply) and ply:IsSuperAdmin()
end

local function AdminListe()
	local ucan = {}
	for id, ent in pairs(C.Zarflar or {}) do
		if IsValid(ent) then
			local F = ent.F
			ucan[#ucan + 1] = {
				id = id,
				gonderen = F and F.gonderenAd or ent:GetGonderen(),
				alici = F and (IsValid(F.hedef) and F.hedef:Name() or F.grupAd) or "?",
				durum = ent:GetDurum(),
				sure = F and F.sure or ent:GetSure(),
				anonim = F and F.anonim,
			}
		end
	end
	return {
		ucan = ucan,
		yasak = C.Yasak or {},
		son = C.Son or {},
		kurallar = C.Kurallar or {},
	}
end

net.Receive("SardonCigirtkan.Admin", function(_, ply)
	if not IsSuper(ply) then return end
	local islem = net.ReadString()
	local veri = net.ReadTable() or {}

	if islem == "liste" then
		net.Start("SardonCigirtkan.AdminListe")
		net.WriteTable(AdminListe())
		net.Send(ply)
		return
	end

	if islem == "ver" then
		local inv = ply:GetCharacter() and ply:GetCharacter():GetInventory()
		if inv and inv:Add(C.ITEM) then
			C.Bildir(ply, "Howler añadido al inventario.")
		else
			ix.item.Spawn(C.ITEM, ply:GetItemDropPos())
			C.Bildir(ply, "Howler generado a tus pies.")
		end
		return
	end

	if islem == "yokEt" and veri.id then
		local ent = C.Zarflar[veri.id]
		if IsValid(ent) then ent:Remove() end
		C.Bitir(C.Ucus[veri.id], "admin")
		C.Bildir(ply, "Howler destruido.")
		return
	end

	if islem == "kuralEkle" and veri.gTur and veri.hTur then
		C.Kurallar[#C.Kurallar + 1] = {
			id = #C.Kurallar + 1,
			gTur = veri.gTur,
			gId = veri.gId or "",
			hTur = veri.hTur,
			hId = veri.hId or "",
			gonderen = veri.gId or "?",
			hedef = veri.hId or "?",
		}
		C.PersistSave()
		C.Bildir(ply, "Regla masiva añadida.")
		return
	end

	if islem == "kuralSil" and veri.id then
		for i, k in ipairs(C.Kurallar) do
			if k.id == veri.id then
				table.remove(C.Kurallar, i)
				break
			end
		end
		C.PersistSave()
		return
	end

	if islem == "yasakBak" then
		local tr = ply:GetEyeTrace()
		local obj = tr.Entity
		if not IsValid(obj) or not obj:IsPlayer() then
			C.Bildir(ply, "Mira a un jugador.")
			return
		end
		C.Yasak[obj:SteamID64()] = {
			sid = obj:SteamID64(),
			ad = obj:Name(),
			kim = ply:Name(),
			zaman = os.time(),
		}
		C.PersistSave()
		C.Bildir(ply, obj:Name() .. " no puede enviar Howlers.")
		return
	end

	if islem == "yasakKaldir" and veri.sid then
		C.Yasak[veri.sid] = nil
		C.PersistSave()
		return
	end

	net.Start("SardonCigirtkan.AdminListe")
	net.WriteTable(AdminListe())
	net.Send(ply)
end)

MsgN("[SardonCigirtkan] Servidor listo.")

hook.Add("Initialize", "SardonCigirtkan.AdminCon", function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) then ply:SetNW2Bool("SardonCigirtkanToplu", C.TopluYetki(ply)) end
	end
end)