-- Servidor :: Shine Admin (cl_7yonetim)
if not SERVER then return end

local SG = SardonGacha
if not SG then return end

local function AlanOk(alan)
	return alan == "adak" or alan == "bilet" or alan == "toz"
end

local function PaketBirlestir(base, extra)
	for k, v in pairs(extra or {}) do base[k] = v end
	return base
end

local function YonetimGonder(ply, tbl)
	if not IsValid(ply) then return end
	net.Start("SardonGacha.YonetimVeri")
	SG.Yaz(tbl)
	net.Send(ply)
end

local function YeniAfisId()
	return "afis_" .. os.time() .. "_" .. math.random(1000, 9999)
end

local function OyuncuOzet(sid, plyEnLinea)
	local v = SG.OyuncuYukle(sid)
	if not v then return nil end
	local pk = v.p and v.p.etkinlik or { p5 = 0, g5 = 0 }
	local kol = 0
	if v.k then for _ in pairs(v.k) do kol = kol + 1 end end
	local ad = plyEnLinea and IsValid(plyEnLinea) and plyEnLinea:Nick() or sid
	return {
		sid = sid,
		ad = ad,
		adak = v.adak or 0,
		bilet = v.bilet or 0,
		toz = v.toz or 0,
		p5 = (pk.p5 or 0),
		g5 = pk.g5 or 0,
		p4 = (pk.p4 or 0),
		toplam = v.toplam or 0,
		kol = kol,
		kazanilan = v.kazanilan or 0,
		gecmis = v.gecmis or {},
	}
end

local function DurumPaketi(seciliSid)
	local paket = {
		afisler = SG.Afisler or {},
		ayar = SG.Ayar,
		oyuncular = {},
		ist = SG.IstYukle(),
		kayit = SG.KayitYukle(),
	}
	for _, ply in ipairs(player.GetAll()) do
		local sid = SG.Sid64(ply)
		local o = OyuncuOzet(sid, ply)
		if o then paket.oyuncular[#paket.oyuncular + 1] = o end
	end
	table.sort(paket.oyuncular, function(a, b) return a.ad:lower() < b.ad:lower() end)
	if seciliSid then
		paket.arama = OyuncuOzet(seciliSid, PlyPorSid(seciliSid))
	end
	return paket
end

local function PlyPorSid(sid)
	for _, p in ipairs(player.GetAll()) do
		if SG.Sid64(p) == sid then return p end
	end
	return nil
end

net.Receive("SardonGacha.Yonetim", function(_, ply)
	if not SG.Yonetici(ply) then
		return SG.BildirimGonder(ply, "No tienes permiso de administración del gacha.", "hata")
	end

	local islem = net.ReadString()
	local arg = SG.OkuNet() or {}

	if islem == "durum" then
		YonetimGonder(ply, DurumPaketi())
		return
	end

	if islem == "ayar" then
		if istable(arg) then
			for k, v in pairs(arg) do
				if SG.AyarVarsayilan[k] ~= nil then SG.Ayar[k] = v end
			end
			SG.AyarKaydet()
		end
		YonetimGonder(ply, PaketBirlestir(DurumPaketi(), { ileti = "Economía guardada." }))
		return
	end

	if islem == "afis.kaydet" then
		if not istable(arg) then
			return YonetimGonder(ply, { ileti = "Datos del póster no válidos." })
		end
		if not arg.id or arg.id == "" then arg.id = YeniAfisId() end
		arg.havuz = istable(arg.havuz) and arg.havuz or {}
		local found = false
		for i, a in ipairs(SG.Afisler) do
			if a.id == arg.id then
				SG.Afisler[i] = arg
				found = true
				break
			end
		end
		if not found then SG.Afisler[#SG.Afisler + 1] = arg end
		SG.AfislerKaydet()
		YonetimGonder(ply, PaketBirlestir(DurumPaketi(), { ileti = "Póster guardado.", secili = arg.id }))
		return
	end

	if islem == "afis.sil" then
		local id = tostring(arg.id or "")
		for i, a in ipairs(SG.Afisler) do
			if a.id == id then
				table.remove(SG.Afisler, i)
				break
			end
		end
		SG.AfislerKaydet()
		YonetimGonder(ply, PaketBirlestir(DurumPaketi(), { ileti = "Póster eliminado." }))
		return
	end

	if islem == "cuzdan" then
		local sid = tostring(arg.sid or "")
		local alan = tostring(arg.alan or "")
		local miktar = math.floor(tonumber(arg.miktar) or 0)
		local sebep = tostring(arg.sebep or "Admin")
		if sid == "" or not AlanOk(alan) or miktar == 0 then
			return YonetimGonder(ply, { ileti = "Parámetros de monedero no válidos." })
		end
		local hedef = PlyPorSid(sid)
		local v = SG.OyuncuYukle(sid)
		if not v then return YonetimGonder(ply, { ileti = "Cuenta no encontrada." }) end
		if miktar > 0 then
			v[alan] = (v[alan] or 0) + miktar
		else
			local n = v[alan] or 0
			if n + miktar < 0 then
				return YonetimGonder(ply, { ileti = "El jugador no tiene tanto saldo." })
			end
			v[alan] = n + miktar
		end
		SG.KayitEkle(sid, alan, miktar, v[alan], sebep)
		SG.OyuncuKaydet(sid)
		if IsValid(hedef) then SG.DurumGonder(hedef) end
		YonetimGonder(ply, PaketBirlestir(DurumPaketi(sid), { ileti = "Monedero actualizado." }))
		return
	end

	if islem == "ara" then
		local sid = tostring(arg.sid or "")
		YonetimGonder(ply, DurumPaketi(sid))
		return
	end

	if islem == "pity.sifirla" then
		local sid = tostring(arg.sid or "")
		local v = SG.OyuncuYukle(sid)
		if not v then return YonetimGonder(ply, { ileti = "Cuenta no encontrada." }) end
		v.p = v.p or {}
		for _, pk in ipairs({ "standart", "etkinlik" }) do
			v.p[pk] = { p5 = 0, p4 = 0, g5 = 0, g4 = 0 }
		end
		SG.OyuncuKaydet(sid)
		local hedef = PlyPorSid(sid)
		if IsValid(hedef) then SG.DurumGonder(hedef) end
		YonetimGonder(ply, PaketBirlestir(DurumPaketi(sid), { ileti = "Pity reiniciado." }))
		return
	end

	YonetimGonder(ply, { ileti = "Operación desconocida: " .. tostring(islem) })
end)

local function ChatAdmin(ply, args, usage)
	if not SG.Yonetici(ply) then
		if IsValid(ply) then ply:ChatPrint("Sin permiso.") end
		return
	end
	local t = string.Explode(" ", args or "")
	local hedef = player.GetBySteamID64(t[1]) or nil
	for _, p in ipairs(player.GetAll()) do
		if p:Nick():lower():find((t[1] or ""):lower(), 1, true) then hedef = p break end
	end
	if not IsValid(hedef) then
		ply:ChatPrint(usage)
		return
	end
	return hedef, math.floor(tonumber(t[2]) or 0), table.concat(t, " ", 3)
end

concommand.Add("sardon_gacha_adakver", function(ply, _, args)
	local hedef, n, sebep = ChatAdmin(ply, args, "Uso: sardon_gacha_adakver <jugador> <cantidad> [motivo]")
	if not hedef or n == 0 then return end
	local ok, msg = SG.CuzdanEkle(hedef, "adak", n, sebep or "Admin", false)
	if IsValid(ply) then ply:ChatPrint(ok and "Hecho." or tostring(msg)) end
end)

concommand.Add("sardon_gacha_biletver", function(ply, _, args)
	local hedef, n, sebep = ChatAdmin(ply, args, "Uso: sardon_gacha_biletver <jugador> <cantidad> [motivo]")
	if not hedef or n == 0 then return end
	SG.CuzdanEkle(hedef, "bilet", n, sebep or "Admin", false)
	if IsValid(ply) then ply:ChatPrint("Hecho.") end
end)

concommand.Add("sardon_gacha_tozver", function(ply, _, args)
	local hedef, n, sebep = ChatAdmin(ply, args, "Uso: sardon_gacha_tozver <jugador> <cantidad> [motivo]")
	if not hedef or n == 0 then return end
	SG.CuzdanEkle(hedef, "toz", n, sebep or "Admin", false)
	if IsValid(ply) then ply:ChatPrint("Hecho.") end
end)