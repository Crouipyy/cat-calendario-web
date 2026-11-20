-- Minimal Shine Store responses. Full gacha economy is in missing sv_*.lua.

if not SERVER then return end

local SG = SardonGacha
if not SG then return end

local function Yaz(tbl)
	local data = util.Compress(util.TableToJSON(tbl or {}) or "{}") or ""
	net.WriteUInt(#data, 32)
	if #data > 0 then net.WriteData(data, #data) end
end

local function EmptyDurum()
	return {
		c = { adak = 0, bilet = 0, toz = 0 },
		p = {},
		a = {},
		ay = {},
		k = {},
		t = os.time(),
	}
end

net.Receive("SardonGacha.Istek", function(_, ply)
	if not IsValid(ply) then return end
	local tur = net.ReadUInt(4)
	local ISTEK = SG.ISTEK or {}

	if tur == ISTEK.DURUM then
		net.Start("SardonGacha.Durum")
			Yaz(EmptyDurum())
		net.Send(ply)
	elseif tur == ISTEK.GECMIS then
		net.Start("SardonGacha.Gecmis")
			Yaz({ liste = {} })
		net.Send(ply)
	else
		-- consume remaining payload safely for CEK/TAKAS
		if tur == ISTEK.CEK then
			net.ReadString(); net.ReadUInt(4); net.ReadBool()
		elseif tur == ISTEK.TAKAS then
			net.ReadString(); net.ReadUInt(8)
		end
		net.Start("SardonGacha.Bildirim")
			net.WriteString("Shine Store: economía de servidor incompleta (stub).")
			net.WriteString("hata")
		net.Send(ply)
	end
end)

net.Receive("SardonGacha.Yonetim", function() end)
