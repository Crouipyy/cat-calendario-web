-- Servidor :: mercado de jugadores (ilan tezgâhı)
if not SERVER then return end

local E = SardonEkonomi
if not E then return end

function E.TezgahYukle()
	E._Tezgah = E._Tezgah or E.OkuJSON(E.DATA .. "/tezgah.json", {}) or {}
	return E._Tezgah
end

function E.TezgahKaydet()
	E.YazJSON(E.DATA .. "/tezgah.json", E.TezgahYukle())
end

local function IlanTemizle()
	local t = E.TezgahYukle()
	local now = os.time()
	local degisti
	for id, il in pairs(t) do
		if il.bitis and il.bitis < now and il.durum ~= 2 then
			il.durum = 2
			degisti = true
		end
	end
	if degisti then E.TezgahKaydet() end
end

timer.Create("SardonEkonomi.TezgahTemiz", 300, 0, IlanTemizle)

function E.TezgahVeri(ply)
	IlanTemizle()
	local char = E.Char(ply)
	if not char then return nil end
	local sid = E.Sid64(ply)
	local t = E.TezgahYukle()
	local pazar, benim = {}, {}
	for id, il in pairs(t) do
		if il.durum == 0 then
			local satir = {
				id = id, ad = il.ad, satici = il.saticiAd, fiyat = il.fiyat,
			}
			if il.sid ~= sid then pazar[#pazar + 1] = satir end
		end
		if il.sid == sid then
			benim[#benim + 1] = {
				id = id, ad = il.ad, fiyat = il.fiyat, durum = il.durum or 0,
				kalan = math.max(0, (il.bitis or 0) - os.time()),
			}
		end
	end
	local envanter = {}
	for _, item in ipairs(char:GetInventory():GetItems()) do
		if IsValid(item.entity) then continue end
		if item.uniqueID == "ekonomi_makbuz" then continue end
		envanter[#envanter + 1] = {id = item.id, ad = item:GetName()}
	end
	return {
		para = E.Cep(char),
		sinir = E.TezgahSinir,
		vergi = math.floor((E.Ayar.vergi or 0.05) * 100 + 0.5),
		pazar = pazar,
		benim = benim,
		envanter = envanter,
	}
end

function E.TezgahIlan(ply, itemId, fiyat)
	local char = E.Char(ply)
	if not char then return end
	fiyat = math.floor(tonumber(fiyat) or 0)
	if fiyat < 1 then
		E.Bildir(ply, "Precio no válido.", "uyari")
		return
	end
	local t = E.TezgahYukle()
	local sid = E.Sid64(ply)
	local say = 0
	for _, il in pairs(t) do if il.sid == sid and il.durum == 0 then say = say + 1 end end
	if say >= E.TezgahSinir then
		E.Bildir(ply, "Límite de anuncios alcanzado (" .. E.TezgahSinir .. ").", "uyari")
		return
	end
	local item = ix.item.instances[tonumber(itemId)]
	if not item or item:GetInventory() ~= char:GetInventory() then
		E.Bildir(ply, "El artículo debe estar en tu inventario.", "uyari")
		return
	end
	local id = "il_" .. sid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
	t[id] = {
		sid = sid, saticiAd = char:GetName(), itemUid = item.uniqueID, itemData = item.data,
		instance = item.id, ad = item:GetName(), fiyat = fiyat,
		bitis = os.time() + E.TezgahGun, durum = 0,
	}
	item:Remove()
	E.TezgahKaydet()
	E.Bildir(ply, "Anuncio publicado por " .. fiyat .. " galeones.", "basari")
	if IsValid(ply._EkoEnt) then E.PencereGonder(ply, "tezgah", ply._EkoEnt) end
end

function E.TezgahAl(ply, ilanId)
	local char = E.Char(ply)
	if not char then return end
	local t = E.TezgahYukle()
	local il = t[ilanId]
	if not il or il.durum ~= 0 then
		E.Bildir(ply, "Anuncio no disponible.", "uyari")
		return
	end
	if il.sid == E.Sid64(ply) then
		E.Bildir(ply, "No puedes comprar tu propio anuncio.", "uyari")
		return
	end
	local fiyat = il.fiyat or 0
	if E.Cep(char) < fiyat then
		E.Bildir(ply, "No tienes suficientes galeones.", "uyari")
		return
	end
	local vergi = E.VergiHesap(fiyat, false)
	local satici = player.GetBySteamID64(il.sid)
	local sChar = satici and E.Char(satici)
	E.Harca(ply, fiyat, "tezgah", {aciklama = "Compra mercado"})
	if vergi > 0 then E.HazineEkle(vergi, "Mercado jugadores", ply:Name()) end
	local net = fiyat - vergi
	if sChar and sChar.SetBankBalance then
		E.BankaVer(sChar, net)
	elseif satici then
		E.Kazandir(satici, net, "tezgah_venta", {vergisiz = true, p2p = true})
	else
		local a = E.AlacakYukle()
		a[il.sid] = a[il.sid] or {}
		a[il.sid][#a[il.sid] + 1] = {miktar = net, kaynak = "tezgah", t = os.time()}
		E.AlacakKaydet()
	end
	char:GetInventory():Add(il.itemUid, 1, il.itemData)
	il.durum = 1
	E.TezgahKaydet()
	E.Bildir(ply, "Compra realizada.", "basari")
	if IsValid(ply._EkoEnt) then E.PencereGonder(ply, "tezgah", ply._EkoEnt) end
end

function E.TezgahGeri(ply, ilanId)
	local char = E.Char(ply)
	if not char then return end
	local t = E.TezgahYukle()
	local il = t[ilanId]
	if not il or il.sid ~= E.Sid64(ply) then
		E.Bildir(ply, "Anuncio no válido.", "uyari")
		return
	end
	if il.durum ~= 0 and il.durum ~= 2 then
		E.Bildir(ply, "Este anuncio ya se vendió.", "uyari")
		return
	end
	char:GetInventory():Add(il.itemUid, 1, il.itemData)
	t[ilanId] = nil
	E.TezgahKaydet()
	E.Bildir(ply, "Artículo recuperado del mercado.", "basari")
	if IsValid(ply._EkoEnt) then E.PencereGonder(ply, "tezgah", ply._EkoEnt) end
end