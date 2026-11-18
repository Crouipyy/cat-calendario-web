-- Sardon Öğrenci :: aplicar aspecto al jugador (modelo, NW2, altura, huesos).
-- El espejo / creación escriben char data "ogrenciGorunum"; aquí se traduce a lo que dibuja HLStudents.
if not SERVER then return end

local O = SardonOgrenci
local LVL_AVISO = false

----------------------------------------------------------------------------------------
-- Altura: año escolar × factor personal (±4 %). Sin [sardon] level, año = 1.
----------------------------------------------------------------------------------------
function O.BoyCarpani(char)
	local d = O.KarakterDurumu(char)
	local personal = O.KisiselBoy(d and d.height or 1)
	local yil = 1

	if char then
		if char.GetLVL then
			yil = O.YilBoyu(char)
		else
			if not LVL_AVISO then
				LVL_AVISO = true
				MsgN("[SardonOgrenci] GetLVL no existe; altura de año = 1 hasta que cargue sardonlevel.")
			end
			yil = O.YilBoyTablo[1] or 1
		end
	end

	return yil * personal
end

----------------------------------------------------------------------------------------
-- Ropa equipada → tabla {slot = {piece, look}} + capucha
----------------------------------------------------------------------------------------
function O.GiyiliTablo(char)
	local d = O.KarakterDurumu(char)
	local giyili, kapuson = {}, false
	if not d then return giyili, kapuson end

	local ek = O.Ekipman(char)
	if not ek then return giyili, kapuson end

	for _, item in pairs(ek:GetItems(true)) do
		if item.giysi then
			local pid = O.GiysiParcaKimligi(item.giysi, d.gender)
			local p = pid and O.GiysiParcasi(item.giysi, d.gender)
			if p then
				giyili[p.slot] = {piece = pid, look = tonumber(item:GetData("l", 1)) or 1}
				if p.slot == "robe" and item:GetData("h") then
					kapuson = true
				end
			end
		end
	end

	return giyili, kapuson
end

----------------------------------------------------------------------------------------
-- Índice de ranura TAB (1..9) para un slot de ropa
----------------------------------------------------------------------------------------
function O.YuvaX(slot)
	for i, s in ipairs(O.YuvaSira) do
		if s == slot then return i end
	end
end

----------------------------------------------------------------------------------------
-- Aplicar aspecto al jugador vivo
----------------------------------------------------------------------------------------
function O.Uygula(ply, char)
	if not IsValid(ply) then return end
	char = char or ply:GetCharacter()
	if not char then return end

	-- Cuerpo base estudiante (cabeza/manos) sin gear = cabeza flotante.
	-- Si la facción no es de alumno pero el modelo/datos sí lo son (p.ej. Ministro con Staylofft),
	-- seguimos aplicando ropa; no vaciar hl_gear (eso dejaba el cuerpo desnudo).
	local faccionOk = O.FraksiyonUygun(char:GetFaction())
	if not faccionOk and not O.TabanMi(ply:GetModel()) and not O.KarakterDurumu(char) then
		return
	end

	if not O.Hazir() then
		MsgN("[SardonOgrenci] HLStudents no listo; no se aplica aspecto a " .. tostring(ply))
		return
	end

	local d = O.KarakterDurumu(char)
	if not d then
		-- Modelo estudiante huérfano sin ogrenciGorunum: no strip; avisa
		if O.TabanMi(ply:GetModel()) then
			MsgN("[SardonOgrenci] " .. tostring(ply) .. " tiene cuerpo estudiante sin ogrenciGorunum (faccion=" .. tostring(char:GetFaction()) .. ")")
		end
		return
	end

	local mdl = O.Model(d.gender, d.face)
	if ply:GetModel() ~= mdl then
		ply:SetModel(mdl)
	end

	local giyili, kapuson = O.GiyiliTablo(char)
	local olcek = O.BoyCarpani(char)
	local s = O.Ayarlar(d, giyili, O.HaneNo(char:GetFaction()), kapuson, olcek)

	ply:SetNW2String("hl_gear", HLStudents.EncodeGear(s))
	ply:SetNW2String("hl_face", HLStudents.EncodeFace(s))

	for _, f in ipairs(HLStudents.Config.ColorFields) do
		local col = (s.colors and s.colors[f.key]) or HLStudents.Config.Defaults.colors[f.key]
		ply:SetNW2Vector("hl_col_" .. f.key, col)
	end

	ply:SetNW2String("SOgIfade", O.IfadeKodla(d.ifade))
	ply:SetNW2String("SOgVucut", O.VucutKodla(d.vucut))

	-- RP: HLStudents no escala el casco; la escala del cuerpo va aquí
	if math.abs(ply:GetModelScale() - olcek) > 0.001 then
		ply:SetModelScale(olcek, 0)
	end

	-- bodygroups de brazos según manga / guantes
	if HLStudents.ApplyBase then
		HLStudents.ApplyBase(ply, s)
	end

	O.VucutUygula(ply, d.gender, d.vucut)
end

----------------------------------------------------------------------------------------
-- Hooks
----------------------------------------------------------------------------------------
hook.Add("PlayerLoadedCharacter", "SardonOgrenci.Uygula", function(client, character)
	-- Cargar equipo también fuera de casas (Ministerio/staff con cuerpo HL + ogrenciGorunum).
	local necesitaEquipo = O.KiyafetYukle and (
		O.FraksiyonUygun(character:GetFaction())
		or O.KarakterDurumu(character)
		or O.TabanMi(client:GetModel())
	)
	if necesitaEquipo then
		O.KiyafetYukle(client, character)
	else
		timer.Simple(0, function()
			if IsValid(client) and client:GetCharacter() == character then
				O.Uygula(client, character)
			end
		end)
	end
end)

hook.Add("PlayerSpawn", "SardonOgrenci.Uygula", function(client)
	timer.Simple(0, function()
		if not IsValid(client) then return end
		local char = client:GetCharacter()
		if char then
			O.Uygula(client, char)
		end
	end)
end)

-- Si un hechizo / pose pone huesos a neutro, reponer
timer.Create("SardonOgrenci.VucutDenetle", 2, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:Alive() and O.TabanMi(ply:GetModel()) then
			O.VucutDenetle(ply)
		end
	end
end)

----------------------------------------------------------------------------------------
-- /Gorunum: abrir espejo completo y guardar
----------------------------------------------------------------------------------------
util.AddNetworkString("SardonOgrenci.AynaAc")
util.AddNetworkString("SardonOgrenci.Kaydet")
util.AddNetworkString("SardonOgrenci.Sonuc")
util.AddNetworkString("SardonOgrenci.Renk")

local function sonuc(ply, ok, metin)
	net.Start("SardonOgrenci.Sonuc")
		net.WriteBool(ok and true or false)
		net.WriteString(metin or "")
	net.Send(ply)
end

-- Migración v1 → v2: sin esquema v1 recuperado, se descarta el registro viejo
local function migrarV1(char)
	local t = char:GetData(O.VERI)
	if not istable(t) then return end
	if t.v == O.SURUM then return end
	MsgN("[SardonOgrenci] descartando ogrenciGorunum v" .. tostring(t.v) .. " de char " .. char:GetID())
	char:SetData(O.VERI, nil)
end

function O.DuzenIzni(char)
	return char and char:GetData("ogrenciGorunumIzni") == true
end

-- returns ok, ilkKez, usaIzni
function O.Duzenleyebilir(ply, char)
	if not IsValid(ply) or not char then return false end
	if not O.FraksiyonUygun(char:GetFaction()) then return false end
	if not O.Hazir() then return false end

	migrarV1(char)
	local d = O.KarakterDurumu(char)
	local ilk = d == nil
	local izin = O.DuzenIzni(char)
	local mod = O.Ayar.Duzenleme or "ilk"

	if ilk then return true, true, false end
	if izin then return true, false, true end
	if mod == "serbest" then return true, false, false end
	if mod == "yetkili" then return O.Yetkili(ply), false, false end
	-- "ilk": solo primera vez (o permiso one-shot ya cubierto)
	return false, false, false
end

local function giyiliNet(char)
	local giyili = {}
	local tab, _ = O.GiyiliTablo(char)
	for slot, g in pairs(tab or {}) do
		giyili[slot] = {piece = g.piece, look = g.look}
	end
	return giyili
end

function O.AynaAcTam(ply)
	local char = ply:GetCharacter()
	if not char then return end

	local ok, ilk, _ = O.Duzenleyebilir(ply, char)
	if not ok then
		ply:ChatPrint("No puedes editar el aspecto. (staff /GorunumIzni)")
		return
	end

	local d = O.KarakterDurumu(char) or O.Varsayilan("m")
	-- primera vez vía /Gorunum: selector de ropa inicial
	local baslangic = ilk == true

	net.Start("SardonOgrenci.AynaAc")
		net.WriteTable(d)
		net.WriteBool(ilk)
		net.WriteBool(baslangic)
		net.WriteTable(giyiliNet(char))
		net.WriteUInt(O.HaneNo(char:GetFaction()) or 1, 4)
	net.Send(ply)
end

local function darHaneTakimi(char, d)
	local liste = O.HaneTakimi[d.gender]
	if not liste then return end
	local ek = O.Ekipman(char)
	if not ek then return end

	for _, item in pairs(ek:GetItems(true)) do
		item:Remove()
	end

	O.BaslangicAktif = true
	for i, row in ipairs(liste) do
		local id, look = row[1], row[2]
		local uniqueID = O.ESYA_ONEK .. id
		if ix.item.list[uniqueID] then
			local p = O.GiysiParcasi(id, d.gender)
			local x = p and O.YuvaX(p.slot) or i
			ek:Add(uniqueID, 1, {l = look or 1}, x, 1)
		end
	end
	O.BaslangicAktif = nil
end

function O.Kaydet(ply, ham)
	local char = ply:GetCharacter()
	if not char then return end

	local ok, ilk, usaIzni = O.Duzenleyebilir(ply, char)
	if not ok then
		sonuc(ply, false, "No tienes permiso para editar el aspecto.")
		return
	end

	local t, hata = O.Temizle(ham, true)
	if not t then
		sonuc(ply, false, hata or "Aspecto no válido.")
		return
	end

	if O.KanonYuzMu and O.KanonYuzMu(t.gender, t.face) then
		t.face = 1
	end

	local eski = O.KarakterDurumu(char)
	local kiyafetSecim

	if ilk then
		kiyafetSecim = O.BaslangicTemizle(t.gender, istable(ham) and ham.kiyafet, true)
		if not kiyafetSecim and istable(ham) and ham.kiyafet ~= nil then
			sonuc(ply, false, "Conjunto inicial no válido.")
			return
		end
	elseif eski then
		-- re-edición completa: no se permiten cambios fuera de piezas si hubiera restricciones futuras
		t.rev = (eski.rev or 0) + 1
	end

	t.kiyafet = nil
	t.rev = t.rev or ((eski and eski.rev) or 0) + 1
	if ilk then t.rev = 1 end

	char:SetData(O.VERI, t)

	if usaIzni then
		char:SetData("ogrenciGorunumIzni", nil)
	end

	-- ropa inicial / uniforme de casa en el primer /Gorunum
	if ilk then
		O.EkipmanAl(char, function(ek)
			if not IsValid(ply) or ply:GetCharacter() ~= char then return end
			if O.HaneFraksiyonu(char:GetFaction()) then
				darHaneTakimi(char, t)
			else
				O.BaslangicVer(char, kiyafetSecim or {})
			end
			O.Uygula(ply, char)
			sonuc(ply, true, "Apariencia guardada.")
		end)
	else
		O.Uygula(ply, char)
		sonuc(ply, true, "Apariencia guardada.")
	end

	local fx = O.Ayar.DegisimEfekti
	if isstring(fx) and fx ~= "" then
		ParticleEffect(fx, ply:GetPos() + Vector(0, 0, 40), Angle(0, 0, 0), ply)
	end
end

net.Receive("SardonOgrenci.Kaydet", function(_, ply)
	if not IsValid(ply) then return end
	if (ply.sogKaydetCD or 0) > CurTime() then return end
	ply.sogKaydetCD = CurTime() + 1
	local ham = net.ReadTable()
	O.Kaydet(ply, ham)
end)

-- Cambio de color de prenda (RenkDegistir); por defecto cerrado
net.Receive("SardonOgrenci.Renk", function(_, ply)
	if not IsValid(ply) then return end
	local itemID = net.ReadUInt(32)
	local look = net.ReadUInt(8)
	local mod = O.Ayar.RenkDegistir or "kapali"

	if mod == "kapali" then
		ply:ChatPrint("El color de la prenda se elige al comprar; aquí no se puede cambiar.")
		return
	end
	if mod == "yetkili" and not O.Yetkili(ply) then return end

	local char = ply:GetCharacter()
	local item = ix.item.instances[itemID]
	if not char or not item or not item.giysi then return end

	local d = O.KarakterDurumu(char)
	local p = d and O.GiysiParcasi(item.giysi, d.gender)
	if not p or look < 1 or look > #p.looks then return end

	item:SetData("l", look)
	O.Uygula(ply, char)
end)

ix.command.Add("Gorunum", {
	description = "Edita el aspecto de estudiante (Espejo de apariencia).",
	OnRun = function(_, ply)
		O.AynaAcTam(ply)
	end
})

ix.command.Add("GorunumIzni", {
	description = "Da a un jugador permiso de una sola vez para editar el aspecto.",
	adminOnly = true,
	arguments = ix.type.character,
	OnRun = function(_, ply, target)
		if not target or not target.SetData then
			return "Personaje no encontrado."
		end
		target:SetData("ogrenciGorunumIzni", true)
		local owner = target:GetPlayer()
		if IsValid(owner) then
			owner:ChatPrint("Se ha activado tu permiso de /Gorunum de una sola vez.")
		end
		return "Permiso de /Gorunum concedido a " .. target:GetName() .. "."
	end
})

-- asegurar migración al cargar
hook.Add("PlayerLoadedCharacter", "SardonOgrenci.Migrar", function(_, character)
	migrarV1(character)
end)

MsgN("[SardonOgrenci] sv_1kayit cargado.")
