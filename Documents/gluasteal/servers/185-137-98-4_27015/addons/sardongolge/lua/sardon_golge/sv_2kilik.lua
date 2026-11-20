-- Servidor :: disfraz (DONUS / GERI / HANE) + Finite / Revelio / muerte
if not SERVER then return end
local S = SardonGolge
if not S then return end

local function Char(ply) return IsValid(ply) and ply:GetCharacter() end

local function GuardaReal(ply, char)
	local real = char:GetData("gerceklikReal")
	if istable(real) then return real end
	real = {
		model = ply:GetModel(),
		skin = ply:GetSkin(),
		bg = {},
		ad = char:GetName(),
		fakeFaction = "",
	}
	for i = 0, 31 do
		local v = ply:GetBodygroup(i)
		if v and v ~= 0 then real.bg[tostring(i)] = v end
	end
	char:SetData("gerceklikReal", real)
	return real
end

local function AplicaCopia(ply, k)
	if not istable(k) then return end
	if isstring(k.kod) and k.kod ~= "" then ply:SetNW2String("hl_gear", k.kod) end
	if k.model and util.IsValidModel(k.model) then ply:SetModel(k.model) end
	if k.skin then ply:SetSkin(k.skin) end
	if istable(k.bg) then
		for i, v in pairs(k.bg) do ply:SetBodygroup(tonumber(i) or 0, tonumber(v) or 0) end
	end
	local O = SardonOgrenci
	if istable(k.s) and O and O.Hazir and O.Hazir() and O.Model then
		ply:SetModel(O.Model(k.s.gender, k.s.face) or k.model or ply:GetModel())
		local giyili = O.BaslangicGiyili and O.BaslangicGiyili(k.s.gender, k.s.kiyafet) or {}
		local hane = O.HaneNo and O.HaneNo(k.fraksiyon) or 1
		local s = O.Ayarlar(k.s, giyili, hane, false, 1)
		if (not k.kod or k.kod == "") and HLStudents and HLStudents.EncodeGear then
			ply:SetNW2String("hl_gear", HLStudents.EncodeGear(s))
		end
		if HLStudents and HLStudents.EncodeFace then ply:SetNW2String("hl_face", HLStudents.EncodeFace(s)) end
		if HLStudents and HLStudents.ApplyBase then HLStudents.ApplyBase(ply, s) end
		if O.BoyUygula then O.BoyUygula(ply, 1) end
	end
end

function S.DumanGonder(pos, giris)
	S.NetGonder(S.OP.DUMAN, function()
		net.WriteVector(pos or vector_origin)
		net.WriteBool(giris == true)
	end)
end

function S.DurumTablosu(ply)
	local char = Char(ply)
	if not char then return nil end
	local d = char:GetData("gerceklikDurum") or {}
	return {
		aktif = d.aktif == true and ply:GetNW2Bool("GolgeKilik", false),
		kalan = math.max(0, tonumber(d.kalan) or 0),
		bekle = math.max(0, tonumber(d.bekle) or 0),
		sapla = math.max(0, ply:GetNW2Float("GolgeSaplaCd", 0) - CurTime()),
	}
end

local function Restaura(ply, char)
	local real = char:GetData("gerceklikReal")
	if istable(real) then
		if real.model and util.IsValidModel(real.model) then ply:SetModel(real.model) end
		if real.skin then ply:SetSkin(real.skin) end
		if istable(real.bg) then
			for i, v in pairs(real.bg) do ply:SetBodygroup(tonumber(i) or 0, tonumber(v) or 0) end
		end
	end
	ply:SetNWString("FakeFaction", "")
	ply:SetNWString("FakeFaction.Name", "")
	ply:SetNWString("FakeFaction.Desc", "")
	char:SetData("fakeFaction", nil)
	ply:SetNW2Bool("GolgeKilik", false)
end

function S.KilikBitir(ply, sebep, bekle)
	local char = Char(ply)
	if not char then return end
	if not ply:GetNW2Bool("GolgeKilik", false) then return end
	S.DumanGonder(ply:WorldSpaceCenter(), false)
	Restaura(ply, char)
	local d = { aktif = false, kalan = 0, bekle = bekle and (S.Ayar.YenidenBekleme or 300) or 0 }
	char:SetData("gerceklikDurum", d)
	S.DurumGonder(ply)
	if S.KayitEkle then S.KayitEkle("kilik_bitti", ply, nil, sebep or "fin") end
	S.Bildir(ply, "Has vuelto a tu forma." .. (sebep and (" (" .. sebep .. ")") or ""), false)
end

function S.KilikDonus(ply)
	local char = Char(ply)
	if not char then return end
	if ply:GetNW2Bool("GolgeKilik", false) then
		return S.Bildir(ply, "Ya estás disfrazado.", true)
	end
	local d = char:GetData("gerceklikDurum") or {}
	if (tonumber(d.bekle) or 0) > 0 then
		return S.Bildir(ply, "El cuchillo se recarga (" .. S.Sure(d.bekle) .. ").", true)
	end
	local k = char:GetData("gerceklik")
	if not istable(k) then
		return S.Bildir(ply, "No hay aspecto en el cuchillo.", true)
	end
	GuardaReal(ply, char)
	S.DumanGonder(ply:WorldSpaceCenter(), true)
	AplicaCopia(ply, k)
	ply:SetNW2Bool("GolgeKilik", true)
	ply:SetNWString("FakeFaction", tostring(k.fraksiyon or ""))
	ply:SetNWString("FakeFaction.Name", tostring(k.ad or ""))
	ply:SetNWString("FakeFaction.Desc", "")
	char:SetData("fakeFaction", k.fraksiyon or "")
	char:SetData("gerceklikDurum", { aktif = true, kalan = S.Ayar.KilikSure or 3600, bekle = 0 })
	S.DurumGonder(ply)
	if S.KayitEkle then S.KayitEkle("donus", ply, nil, k.ad or "?") end
	S.Bildir(ply, "Te has disfrazado de " .. (k.ad or "?") .. ".", false)
end

function S.KilikGeri(ply)
	local char = Char(ply)
	if not char then return end
	if ply:GetNWString("FakeFaction", "") == "" and not ply:GetNW2Bool("GolgeKilik", false) then
		return S.Bildir(ply, "No estás disfrazado.", true)
	end
	S.KilikBitir(ply, "manual", false)
end

function S.KilikHane(ply, fraksiyon, ad, aciklama)
	local char = Char(ply)
	if not char then return end
	local grup = S.Grup(ply)
	if grup ~= "snatcher" and grup ~= "karanlik" then
		return S.Bildir(ply, "Solo Snatchers / magos oscuros pueden usar disfraz de casa.", true)
	end
	fraksiyon = tostring(fraksiyon or "")
	ad = string.sub(string.Trim(tostring(ad or "")), 1, 48)
	aciklama = string.sub(string.Trim(tostring(aciklama or "")), 1, 120)
	if ad == "" then return S.Bildir(ply, "Escribe un nombre visible.", true) end
	GuardaReal(ply, char)
	S.DumanGonder(ply:WorldSpaceCenter(), true)
	ply:SetNW2Bool("GolgeKilik", true)
	ply:SetNWString("FakeFaction", fraksiyon)
	ply:SetNWString("FakeFaction.Name", ad)
	ply:SetNWString("FakeFaction.Desc", aciklama)
	char:SetData("fakeFaction", fraksiyon)
	char:SetData("Gerceklik.Name", ad)
	char:SetData("Gerceklik.Desc", aciklama)
	-- Modelo de casa vía clase si existe
	local fac = ix.faction.Get(fraksiyon) or (ix.faction.indices and nil)
	for _, f in pairs(ix.faction.indices or {}) do
		if f.uniqueID == fraksiyon and f.models then
			local mdl = istable(f.models) and f.models[1] or f.models
			if isstring(mdl) and util.IsValidModel(mdl) then ply:SetModel(mdl) end
			break
		end
	end
	char:SetData("gerceklikDurum", { aktif = true, kalan = S.Ayar.KilikSure or 3600, bekle = 0 })
	S.DurumGonder(ply)
	S.Bildir(ply, "Disfraz de casa aplicado.", false)
end

-- Temporizador (solo online)
timer.Create("SardonGolge.KilikTick", 1, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		local char = Char(ply)
		if not char then continue end
		local d = char:GetData("gerceklikDurum")
		if not istable(d) then continue end
		local dirty = false
		if d.bekle and d.bekle > 0 then
			d.bekle = math.max(0, d.bekle - 1)
			dirty = true
		end
		if ply:GetNW2Bool("GolgeKilik", false) and d.aktif then
			d.kalan = math.max(0, (d.kalan or 0) - 1)
			dirty = true
			if d.kalan <= 0 then
				char:SetData("gerceklikDurum", d)
				S.KilikBitir(ply, "tiempo", true)
				continue
			end
		end
		if dirty then
			char:SetData("gerceklikDurum", d)
			if CurTime() % 5 < 1 then S.DurumGonder(ply) end
		end
	end
end)

hook.Add("PlayerDeath", "SardonGolge.Kilik", function(vic)
	if IsValid(vic) and vic:GetNW2Bool("GolgeKilik", false) then
		S.KilikBitir(vic, "muerte", false)
	end
end)

hook.Add("HpwFiniteCast", "SardonGolge.Finite", function(caster, spell, target)
	local menzil = S.Ayar.FiniteMenzil or 400
	local function ClearNear(pos)
		for _, p in ipairs(player.GetAll()) do
			if p:GetNW2Bool("GolgeKilik", false) and p:GetPos():DistToSqr(pos) <= menzil * menzil then
				S.KilikBitir(p, "Finite", false)
			end
		end
	end
	if IsValid(target) and target:IsPlayer() then
		if target:GetNW2Bool("GolgeKilik", false) then S.KilikBitir(target, "Finite", false) end
	elseif IsValid(caster) then
		ClearNear(caster:GetPos())
	end
end)

-- Homenum Revelio: si el hechizo existe como hook genérico
hook.Add("HpwRewriteSpellCasted", "SardonGolge.Revelio", function(ply, spell)
	if not IsValid(ply) or not spell then return end
	local ad = isstring(spell) and spell or (spell.Name or spell.name or "")
	ad = string.lower(tostring(ad))
	if not string.find(ad, "revelio") and not string.find(ad, "homenum") then return end
	local r = S.Ayar.RevelioYaricap or 600
	for _, p in ipairs(player.GetAll()) do
		if p:GetNW2Bool("GolgeKilik", false) and p:GetPos():DistToSqr(ply:GetPos()) <= r * r then
			S.KilikBitir(p, "Homenum Revelio", false)
			S.Bildir(ply, "Detectas un disfraz cercano.", false)
		end
	end
end)
