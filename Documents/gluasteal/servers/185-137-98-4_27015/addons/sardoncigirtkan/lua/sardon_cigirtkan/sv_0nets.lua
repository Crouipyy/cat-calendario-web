-- Sardon Çığırtkan :: redes y utilidades
SardonCigirtkan = SardonCigirtkan or {}
local C = SardonCigirtkan
local A = C.Ayar
local K = C.K
local I = C.I

local NETS = {
	"Basla",
	"Islem",
	"Durum",
	"Parca",
	"Unut",
	"Yazi",
	"TopluListe",
	"Admin",
	"AdminListe",
}

for _, n in ipairs(NETS) do
	util.AddNetworkString("SardonCigirtkan." .. n)
end

C.Oturumlar = C.Oturumlar or {}
C.Sesler = C.Sesler or {}
C.Ucus = C.Ucuslar or {}
C.Zarflar = C.Zarflar or {}
C.Son = C.Son or {}
C.Yasak = C.Yasak or {}
C.Kurallar = C.Kurallar or {}

C.DATA = "sardon_cigirtkan"
file.CreateDir(C.DATA)

local function jRead(path, fb)
	local raw = file.Read(path, "DATA")
	if not raw or raw == "" then return fb end
	return util.JSONToTable(raw) or fb
end

local function jWrite(path, tab)
	file.Write(path, util.TableToJSON(tab, false))
end

function C.PersistLoad()
	C.Kurallar = jRead(C.DATA .. "/kurallar.json", {})
	C.Yasak = jRead(C.DATA .. "/yasak.json", {})
	C.Son = jRead(C.DATA .. "/son.json", {})
end

function C.PersistSave()
	jWrite(C.DATA .. "/kurallar.json", C.Kurallar)
	jWrite(C.DATA .. "/yasak.json", C.Yasak)
	while #C.Son > 120 do table.remove(C.Son, 1) end
	jWrite(C.DATA .. "/son.json", C.Son)
end

hook.Add("Initialize", "SardonCigirtkan.Load", function()
	timer.Simple(0, function()
		C.PersistLoad()
		C._nextId = C._nextId or math.random(1000, 9000)
	end)
end)

function C.SonrakiKimlik()
	C._nextId = (C._nextId or 1000) + 1
	return C._nextId
end

function C.Bildir(ply, msg)
	if not IsValid(ply) or not msg or msg == "" then return end
	if ply.Notify then ply:Notify(msg) elseif ix.util.Notify then ix.util.Notify(ply, msg) end
end

function C.DurumGonder(ply, sess)
	if not IsValid(ply) or not sess then return end
	net.Start("SardonCigirtkan.Durum")
	net.WriteUInt(sess.durum or K.KAPALI, 3)
	net.WriteEntity(sess.hedef or NULL)
	net.WriteFloat(sess.konusma or 0)
	net.WriteBool(sess.anonim == true)
	net.WriteString(sess.hata or "")
	net.WriteUInt(sess.onizleme or 0, 32)
	net.WriteFloat(sess.sure or 0)
	net.WriteString(sess.dalga or "")
	net.WriteString(sess.grupAd or "")
	net.WriteUInt(sess.grupSayi or 0, 8)
	net.Send(ply)
end

function C.SesVarMi()
	return istable(voicechat) and isfunction(voicechat.SetPlayerVoiceDataHook)
end

function C.DalgaUret(sure)
	local t = {}
	for i = 1, 48 do
		t[i] = string.format("%02x", math.floor((0.15 + 0.85 * math.abs(math.sin(i * 0.7 + sure))) * 255))
	end
	return table.concat(t)
end

function C.Gunluk(olay, F)
	C.Son = C.Son or {}
	C.Son[#C.Son + 1] = {
		zaman = os.time(),
		olay = olay or "",
		gonderen = F and (F.gonderenAd or "") or "",
		alici = F and (IsValid(F.hedef) and F.hedef:Name() or F.grupAd) or "",
		sure = F and F.sure or 0,
		anonim = F and F.anonim and 1 or 0,
	}
	C.PersistSave()
end