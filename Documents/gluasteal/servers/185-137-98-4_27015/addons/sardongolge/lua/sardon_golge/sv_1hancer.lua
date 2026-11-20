-- Servidor :: cuchillo — stacks, clavar, copiar aspecto
if not SERVER then return end
local S = SardonGolge
if not S then return end

function S.HancerEkle(char, adet)
	adet = math.floor(tonumber(adet) or 0)
	if not char or adet <= 0 then return false end
	local inv = char:GetInventory()
	if not inv then return false end
	local mevcut = inv:HasItem(S.ESYA)
	if mevcut then
		mevcut:SetData("adet", mevcut:GetAdet() + adet)
		return true
	end
	return inv:Add(S.ESYA, 1, { adet = adet }) ~= false
end

function S.HancerHarca(char, adet)
	adet = math.floor(tonumber(adet) or 1)
	if not char or adet <= 0 then return false end
	if S.HancerSay(char) < adet then return false end
	local inv = char:GetInventory()
	for _, it in pairs(inv:GetItemsByUniqueID(S.ESYA) or {}) do
		local n = it:GetAdet()
		if n > adet then
			it:SetData("adet", n - adet)
			return true
		else
			adet = adet - n
			it:Remove()
			if adet <= 0 then return true end
		end
	end
	return adet <= 0
end

function S.HancerAyir(item)
	if not item or item:GetAdet() <= 1 then return end
	local ply = item.player
	local char = ply and ply:GetCharacter()
	if not char then return end
	item:SetData("adet", item:GetAdet() - 1)
	local inv = char:GetInventory()
	if inv then inv:Add(S.ESYA, 1, { adet = 1 }) end
	S.Bildir(ply, "Has separado un cuchillo.", false)
end

function S.GorunumYakala(hedef)
	local char = hedef:GetCharacter()
	local t = {
		model = hedef:GetModel(),
		ad = char and char:GetName() or hedef:Nick(),
		fraksiyon = S.Fraksiyon(hedef),
		zaman = os.time(),
		skin = hedef:GetSkin(),
		bg = {},
	}
	for i = 0, hedef:GetNumBodyGroups() - 1 do
		t.bg[tostring(i)] = hedef:GetBodygroup(i)
	end
	local O = SardonOgrenci
	if char and O and O.AfisGorunum then
		local pak = O.AfisGorunum(char)
		if istable(pak) and istable(pak.d) then
			t.s = table.Copy(pak.d)
			if pak.kod and pak.kod ~= "" then t.kod = pak.kod end
			if O.Model then t.model = O.Model(pak.d.gender, pak.d.face) or t.model end
		end
	elseif char and istable(char:GetData("ogrenciGorunum")) then
		t.s = table.Copy(char:GetData("ogrenciGorunum"))
	end
	return t
end

function S.Sapla(ply, wep)
	if not IsValid(ply) or not ply:Alive() then return end
	local char = ply:GetCharacter()
	if not char then return end

	local ay = S.Ayar
	local cd = ply:GetNW2Float("GolgeSaplaCd", 0)
	if cd > CurTime() then
		return S.Bildir(ply, "El cuchillo se enfría (" .. math.ceil(cd - CurTime()) .. " s).", true)
	end
	if S.HancerSay(char) < 1 then
		return S.Bildir(ply, "No te quedan cuchillos.", true)
	end

	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * (ay.Menzil or 72),
		filter = ply,
		mask = MASK_SHOT_HULL,
	})
	local hedef = tr.Entity
	if not IsValid(hedef) or not hedef:IsPlayer() or not hedef:Alive() then
		-- esfera corta
		local nearest, nd
		for _, p in ipairs(ents.FindInSphere(ply:GetShootPos() + ply:GetAimVector() * 40, 48)) do
			if p:IsPlayer() and p ~= ply and p:Alive() then
				local d = p:GetPos():DistToSqr(ply:GetPos())
				local dir = (p:WorldSpaceCenter() - ply:GetShootPos()):GetNormalized()
				if dir:Dot(ply:GetAimVector()) >= (ay.KoniCos or 0.6) then
					if not nd or d < nd then nearest, nd = p, d end
				end
			end
		end
		hedef = nearest
	end
	if not IsValid(hedef) or not hedef:IsPlayer() then
		return S.Bildir(ply, "No hay nadie delante.", true)
	end

	local fid = S.Fraksiyon(hedef)
	if ay.YasakFraksiyon and ay.YasakFraksiyon[fid] then
		return S.Bildir(ply, "En servicio autorizado — no puedes clavar.", true)
	end

	if not S.HancerHarca(char, 1) then
		return S.Bildir(ply, "No te quedan cuchillos.", true)
	end

	ply:SetNW2Float("GolgeSaplaCd", CurTime() + (ay.Bekleme or 15))
	local dmg = DamageInfo()
	dmg:SetDamage(ay.Hasar or 5)
	dmg:SetAttacker(ply)
	dmg:SetInflictor(IsValid(wep) and wep or ply)
	dmg:SetDamageType(DMG_SLASH)
	hedef:TakeDamageInfo(dmg)

	local bitis = CurTime() + (ay.Yavaslatma or 0.8)
	ply:SetNW2Float("GolgeYavas", bitis)
	hedef:SetNW2Float("GolgeYavas", bitis)

	char:SetData("gerceklik", S.GorunumYakala(hedef))
	ply:SetNW2Bool("GolgeKopyaVar", true)

	S.NetGonder(S.OP.SAPLA, function()
		net.WriteEntity(ply)
		net.WriteEntity(hedef)
	end)
	S.NetGonder(S.OP.SIZI, nil, hedef)

	S.DurumGonder(ply)
	if S.KayitEkle then
		S.KayitEkle("saplama", ply, hedef, (hedef:GetCharacter() and hedef:GetCharacter():GetName()) or hedef:Nick())
	end
	S.Bildir(ply, "Has absorbido el aspecto de " .. (hedef:GetCharacter() and hedef:GetCharacter():GetName() or hedef:Nick()) .. ".", false)
end
