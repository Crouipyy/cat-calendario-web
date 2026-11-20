-- Sardon Çığırtkan :: grabación del remitente
local C = SardonCigirtkan
local A = C.Ayar
local K = C.K
local I = C.I

-- MP3 mínimo válido (silencio ~0,1s, base64 recortado de clip interno)
local SILENT_MP3 = util.Base64Decode("SUQzBAAAAAAAIlRTU0UAAAAOAAADTGF2ZjYzLjEuMTAyAAAAAAAAAAAAAAD/+zjAAAAAAAAAAAAAAAAAAAAAAABJbmZvAAAADwAAAAUAAAUQAFVVVVVVVVVVVVVVVVVVVVVVVVWAgICAgICAgICAgICAgICAgICAgKqqqqqqqqqqqqqqqqqqqqqqqqqq1dXV1dXV1dXV1dXV1dXV1dXV1dX//////////////////////////wAAAABMYXZmAAAAAAAAAAAAAAAAAAAAAAAkAsAAAAAAAAAFEAwbEX0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/+zjEAAAJqHMcFPMACa8a7F8w8ABWKx5Kc43xNxxsxbzrhHIaB0MmoYQgeAwGT3ngAAEIc8npgDAafj3dxBAhHvTAGFp6jh6AAAAB2YeHn+AABgGHh4eP+AACPzD/8Ad8BWADAAQqMSAAABa7SFUhtcFhhnUa+1iAp6Anbgd+VbMY4ZDWLiLS3JVVxGNcNRWR3BRR1fHoZSdKKDHhqKSPAiM++xKrbFGntvW//TWIES987g2jZ/1b///++83vSnt9Qq1xXwfgg7ywBIgFbAAgpgASXbQIAAD/+zjEBQALqK1LWaYAAYysakMkcAEAAIhPkQEQw4iUZFAsmkZBDAPWfLm9ZVI6spuoIKDyoZiBQRFB8OQjQZcEieCpiqLq2BmlHyChpjB46lpOhPcfQW/6n29/bmfvzMzOT86+//6R24SEAphSILoMYGrS/LVD+36p/z+b56EDiC+h35A9wfkhIDwWI5o6NSJpn+JBQHjKPkx8S3EY1HOUdUdB7/4jiXOHDEGhA4aMNNFnUGxrDyf/yIliwbuNzhoXMkFfnKPHAoLkdiowa4bqNijBCTEZB6//+zjEBgALfHb+GfeAAaQU6DcxQAAxsMk6MWQDszQBgQMwy0Bpa6YFuCkvyYQIAxbLUoKw0+1W6T0tqfbF1QECLYT9ELbldteiqHQxsishK85da1MLcilUaM259N3zFloegXu/1EBkDENh4Xj8XAMAAAAF/EQWGIRBcxVfMey9zzI4lR/nLQlByinGAwUC18DMKQNQi4n8SmQcDIigBAAft5uJTJNAGyhCwN1hF/xH5NEQK5MFQP2DVQz4hMO4cn/QQZDy8mXVhIJf/YRFlzbwnMVCsxwmTHH/+zjEBQPLiFUWHc2AAYiKX0HubHHdPSJ0xErjCJTM7rA2CqBwwmQnqccRJpVhGixkZvMJpAzmrXkbFZhpSwHa5rQEahImmK4GnR0BASoRDZd0AAaj4qAAUAVipmnRl2n+r1bPTz+JQNaaYDgCBgBhumRIPCa9gh+PtHqXUYEeJ1pQmN3QblgwdbzU7IOJzI5GwDNZmDAEct2xyiEmyoCb0eJp4KG/TpzRSECxv9kcCLGmnxMbmEA5hgSYsHpwNCR5bx1ZVDU/iGyqPifMRCIwgIDRL4NpkZT/+zjEBwIKcET8DmcEQY6FXqWsmBmafwBQOGYwAjzIOUMFAWX0hJjF1B1aTI1WGWh7sHSir7TvKs1GqbMDNFBdSlq2s1L//////9Ce9zUoSpTnnGk0F1Kc84HwJWqpDb7DamT2NAoTNnxb2egKUBWzMJApRRNEbFhIkripoqWLlk2440VCi5ZNkjjRUKLlk2SONFQouWTZpxoqFjkibNOFioWOSJs04WCwsckRU0aLBYWKJEVNGixULHJgqaNF1UxBTUUzLjEwMVVVVVVVVVVVVVVVVVVVVVU=") or ""

local function Cooldown(ply)
	local t = ply:GetNW2Float("SardonCigirtkanSon", 0)
	return math.max(0, A.Bekleme - (CurTime() - t))
end

local function TieneItem(ply)
	local ch = ply:GetCharacter()
	return ch and ch:GetInventory() and ch:GetInventory():HasItem(C.ITEM)
end

local function TieneBuho(ply)
	local inv = ply:GetCharacter() and ply:GetCharacter():GetInventory()
	return inv and inv:HasItem("PetOwl")
end

function C.KayitKapat(ply, sess)
	if not sess then return end
	sess.durum = K.KAPALI
	ply:SetNWBool("SardonCigirtkanKayit", false)
	local n = math.max(0, GetGlobalInt("SardonCigirtkanKayit", 0) - 1)
	SetGlobalInt("SardonCigirtkanKayit", n)
	C.Oturumlar[ply] = nil
	C.DurumGonder(ply, sess)
end

local function FinalizarMp3(sess)
	sess.mp3 = SILENT_MP3
	sess.sure = math.max(A.EnKisa, math.min(A.EnUzun, sess.konusma or A.EnKisa))
	sess.dalga = C.DalgaUret(sess.sure)
	sess.onizleme = C.SonrakiKimlik()
	C.Sesler[sess.onizleme] = {mp3 = sess.mp3, sure = sess.sure, dalga = sess.dalga}
end

net.Receive("SardonCigirtkan.Islem", function(_, ply)
	local no = net.ReadUInt(3)
	local flag = net.ReadBool()
	local sess = C.Oturumlar[ply]
	if not sess then return end

	if no == I.BITIR then
		sess.konusma = math.max(sess.konusma or 0, CurTime() - (sess.basla or CurTime()))
		if sess.konusma < A.EnKisa then
			sess.durum = K.HATA
			sess.hata = "Grabación demasiado corta.\nMínimo " .. A.EnKisa .. " s."
			C.DurumGonder(ply, sess)
			return
		end
		sess.durum = K.ISLENIYOR
		sess.hata = ""
		C.DurumGonder(ply, sess)
		timer.Simple(0.6, function()
			if not IsValid(ply) or C.Oturumlar[ply] ~= sess then return end
			FinalizarMp3(sess)
			sess.durum = K.ONIZLEME
			C.DurumGonder(ply, sess)
		end)
	elseif no == I.YENIDEN then
		sess.basla = CurTime()
		sess.konusma = 0
		sess.durum = K.KAYIT
		sess.hata = ""
		sess.onizleme = 0
		C.DurumGonder(ply, sess)
	elseif no == I.ANONIM then
		sess.anonim = flag
		C.DurumGonder(ply, sess)
	elseif no == I.GONDER then
		if sess.durum ~= K.ONIZLEME then return end
		C.Despachar(ply, sess)
	elseif no == I.VAZGEC then
		C.KayitKapat(ply, sess)
	end
end)

timer.Create("SardonCigirtkan.KayitTick", 0.25, 0, function()
	for ply, sess in pairs(C.Oturumlar) do
		if not IsValid(ply) then
			C.Oturumlar[ply] = nil
			continue
		end
		if sess.durum ~= K.KAYIT then continue end
		local elapsed = CurTime() - (sess.basla or CurTime())
		sess.konusma = elapsed
		if elapsed >= A.EnUzun then
			net.Start("SardonCigirtkan.Islem")
			net.WriteUInt(I.BITIR, 3)
			net.WriteBool(false)
			net.Send(ply)
		elseif elapsed >= A.KayitZamanAsimi then
			C.Bildir(ply, "Tiempo de grabación agotado.")
			C.KayitKapat(ply, sess)
		else
			C.DurumGonder(ply, sess)
		end
	end
end)

-- Boğuk / grabación: globals para clientes
hook.Add("PlayerCanHearPlayersVoice", "SardonCigirtkan.Boguk", function(listener, talker)
	if not A.KayitBoguk then return end
	if talker:GetNWBool("SardonCigirtkanKayit", false) and listener ~= talker then
		return true, false
	end
end)