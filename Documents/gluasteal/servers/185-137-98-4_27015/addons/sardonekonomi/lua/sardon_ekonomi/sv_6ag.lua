-- Servidor :: red y enrutador de ventanas
if not SERVER then return end

local E = SardonEkonomi
if not E then return end

local NETS = {
	"SardonEko.Istek", "SardonEko.Pencere", "SardonEko.Bildir",
	"SardonEko.Takas", "SardonEko.TakasDurum",
	"SardonEko.Masa", "SardonEko.MasaDurum", "SardonEko.MasaGorsel",
	"SardonEko.Yonetim",
}
for _, n in ipairs(NETS) do util.AddNetworkString(n) end

function E.Bildir(ply, metin, tur)
	if not IsValid(ply) then return end
	net.Start("SardonEko.Bildir")
	net.WriteString(metin or "")
	net.WriteString(tur or "bilgi")
	net.Send(ply)
end

function E.PencereGonder(ply, kip, ent)
	if not IsValid(ply) then return end
	local v
	if kip == "tuccar" and E.TuccarVeri then v = E.TuccarVeri(ply, ent)
	elseif kip == "pano" and E.PanoVeri then v = E.PanoVeri(ply)
	elseif kip == "tezgah" and E.TezgahVeri then v = E.TezgahVeri(ply)
	end
	if not v then return end
	ply._EkoEnt = ent
	net.Start("SardonEko.Pencere")
	net.WriteString(kip or "")
	net.WriteTable(v)
	net.Send(ply)
end

local function Uzaklik(ply, ent)
	if not IsValid(ent) then return 9999 end
	return ply:GetPos():Distance(ent:GetPos())
end

local CD = {}
local CD_SURE = 0.35

net.Receive("SardonEko.Istek", function(_, ply)
	if not IsValid(ply) then return end
	local sid = E.Sid64(ply)
	CD[sid] = CD[sid] or 0
	if CD[sid] > CurTime() then return end
	CD[sid] = CurTime() + CD_SURE

	local islem = net.ReadString()
	local arg = net.ReadTable() or {}
	local ent = ply._EkoEnt
	if IsValid(ent) and Uzaklik(ply, ent) > 200 then
		E.Bildir(ply, "Demasiado lejos.", "uyari")
		return
	end

	if islem == "sat" and E.TuccarSat then
		E.TuccarSat(ply, arg.mal, arg.demet)
	elseif islem == "al" then
		if arg.ilan and E.TezgahAl then E.TezgahAl(ply, arg.ilan)
		elseif E.TuccarAl then E.TuccarAl(ply, arg.mal, arg.demet)
		end
	elseif islem == "teslim" and E.PanoTeslim then
		E.PanoTeslim(ply, tonumber(arg.slot))
	elseif islem == "degistir" and E.PanoDegistir then
		E.PanoDegistir(ply, tonumber(arg.slot))
	elseif islem == "geri" and E.TezgahGeri then
		E.TezgahGeri(ply, arg.ilan)
	elseif islem == "ilan" and E.TezgahIlan then
		E.TezgahIlan(ply, arg.item, arg.fiyat)
	end
end)

hook.Add("PlayerDisconnected", "SardonEkonomi.Ag", function(ply)
	CD[E.Sid64(ply) or ""] = nil
	ply._EkoEnt = nil
end)