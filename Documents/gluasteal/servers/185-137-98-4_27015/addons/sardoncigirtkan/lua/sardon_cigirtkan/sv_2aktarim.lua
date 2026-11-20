-- Sardon Çığırtkan :: envío de MP3 por partes
local C = SardonCigirtkan
local A = C.Ayar

C.veriGonderildi = C.veriGonderildi or {}

function C.ParcaGonder(ply, id, mp3)
	if not IsValid(ply) or not isstring(mp3) or #mp3 == 0 then return end
	local boy = #mp3
	local chunk = math.max(512, A.Parca or 16000)
	local n = math.ceil(boy / chunk)
	if n > 255 then n = 255 end

	for i = 1, n do
		local bas = (i - 1) * chunk + 1
		local son = math.min(i * chunk, boy)
		local d = string.sub(mp3, bas, son)
		net.Start("SardonCigirtkan.Parca")
		net.WriteUInt(id, 32)
		net.WriteUInt(i, 8)
		net.WriteUInt(n, 8)
		net.WriteUInt(boy, 24)
		net.WriteUInt(#d, 16)
		net.WriteData(d, #d)
		net.Send(ply)
	end
end

function C.Yayin(F, pos, menzil)
	if not F then return end
	if F.yazi then
		if C.YaziYayin then C.YaziYayin(F, pos, menzil) end
		return
	end
	local id = F.sesId or F.onizleme or F.id
	local ses = C.Sesler[id] or (id and C.Sesler[F.id])
	local mp3 = ses and ses.mp3
	if not mp3 then return end

	menzil = menzil or A.Menzil
	local alicilar = {}
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then continue end
		if ply:GetPos():DistToSqr(pos) <= menzil * menzil then
			alicilar[#alicilar + 1] = ply
		end
	end

	local butce = A.TikButce or 6
	for i = 1, math.min(butce, #alicilar) do
		local ply = alicilar[i]
		local key = ply:SteamID64() .. "_" .. id
		if not C.veriGonderildi[key] then
			C.veriGonderildi[key] = true
			C.ParcaGonder(ply, id, mp3)
		end
	end
end

function C.UnutKimlik(id)
	net.Start("SardonCigirtkan.Unut")
	net.WriteUInt(id, 32)
	net.Broadcast()
	C.Sesler[id] = nil
	for k in pairs(C.veriGonderildi) do
		if string.EndsWith(k, "_" .. id) then
			C.veriGonderildi[k] = nil
		end
	end
end

function C.Bitir(F, reason)
	if not F then return end
	if F.id then C.UnutKimlik(F.id) end
	if F.sesId and F.sesId ~= F.id then C.UnutKimlik(F.sesId) end
	C.Zarflar[F.id] = nil
	C.Ucus[F.id] = nil
	C.Gunluk(reason or "fin", F)
end

function C.HedefGecerli(F)
	if not F then return false end
	if F.grup then
		for _, p in ipairs(F.grup.uyeler or {}) do
			if IsValid(p) and p:Alive() then return true end
		end
		return false
	end
	return IsValid(F.hedef) and F.hedef:Alive()
end

function C.GrupUyesi(F, ply)
	if not F or not F.grup then return false end
	for _, p in ipairs(F.grup.uyeler or {}) do
		if p == ply then return true end
	end
	return false
end

function C.KumeNoktasi(F)
	if not F or not F.grup then return nil end
	local c = Vector(0, 0, 0)
	local n = 0
	for _, p in ipairs(F.grup.uyeler or {}) do
		if IsValid(p) then
			c = c + p:GetPos()
			n = n + 1
		end
	end
	if n == 0 then return nil end
	c = c / n
	return c + Vector(0, 0, A.GrupYukseklik or 26)
end