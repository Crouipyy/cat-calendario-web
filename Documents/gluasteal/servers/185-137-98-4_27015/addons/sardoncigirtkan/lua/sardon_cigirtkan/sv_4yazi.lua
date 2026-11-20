-- Sardon Çığırtkan :: Howler escrito (ministerio)
local C = SardonCigirtkan
local A = C.Ayar

function C.YaziYayin(F, pos, menzil)
	if not F or not F.yazi then return end
	menzil = menzil or A.DaktiloMenzil or 650
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:GetPos():DistToSqr(pos) <= menzil * menzil then
			net.Start("SardonCigirtkan.Yazi")
			net.WriteUInt(F.id, 32)
			net.WriteTable(F.yazi)
			net.Send(ply)
		end
	end
end

-- Uso: C.YaziGonder(ply, hedefPlayer, { tur, metin, alici, ... })
function C.YaziGonder(ply, hedef, yazi)
	if not IsValid(ply) or not IsValid(hedef) or not hedef:IsPlayer() then return false end
	yazi = C.YaziTemizle(yazi or {})
	if (yazi.metin or "") == "" and (yazi.tur or "") == "" then return false end

	local F = {
		id = C.SonrakiKimlik(),
		gonderen = ply,
		gonderenAd = yazi.antet or "Ministerio de Magia",
		hedef = hedef,
		anonim = false,
		yazi = yazi,
		sure = (C.DaktiloBelge and C.DaktiloBelge(yazi).toplam) or 15,
	}

	C.Ucus = C.Ucus or {}
	C.Ucus[F.id] = F
	C.Zarflar = C.Zarflar or {}

	local owl = StPets and (StPets.DoesHave(ply, "PetOwl") or StPets.DoesHave(ply, "owl"))
	if IsValid(owl) and IsValid(hedef) then
		owl:SetNWBool("SardonCigirtkan", true)
		owl:SetNWEntity("target", hedef)
	end

	timer.Simple(5, function()
		local ent = ents.Create(C.Sinif)
		if not IsValid(ent) then return end
		ent:SetPos(hedef:GetPos() + Vector(0, 0, 70))
		ent:Spawn()
		ent:Kur(F)
		C.Zarflar[F.id] = ent
		if IsValid(owl) then
			owl:SetNWBool("SardonCigirtkan", false)
			owl:SetNWEntity("target", NULL)
		end
		C.Gunluk("tebligat", F)
	end)

	C.Bildir(hedef, "Un buho trae un sobre oficial sellado.")
	return true
end