-- Servidor :: núcleo de economía (data/sardon_ekonomi/)
if not SERVER then return end

local E = SardonEkonomi
if not E then return end

local DATA = "sardon_ekonomi"
E.DATA = DATA

E._Kaynak = E._Kaynak or {}
E._TavanCache = E._TavanCache or nil
E._AlacakCache = E._AlacakCache or nil
E._GunlukCache = E._GunlukCache or nil
E._KayitCache = E._KayitCache or nil

local function OkuJSON(yol, defecto)
	if not file.Exists(yol, "DATA") then return defecto end
	local raw = file.Read(yol, "DATA")
	if not isstring(raw) or raw == "" then return defecto end
	return util.JSONToTable(raw) or defecto
end

function E.YazJSON(yol, tbl)
	file.CreateDir(DATA)
	local dir = yol:match("^(.+)/[^/]+$")
	if dir then file.CreateDir(dir) end
	file.Write(yol, util.TableToJSON(tbl, true) or "{}")
end

function E.OkuJSON(yol, defecto)
	return OkuJSON(yol, defecto)
end

function E.Sid64(ply)
	if not IsValid(ply) then return nil end
	return ply:SteamID64()
end

function E.Char(ply)
	if not IsValid(ply) then return nil end
	return ply:GetCharacter()
end

function E.Cep(char)
	if not char then return 0 end
	return math.floor(char:GetMoney() or 0)
end

function E.Banka(char)
	if not char or not char.GetBankBalance then return 0 end
	return math.floor(char:GetBankBalance() or 0)
end

function E.BankaVer(char, miktar)
	miktar = math.floor(tonumber(miktar) or 0)
	if miktar == 0 or not char or not char.SetBankBalance then return false end
	char:SetBankBalance(math.max(0, E.Banka(char) + miktar))
	return true
end

function E.Seviye(char)
	if not char or not char.GetLVL then return nil end
	return tonumber(char:GetLVL()) or 0
end

function E.OgrenciMi(char)
	if not char then return false end
	if char:GetData("ogrenciGorunum") then return true end
	local fac = ix.faction.indices[char:GetFaction()]
	if fac and fac.name and string.find(string.lower(fac.name), "öğrenci") then return true end
	if fac and fac.name and string.find(string.lower(fac.name), "estudiante") then return true end
	local lvl = E.Seviye(char)
	return lvl ~= nil and lvl < 36
end

function E.HazineEkle(miktar, aciklama, kisi)
	miktar = math.floor(tonumber(miktar) or 0)
	if miktar == 0 then return end
	local B = SardonBakanlik
	if B and B.MoverHazine then
		B.MoverHazine("ekonomi", miktar, aciklama or "Economía", kisi or "")
	else
		MsgN("[SardonEkonomi] Tesoro +" .. miktar .. " (" .. tostring(aciklama) .. ") — Bakanlik ausente.")
	end
end

function E.HazineSaldo()
	local B = SardonBakanlik
	if B and B.SaldoHazine then return math.floor(B.SaldoHazine() or 0) end
	return 0
end

function E.AyarYukle()
	E.Ayar = OkuJSON(DATA .. "/ayar.json", nil) or {}
	for k, v in pairs(E.AyarVarsayilan) do
		if E.Ayar[k] == nil then E.Ayar[k] = v end
	end
	return E.Ayar
end

function E.AyarKaydet()
	E.YazJSON(DATA .. "/ayar.json", E.Ayar)
end

function E.TavanYukle()
	if not E._TavanCache then
		E._TavanCache = OkuJSON(DATA .. "/tavan.json", {}) or {}
	end
	return E._TavanCache
end

function E.TavanKaydet()
	E.YazJSON(DATA .. "/tavan.json", E.TavanYukle())
end

function E.AlacakYukle()
	if not E._AlacakCache then
		E._AlacakCache = OkuJSON(DATA .. "/alacak.json", {}) or {}
	end
	return E._AlacakCache
end

function E.AlacakKaydet()
	E.YazJSON(DATA .. "/alacak.json", E.AlacakYukle())
end

function E.GunlukYukle()
	if not E._GunlukCache then
		E._GunlukCache = OkuJSON(DATA .. "/gunluk.json", {}) or {}
	end
	return E._GunlukCache
end

function E.GunlukKaydet()
	E.YazJSON(DATA .. "/gunluk.json", E.GunlukYukle())
end

function E.KayitYukle()
	if not E._KayitCache then
		E._KayitCache = OkuJSON(DATA .. "/kayit.json", {}) or {}
	end
	return E._KayitCache
end

function E.KayitKaydet()
	E.YazJSON(DATA .. "/kayit.json", E.KayitYukle())
end

function E.KayitEkle(sid, kaynak, tur, miktar, yeni, aciklama)
	local k = E.KayitYukle()
	k[#k + 1] = {
		t = os.time(),
		sid = tostring(sid or "?"),
		kaynak = tostring(kaynak or "?"),
		tur = tur or "giris",
		miktar = math.floor(tonumber(miktar) or 0),
		yeni = math.floor(tonumber(yeni) or 0),
		aciklama = tostring(aciklama or ""),
	}
	while #k > 800 do table.remove(k, 1) end
	E.KayitKaydet()

	local gun = E.GunAnahtari()
	local g = E.GunlukYukle()
	local satir = g[gun]
	if not istable(satir) then
		satir = {kaynaklar = {}}
		g[gun] = satir
	end
	local kk = tostring(kaynak or "otro")
	local r = satir.kaynaklar[kk]
	if not istable(r) then r = {giris = 0, cikis = 0, hesap = "cep"} r = r end
	if tur == "cikis" then r.cikis = r.cikis + math.abs(miktar) else r.giris = r.giris + math.max(0, miktar) end
	satir.kaynaklar[kk] = r
	E.GunlukKaydet()
end

function E.BugunKazanilan(sid)
	sid = tostring(sid or "")
	local gun = E.GunAnahtari()
	local t = E.TavanYukle()
	local r = t[sid]
	if not r or r.gun ~= gun then return 0 end
	return math.floor(r.miktar or 0)
end

function E.TavanEkle(sid, miktar)
	sid = tostring(sid or "")
	miktar = math.floor(tonumber(miktar) or 0)
	if miktar <= 0 then return end
	local gun = E.GunAnahtari()
	local t = E.TavanYukle()
	local r = t[sid]
	if not r or r.gun ~= gun then r = {gun = gun, miktar = 0} end
	r.gun = gun
	r.miktar = math.floor((r.miktar or 0) + miktar)
	t[sid] = r
	E.TavanKaydet()
end

function E.KalanTavan(ply)
	local sid = E.Sid64(ply)
	if not sid then return 0 end
	local ay = E.Ayar
	return math.max(0, math.floor(ay.tavan or 25) - E.BugunKazanilan(sid))
end

function E.Baglam(kaynak, tur, fn, ...)
	local id = (E.Sid64(kaynak) or tostring(kaynak or "?")) .. ":" .. (CurTime() + math.random())
	E._Kaynak[id] = {kaynak = kaynak, tur = tur}
	local a, b, c, d = fn(...)
	E._Kaynak[id] = nil
	return a, b, c, d
end

local function KaynakBilgi(ply)
	for _, v in pairs(E._Kaynak) do
		if v.kaynak == ply then return v end
	end
	return nil
end

function E.VergiHesap(miktar, vergisiz)
	if vergisiz then return 0 end
	return math.floor(math.max(0, miktar) * (E.Ayar.vergi or 0.05) + 0.5)
end

function E.Kazandir(ply, miktar, kaynak, ops)
	if not IsValid(ply) then return false, "jugador" end
	local char = E.Char(ply)
	if not char then return false, "personaje" end
	miktar = math.floor(tonumber(miktar) or 0)
	if miktar <= 0 then return false, "monto" end
	ops = ops or {}
	local sid = E.Sid64(ply)
	local kalan = ops.vergisiz and miktar or (miktar - E.VergiHesap(miktar, false))
	local vergi = miktar - kalan

	local yeniPara = not ops.p2p and kaynak ~= "p2p"
	if yeniPara then
		local kalanTavan = E.KalanTavan(ply)
		if kalanTavan <= 0 then
			if ops.ertele then
				local a = E.AlacakYukle()
				a[sid] = a[sid] or {}
				a[sid][#a[sid] + 1] = {miktar = kalan, kaynak = kaynak, t = os.time()}
				E.AlacakKaydet()
				if E.Bildir then E.Bildir(ply, "Límite diario alcanzado: " .. kalan .. " galeones irán al banco mañana.", "uyari") end
				return true, "ertelendi"
			end
			if E.Bildir then E.Bildir(ply, "Has alcanzado el límite diario de galeones nuevos (" .. (E.Ayar.tavan or 25) .. " G).", "uyari") end
			return false, "tavan"
		end
		if kalan > kalanTavan then
			kalan = kalanTavan
			miktar = kalan + vergi
		end
		E.TavanEkle(sid, kalan)
	end

	if vergi > 0 then E.HazineEkle(vergi, "Impuesto: " .. tostring(kaynak), ply:Name()) end

	if ops.ertele and not yeniPara then
		E.BankaVer(char, kalan)
	else
		char:GiveMoney(kalan)
	end

	E.KayitEkle(sid, kaynak, "giris", kalan, yeniPara and kalan or 0, ops.aciklama or kaynak)
	return true, kalan
end

function E.Harca(ply, miktar, kaynak, ops)
	if not IsValid(ply) then return false end
	local char = E.Char(ply)
	if not char then return false end
	miktar = math.floor(tonumber(miktar) or 0)
	if miktar <= 0 then return false end
	ops = ops or {}
	if E.Cep(char) < miktar then
		if E.Bildir then E.Bildir(ply, "No tienes suficientes galeones en el bolsillo.", "uyari") end
		return false
	end
	char:TakeMoney(miktar)
	if ops.hazineye then E.HazineEkle(miktar, ops.aciklama or kaynak, ply:Name()) end
	E.KayitEkle(E.Sid64(ply), kaynak, "cikis", miktar, 0, ops.aciklama or kaynak)
	return true
end

function E.Aktar(gonderen, alan, miktar, tur)
	if not IsValid(gonderen) or not IsValid(alan) then return false end
	local cg, ca = E.Char(gonderen), E.Char(alan)
	if not cg or not ca then return false end
	miktar = math.floor(tonumber(miktar) or 0)
	if miktar <= 0 then return false end
	local vergi = E.VergiHesap(miktar, false)
	local net = miktar - vergi
	if E.Cep(cg) < miktar then
		if E.Bildir then E.Bildir(gonderen, "No tienes suficientes galeones.", "uyari") end
		return false
	end
	cg:TakeMoney(miktar)
	ca:GiveMoney(net)
	if vergi > 0 then E.HazineEkle(vergi, "Transferencia P2P (" .. tostring(tur) .. ")", gonderen:Name()) end
	E.KayitEkle(E.Sid64(gonderen), tur or "p2p", "cikis", miktar, 0, "→ " .. alan:Name())
	E.KayitEkle(E.Sid64(alan), tur or "p2p", "giris", net, 0, "← " .. gonderen:Name())
	return true
end

function E.AlacakIsle(ply)
	local sid = E.Sid64(ply)
	if not sid then return end
	local char = E.Char(ply)
	if not char or not char.SetBankBalance then
		return
	end
	local a = E.AlacakYukle()
	local liste = a[sid]
	if not liste or #liste == 0 then return end
	local toplam = 0
	for _, r in ipairs(liste) do toplam = toplam + math.floor(r.miktar or 0) end
	if toplam > 0 then
		E.BankaVer(char, toplam)
		if E.Bildir then E.Bildir(ply, "+" .. toplam .. " galeones pendientes ingresaron en tu cuenta bancaria.", "basari") end
	end
	a[sid] = nil
	E.AlacakKaydet()
end

local function BaslangicPara(char)
	if char:GetData("ekoBaslangic") then return end
	local miktar = E.OgrenciMi(char) and (E.Ayar.baslangicOgrenci or 20) or (E.Ayar.baslangicYetiskin or 10)
	if miktar > 0 then char:GiveMoney(miktar) end
	char:SetData("ekoBaslangic", true)
	E.KayitEkle(char:GetPlayer() and E.Sid64(char:GetPlayer()) or "?", "baslangic", "giris", miktar, miktar, "Inicio")
end

hook.Add("PlayerLoadedCharacter", "SardonEkonomi.Baslangic", function(ply, char)
	timer.Simple(0.5, function()
		if not IsValid(ply) or ply:GetCharacter() ~= char then return end
		BaslangicPara(char)
		E.AlacakIsle(ply)
	end)
end)

hook.Add("PlayerDeath", "SardonEkonomi.Olum", function(victim)
	local char = E.Char(victim)
	if not char then return end
	local muaf = E.Ayar.olumMuafSeviye or 10
	local lvl = E.Seviye(char)
	if lvl == nil or lvl < muaf then return end
	local cep = E.Cep(char)
	local kayip = math.floor(cep * (E.Ayar.olumOran or 0.25))
	if kayip <= 0 then return end
	char:TakeMoney(kayip)
	if E.Bildir then E.Bildir(victim, "Perdiste " .. kayip .. " galeones al morir (" .. math.floor((E.Ayar.olumOran or 0.25) * 100) .. "% del bolsillo).", "uyari") end
	E.KayitEkle(E.Sid64(victim), "olum", "cikis", kayip, 0, "Muerte")
end)

timer.Create("SardonEkonomi.GunDegis", 60, 0, function()
	local gun = E.GunAnahtari()
	if E._SonGun == gun then return end
	E._SonGun = gun
	for _, ply in ipairs(player.GetHumans()) do
		E.AlacakIsle(ply)
	end
end)

E.AyarYukle()
E._SonGun = E.GunAnahtari()