-- Minimal actor spawn/despawn for Canlı Okul (SardonOkul).
-- Protocol mirrors cl_3aktor.lua (OLUSTUR / SIL / DUR / KONUS).

if not SERVER then return end

local G = SardonGorev
if not G or not G.AKTOR or not G.YazTablo then return end

G.SvAktor = G.SvAktor or {}
local S = G.SvAktor
S.sonraki = S.sonraki or 100
S.liste = S.liste or {} -- [no] = { veri = {}, pos = Vector, yaw = number }

util.AddNetworkString("SardonGorev.Aktor")

local function BroadcastAktor(yaz)
	net.Start("SardonGorev.Aktor")
		yaz()
	net.Broadcast()
end

function G.AktorOlustur(veri, pos, yaw)
	S.sonraki = S.sonraki + 1
	local no = S.sonraki
	veri = table.Copy(veri or {})
	veri.pos = pos or vector_origin
	veri.yaw = yaw or 0
	S.liste[no] = { veri = veri, pos = veri.pos, yaw = veri.yaw }

	BroadcastAktor(function()
		net.WriteUInt(G.AKTOR.OLUSTUR, 4)
		net.WriteUInt(no, 16)
		G.YazTablo(veri)
		net.WriteString("")
		net.WriteBool(false)
	end)

	return no
end

function G.AktorSilSv(no)
	if not S.liste[no] then return end
	S.liste[no] = nil
	BroadcastAktor(function()
		net.WriteUInt(G.AKTOR.SIL, 4)
		net.WriteUInt(no, 16)
		net.WriteString("")
	end)
end

function G.AktorDurSv(no, pos, yaw)
	local a = S.liste[no]
	if not a then return end
	a.pos, a.yaw = pos or a.pos, yaw or a.yaw
	if a.veri then a.veri.pos, a.veri.yaw = a.pos, a.yaw end
	BroadcastAktor(function()
		net.WriteUInt(G.AKTOR.DUR, 4)
		net.WriteUInt(no, 16)
		net.WriteVector(a.pos)
		net.WriteFloat(a.yaw)
	end)
end

function G.AktorKonusSv(no, metin, bakanEntIndex, sahipEntIndex)
	local a = S.liste[no]
	if not a then return end
	metin = tostring(metin or "")
	local sure = (G.MetinSure and G.MetinSure(metin)) or 2.5
	BroadcastAktor(function()
		net.WriteUInt(G.AKTOR.KONUS, 4)
		net.WriteUInt(no, 16)
		net.WriteString(metin)
		net.WriteString("")
		net.WriteString("")
		net.WriteFloat(sure)
		net.WriteString("")
		net.WriteUInt(tonumber(bakanEntIndex) or 0, 16)
		net.WriteString("altyazi") -- sahip oyuncuya altyazı
		net.WriteUInt(tonumber(sahipEntIndex) or 0, 16)
	end)
end

-- Late joiners get currently living actors
hook.Add("PlayerInitialSpawn", "SardonGorev.AktorSync", function(ply)
	timer.Simple(4, function()
		if not IsValid(ply) then return end
		for no, a in pairs(S.liste) do
			net.Start("SardonGorev.Aktor")
				net.WriteUInt(G.AKTOR.OLUSTUR, 4)
				net.WriteUInt(no, 16)
				G.YazTablo(a.veri)
				net.WriteString("")
				net.WriteBool(false)
			net.Send(ply)
		end
	end)
end)
