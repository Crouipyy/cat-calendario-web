-- Servidor :: mercado negro Sombra + derechos semanales + condiciones misión
if not SERVER then return end
local S = SardonGolge
if not S then return end

local DATA = "sardon_golge"
S.DATA = DATA

local function OkuJSON(yol, def)
	if not file.Exists(yol, "DATA") then return def end
	return util.JSONToTable(file.Read(yol, "DATA") or "") or def
end
local function YazJSON(yol, tbl)
	file.CreateDir(DATA)
	file.Write(yol, util.TableToJSON(tbl, true) or "{}")
end

-- SQLite derechos semanales
sql.Query([[CREATE TABLE IF NOT EXISTS sardon_golge_hak (
	sid TEXT NOT NULL,
	hafta TEXT NOT NULL,
	adet INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY (sid, hafta)
)]])

function S.HakAl(sid, hafta)
	hafta = hafta or S.Hafta()
	local r = sql.Query(string.format("SELECT adet FROM sardon_golge_hak WHERE sid=%s AND hafta=%s",
		sql.SQLStr(sid), sql.SQLStr(hafta)))
	return r and r[1] and tonumber(r[1].adet) or 0
end

function S.HakEkle(sid, n, hafta)
	hafta = hafta or S.Hafta()
	local cur = S.HakAl(sid, hafta) + (tonumber(n) or 0)
	sql.Query(string.format("DELETE FROM sardon_golge_hak WHERE sid=%s AND hafta=%s", sql.SQLStr(sid), sql.SQLStr(hafta)))
	sql.Query(string.format("INSERT INTO sardon_golge_hak (sid,hafta,adet) VALUES (%s,%s,%d)",
		sql.SQLStr(sid), sql.SQLStr(hafta), cur))
end

function S.MallarYukle()
	S._Mallar = S._Mallar or OkuJSON(DATA .. "/mallar.json", nil)
	if not S._Mallar then
		S._Mallar = {
			{ id = 1, esya = S.ESYA, ad = "Cuchillo de la Realidad", fiyat = 50, snatcherFiyat = 50,
				stok = -1, kisiSinir = 1, kimler = "hepsi", aktif = true, soz = "Afilado y discreto.",
				veri = { adet = 1 }, satilan = 0 },
		}
		YazJSON(DATA .. "/mallar.json", S._Mallar)
	end
	S.Mallar = S._Mallar
	return S._Mallar
end

function S.MallarKaydet()
	YazJSON(DATA .. "/mallar.json", S.Mallar or S._Mallar or {})
end

function S.NoktalarYukle()
	S._Noktalar = S._Noktalar or OkuJSON(DATA .. "/noktalar.json", {}) or {}
	return S._Noktalar
end

function S.NoktalarKaydet()
	YazJSON(DATA .. "/noktalar.json", S._Noktalar or S.Noktalar or {})
end

local function Sinir(ply)
	return S.SnatcherMi(ply) and (S.Ayar.SnatcherSinir or 1) or (S.Ayar.DigerSinir or 1)
end

local function KalanHak(ply)
	local sid = ply:SteamID64()
	return math.max(0, Sinir(ply) - S.HakAl(sid))
end

local function MalListePara(ply)
	local para = 0
	local char = ply:GetCharacter()
	if char then para = math.floor(char:GetMoney() or 0) end
	local liste = {}
	local sn = S.SnatcherMi(ply)
	for _, m in ipairs(S.MallarYukle()) do
		if m.aktif == false then continue end
		local kim = m.kimler or "hepsi"
		if kim == "snatcher" and not sn then continue end
		if kim == "diger" and sn then continue end
		local fiyat = sn and (m.snatcherFiyat or m.fiyat or S.Ayar.SnatcherFiyat) or (m.fiyat or S.DigerFiyat())
		liste[#liste + 1] = {
			id = m.id, esya = m.esya, ad = m.ad or m.esya, soz = m.soz or "",
			stok = tonumber(m.stok) or -1, kisi = KalanHak(ply), fiyat = math.floor(fiyat),
		}
	end
	return { mallar = liste, para = para }
end

function S.MalAc(ply)
	if not IsValid(ply) then return end
	if S.Ayar.Kapali then
		return S.Bildir(ply, "El mostrador de Sombra está cerrado.", true)
	end
	local c = ply:GetCharacter()
	if c then c:SetData("golgeTanis", true) end
	S.Golge.muhatap = ply:Nick()
	ply._GolgeMalAcik = true
	net.Start("SardonGolge.Mal")
	net.WriteString(util.TableToJSON(MalListePara(ply)))
	net.Send(ply)
end

local function DarHancer(ply, adet)
	local char = ply:GetCharacter()
	if not char then return false end
	return S.HancerEkle(char, adet)
end

local function MalAl(ply, id)
	id = tonumber(id)
	local char = ply:GetCharacter()
	if not char or not id then return end
	if KalanHak(ply) <= 0 then
		return S.Bildir(ply, "No te queda cupo esta semana.", true)
	end
	local mal
	for _, m in ipairs(S.MallarYukle()) do if m.id == id then mal = m break end end
	if not mal or mal.aktif == false then
		return S.Bildir(ply, "Mercancía no disponible.", true)
	end
	if (tonumber(mal.stok) or -1) == 0 then
		return S.Bildir(ply, "Agotado esta semana.", true)
	end
	local sn = S.SnatcherMi(ply)
	local fiyat = sn and (mal.snatcherFiyat or mal.fiyat or S.Ayar.SnatcherFiyat) or (mal.fiyat or S.DigerFiyat())
	fiyat = math.floor(fiyat)
	if char:GetMoney() < fiyat then
		return S.Bildir(ply, "No tienes suficientes galeones.", true)
	end
	char:TakeMoney(fiyat)
	local adet = sn and (S.Ayar.SnatcherPaket or 5) or (S.Ayar.DigerAdet or 1)
	if mal.esya == S.ESYA then
		DarHancer(ply, adet)
		if sn and math.random() < (S.Ayar.HediyeSans or 0.15) then
			DarHancer(ply, 1)
			S.Bildir(ply, "¡Sombra te ha regalado un cuchillo extra!", false)
		end
	else
		local inv = char:GetInventory()
		if inv then inv:Add(mal.esya, 1, mal.veri or {}) end
	end
	S.HakEkle(ply:SteamID64(), 1)
	if (tonumber(mal.stok) or -1) > 0 then
		mal.stok = mal.stok - 1
		S.MallarKaydet()
	end
	mal.satilan = (mal.satilan or 0) + 1
	S.MallarKaydet()
	if S.KayitEkle then S.KayitEkle("satin", ply, nil, mal.ad or mal.esya) end
	S.Bildir(ply, "Has comprado " .. (mal.ad or mal.esya) .. ".", false)
	ply._GolgeAlindi = true
	if ply._GolgeMalAcik then
		net.Start("SardonGolge.Mal")
		net.WriteString(util.TableToJSON(MalListePara(ply)))
		net.Send(ply)
	end
end

net.Receive("SardonGolge.Mal", function(_, ply)
	if not IsValid(ply) then return end
	local t = util.JSONToTable(net.ReadString() or "") or {}
	if t.islem == "al" then MalAl(ply, t.id)
	elseif t.islem == "kapat" then
		ply._GolgeMalAcik = nil
		S.Golge.muhatap = ""
		if ply._GolgeAlindi then
			ply._GolgeAlindi = nil
			if S.GolgeTeleport then S.GolgeTeleport(true) end
		end
	end
end)

-- Condiciones misión
local function KosulKaydet()
	local G = SardonGorev
	if not (G and G.Kosul) then return false end
	G.Kosul["golge_tanis"] = function(ply)
		return ply:GetCharacter() and ply:GetCharacter():GetData("golgeTanis") == true
	end
	G.Kosul["golge_grup"] = function(ply, e)
		return S.Grup(ply) == tostring(e and e.deger or "")
	end
	G.Kosul["golge_alabilir"] = function(ply)
		local char = ply:GetCharacter()
		if not char then return false end
		return KalanHak(ply) > 0 and char:GetMoney() >= S.Fiyat(ply)
	end
	G.Kosul["golge_bakanlik_yakala"] = function(ply)
		if S.Grup(ply) ~= "bakanlik" then return false end
		return math.random() < (S.Ayar.BakanlikYakalama or 0.5)
	end
	G.Kosul["golge_mal_var"] = function(ply)
		local t = MalListePara(ply)
		return #(t.mallar or {}) > 0
	end
	return true
end

-- Abrir mostrador desde diálogo de misión
hook.Add("SardonGorevOlay", "SardonGolge.Mal", function(ply, olay, veri)
	if olay == "golge_mal" or (veri and veri.menu == "golge") then
		S.MalAc(ply)
	end
end)

hook.Add("InitPostEntity", "SardonGolge.Golge", function()
	S.MallarYukle()
	S.NoktalarYukle()
	timer.Simple(2, function()
		if not KosulKaydet() then
			timer.Create("SardonGolge.Kosul", 2, 30, function()
				if KosulKaydet() then timer.Remove("SardonGolge.Kosul") end
			end)
		end
	end)
end)

concommand.Add("sardon_golge_mal", function(ply)
	if IsValid(ply) then S.MalAc(ply) end
end)

S.AYAR_VARSAYILAN = table.Copy(S.Ayar)

function S.AyarYukle()
	local yol = DATA .. "/ayar.json"
	if file.Exists(yol, "DATA") then
		table.Merge(S.Ayar, util.JSONToTable(file.Read(yol, "DATA") or "") or {})
	end
end

function S.AyarKaydet()
	YazJSON(DATA .. "/ayar.json", S.Ayar)
end

S.AYAR_SEMA = {
	{ k = "Kapali", ad = "Puesto cerrado", grup = "Sombra", tur = "bool" },
	{ k = "SnatcherFiyat", ad = "Precio Snatcher (G)", grup = "Sombra", tur = "num", min = 0, max = 5000, birim = 1 },
	{ k = "SnatcherPaket", ad = "Pack Snatcher", grup = "Sombra", tur = "num", min = 1, max = 20, birim = 1 },
	{ k = "SnatcherSinir", ad = "Cupos Snatcher/semana", grup = "Sombra", tur = "num", min = 0, max = 10, birim = 1 },
	{ k = "DigerFiyat", ad = "Precio base otros", grup = "Sombra", tur = "num", min = 10, max = 5000, birim = 1 },
	{ k = "DigerAdet", ad = "Cantidad otros", grup = "Sombra", tur = "num", min = 1, max = 10, birim = 1 },
	{ k = "DigerSinir", ad = "Cupos otros/semana", grup = "Sombra", tur = "num", min = 0, max = 10, birim = 1 },
	{ k = "HediyeSans", ad = "Regalo extra Snatcher", grup = "Sombra", tur = "num", min = 0, max = 100, birim = 0.01 },
	{ k = "BakanlikYakalama", ad = "Ministerio pillado", grup = "Sombra", tur = "num", min = 0, max = 100, birim = 0.01 },
	{ k = "GezintiSure", ad = "Ronda automática (s)", grup = "Sombra", tur = "num", min = 60, max = 7200, birim = 1 },
	{ k = "Menzil", ad = "Alcance al clavar", grup = "Cuchillo", tur = "num", min = 32, max = 200, birim = 1 },
	{ k = "Bekleme", ad = "Enfriamiento clavar", grup = "Cuchillo", tur = "num", min = 0, max = 120, birim = 1 },
	{ k = "Hasar", ad = "Daño", grup = "Cuchillo", tur = "num", min = 0, max = 100, birim = 1 },
	{ k = "KilikSure", ad = "Duración disfraz", grup = "Disfraz", tur = "num", min = 60, max = 14400, birim = 1 },
	{ k = "YenidenBekleme", ad = "Recarga disfraz", grup = "Disfraz", tur = "num", min = 0, max = 3600, birim = 1 },
}

S.Golge = S.Golge or { no = nil, simdiki = 0, siradaki = 1, gezintiBit = 0, muhatap = "" }

function S.GolgeVeri()
	return { id = S.AKTOR, ad = "Sombra", unvan = "Proveedor", menu = "golge", model = "models/player/skeleton.mdl", boy = 0.92 }
end

function S.GolgeTeleport(satin)
	local G = SardonGorev
	S.Noktalar = S.NoktalarYukle()
	if not (G and G.AktorDurSv and S.Golge.no) or #S.Noktalar == 0 then return end
	local n = #S.Noktalar
	local hedef = satin and ((S.Golge.simdiki % n) + 1) or math.Clamp(S.Golge.siradaki or 1, 1, n)
	local pkt = S.Noktalar[hedef]
	local p = pkt.pos
	local pos = Vector(p.x or p[1] or 0, p.y or p[2] or 0, p.z or p[3] or 0)
	G.AktorDurSv(S.Golge.no, pos, pkt.yaw or 0)
	S.Golge.simdiki, S.Golge.siradaki = hedef, (hedef % n) + 1
	S.Golge.gezintiBit = CurTime() + (S.Ayar.GezintiSure or 2700)
	if S.KayitEkle then S.KayitEkle("isinlanma", nil, nil, "Punto " .. hedef) end
end

function S.GolgeSpawn()
	local G = SardonGorev
	if not (G and G.AktorOlustur) or S.Golge.no then return end
	S.Noktalar = S.NoktalarYukle()
	local pos, yaw = Vector(0, 0, 64), 0
	if S.Noktalar[1] and S.Noktalar[1].pos then
		local p = S.Noktalar[1].pos
		pos = Vector(p.x or 0, p.y or 0, p.z or 0)
		yaw = S.Noktalar[1].yaw or 0
		S.Golge.simdiki = 1
	end
	S.Golge.no = G.AktorOlustur(S.GolgeVeri(), pos, yaw)
	S.Golge.gezintiBit = CurTime() + (S.Ayar.GezintiSure or 2700)
end

hook.Add("SardonGorevOlay", "SardonGolge.Menu", function(ply, olay)
	if olay == "golge" or olay == "golge_mal" then S.MalAc(ply) end
end)

timer.Create("SardonGolge.Gezinti", 45, 0, function()
	if S.Golge.muhatap ~= "" then return end
	if CurTime() < (S.Golge.gezintiBit or 0) then return end
	S.GolgeTeleport(false)
end)

S.AyarYukle()
S.Mallar = S.MallarYukle()
S.Noktalar = S.NoktalarYukle()
timer.Simple(5, function() S.GolgeSpawn() end)
