-- Minimal server stubs for Rehber TAB + actor KONUS → Canlı Okul radial.
-- Full quest sim is in missing sv_*.lua files.

if not SERVER then return end

local G = SardonGorev
if not G then return end

local NETS = {
	"SardonGorev.Istek",
	"SardonGorev.Durum",
	"SardonGorev.Olay",
	"SardonGorev.Diyalog",
	"SardonGorev.Ses",
	"SardonGorev.Sandal",
	"SardonGorev.Aktor",
	"SardonGorev.Sahne",
	"SardonGorev.Yonetim",
	"SardonGorev.ArayuzOlay",
}

for _, name in ipairs(NETS) do
	util.AddNetworkString(name)
end

local function SendEmptyDurum(ply)
	if not IsValid(ply) or not G.YazTablo then return end
	net.Start("SardonGorev.Durum")
		G.YazTablo({
			gorevler = {},
			bitti = {},
			gunluk = {},
			teklif = {},
		})
	net.Send(ply)
end

net.Receive("SardonGorev.Istek", function(_, ply)
	if not IsValid(ply) then return end
	local kod = net.ReadUInt(8)
	local ISTEK = G.ISTEK or {}

	if kod == ISTEK.DURUM or kod == ISTEK.HAZIR then
		SendEmptyDurum(ply)
		return
	end

	if kod == ISTEK.KONUS then
		local no = net.ReadUInt(16)
		local a = G.SvAktor and G.SvAktor.liste and G.SvAktor.liste[no]
		if not a then return end
		local id = a.veri and a.veri.id
		if isstring(id) and string.sub(id, 1, 5) == "okul:" and SardonOkul and SardonOkul.MuhurAcSv then
			SardonOkul.MuhurAcSv(ply, no, string.sub(id, 6))
		elseif a.veri and a.veri.ad and G.AktorKonusSv then
			G.AktorKonusSv(no, "Hola.", ply:EntIndex(), ply:EntIndex())
		end
		return
	end

	-- consume remaining payloads for unused codes without erroring
end)

net.Receive("SardonGorev.Yonetim", function() end)
net.Receive("SardonGorev.ArayuzOlay", function() end)

hook.Add("PlayerInitialSpawn", "SardonGorev.StubDurum", function(ply)
	timer.Simple(2, function()
		SendEmptyDurum(ply)
	end)
end)
