-- Servidor :: tiradas (pity, UP 50/50, duplicados → polvo, entrega HpwRewrite)
if not SERVER then return end

local SG = SardonGacha
if not SG then return end

local function PityAnahtar(afis)
	return afis.tur == "standart" and "standart" or "etkinlik"
end

local function PityAl(v, afis)
	local pk = PityAnahtar(afis)
	v.p = v.p or {}
	v.p[pk] = v.p[pk] or { p5 = 0, p4 = 0, g5 = 0, g4 = 0 }
	return v.p[pk]
end

local function HavuzNadirlik(afis, y)
	local t = {}
	for i, e in ipairs(afis.havuz or {}) do
		if e.y == y then t[#t + 1] = { idx = i, e = e } end
	end
	if #t > 0 then return t end
	for dy = 0, 2 do
		for i, e in ipairs(afis.havuz or {}) do
			if e.y == y - dy or e.y == y + dy then t[#t + 1] = { idx = i, e = e } end
		end
		if #t > 0 then return t end
	end
	return {}
end

local function AgirlikSec(liste)
	local sum = 0
	for _, c in ipairs(liste) do sum = sum + math.max(0, tonumber(c.e.w) or 1) end
	if sum <= 0 then return liste[math.random(#liste)] end
	local r = math.random() * sum
	for _, c in ipairs(liste) do
		r = r - math.max(0, tonumber(c.e.w) or 1)
		if r <= 0 then return c end
	end
	return liste[#liste]
end

local function HavuzSec(afis, y, zorunluUp, garantiKayip)
	local tum = HavuzNadirlik(afis, y)
	if #tum == 0 then
		return nil, "El pool no tiene varitas de rareza ★" .. y .. "."
	end

	local up, normal = {}, {}
	for _, c in ipairs(tum) do
		if c.e.up and afis.tur ~= "standart" and y >= 4 then
			up[#up + 1] = c
		else
			normal[#normal + 1] = c
		end
	end

	if zorunluUp and #up > 0 then
		return AgirlikSec(up).e, nil
	end

	if afis.tur ~= "standart" and y >= 4 and #up > 0 and #normal > 0 then
		local pay = math.Clamp(tonumber(y == 5 and afis.up5 or afis.up4) or 50, 0, 100) / 100
		if math.random() < pay then return AgirlikSec(up).e, "up" end
		return AgirlikSec(normal).e, "miss"
	end

	return AgirlikSec(tum).e, nil
end

local function NadirlikTirar(afis, pity)
	local p5, p4 = pity.p5 or 0, pity.p4 or 0
	local h5 = math.max(1, math.floor(tonumber(afis.h5) or 90))
	local h4 = math.max(1, math.floor(tonumber(afis.h4) or 10))

	if p5 + 1 >= h5 then return 5 end
	if math.random() * 100 < SG.Sans5(afis, p5 + 1) then return 5 end
	if p4 + 1 >= h4 then return 4 end

	local taban = SG.TabanOranlar(afis)
	local rest = math.max(0, 100 - taban[5])
	if rest <= 0 then return 3 end
	local r = math.random() * rest
	if r < taban[4] then return 4 end
	return 3
end

local function PityGuncelle(pity, y)
	if y >= 5 then
		pity.p5 = 0
		pity.p4 = 0
	elseif y >= 4 then
		pity.p5 = (pity.p5 or 0) + 1
		pity.p4 = 0
	else
		pity.p5 = (pity.p5 or 0) + 1
		pity.p4 = (pity.p4 or 0) + 1
	end
end

function SG.TekTirada(ply, v, afis)
	local pity = PityAl(v, afis)
	local y = NadirlikTirar(afis, pity)

	local zorunluUp = false
	if y == 5 and (pity.g5 or 0) == 1 then zorunluUp = true end
	if y == 4 and (pity.g4 or 0) == 1 then zorunluUp = true end

	local e, upDurum = HavuzSec(afis, y, zorunluUp, false)
	if not e then
		return nil, "No hay varitas en el pool para esta rareza."
	end

	-- Banderas 50/50 tras elegir
	if afis.tur ~= "standart" and afis.garanti then
		if y == 5 then
			if zorunluUp or (e.up and upDurum ~= "miss") or upDurum == "up" then
				pity.g5 = 0
			elseif #HavuzNadirlik(afis, 5) > 0 then
				local hayUp = false
				for _, c in ipairs(HavuzNadirlik(afis, 5)) do if c.e.up then hayUp = true break end end
				if hayUp then pity.g5 = 1 end
			end
		elseif y == 4 then
			if zorunluUp or (e.up and upDurum ~= "miss") or upDurum == "up" then
				pity.g4 = 0
			else
				local hayUp = false
				for _, c in ipairs(HavuzNadirlik(afis, 4)) do if c.e.up then hayUp = true break end end
				if hayUp then pity.g4 = 1 end
			end
		end
	end

	PityGuncelle(pity, y)

	local skin = e.skin
	local dup = SG.EldeSunucu(ply, v, skin)
	local ay = SG.Ayar
	local toz = 0
	local yeni = false
	if dup then
		local tok = ({ [3] = "toz3", [4] = "toz4", [5] = "toz5" })[y] or "toz3"
		toz = math.max(0, math.floor(tonumber(ay[tok]) or 0))
		if toz > 0 then v.toz = (v.toz or 0) + toz end
	else
		SG.AsaVer(ply, v, skin)
		yeni = true
	end

	v.toplam = (v.toplam or 0) + 1
	SG.IstEkle(afis.id, afis.ad, y)

	local entrada = {
		y = y,
		ad = SG.AsaAd(skin, e.ad),
		afis = afis.ad or afis.id,
		yeni = yeni,
		toz = toz,
		t = os.time(),
		skin = skin,
	}
	SG.GecmisEkle(v, entrada)

	return {
		skin = skin,
		ad = entrada.ad,
		model = e.model or SG.SpellModel(skin),
		y = y,
		yeni = yeni,
		toz = toz,
		up = e.up == true and afis.tur ~= "standart",
	}, nil
end

function SG.TiradaYap(ply, afisId, adet, adakla)
	adet = math.Clamp(math.floor(tonumber(adet) or 1), 1, 10)
	if adet ~= 1 and adet ~= 10 then
		return nil, "Solo puedes desear ×1 o ×10."
	end

	local afis = SG.AfisBul(afisId)
	if not afis then return nil, "Póster no encontrado." end
	if not SG.AfisAcik(afis) then return nil, "Este póster no está abierto ahora." end
	if #(afis.havuz or {}) == 0 then return nil, "El póster no tiene varitas en el pool." end

	local v = SG.OyuncuAl(ply)
	if not v then return nil, "No se pudo cargar tu monedero." end

	local ay = SG.Ayar
	local bilet = v.bilet or 0
	local adak = v.adak or 0
	local biletFiyat = math.max(1, math.floor(tonumber(ay.biletFiyat) or 160))

	local eksik = math.max(0, adet - bilet)
	local maliyetAdak = eksik * biletFiyat

	if bilet < adet then
		if not adakla or eksik == 0 then
			return nil, "No tienes suficientes " .. (ay.biletAd or "boletos") .. "."
		end
		if adak < maliyetAdak then
			return nil, "No tienes suficiente " .. (ay.adakAd or "ofrenda") .. " para comprar los boletos."
		end
	end

	-- Cobro
	if bilet >= adet then
		v.bilet = bilet - adet
	else
		v.bilet = 0
		v.adak = adak - maliyetAdak
		if eksik > 0 then
			SG.KayitEkle(SG.Sid64(ply), "adak", -maliyetAdak, v.adak, "Canje automático por " .. eksik .. " " .. (ay.biletAd or "boleto"))
		end
	end

	local afisZ = SG.AfisHavuzZengin(afis)
	local sonuc = {}
	for i = 1, adet do
		local r, err = SG.TekTirada(ply, v, afisZ)
		if not r then
			SG.OyuncuKaydet(SG.Sid64(ply))
			return nil, err or "Error en la tirada."
		end
		sonuc[#sonuc + 1] = r
	end

	SG.OyuncuKaydet(SG.Sid64(ply))
	return sonuc, nil
end