-- Servidor :: intercambio seguro (/Takas)
if not SERVER then return end

local E = SardonEkonomi
if not E then return end

E.Takas = E.Takas or {}
local T = E.Takas
T.Oturumlar = T.Oturumlar or {}
T.Bekleyen = T.Bekleyen or {}

local function GonderDurum(ply, tur, tablo)
	if not IsValid(ply) then return end
	net.Start("SardonEko.TakasDurum")
	net.WriteString(tur or "")
	net.WriteTable(tablo or {})
	net.Send(ply)
end

local function Oturum(ply)
	return T.Oturumlar[ply]
end

local function Karsi(ply)
	local o = Oturum(ply)
	return o and o.karsi
end

local function EnvanterListe(char, secili)
	local liste = {}
	if not char then return liste end
	secili = secili or {}
	for _, item in ipairs(char:GetInventory():GetItems()) do
		if IsValid(item.entity) then continue end
		liste[#liste + 1] = {
			id = item.id, ad = item:GetName(), secili = secili[item.id] or false,
		}
	end
	return liste
end

local function OturumAc(a, b)
	local oturum = {
		a = a, b = b,
		oyuncular = {[a] = "a", [b] = "b"},
		teklifA = {esya = {}, para = 0, onay = false},
		teklifB = {esya = {}, para = 0, onay = false},
	}
	T.Oturumlar[a], T.Oturumlar[b] = oturum, oturum
	return oturum
end

local function TabloGonder(oturum)
	for ply, taraf in pairs(oturum.oyuncular) do
		if not IsValid(ply) then continue end
		local diger = taraf == "a" and oturum.b or oturum.a
		local ben, o = taraf == "a" and oturum.teklifA or oturum.teklifB, taraf == "a" and oturum.teklifB or oturum.teklifA
		local onunEsya = {}
		for id in pairs(o.esya or {}) do
			local it = ix.item.instances[id]
			if it then onunEsya[#onunEsya + 1] = it:GetName() end
		end
		GonderDurum(ply, "pencere", {
			karsiAd = IsValid(diger) and diger:Name() or "?",
			cep = E.Cep(E.Char(ply)),
			para = ben.para or 0,
			onunPara = o.para or 0,
			envanter = EnvanterListe(E.Char(ply), ben.esya),
			onunEsya = onunEsya,
			benOnay = ben.onay or false,
			oOnay = o.onay or false,
			vergi = math.floor((E.Ayar.vergi or 0.05) * 100 + 0.5),
		})
	end
end

local function Kapat(oturum, sebep)
	for ply in pairs(oturum.oyuncular or {}) do
		if IsValid(ply) then
			T.Oturumlar[ply] = nil
			GonderDurum(ply, "kapat", {sebep = sebep or "Intercambio cerrado."})
		end
	end
end

local function Tamamla(oturum)
	local ca, cb = E.Char(oturum.a), E.Char(oturum.b)
	if not ca or not cb then Kapat(oturum, "Error de personaje.") return end
	local ta, tb = oturum.teklifA, oturum.teklifB
	if (ta.para or 0) > E.Cep(ca) or (tb.para or 0) > E.Cep(cb) then
		Kapat(oturum, "Galeones insuficientes.")
		return
	end
	for id in pairs(ta.esya or {}) do
		local it = ix.item.instances[id]
		if not it or it:GetInventory() ~= ca:GetInventory() then Kapat(oturum, "Artículo inválido.") return end
	end
	for id in pairs(tb.esya or {}) do
		local it = ix.item.instances[id]
		if not it or it:GetInventory() ~= cb:GetInventory() then Kapat(oturum, "Artículo inválido.") return end
	end
	if ta.para and ta.para > 0 then ca:TakeMoney(ta.para) end
	if tb.para and tb.para > 0 then cb:TakeMoney(tb.para) end
	local function VergiAktar(desde, hacia, miktar)
		miktar = math.floor(tonumber(miktar) or 0)
		if miktar <= 0 then return 0 end
		local v = E.VergiHesap(miktar, false)
		hacia:GiveMoney(miktar - v)
		if v > 0 then E.HazineEkle(v, "Intercambio P2P", desde:GetPlayer():Name()) end
		return v
	end
	if ta.para and ta.para > 0 then VergiAktar(ca, cb, ta.para) end
	if tb.para and tb.para > 0 then VergiAktar(cb, ca, tb.para) end
	for id in pairs(ta.esya or {}) do
		local it = ix.item.instances[id]
		if it then it:Transfer(cb:GetInventory():GetID()) end
	end
	for id in pairs(tb.esya or {}) do
		local it = ix.item.instances[id]
		if it then it:Transfer(ca:GetInventory():GetID()) end
	end
	Kapat(oturum, "¡Intercambio completado!")
	E.Bildir(oturum.a, "Intercambio completado.", "basari")
	E.Bildir(oturum.b, "Intercambio completado.", "basari")
end

function T.Iste(ply)
	local tr = ply:GetEyeTrace()
	local hedef = tr.Entity
	if not IsValid(hedef) or not hedef:IsPlayer() or hedef == ply then
		E.Bildir(ply, "Mira a un jugador cercano.", "uyari")
		return
	end
	if ply:GetPos():Distance(hedef:GetPos()) > 200 then
		E.Bildir(ply, "Demasiado lejos.", "uyari")
		return
	end
	if Oturum(ply) or Oturum(hedef) then
		E.Bildir(ply, "Ese jugador ya está en un intercambio.", "uyari")
		return
	end
	local bid = hedef:SteamID64() .. "_" .. ply:SteamID64()
	T.Bekleyen[bid] = {kimden = ply, id = bid, t = CurTime() + 30}
	GonderDurum(hedef, "istek", {kimden = ply:Name(), id = bid})
	E.Bildir(ply, "Solicitud de intercambio enviada.", "basari")
end

local CD = {}

net.Receive("SardonEko.Takas", function(_, ply)
	local sid = E.Sid64(ply)
	CD[sid] = CD[sid] or 0
	if CD[sid] > CurTime() then return end
	CD[sid] = CurTime() + 0.25
	local islem = net.ReadString()
	local arg = net.ReadTable() or {}
	local oturum = Oturum(ply)
	if islem == "kabul" then
		local bek = T.Bekleyen[arg.id]
		if bek and IsValid(bek.kimden) and bek.kimden ~= ply then
			T.Bekleyen[arg.id] = nil
			local oturum = OturumAc(bek.kimden, ply)
			TabloGonder(oturum)
		end
		return
	end
	if islem == "red" then return end
	if not oturum then return end
	local taraf = oturum.oyuncular[ply]
	local ben = taraf == "a" and oturum.teklifA or oturum.teklifB
	if islem == "esya" then
		local id = tonumber(arg.id)
		if arg.ekle then ben.esya[id] = true else ben.esya[id] = nil end
		ben.onay, (taraf == "a" and oturum.teklifB or oturum.teklifA).onay = false, false
	elseif islem == "para" then
		ben.para = math.max(0, math.floor(tonumber(arg.miktar) or 0))
		ben.onay, (taraf == "a" and oturum.teklifB or oturum.teklifA).onay = false, false
	elseif islem == "onay" then
		ben.onay = true
		local o = taraf == "a" and oturum.teklifB or oturum.teklifA
		if ben.onay and o.onay then Tamamla(oturum) return end
	elseif islem == "iptal" then
		Kapat(oturum, "Intercambio cancelado.")
		return
	end
	TabloGonder(oturum)
end)

hook.Add("PlayerDisconnected", "SardonEkonomi.Takas", function(ply)
	local o = Oturum(ply)
	if o then Kapat(o, "Jugador desconectado.") end
end)