-- Servidor :: mesa Gringotts (takas + emanet)
if not SERVER then return end

local E = SardonEkonomi
if not E then return end

E.Masa = E.Masa or {}
local M = E.Masa
M.Yan = M.Yan or {}
M.Oturum = M.Oturum or {}
M.Emanet = M.Emanet or {}
M._SozNo = M._SozNo or 0

local INCELEME = 6

function E.EmanetYukle()
	M._EmanetFile = M._EmanetFile or E.OkuJSON(E.DATA .. "/emanet.json", {}) or {}
	return M._EmanetFile
end

function E.EmanetKaydet()
	E.YazJSON(E.DATA .. "/emanet.json", E.EmanetYukle())
end

local function GonderMasa(ply, v)
	if not IsValid(ply) then return end
	net.Start("SardonEko.MasaDurum")
	net.WriteTable(v or {})
	net.Send(ply)
end

local function GorselGonder(ent, veri)
	if not IsValid(ent) then return end
	net.Start("SardonEko.MasaGorsel")
	net.WriteEntity(ent)
	net.WriteTable(veri or {})
	net.Broadcast()
end

local function MakbuzVer(ply, data)
	local char = E.Char(ply)
	if not char then return end
	local inv = char:GetInventory()
	if not inv then return end
	inv:Add("ekonomi_makbuz", 1, data)
end

local function DurumTablosu(ply, ent)
	local char = E.Char(ply)
	local ot = M.Oturum[ent]
	local yan = M.Yan[ply]
	local v = {
		oran = math.floor((E.MasaOran or 0.03) * 100 + 0.5),
		harc = E.MasaHarc or 3,
		sozlesmeSiniri = E.SozlesmeSiniri or 3,
		cep = E.Cep(char),
		hesap = E.Banka(char),
		bana = {},
		benimSozlesme = {},
		envanter = {},
	}
	if char then
		for _, item in ipairs(char:GetInventory():GetItems()) do
			if not IsValid(item.entity) and item.uniqueID ~= "ekonomi_makbuz" then
				v.envanter[#v.envanter + 1] = {id = item.id, ad = item:GetName(), secili = false}
			end
		end
	end
	local sid = char and char:GetID() or 0
	for id, so in pairs(E.EmanetYukle()) do
		if so.hedefId == sid and so.durum == 0 then
			v.bana[#v.bana + 1] = {
				id = id, a = so.aAd, esya = so.esyaAdlar or {}, para = so.para or 0,
				karsilik = so.karsilik or 0, notu = so.notu or "", kalan = math.max(0, (so.bitis or 0) - os.time()),
			}
		end
		if so.aId == sid then
			v.benimSozlesme[#v.benimSozlesme + 1] = {
				id = id, b = so.bAd or "?", esya = so.esyaAdlar or {}, para = so.para or 0,
				karsilik = so.karsilik or 0, durum = so.durum or 0, kalan = math.max(0, (so.bitis or 0) - os.time()),
			}
		end
	end
	if ot and yan then
		local diger = yan.taraf == "a" and ot.b or ot.a
		local ben = yan.taraf == "a" and ot.teklifA or ot.teklifB
		local o = yan.taraf == "a" and ot.teklifB or ot.teklifA
		v.karsiAd = IsValid(diger) and diger:Name() or "?"
		v.benCep, v.benHesap = ben.cep or 0, ben.hesap or 0
		v.onunPara = (o.cep or 0) + (o.hesap or 0)
		v.benOnay, v.oOnay = ben.onay, o.onay
		v.inceleme = ot.kilit and (ot.kilitBit - CurTime()) or nil
		for _, e in ipairs(v.envanter) do e.secili = ben.esya[e.id] or false end
		v.onunEsya = {}
		for id in pairs(o.esya or {}) do
			local it = ix.item.instances[id]
			if it then v.onunEsya[#v.onunEsya + 1] = it:GetName() end
		end
	end
	return v
end

function M.Kullan(ent, ply)
	if not IsValid(ent) or not IsValid(ply) then return end
	if ply:GetPos():Distance(ent:GetPos()) > 180 then
		E.Bildir(ply, "Demasiado lejos.", "uyari")
		return
	end
	local ot = M.Oturum[ent]
	if not ot then
		ot = {ent = ent, teklifA = {esya = {}, cep = 0, hesap = 0, onay = false}, teklifB = {esya = {}, cep = 0, hesap = 0, onay = false}}
		M.Oturum[ent] = ot
	end
	if M.Yan[ply] then
		GonderMasa(ply, DurumTablosu(ply, ent))
		return
	end
	local taraf
	if not IsValid(ot.a) then ot.a, taraf = ply, "a"
	elseif not IsValid(ot.b) then ot.b, taraf = ply, "b"
	else
		E.Bildir(ply, "La mesa está llena.", "uyari")
		return
	end
	M.Yan[ply] = {ent = ent, taraf = taraf}
	ent:SetNWString("Durum", "selam")
	if ent.GobAnim then ent:GobAnim("selam") end
	GonderMasa(ply, DurumTablosu(ply, ent))
	if IsValid(ot.a) and IsValid(ot.b) then
		GonderMasa(ot.a, DurumTablosu(ot.a, ent))
		GonderMasa(ot.b, DurumTablosu(ot.b, ent))
	end
end

function M.Kalk(ply, sebep)
	local yan = M.Yan[ply]
	if not yan then return end
	local ent = yan.ent
	local ot = ent and M.Oturum[ent]
	M.Yan[ply] = nil
	if ot then
		if ot.a == ply then ot.a = nil elseif ot.b == ply then ot.b = nil end
		if not IsValid(ot.a) and not IsValid(ot.b) then M.Oturum[ent] = nil end
	end
	GonderMasa(ply, {kapat = true})
	if sebep then E.Bildir(ply, sebep, "bilgi") end
end

local function OturumGuncelle(ent)
	local ot = M.Oturum[ent]
	if not ot then return end
	if IsValid(ot.a) then GonderMasa(ot.a, DurumTablosu(ot.a, ent)) end
	if IsValid(ot.b) then GonderMasa(ot.b, DurumTablosu(ot.b, ent)) end
end

local function TamamlaTakas(ent)
	local ot = M.Oturum[ent]
	if not ot or not IsValid(ot.a) or not IsValid(ot.b) then return end
	local ca, cb = E.Char(ot.a), E.Char(ot.b)
	local ta, tb = ot.teklifA, ot.teklifB
	if not ca or not cb then return end
	local function Cek(ply, char, t)
		if (t.cep or 0) > E.Cep(char) or (t.hesap or 0) > E.Banka(char) then return false end
		if t.cep and t.cep > 0 then char:TakeMoney(t.cep) end
		if t.hesap and t.hesap > 0 and char.SetBankBalance then char:SetBankBalance(E.Banka(char) - t.hesap) end
		return true
	end
	if not Cek(ot.a, ca, ta) or not Cek(ot.b, cb, tb) then
		E.Bildir(ot.a, "Fondos insuficientes.", "uyari")
		E.Bildir(ot.b, "Fondos insuficientes.", "uyari")
		return
	end
	local function Ver(char, miktar)
		miktar = math.floor(miktar or 0)
		if miktar <= 0 then return end
		local noter = math.floor(miktar * (E.MasaOran or 0.03))
		local net = miktar - noter
		if noter > 0 then E.HazineEkle(noter, "Notario Gringotts", char:GetPlayer():Name()) end
		if char.SetBankBalance then E.BankaVer(char, net) else char:GiveMoney(net) end
	end
	Ver(cb, (ta.cep or 0) + (ta.hesap or 0))
	Ver(ca, (tb.cep or 0) + (tb.hesap or 0))
	for id in pairs(ta.esya or {}) do
		local it = ix.item.instances[id]
		if it then it:Transfer(cb:GetInventory():GetID()) end
	end
	for id in pairs(tb.esya or {}) do
		local it = ix.item.instances[id]
		if it then it:Transfer(ca:GetInventory():GetID()) end
	end
	M._SozNo = M._SozNo + 1
	local no = os.date("%Y%m%d") .. "-" .. M._SozNo
	local mk = {
		no = no, tarih = os.time(), a = ca:GetName(), b = cb:GetName(),
		aKalem = {}, bKalem = {}, aPara = (ta.cep or 0) + (ta.hesap or 0), bPara = (tb.cep or 0) + (tb.hesap or 0),
		ucret = math.floor(((ta.cep or 0) + (ta.hesap or 0) + (tb.cep or 0) + (tb.hesap or 0)) * (E.MasaOran or 0.03)),
		tur = "takas",
	}
	for id in pairs(ta.esya or {}) do local it = ix.item.instances[id] if it then mk.aKalem[#mk.aKalem + 1] = it:GetName() end end
	for id in pairs(tb.esya or {}) do local it = ix.item.instances[id] if it then mk.bKalem[#mk.bKalem + 1] = it:GetName() end end
	MakbuzVer(ot.a, mk)
	MakbuzVer(ot.b, mk)
	ot.teklifA, ot.teklifB = {esya = {}, cep = 0, hesap = 0, onay = false}, {esya = {}, cep = 0, hesap = 0, onay = false}
	ot.kilit = false
	ent:SetNWString("Durum", "muhur")
	if ent.GobAnim then ent:GobAnim("muhur") end
	GorselGonder(ent, {})
	E.Bildir(ot.a, "Intercambio sellado por el notario.", "basari")
	E.Bildir(ot.b, "Intercambio sellado por el notario.", "basari")
	OturumGuncelle(ent)
end

local CD = {}

net.Receive("SardonEko.Masa", function(_, ply)
	local sid = E.Sid64(ply)
	CD[sid] = CD[sid] or 0
	if CD[sid] > CurTime() then return end
	CD[sid] = CurTime() + 0.3
	local islem = net.ReadString()
	local arg = net.ReadTable() or {}
	local yan = M.Yan[ply]
	local ent = yan and yan.ent

	if islem == "kalk" then M.Kalk(ply) return end

	if islem == "emanet_kabul" or islem == "emanet_geri" or islem == "emanet_ver" then
		-- emanet (simplificado pero funcional)
		local em = E.EmanetYukle()
		if islem == "emanet_kabul" then
			local so = em[arg.id]
			local char = E.Char(ply)
			if not so or not char or so.hedefId ~= char:GetID() then return end
			local karsilik = so.karsilik or 0
			if E.Banka(char) + E.Cep(char) < karsilik then
				E.Bildir(ply, "No puedes pagar la contraprestación.", "uyari")
				return
			end
			if E.Banka(char) >= karsilik then
				char:SetBankBalance(E.Banka(char) - karsilik)
			else
				local rest = karsilik - E.Banka(char)
				char:SetBankBalance(0)
				char:TakeMoney(rest)
			end
			for _, snap in ipairs(so.esyalar or {}) do char:GetInventory():Add(snap.uid, 1, snap.data) end
			if (so.para or 0) > 0 and char.SetBankBalance then E.BankaVer(char, so.para) end
			so.durum = 1
			E.EmanetKaydet()
			E.Bildir(ply, "Contrato de depósito aceptado.", "basari")
		elseif islem == "emanet_geri" then
			local so = em[arg.id]
			local char = E.Char(ply)
			if not so or not char or so.aId ~= char:GetID() then return end
			for _, snap in ipairs(so.esyalar or {}) do char:GetInventory():Add(snap.uid, 1, snap.data) end
			if (so.para or 0) > 0 then
				if char.SetBankBalance then E.BankaVer(char, so.para) else char:GiveMoney(so.para) end
			end
			em[arg.id] = nil
			E.EmanetKaydet()
			E.Bildir(ply, "Contrato recuperado.", "basari")
		elseif islem == "emanet_ver" then
			local char = E.Char(ply)
			if not char then return end
			if not E.Harca(ply, E.MasaHarc or 3, "emanet_harc", {hazineye = true, aciklama = "Tasa depósito"}) then return end
			local hedefAd = tostring(arg.hedef or "")
			local hedefChar
			for _, p in ipairs(player.GetAll()) do
				local c = E.Char(p)
				if c and string.find(string.lower(c:GetName()), string.lower(hedefAd), 1, true) then hedefChar = c break end
			end
			if not hedefChar then
				E.Bildir(ply, "Personaje destinatario no encontrado (debe estar conectado).", "uyari")
				return
			end
			local esyalar, adlar = {}, {}
			for _, id in ipairs(arg.esyalar or {}) do
				local it = ix.item.instances[tonumber(id)]
				if it and it:GetInventory() == char:GetInventory() then
					esyalar[#esyalar + 1] = {uid = it.uniqueID, data = it.data}
					adlar[#adlar + 1] = it:GetName()
					it:Remove()
				end
			end
			local cep, hesap = math.floor(arg.cep or 0), math.floor(arg.hesap or 0)
			if cep > 0 then char:TakeMoney(cep) end
			if hesap > 0 and char.SetBankBalance then char:SetBankBalance(E.Banka(char) - hesap) end
			M._SozNo = M._SozNo + 1
			local id = "soz_" .. os.time() .. "_" .. M._SozNo
			em[id] = {
				aId = char:GetID(), aAd = char:GetName(), bAd = hedefChar:GetName(), hedefId = hedefChar:GetID(),
				esyalar = esyalar, esyaAdlar = adlar, para = cep + hesap, karsilik = math.floor(arg.karsilik or 0),
				notu = tostring(arg.notu or ""), durum = 0, bitis = os.time() + 72 * 3600,
			}
			E.EmanetKaydet()
			E.Bildir(ply, "Contrato de depósito registrado.", "basari")
		end
		if IsValid(ent) then GonderMasa(ply, DurumTablosu(ply, ent)) else GonderMasa(ply, DurumTablosu(ply, nil)) end
		return
	end

	if not yan or not IsValid(ent) then return end
	local ot = M.Oturum[ent]
	if not ot then return end
	local ben = yan.taraf == "a" and ot.teklifA or ot.teklifB
	local o = yan.taraf == "a" and ot.teklifB or ot.teklifA

	if islem == "esya" then
		if ot.kilit then return end
		local id = tonumber(arg.id)
		if arg.ekle then ben.esya[id] = true else ben.esya[id] = nil end
		ben.onay, o.onay = false, false
	elseif islem == "para" then
		if ot.kilit then return end
		ben.cep = math.max(0, math.floor(arg.cep or 0))
		ben.hesap = math.max(0, math.floor(arg.hesap or 0))
		ben.onay, o.onay = false, false
	elseif islem == "onay" then
		ben.onay = true
		if ben.onay and o.onay and not ot.kilit then
			ot.kilit = true
			ot.kilitBit = CurTime() + INCELEME
			ent:SetNWString("Durum", "inceler")
			if ent.GobAnim then ent:GobAnim("inceler") end
			timer.Simple(INCELEME, function()
				if not IsValid(ent) or not M.Oturum[ent] then return end
				TamamlaTakas(ent)
			end)
		end
	elseif islem == "iptal" then
		ot.kilit = false
		ben.onay, o.onay = false, false
		ent:SetNWString("Durum", "bekler")
	end
	OturumGuncelle(ent)
end)

hook.Add("PlayerDisconnected", "SardonEkonomi.Masa", function(ply)
	M.Kalk(ply)
end)