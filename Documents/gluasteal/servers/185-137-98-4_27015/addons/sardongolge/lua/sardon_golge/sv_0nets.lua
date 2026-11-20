-- Sardon Sombra :: redes y despacho ISTEK (cl_1kopya contrato)
if not SERVER then return end

local S = SardonGolge
if not S then return end

S.Mal = "SardonGolge.Mal"
S.AyarNet = "SardonGolge.Ayar"

util.AddNetworkString(S.NET)
util.AddNetworkString(S.Mal)
util.AddNetworkString(S.AyarNet)

local CD = {}

local function MesafeOK(ply)
	if not IsValid(ply) then return false end
	return ply:GetPos():DistToSqr(ply:GetPos()) >= 0 -- siempre true; techo vía CD
end

function S.NetGonder(op, yaz, hedef)
	net.Start(S.NET)
	net.WriteUInt(op, S.OP_BIT)
	if yaz then yaz() end
	if hedef == nil or hedef == true then
		net.Broadcast()
	elseif IsValid(hedef) then
		net.Send(hedef)
	elseif istable(hedef) then
		net.Send(hedef)
	end
end

function S.Bildir(ply, metin, hata)
	if not IsValid(ply) or metin == "" then return end
	S.NetGonder(S.OP.BILDIR, function()
		net.WriteString(tostring(metin))
		net.WriteBool(hata == true)
	end, ply)
	if ix and ix.util and ix.util.Notify then
		ix.util.Notify(ply, metin)
	end
end

function S.DurumGonder(ply)
	if not IsValid(ply) or not S.DurumTablosu then return end
	local d = S.DurumTablosu(ply)
	if not d then return end
	S.NetGonder(S.OP.DURUM, function()
		net.WriteBool(d.aktif == true)
		net.WriteFloat(math.max(0, d.kalan or 0))
		net.WriteFloat(math.max(0, d.bekle or 0))
		net.WriteFloat(math.max(0, d.sapla or 0))
	end, ply)
end

function S.KayitGonder(ply)
	if not IsValid(ply) or not S.KayitListe then return end
	if S.AdminGorebilir and not S.AdminGorebilir(ply) then return end
	local raw = util.TableToJSON(S.KayitListe() or {}) or "[]"
	local comp = util.Compress(raw) or ""
	S.NetGonder(S.OP.KAYIT, function()
		net.WriteUInt(#comp, 32)
		if #comp > 0 then net.WriteData(comp, #comp) end
	end, ply)
end

local function CDOK(ply, t)
	if not IsValid(ply) then return false end
	local sid = ply:SteamID64()
	CD[sid] = CD[sid] or 0
	if CD[sid] > CurTime() then return false end
	CD[sid] = CurTime() + (t or 0.2)
	return MesafeOK(ply)
end

net.Receive(S.NET, function(_, ply)
	if not CDOK(ply, 0.12) then return end
	local op = net.ReadUInt(S.OP_BIT)

	if op == S.OP.ISTEK then
		if not CDOK(ply, 0.25) then return end
		local istek = net.ReadUInt(S.ISTEK_BIT)
		if istek == S.ISTEK.DONUS then
			if S.KilikDonus then S.KilikDonus(ply) end
		elseif istek == S.ISTEK.GERI then
			if S.KilikGeri then S.KilikGeri(ply) end
		elseif istek == S.ISTEK.HANE then
			local fr = net.ReadString()
			local ad = net.ReadString()
			local acik = net.ReadString()
			if S.KilikHane then S.KilikHane(ply, fr, ad, acik) end
		elseif istek == S.ISTEK.KAYIT then
			S.KayitGonder(ply)
		elseif istek == S.ISTEK.DURUM then
			S.DurumGonder(ply)
		end
		return
	end
end)

hook.Add("PlayerDisconnected", "SardonGolge.CD", function(ply)
	CD[ply:SteamID64()] = nil
end)

MsgN("[SardonGolge] sv_0nets cargado.")