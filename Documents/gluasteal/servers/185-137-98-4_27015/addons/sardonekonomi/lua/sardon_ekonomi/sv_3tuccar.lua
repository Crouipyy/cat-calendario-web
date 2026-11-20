-- Servidor :: NPC comerciantes (venta/compra, demanda)
if not SERVER then return end

local E = SardonEkonomi
if not E or not E.Tuccar then return end

local UZAK = 200

function E.EnvanterEsya(char, malId)
	local inv = char:GetInventory()
	if not inv then return 0 end
	local toplam = 0
	if string.StartWith(malId, "ingredient:") then
		local tip = malId:sub(12)
		for _, item in ipairs(inv:GetItemsByUniqueID("ingredient", false)) do
			if item:GetData("type") == tip then toplam = toplam + E.EsyaAdet(item) end
		end
		return toplam
	end
	for _, item in ipairs(inv:GetItems()) do
		if E.EsyaMalID(item) == malId or item.uniqueID == malId then
			toplam = toplam + E.EsyaAdet(item)
		end
	end
	return toplam
end

function E.EsyaDus(char, malId, adet)
	adet = math.floor(tonumber(adet) or 0)
	if adet <= 0 then return false end
	local inv = char:GetInventory()
	if not inv then return false end
	if string.StartWith(malId, "ingredient:") then
		local tip = malId:sub(12)
		for _, item in ipairs(inv:GetItemsByUniqueID("ingredient", false)) do
			if item:GetData("type") == tip then
				local c = E.EsyaAdet(item)
				if c <= adet then
					adet = adet - c
					item:Remove()
				else
					item:SetData("count", c - adet)
					adet = 0
				end
				if adet <= 0 then return true end
			end
		end
		return adet <= 0
	end
	for _, item in ipairs(inv:GetItems()) do
		if E.EsyaMalID(item) == malId or item.uniqueID == malId then
			local c = E.EsyaAdet(item)
			if item.UseUp and c >= adet then
				item:UseUp(adet)
				return true
			elseif c <= adet then
				adet = adet - c
				item:Remove()
			else
				item:SetData("count", c - adet)
				return true
			end
			if adet <= 0 then return true end
		end
	end
	return adet <= 0
end

function E.EsyaVer(char, malId, adet)
	adet = math.floor(tonumber(adet) or 0)
	if adet <= 0 then return false end
	local inv = char:GetInventory()
	if not inv then return false end
	if string.StartWith(malId, "ingredient:") then
		local tip = malId:sub(12)
		local yigin = inv:HasItem("ingredient")
		for _, item in ipairs(inv:GetItemsByUniqueID("ingredient", false)) do
			if item:GetData("type") == tip then
				yigin = item
				break
			end
		end
		if yigin and yigin:GetData("type") == tip then
			yigin:SetData("count", E.EsyaAdet(yigin) + adet)
			return true
		end
		return inv:Add("ingredient", 1, {type = tip, count = adet}) ~= false
	end
	local yigin = inv:HasItem(malId)
	if yigin then
		yigin:SetData("count", E.EsyaAdet(yigin) + adet)
		return true
	end
	local it, err = inv:Add(malId, 1)
	if it then
		it:SetData("count", adet)
		return true
	end
	return false
end

E._AvcuStok = E._AvcuStok or {}

function E.AvcuStokYukle()
	if not E._AvcuStokFile then
		E._AvcuStokFile = E.OkuJSON(E.DATA .. "/avcu_stok.json", {}) or {}
	end
	return E._AvcuStokFile
end

function E.AvcuStokKaydet()
	E.YazJSON(E.DATA .. "/avcu_stok.json", E.AvcuStokYukle())
end

local function TalepDus(malId, demet)
	local t = E.TalepYukle()
	local r = t[malId] or {oran = 70, adet = 0}
	r.adet = (r.adet or 0) + demet
	r.oran = math.max(40, (r.oran or 70) - demet * 3)
	t[malId] = r
	E.TalepKaydet()
end

function E.TuccarVeri(ply, ent)
	local tur = IsValid(ent) and ent:GetTur() or "botanik"
	local tt = E.Tuccar.Turler[tur] or E.Tuccar.Turler.botanik
	local char = E.Char(ply)
	if not char then return nil end
	local vergi = math.floor((E.Ayar.vergi or 0.05) * 100 + 0.5)
	local satirlar = {}
	for _, m in ipairs(tt.satirlar or {}) do
		local oran = E.TalepOran(m.id)
		local birim = E.TalepFiyat(m, oran)
		local elde = E.EnvanterEsya(char, m.id)
		satirlar[#satirlar + 1] = {
			id = m.id, ad = m.ad or E.EsyaAd(m.id), elde = elde, n = m.n or 3, p = birim * (m.n or 3),
			oran = oran, kademe = m.kademe or 1,
		}
	end
	local satilik, stok
	if tt.satilik then
		satilik = {}
		for _, s in ipairs(tt.satilik) do
			local durum
			if E.EnvanterEsya(char, s.id) > 0 then durum = "elde" end
			satilik[#satilik + 1] = {
				id = s.id, ad = E.EsyaAd(s.id), fiyat = s.fiyat or 10, aciklama = s.aciklama or "",
				durum = durum,
			}
		end
	end
	if tur == "avci" then
		stok = {}
		local st = E.AvcuStokYukle()
		for _, m in ipairs(tt.satirlar or {}) do
			local s = st[m.id] or 0
			if s > 0 then
				local oran = E.TalepOran(m.id)
				local fiyat = E.TalepFiyat(m, oran) * (m.n or 3)
				stok[#stok + 1] = {id = m.id, ad = m.ad, stok = s, n = m.n, fiyat = fiyat, kademe = m.kademe}
			end
		end
	end
	return {
		ad = tt.ad,
		unvan = tt.unvan,
		kazanc = E.BugunKazanilan(E.Sid64(ply)),
		tavan = E.Ayar.tavan or 25,
		vergi = vergi,
		sifirlama = E.SonrakiSifirlama() - os.time(),
		para = E.Cep(char),
		satirlar = satirlar,
		satilik = satilik,
		stok = stok,
	}
end

function E.TuccarSat(ply, malId, demet)
	local char = E.Char(ply)
	if not char then return end
	local ent = ply._EkoEnt
	local tur = IsValid(ent) and ent:GetTur() or "botanik"
	local tt = E.Tuccar.Turler[tur]
	if not tt then return end
	local mal
	for _, m in ipairs(tt.satirlar or {}) do if m.id == malId then mal = m break end end
	if not mal then
		E.Bildir(ply, "Este mercader no compra ese artículo.", "uyari")
		return
	end
	local elde = E.EnvanterEsya(char, malId)
	local paket = mal.n or 3
	if demet == 0 then demet = math.floor(elde / paket) else demet = math.floor(demet) end
	if demet <= 0 or elde < demet * paket then
		E.Bildir(ply, "No tienes suficientes unidades para vender.", "uyari")
		return
	end
	local adet = demet * paket
	local oran = E.TalepOran(malId)
	local birim = E.TalepFiyat(mal, oran)
	local brut = birim * adet
	if not E.EsyaDus(char, malId, adet) then
		E.Bildir(ply, "No se pudo retirar el artículo del inventario.", "uyari")
		return
	end
	TalepDus(malId, demet)
	if tur == "avci" then
		local st = E.AvcuStokYukle()
		st[malId] = (st[malId] or 0) + adet
		E.AvcuStokKaydet()
	end
	local ok = E.Kazandir(ply, brut, "tuccar_" .. tur, {aciklama = "Venta NPC"})
	if ok then
		E.Bildir(ply, "+" .. brut .. " galeones (impuesto descontado al Tesoro).", "basari")
	else
		E.EsyaVer(char, malId, adet)
		return
	end
	if IsValid(ent) then E.PencereGonder(ply, "tuccar", ent) end
end

function E.TuccarAl(ply, malId, demet)
	local char = E.Char(ply)
	if not char then return end
	local ent = ply._EkoEnt
	local tur = IsValid(ent) and ent:GetTur() or "botanik"
	local tt = E.Tuccar.Turler[tur]
	if not tt then return end

	-- satılık fijo (libro pesca, etc.)
	for _, s in ipairs(tt.satilik or {}) do
		if s.id == malId then
			local fiyat = s.fiyat or 10
			if E.Cep(char) < fiyat then
				E.Bildir(ply, "No tienes suficientes galeones.", "uyari")
				return
			end
			if E.EnvanterEsya(char, malId) > 0 then
				E.Bildir(ply, "Ya tienes este artículo.", "uyari")
				return
			end
			E.Harca(ply, fiyat, "tuccar_al", {hazineye = false, aciklama = "Compra NPC"})
			local vergi = E.VergiHesap(fiyat, false)
			if vergi > 0 then E.HazineEkle(vergi, "Compra NPC " .. malId, ply:Name()) end
			E.EsyaVer(char, malId, 1)
			E.Bildir(ply, "Compraste " .. E.EsyaAd(malId) .. ".", "basari")
			if IsValid(ent) then E.PencereGonder(ply, "tuccar", ent) end
			return
		end
	end

	-- stock cazador
	if tur == "avci" then
		local st = E.AvcuStokYukle()
		local mal
		for _, m in ipairs(tt.satirlar or {}) do if m.id == malId then mal = m break end end
		if not mal then return end
		local paket = mal.n or 3
		demet = math.floor(demet or 1)
		local stok = st[malId] or 0
		if stok < demet * paket then
			E.Bildir(ply, "No hay stock suficiente.", "uyari")
			return
		end
		local oran = E.TalepOran(malId)
		local fiyat = E.TalepFiyat(mal, oran) * demet * paket
		local vergi = E.VergiHesap(fiyat, false)
		local total = fiyat
		if E.Cep(char) < total then
			E.Bildir(ply, "No tienes suficientes galeones.", "uyari")
			return
		end
		E.Harca(ply, total, "tuccar_stok", {aciklama = "Compra cazador"})
		if vergi > 0 then E.HazineEkle(vergi, "Compra stock cazador", ply:Name()) end
		st[malId] = stok - demet * paket
		E.AvcuStokKaydet()
		E.EsyaVer(char, malId, demet * paket)
		E.Bildir(ply, "Compraste " .. demet .. " lote(s).", "basari")
		if IsValid(ent) then E.PencereGonder(ply, "tuccar", ent) end
	end
end

timer.Create("SardonEkonomi.TalepGece", 120, 0, function()
	if os.time() < (E._SonrakiTalep or 0) then return end
	E._SonrakiTalep = E.SonrakiSifirlama()
	local t = E.TalepYukle()
	for id, r in pairs(t) do
		r.oran = math.min(100, (r.oran or 60) + math.random(8, 18))
		r.adet = 0
	end
	E.TalepKaydet()
end)