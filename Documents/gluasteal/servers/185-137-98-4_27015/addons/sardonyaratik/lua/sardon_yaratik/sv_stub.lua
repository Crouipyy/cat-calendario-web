-- Minimal SV so SardonYaratik client UI (Muhur) can load without full creature sim.

if not SERVER then return end

local Y = SardonYaratik
if not Y or not Y.NET then return end

for _, name in pairs(Y.NET) do
	if isstring(name) then util.AddNetworkString(name) end
end

local function YazListe(ply, veri)
	local raw = util.Compress(util.TableToJSON(veri or {}) or "{}") or ""
	net.Start(Y.NET.LISTE)
		net.WriteUInt(#raw, 32)
		if #raw > 0 then net.WriteData(raw, #raw) end
	net.Send(ply)
end

local function BosListe()
	return { liste = {}, yemlik = {}, kapasite = 0, canli = 0, yumurta = 0, zaman = os.time() }
end

net.Receive(Y.NET.ISLEM, function(_, ply)
	if not IsValid(ply) then return end
	-- client writes: action string, entIndex/id, ek, float — swallow safely
	pcall(function()
		net.ReadString()
		net.ReadUInt(32)
		net.ReadString()
		net.ReadFloat()
	end)
	net.Start(Y.NET.BILDIRIM)
		net.WriteString("Yaratık simülasyonu henüz sunucuda yok (stub).")
		net.WriteString("hata")
	net.Send(ply)
end)

net.Receive(Y.NET.YONETIM, function() end)
net.Receive(Y.NET.BINEK, function() end)

hook.Add("PlayerInitialSpawn", "SardonYaratik.StubListe", function(ply)
	timer.Simple(3, function()
		if IsValid(ply) then YazListe(ply, BosListe()) end
	end)
end)

print("[SardonYaratik] sv_stub yüklendi.")
