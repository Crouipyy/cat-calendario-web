-- Servidor :: persistencia y economía (data/sardon_gacha/)
if not SERVER then return end

local SG = SardonGacha
if not SG then return end

local DATA = "sardon_gacha"
local OYUNCU = DATA .. "/oyuncular"
local AYAR_DOSYA = DATA .. "/ayar.json"
local AFIS_DOSYA = DATA .. "/afisler.json"
local KAYIT_DOSYA = DATA .. "/kayit.json"
local IST_DOSYA = DATA .. "/istatistik.json"

SG._OyuncuCache = SG._OyuncuCache or {}
SG._Kayit = SG._Kayit or nil
SG._Ist = SG._Ist or nil

local function OkuJSON(yol, defecto)
	if not file.Exists(yol, "DATA") then return defecto end
	local raw = file.Read(yol, "DATA")
	if not isstring(raw) or raw == "" then return defecto end
	return util.JSONToTable(raw) or defecto
end

local function YazJSON(yol, tbl)
	file.CreateDir(DATA)
	local dir = yol:match("^(.+)/[^/]+$")
	if dir then file.CreateDir(dir) end
	file.Write(yol, util.TableToJSON(tbl, true) or "{}")
end

function SG.Sid64(ply)
	if not IsValid(ply) then return nil end
	return ply:SteamID64()
end

function SG.Yaz(tbl)
	local data = util.Compress(util.TableToJSON(tbl or {}) or "{}") or ""
	net.WriteUInt(#data, 32)
	if #data > 0 then net.WriteData(data, #data) end
end

function SG.OkuNet()
	local n = net.ReadUInt(32)
	if n <= 0 then return nil end
	return util.JSONToTable(util.Decompress(net.ReadData(n)) or "") or nil
end

function SG.BildirimGonder(ply, metin, tur)
	if not IsValid(ply) then return end
	net.Start("SardonGacha.Bildirim")
	net.WriteString(metin or "")
	net.WriteString(tur or "bilgi")
	net.Send(ply)
end

--[[ Persistencia global ]]--

function SG.AyarYukle()
	SG.Ayar = OkuJSON(AYAR_DOSYA, nil) or {}
	for k, v in pairs(SG.AyarVarsayilan) do
		if SG.Ayar[k] == nil then SG.Ayar[k] = v end
	end
	return SG.Ayar
end

function SG.AyarKaydet()
	YazJSON(AYAR_DOSYA, SG.Ayar)
end

function SG.AfislerYukle()
	SG.Afisler = OkuJSON(AFIS_DOSYA, {})
	if not istable(SG.Afisler) then SG.Afisler = {} end
	return SG.Afisler
end

function SG.AfislerKaydet()
	YazJSON(AFIS_DOSYA, SG.Afisler)
end

function SG.KayitYukle()
	if SG._Kayit then return SG._Kayit end
	SG._Kayit = OkuJSON(KAYIT_DOSYA, {})
	if not istable(SG._Kayit) then SG._Kayit = {} end
	return SG._Kayit
end

function SG.KayitEkle(sid, alan, miktar, yeni, sebep)
	local k = SG.KayitYukle()
	k[#k + 1] = {
		t = os.time(),
		sid = tostring(sid or "?"),
		alan = alan,
		miktar = math.floor(tonumber(miktar) or 0),
		yeni = math.floor(tonumber(yeni) or 0),
		sebep = tostring(sebep or ""),
	}
	while #k > 500 do table.remove(k, 1) end
	YazJSON(KAYIT_DOSYA, k)
end

function SG.IstYukle()
	if SG._Ist then return SG._Ist end
	SG._Ist = OkuJSON(IST_DOSYA, {})
	if not istable(SG._Ist) then SG._Ist = {} end
	return SG._Ist
end

function SG.IstKaydet()
	YazJSON(IST_DOSYA, SG.IstYukle())
end

function SG.IstEkle(afisId, afisAd, y)
	local ist = SG.IstYukle()
	local s = ist[afisId]
	if not istable(s) then
		s = { ad = afisAd or "?", [3] = 0, [4] = 0, [5] = 0 }
		ist[afisId] = s
	end
	s.ad = afisAd or s.ad
	y = math.floor(tonumber(y) or 3)
	s[y] = (s[y] or 0) + 1
	SG.IstKaydet()
end

--[[ Jugador ]]--

local function OyuncuDefecto()
	return {
		adak = 0,
		bilet = 0,
		toz = 0,
		k = {},
		p = {
			standart = { p5 = 0, p4 = 0, g5 = 0, g4 = 0 },
			etkinlik = { p5 = 0, p4 = 0, g5 = 0, g4 = 0 },
		},
		gecmis = {},
		kazanilan = 0,
		toplam = 0,
	}
end

function SG.OyuncuYol(sid)
	return OYUNCU .. "/" .. sid .. ".json"
end

function SG.OyuncuYukle(sid)
	sid = tostring(sid or "")
	if sid == "" or sid == "0" then return nil end
	if SG._OyuncuCache[sid] then return SG._OyuncuCache[sid] end
	local v = OkuJSON(SG.OyuncuYol(sid), nil)
	if not istable(v) then v = OyuncuDefecto() end
	if not istable(v.p) then v.p = OyuncuDefecto().p end
	for _, pk in ipairs({ "standart", "etkinlik" }) do
		v.p[pk] = v.p[pk] or { p5 = 0, p4 = 0, g5 = 0, g4 = 0 }
	end
	v.k = istable(v.k) and v.k or {}
	v.gecmis = istable(v.gecmis) and v.gecmis or {}
	SG._OyuncuCache[sid] = v
	return v
end

function SG.OyuncuKaydet(sid)
	sid = tostring(sid or "")
	local v = SG._OyuncuCache[sid]
	if not v then return end
	file.CreateDir(OYUNCU)
	YazJSON(SG.OyuncuYol(sid), v)
end

function SG.OyuncuAl(ply)
	local sid = SG.Sid64(ply)
	if not sid then return nil end
	return SG.OyuncuYukle(sid)
end

--[[ Economía ]]--

local ALAN = { adak = true, bilet = true, toz = true }

function SG.CuzdanEkle(ply, alan, miktar, sebep, sessiz)
	if not IsValid(ply) then return false, "Jugador no válido." end
	alan = tostring(alan or "")
	if not ALAN[alan] then return false, "Moneda no válida." end
	miktar = math.floor(tonumber(miktar) or 0)
	if miktar == 0 then return false, "Cantidad cero." end

	local sid = SG.Sid64(ply)
	local v = SG.OyuncuAl(ply)
	if not v then return false, "No se pudo cargar la cuenta." end

	local antes = v[alan] or 0
	local despues = math.max(0, antes + miktar)
	if despues ~= antes + miktar then
		return false, "Saldo insuficiente."
	end
	v[alan] = despues
	if alan == "adak" and miktar > 0 then v.kazanilan = (v.kazanilan or 0) + miktar end
	SG.OyuncuKaydet(sid)

	SG.KayitEkle(sid, alan, miktar, despues, sebep or "")

	if not sessiz and IsValid(ply) then
		local ay = SG.Ayar
		local nombres = { adak = ay.adakAd, bilet = ay.biletAd, toz = ay.tozAd }
		local signo = miktar > 0 and "+" or ""
		SG.BildirimGonder(ply, signo .. SG.Sayi(miktar) .. " " .. (nombres[alan] or alan), alan)
		if SG.DurumGonder then SG.DurumGonder(ply) end
	end
	return true, despues
end

function SG.AdakVer(ply, miktar, sebep)
	return SG.CuzdanEkle(ply, "adak", math.floor(tonumber(miktar) or 0), sebep or "Ofrenda", false)
end

--[[ Colección / HpwRewrite ]]--

function SG.SpellModel(skin)
	if HpwRewrite and HpwRewrite.GetSpell then
		local sp = HpwRewrite:GetSpell(skin)
		if sp and sp.WorldModel then return sp.WorldModel end
	end
	return "models/hpwrewrite/w_magicwand.mdl"
end

function SG.EldeSunucu(ply, v, skin)
	if v.k and v.k[skin] then return true end
	if HpwRewrite and HpwRewrite.PlayerHasSpell then
		return HpwRewrite:PlayerHasSpell(ply, skin)
	end
	return false
end

function SG.AsaVer(ply, v, skin)
	v.k = v.k or {}
	v.k[skin] = true
	local ok = false
	if HpwRewrite then
		if HpwRewrite.SaveAndGiveSpell then
			local r = HpwRewrite:SaveAndGiveSpell(ply, skin)
			ok = r ~= false
		elseif HpwRewrite.PlayerGiveSpell then
			HpwRewrite:PlayerGiveSpell(ply, skin)
			ok = true
		end
	end
	-- Sin API HpwRewrite: la colección k[skin] es la fuente de verdad en cuenta.
	return ok or not HpwRewrite
end

--[[
	Ollivander (sv_6etki): llamar SardonGacha.Cezasiz(ply, skin).
	Las varitas obtenidas en gacha están en k[skin] y no deben contar como “segunda varita” penalizada.
	Si no hay HpwRewrite, la colección en JSON es la fuente de verdad.
]]
function SG.Cezasiz(ply, skin)
	if not IsValid(ply) or not isstring(skin) or skin == "" then return false end
	local v = SG.OyuncuAl(ply)
	return v and v.k and v.k[skin] and true or false
end

--[[ Afiş enriquecimiento ]]--

function SG.AfisBul(id)
	for _, a in ipairs(SG.Afisler or {}) do
		if a.id == id then return a end
	end
	return nil
end

function SG.AfisHavuzZengin(a)
	local t = table.Copy(a)
	t.havuz = t.havuz or {}
	for _, e in ipairs(t.havuz) do
		e.ad = SG.AsaAd(e.skin, e.ad)
		if not e.model or e.model == "" then e.model = SG.SpellModel(e.skin) end
	end
	return t
end

function SG.AcikAfisler()
	local simdi = os.time()
	local t = {}
	for _, a in ipairs(SG.Afisler or {}) do
		if SG.AfisAcik(a, simdi) then
			t[#t + 1] = SG.AfisHavuzZengin(a)
		end
	end
	table.sort(t, function(x, y) return (tonumber(x.sira) or 0) < (tonumber(y.sira) or 0) end)
	return t
end

function SG.DurumTablosu(ply)
	local v = SG.OyuncuAl(ply)
	if not v then return nil end
	return {
		c = { adak = v.adak or 0, bilet = v.bilet or 0, toz = v.toz or 0 },
		p = v.p,
		a = SG.AcikAfisler(),
		ay = SG.Ayar,
		k = v.k or {},
		t = os.time(),
	}
end

function SG.GecmisEkle(v, entrada)
	v.gecmis = v.gecmis or {}
	table.insert(v.gecmis, 1, entrada)
	while #v.gecmis > 200 do table.remove(v.gecmis) end
end

--[[ Arranque ]]--

hook.Add("Initialize", "SardonGacha.Veri", function()
	file.CreateDir(DATA)
	file.CreateDir(OYUNCU)
	SG.AyarYukle()
	SG.AfislerYukle()
	SG.KayitYukle()
	SG.IstYukle()
end)

hook.Add("PlayerDisconnected", "SardonGacha.Veri", function(ply)
	local sid = SG.Sid64(ply)
	if sid and SG._OyuncuCache[sid] then
		SG.OyuncuKaydet(sid)
		SG._OyuncuCache[sid] = nil
	end
end)