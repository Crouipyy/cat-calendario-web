-- Minimal server stubs: pool nets so TAB "Desarrollo del personaje" opens without unpooled errors.
-- Full XP/learn logic lives in missing sv_xp.lua / sv_yonetim.lua (not in gluasteal dump).

if not SERVER then return end

local NETS = {
	"SardonGelisim.Ogren",
	"SardonGelisim.Bildirim",
	"SardonGelisim.XP",
	"SardonGelisim.Yonetim",
	"SardonGelisim.YonetimVeri",
}

for _, name in ipairs(NETS) do
	util.AddNetworkString(name)
end

net.Receive("SardonGelisim.Ogren", function(_, ply)
	if not IsValid(ply) then return end
	net.Start("SardonGelisim.Bildirim")
		net.WriteString("Desarrollo: lógica de servidor incompleta (stub).")
		net.WriteBool(false)
	net.Send(ply)
end)

net.Receive("SardonGelisim.Yonetim", function(_, ply)
	if not IsValid(ply) then return end
	-- ignore until full sv_yonetim exists
end)
