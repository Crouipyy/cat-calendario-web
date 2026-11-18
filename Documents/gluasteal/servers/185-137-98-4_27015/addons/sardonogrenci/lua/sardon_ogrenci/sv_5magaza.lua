-- Sardon Öğrenci :: compra de ropa en Madam Malkin + cúpula de bienvenida.
if not SERVER then return end

local O = SardonOgrenci

util.AddNetworkString("SardonOgrenci.SatinAl")
util.AddNetworkString("SardonOgrenci.SatinSonuc")

local function satinSonuc(ply, ok, id, look, metin)
	net.Start("SardonOgrenci.SatinSonuc")
		net.WriteBool(ok and true or false)
		net.WriteString(id or "")
		net.WriteUInt(math.Clamp(tonumber(look) or 1, 0, 255), 8)
		net.WriteString(metin or "")
	net.Send(ply)
end

local function cercaMadam(ply)
	local SA = SardonAksesuar
	if SA and SA.CercaMadam then return SA.CercaMadam(ply) end
	if not SA or not SA.Ayar or not SA.Ayar.MadamPos then return true end
	local pos = SA.Ayar.MadamPos
	local m = SA.Ayar.MadamMesafe or 230
	return ply:GetPos():DistToSqr(pos) <= m * m
end

function O.KiyafetSatinAl(ply, id, look)
	local char = ply:GetCharacter()
	if not char then return end

	if not O.KarakterDurumu(char) then
		satinSonuc(ply, false, id, look, "Primero crea tu aspecto con /Gorunum.")
		return
	end

	if not O.Yetkili(ply) and not cercaMadam(ply) then
		satinSonuc(ply, false, id, look, "No estás lo bastante cerca de Madam Malkin.")
		return
	end

	if not O.Satilik(id) then
		satinSonuc(ply, false, id, look, "Esta prenda no está a la venta.")
		return
	end

	local d = O.KarakterDurumu(char)
	local p = O.GiysiParcasi(id, d.gender)
	if not p then
		satinSonuc(ply, false, id, look, "Esta prenda no tiene una forma que te valga.")
		return
	end

	look = math.floor(tonumber(look) or 1)
	if look < 1 or look > #p.looks then
		satinSonuc(ply, false, id, look, "Color no válido.")
		return
	end

	-- ya posee el mismo id+look
	local ana = char:GetInventory()
	if not ana then
		satinSonuc(ply, false, id, look, "No hay inventario.")
		return
	end

	local uniqueID = O.ESYA_ONEK .. id
	if not ix.item.list[uniqueID] then
		satinSonuc(ply, false, id, look, "Objeto no definido.")
		return
	end

	local function tieneMismo(inv)
		for _, item in pairs(inv:GetItems(true)) do
			if item.uniqueID == uniqueID and tonumber(item:GetData("l", 1)) == look then
				return true
			end
		end
	end

	if tieneMismo(ana) then
		satinSonuc(ply, false, id, look, "Ya tienes este color.")
		return
	end
	local ek = O.Ekipman(char)
	if ek and tieneMismo(ek) then
		satinSonuc(ply, false, id, look, "Ya tienes este color.")
		return
	end

	local fiyat = O.Fiyat(id)
	if fiyat > 0 and not char:HasMoney(fiyat) then
		satinSonuc(ply, false, id, look, "No tienes suficientes Galeones.")
		return
	end

	if fiyat > 0 then char:TakeMoney(fiyat) end

	local x = ana:Add(uniqueID, 1, {l = look})
	if not x then
		if fiyat > 0 then char:GiveMoney(fiyat) end
		satinSonuc(ply, false, id, look, "No cabe en tu inventario.")
		return
	end

	local ad = O.Giysi[id] and O.Giysi[id].ad or id
	satinSonuc(ply, true, id, look, ad .. " comprado/a.")
end

net.Receive("SardonOgrenci.SatinAl", function(_, ply)
	if not IsValid(ply) then return end
	if (ply.sogSatinCD or 0) > CurTime() then return end
	ply.sogSatinCD = CurTime() + 0.5

	local id = net.ReadString()
	local look = net.ReadUInt(8)
	if id == "" or #id > 64 then return end
	O.KiyafetSatinAl(ply, id, look)
end)

----------------------------------------------------------------------------------------
-- Cúpula de bienvenida (evento görev)
----------------------------------------------------------------------------------------
function O.KarsilamaCuppeVer(ply)
	local char = ply:GetCharacter()
	if not char or not O.KarakterDurumu(char) then return false end

	local id = O.Magaza.KarsilamaCuppe
	if not id or not O.Satilik(id) then return false end

	local d = O.KarakterDurumu(char)
	local uniqueID = O.ESYA_ONEK .. id
	if not ix.item.list[uniqueID] then return false end

	-- look 1 = color de casa (o "Hanesiz"); el cliente/HLStudents pinta por hane
	local look = 1
	local ana = char:GetInventory()
	if not ana then return false end

	ana:Add(uniqueID, 1, {l = look})
	return true
end

hook.Add("SardonGorevOlay", "SardonOgrenci.Cuppe", function(ply, olay, _)
	if olay == "cuppe" or olay == "kiyafet_cuppe" or olay == "karsilama_cuppe" then
		if O.KarsilamaCuppeVer(ply) then
			ply:ChatPrint("Madam Malkin te ha dado una túnica escolar.")
		end
	end
end)

ix.command.Add("OgrenciKiyafetVer", {
	description = "Da ropa de estudiante a un jugador (id look).",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.string, ix.type.number},
	OnRun = function(_, ply, hedef, id, look)
		look = math.floor(tonumber(look) or 1)
		local char = IsValid(hedef) and hedef:GetCharacter()
		if not char then return "No hay personaje." end
		if not O.Giysi[id] then return "Prenda desconocida: " .. tostring(id) end

		local uniqueID = O.ESYA_ONEK .. id
		local ana = char:GetInventory()
		if not ana or not ix.item.list[uniqueID] then return "Objeto/inventario ausente." end

		ana:Add(uniqueID, 1, {l = look})
		return id .. " entregado (" .. look .. ")."
	end
})

MsgN("[SardonOgrenci] sv_5magaza cargado.")
