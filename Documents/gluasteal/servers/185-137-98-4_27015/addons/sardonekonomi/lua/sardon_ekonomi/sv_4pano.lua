-- Servidor :: panel de encargos (diario/semanal)
if not SERVER then return end

local E = SardonEkonomi
if not E then return end

function E.PanoYukle()
	E._Pano = E._Pano or E.OkuJSON(E.DATA .. "/pano.json", {}) or {}
	return E._Pano
end

function E.PanoKaydet()
	E.YazJSON(E.DATA .. "/pano.json", E.PanoYukle())
end

local function HaftaAnahtari()
	return os.date("!%Y-W%V", os.time() + (E.SaatDilimi - E.SifirlamaSaati) * 3600)
end

local function RastgeleKalem(havuz, n)
	local kalemler = {}
	local kullanildi = {}
	for i = 1, n do
		if #havuz == 0 then break end
		local m = havuz[math.random(#havuz)]
		kalemler[#kalemler + 1] = {
			id = m.id, ad = m.ad or E.EsyaAd(m.id), adet = (m.n or 3) * math.random(1, 2),
		}
	end
	return kalemler
end

function E.PanoOyuncu(sid)
	sid = tostring(sid or "")
	local p = E.PanoYukle()
	local gun = E.GunAnahtari()
	local hafta = HaftaAnahtari()
	local r = p[sid]
	if not r or r.gun ~= gun then
		local havuz = E.PanoIsSablonlari()
		local yeniGun = not r or r.gun ~= gun
		r = r or {}
		if yeniGun then r.degisti = {} end
		r.gun = gun
		r.hafta = hafta
		r.isler = {}
		for i = 1, E.PanoGunlukIs do
			r.isler[#r.isler + 1] = {
				slot = i, haftalik = false, durum = 0, degisti = 0,
				odul = math.random(4, 9),
				kalemler = RastgeleKalem(havuz, math.random(1, 2)),
			}
		end
		if r.hafta ~= hafta or not r.haftalik then
			r.hafta = hafta
			r.haftalik = {
				slot = 10, haftalik = true, durum = 0, degisti = 1,
				odul = math.random(12, 20),
				kalemler = RastgeleKalem(havuz, math.random(2, 3)),
			}
		end
		p[sid] = r
		E.PanoKaydet()
	end
	return r
end

function E.PanoVeri(ply)
	local char = E.Char(ply)
	if not char then return nil end
	local sid = E.Sid64(ply)
	local r = E.PanoOyuncu(sid)
	local isler = {}
	for _, is in ipairs(r.isler or {}) do
		local kalemler = {}
		for _, k in ipairs(is.kalemler or {}) do
			kalemler[#kalemler + 1] = {
				id = k.id, ad = k.ad, adet = k.adet, elde = E.EnvanterEsya(char, k.id),
			}
		end
		isler[#isler + 1] = {
			slot = is.slot, haftalik = false, durum = is.durum or 0, degisti = is.degisti or 0,
			odul = is.odul, kalemler = kalemler,
		}
	end
	if r.haftalik then
		local is = r.haftalik
		local kalemler = {}
		for _, k in ipairs(is.kalemler or {}) do
			kalemler[#kalemler + 1] = {
				id = k.id, ad = k.ad, adet = k.adet, elde = E.EnvanterEsya(char, k.id),
			}
		end
		isler[#isler + 1] = {
			slot = is.slot, haftalik = true, durum = is.durum or 0, degisti = 1,
			odul = is.odul, kalemler = kalemler,
		}
	end
	local haftaBit = E.SonrakiSifirlama() - os.time() + 6 * 86400
	return {
		kazanc = E.BugunKazanilan(sid),
		tavan = E.Ayar.tavan or 25,
		sifirlama = E.SonrakiSifirlama() - os.time(),
		haftaSonu = haftaBit,
		isler = isler,
	}
end

function E.PanoTeslim(ply, slot)
	local sid = E.Sid64(ply)
	local char = E.Char(ply)
	if not char then return end
	local r = E.PanoOyuncu(sid)
	local is
	if slot == 10 and r.haftalik then is = r.haftalik
	else
		for _, x in ipairs(r.isler or {}) do if x.slot == slot then is = x break end end
	end
	if not is or is.durum == 1 then
		E.Bildir(ply, "Encargo no válido o ya entregado.", "uyari")
		return
	end
	for _, k in ipairs(is.kalemler or {}) do
		if E.EnvanterEsya(char, k.id) < k.adet then
			E.Bildir(ply, "Te faltan materiales.", "uyari")
			return
		end
	end
	for _, k in ipairs(is.kalemler or {}) do E.EsyaDus(char, k.id, k.adet) end
	is.durum = 1
	E.PanoKaydet()
	local odul = is.odul or 5
	local ok = E.Kazandir(ply, odul, "pano", {ertele = true, aciklama = "Panel encargo"})
	if not ok then
		E.Bildir(ply, "Recompensa pendiente (límite diario).", "uyari")
	end
	E.Bildir(ply, "Encargo entregado: +" .. odul .. " galeones.", "basari")
	if IsValid(ply._EkoEnt) then E.PencereGonder(ply, "pano", ply._EkoEnt) end
end

function E.PanoDegistir(ply, slot)
	local sid = E.Sid64(ply)
	local r = E.PanoOyuncu(sid)
	for _, is in ipairs(r.isler or {}) do
		if is.slot == slot then
			if is.degisti == 1 or is.durum == 1 then
				E.Bildir(ply, "No puedes cambiar este encargo.", "uyari")
				return
			end
			is.degisti = 1
			is.kalemler = RastgeleKalem(E.PanoIsSablonlari(), math.random(1, 2))
			is.odul = math.random(4, 9)
			E.PanoKaydet()
			E.Bildir(ply, "Encargo diario sustituido.", "basari")
			if IsValid(ply._EkoEnt) then E.PencereGonder(ply, "pano", ply._EkoEnt) end
			return
		end
	end
end