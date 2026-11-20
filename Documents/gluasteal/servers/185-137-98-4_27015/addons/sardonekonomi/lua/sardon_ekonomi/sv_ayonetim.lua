-- Servidor :: panel Shine Admin (economía)
if not SERVER then return end

local E = SardonEkonomi
if not E then return end

local function Zenginler()
	local lista = {}
	for _, ply in ipairs(player.GetAll()) do
		local c = E.Char(ply)
		if c then
			lista[#lista + 1] = {ad = c:GetName(), cep = E.Cep(c), banka = E.Banka(c)}
		end
	end
	table.sort(lista, function(a, b) return a.cep + a.banka > b.cep + b.banka end)
	while #lista > 10 do table.remove(lista) end
	return liste
end

local function TalepOzet()
	local t = E.TalepYukle()
	local liste = {}
	for id, r in pairs(t) do
		liste[#liste + 1] = {ad = E.EsyaAd(id), adet = r.adet or 0, oran = r.oran or 70}
	end
	table.sort(liste, function(a, b) return a.oran > b.oran end)
	return liste
end

local function GunlukArz()
	local g = E.GunlukYukle()
	local liste = {}
	local now = os.time()
	for i = 13, 0, -1 do
		local gun = E.GunAnahtari(now - i * 86400)
		local r = g[gun]
		local cep, banka = 0, 0
		if r and r.kaynaklar then
			for _, v in pairs(r.kaynaklar) do
				cep = cep + (v.giris or 0) - (v.cikis or 0)
			end
		end
		liste[#liste + 1] = {gun = gun, cep = math.max(0, cep), banka = banka}
	end
	return liste
end

local function BugunDokum()
	local gun = E.GunAnahtari()
	local g = E.GunlukYukle()
	local r = g[gun]
	local liste = {}
	if r and r.kaynaklar then
		for kaynak, v in pairs(r.kaynaklar) do
			liste[#liste + 1] = {kaynak = kaynak, hesap = "cep", giris = v.giris or 0, cikis = v.cikis or 0}
		end
	end
	return liste
end

function E.YonetimVeriOlustur()
	local t = E.TezgahYukle()
	local ilan = 0
	for _, il in pairs(t) do if il.durum == 0 then ilan = ilan + 1 end end
	local em = E.EmanetYukle()
	local soz, alacak = 0, 0
	for _ in pairs(em) do soz = soz + 1 end
	local a = E.AlacakYukle()
	for _, liste in pairs(a) do for _, r in ipairs(liste) do alacak = alacak + (r.miktar or 0) end end
	return {
		gunluk = GunlukArz(),
		bugun = BugunDokum(),
		hazine = E.HazineSaldo(),
		talep = TalepOzet(),
		zengin = Zenginler(),
		ilan = ilan,
		sozlesme = soz,
		alacak = alacak,
		ayar = E.Ayar,
	}
end

local function Gonder(ply)
	net.Start("SardonEko.Yonetim")
	net.WriteTable(E.YonetimVeriOlustur())
	net.Send(ply)
end

net.Receive("SardonEko.Yonetim", function(_, ply)
	if not IsValid(ply) or not ply:IsAdmin() then return end
	local islem = net.ReadString()
	local arg = net.ReadTable() or {}
	if islem == "yenile" then
		Gonder(ply)
	elseif islem == "ayar" and ply:IsSuperAdmin() then
		if arg.tavan then E.Ayar.tavan = math.Clamp(math.floor(arg.tavan), 1, 999) end
		if arg.vergi then E.Ayar.vergi = math.Clamp(tonumber(arg.vergi) or E.Ayar.vergi, 0, 0.5) end
		E.AyarKaydet()
		E.Bildir(ply, "Ajustes de economía guardados.", "basari")
		Gonder(ply)
	end
end)