-- Sardon Çığırtkan :: inicio, envío y buho
local C = SardonCigirtkan
local A = C.Ayar
local K = C.K

local function Cooldown(ply)
	local t = ply:GetNW2Float("SardonCigirtkanSon", 0)
	return math.max(0, A.Bekleme - (CurTime() - t))
end

local function QuitarItem(ply)
	local inv = ply:GetCharacter() and ply:GetCharacter():GetInventory()
	if not inv then return false end
	for _, item in pairs(inv:GetItemsByUniqueID(C.ITEM, true)) do
		if item:Remove() then return true end
	end
	return false
end

local function SpawnZarf(F)
	local ent = ents.Create(C.Sinif)
	if not IsValid(ent) then return end
	local hedef = F.hedef
	local pos = IsValid(hedef) and (hedef:GetPos() + Vector(0, 0, 80)) or F.dropPos or Vector(0, 0, 0)
	ent:SetPos(pos)
	ent:Spawn()
	ent:Kur(F)
	C.Zarflar[F.id] = ent
end

local function OwlFlight(ply, F)
	local owl = StPets and (StPets.DoesHave(ply, "PetOwl") or StPets.DoesHave(ply, "owl"))
	F.owl = owl
	if IsValid(owl) and IsValid(F.hedef) then
		owl:SetNWBool("SardonCigirtkan", true)
		owl:SetNWEntity("target", F.hedef)
	end

	local delay = 6
	if IsValid(owl) and IsValid(F.hedef) then
		delay = math.Clamp(owl:GetPos():Distance(F.hedef:GetPos()) / 350, 4, A.UcusZamanAsimi * 0.5)
	end

	timer.Create("SardonCigirtkan.OnYukle_" .. F.id, math.max(1, delay - 2), 1, function()
		if not F.yazi and IsValid(F.hedef) then
			C.Yayin(F, F.hedef:GetPos(), A.Menzil)
		end
	end)

	timer.Create("SardonCigirtkan.Ucus_" .. F.id, delay, 1, function()
		if C.Ucus[F.id] then
			SpawnZarf(F)
			if IsValid(owl) then
				owl:SetNWBool("SardonCigirtkan", false)
				owl:SetNWEntity("target", NULL)
			end
			C.Ucus[F.id] = nil
		end
	end)
end

function C.Despachar(ply, sess)
	if not sess then return end
	local inv = ply:GetCharacter() and ply:GetCharacter():GetInventory()
	if not inv or not inv:HasItem(C.ITEM) then
		C.Bildir(ply, "No tienes un Howler vacío.")
		return
	end
	if not QuitarItem(ply) then
		C.Bildir(ply, "No se pudo gastar el Howler.")
		return
	end

	local F = {
		id = C.SonrakiKimlik(),
		gonderen = ply,
		gonderenAd = sess.anonim and "" or (ply:GetCharacter() and ply:GetCharacter():GetName() or ply:Name()),
		hedef = sess.hedef or (sess.grup and sess.grup.uyeler and sess.grup.uyeler[1]),
		anonim = sess.anonim,
		sure = sess.sure,
		sesId = sess.onizleme,
		onizleme = sess.onizleme,
		mp3 = (C.Sesler[sess.onizleme] or {}).mp3,
		grup = sess.grup,
		grupAd = sess.grupAd,
	}

	C.Sesler[F.id] = C.Sesler[sess.onizleme] or {mp3 = sess.mp3, sure = sess.sure}
	C.Ucus[F.id] = F
	C.KayitKapat(ply, sess)
	ply:SetNW2Float("SardonCigirtkanSon", CurTime())
	C.Bildir(ply, "Tu Howler vuela hacia el destinatario.")
	OwlFlight(ply, F)
	C.Gunluk("enviado", F)
end

local function BaslaSesion(ply, hedef, anahtar)
	if C.Yasak and C.Yasak[ply:SteamID64()] then
		C.Bildir(ply, "Tienes prohibido enviar Howlers.")
		return
	end
	if C.Oturumlar[ply] then
		C.Bildir(ply, "Ya tienes una grabación abierta.")
		return
	end
	local cd = Cooldown(ply)
	if cd > 0 then
		C.Bildir(ply, "Espera " .. math.ceil(cd) .. " s antes de otro Howler.")
		return
	end
	if not (ply:GetCharacter() and ply:GetCharacter():GetInventory()) then return end
	local inv = ply:GetCharacter():GetInventory()
	if not inv:HasItem(C.ITEM) then
		C.Bildir(ply, "Necesitas un Howler vacío.")
		return
	end
	if not inv:HasItem("PetOwl") then
		C.Bildir(ply, "Necesitas tener una lechuza.")
		return
	end

	local sess = {
		durum = K.KAYIT,
		hedef = hedef,
		anahtar = anahtar or "",
		basla = CurTime(),
		konusma = 0,
		anonim = false,
		hata = "",
		onizleme = 0,
		sure = 0,
		dalga = "",
	}
	C.Oturumlar[ply] = sess
	ply:SetNWBool("SardonCigirtkanKayit", true)
	SetGlobalInt("SardonCigirtkanKayit", GetGlobalInt("SardonCigirtkanKayit", 0) + 1)
	C.DurumGonder(ply, sess)
	C.Bildir(ply, "El sobre escucha. Mantén pulsado para hablar y sella al terminar.")
end

net.Receive("SardonCigirtkan.Basla", function(_, ply)
	local hedef = net.ReadEntity()
	local anahtar = net.ReadString() or ""

	if anahtar ~= "" then
		C.BaslaToplu(ply, anahtar)
		return
	end

	if not IsValid(hedef) or not hedef:IsPlayer() or hedef == ply then
		C.Bildir(ply, "Destinatario inválido.")
		return
	end
	BaslaSesion(ply, hedef, "")
end)

function C.ColectarGrupo(anahtar)
	local tur, hedef = C.HedefTablo(anahtar)
	local _, id = string.match(anahtar or "", "^(%a):(.+)$")
	local lista = {}
	for _, ply in ipairs(player.GetAll()) do
		local ch = ply:GetCharacter()
		if not ch or not ply:Alive() then continue end
		if tur == "faction" then
			local fac = ix.faction.Get(ch:GetFaction())
			if fac and fac.uniqueID == id then
				lista[#lista + 1] = ply
			end
		elseif tur == "class" then
			local cl = ch.GetClass and ch:GetClass()
			if cl and cl.uniqueID == id then
				lista[#lista + 1] = ply
			end
		elseif hedef and tur == "faction" and hedef.uniqueID then
			local fac = ix.faction.Get(ch:GetFaction())
			if fac and fac.uniqueID == hedef.uniqueID then
				lista[#lista + 1] = ply
			end
		end
	end
	return lista
end

function C.BaslaToplu(ply, anahtar)
	local uyeler = C.ColectarGrupo(anahtar)
	if #uyeler == 0 then
		C.Bildir(ply, "Nadie en línea coincide con ese grupo.")
		return
	end
	local sess = {
		durum = K.KAYIT,
		hedef = NULL,
		grup = {uyeler = uyeler, ad = C.HedefAd(anahtar)},
		grupAd = C.HedefAd(anahtar),
		grupSayi = #uyeler,
		basla = CurTime(),
		konusma = 0,
		anonim = false,
		hata = "",
	}
	C.Oturumlar[ply] = sess
	ply:SetNWBool("SardonCigirtkanKayit", true)
	SetGlobalInt("SardonCigirtkanKayit", GetGlobalInt("SardonCigirtkanKayit", 0) + 1)
	C.DurumGonder(ply, sess)
end

function C.TopluYetki(ply)
	if ply:IsSuperAdmin() then return true end
	local ch = ply:GetCharacter()
	if not ch then return false end
	local cl = ch.GetClass and ch:GetClass()
	local fac = ix.faction.Get(ch:GetFaction())
	for _, k in ipairs(C.Kurallar or {}) do
		if k.gTur == "class" and cl and cl.uniqueID == k.gId then return true end
		if k.gTur == "faction" and fac and fac.uniqueID == k.gId then return true end
	end
	return false
end

function C.TopluListeYolla(ply)
	if not C.TopluYetki(ply) then
		C.Bildir(ply, "No tienes permiso para envíos masivos.")
		return
	end
	local out = {}
	for _, k in ipairs(C.Kurallar or {}) do
		local anahtar = (k.hTur == "kendi" and ("f:" .. (ix.faction.Get(ply:GetCharacter():GetFaction()).uniqueID or ""))) or (k.hTur == "faction" and ("f:" .. k.hId)) or (k.hTur == "class" and ("c:" .. k.hId))
		if anahtar then
			local uyeler = C.ColectarGrupo(anahtar)
			if #uyeler > 0 then
				out[#out + 1] = {
					anahtar = anahtar,
					ad = C.HedefAd(anahtar),
					sayi = #uyeler,
					sinif = k.hTur == "class",
				}
			end
		end
	end
	net.Start("SardonCigirtkan.TopluListe")
	net.WriteTable(out)
	net.Send(ply)
end

net.Receive("SardonCigirtkan.TopluListe", function(_, ply)
	C.TopluListeYolla(ply)
end)

hook.Add("PlayerLoadedCharacter", "SardonCigirtkan.Toplu", function(ply)
	ply:SetNW2Bool("SardonCigirtkanToplu", C.TopluYetki(ply))
end)

hook.Add("PlayerUse", "SardonCigirtkan.Zarf", function(ply, ent)
	if not IsValid(ent) or ent:GetClass() ~= C.Sinif then return end
	if ent.Kullan then ent:Kullan(ply) end
end)

-- Yazılı: al abrir zarf