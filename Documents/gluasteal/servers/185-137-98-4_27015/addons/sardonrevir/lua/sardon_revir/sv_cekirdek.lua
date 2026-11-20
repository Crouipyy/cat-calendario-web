-- Sardon Revir :: servidor del turno de enfermería.
-- El cliente ya pinta actores, diálogo, cuaderno y rúnico. Aquí se decide el turno,
-- se guardan el ala y el progreso, y no se calla un fallo.

local R = SardonRevir

local REDES = {
	"SardonRevir.Islem", "SardonRevir.Diyalog", "SardonRevir.Veri", "SardonRevir.Kayit",
	"SardonRevir.Nobet", "SardonRevir.Bildirim", "SardonRevir.Karne", "SardonRevir.Aktor",
	"SardonRevir.Accio", "SardonRevir.Efekt", "SardonRevir.Soz", "SardonRevir.Cizim",
	"SardonRevir.CizimSonuc", "SardonRevir.CizimGoster", "SardonRevir.Yonetim", "SardonRevir.YonetimVeri"
}
for _, n in ipairs(REDES) do util.AddNetworkString(n) end

local OP = {KONUS = 1, SECIM = 2, MUAYENE = 3, TARA = 4, TESHIS = 5, ESYA = 6, SEVK = 7, BIRAK = 8, BASLA = 9}
local CLAVE = "sardonRevir"
local DIR = "sardon_revir"
local SIGUIENTE = 100
local POMFREY = 1
local TURNO = {}
local ACTOR = {}
local LISTO = false

local function Aviso(ply, titulo, texto, tur)
	if not IsValid(ply) then return end
	net.Start("SardonRevir.Bildirim")
		net.WriteString(tostring(titulo or ""))
		net.WriteString(tostring(texto or ""))
		net.WriteString(tur or "bilgi")
	net.Send(ply)
end

local function Personaje(ply)
	if not IsValid(ply) or not ply.GetCharacter then return end
	return ply:GetCharacter()
end

local function NuevoRegistro()
	return {
		deneyim = 0, birikim = 0, dalpuan = 0, iyilesen = 0, devredilen = 0,
		nobet = 0, dogru = 0, gun = "", gunsayi = 0, u = {}, b = {}, tk = {}
	}
end

local function LeerRegistro(char)
	if not char or not char.GetData then return NuevoRegistro() end
	local t = char:GetData(CLAVE, nil)
	if not istable(t) then return NuevoRegistro() end
	local o = NuevoRegistro()
	for k, v in pairs(o) do
		if t[k] ~= nil then o[k] = t[k] end
	end
	o.u = istable(o.u) and o.u or {}
	o.b = istable(o.b) and o.b or {}
	o.tk = istable(o.tk) and o.tk or {}
	return o
end

local function GuardarRegistro(char, reg)
	if char and char.SetData then char:SetData(CLAVE, reg) end
end

local function RutaAyar() return DIR .. "/ayar.json" end
local function RutaMapa() return DIR .. "/harita_" .. game.GetMap() .. ".json" end

local function GuardarAyar()
	file.CreateDir(DIR)
	file.Write(RutaAyar(), util.TableToJSON(R.Ayar, true))
end

local function GuardarMapa()
	if not R.Harita then return end
	file.CreateDir(DIR)
	file.Write(RutaMapa(), util.TableToJSON(R.HaritaYaz(R.Harita), true))
end

local function Cargar()
	file.CreateDir(DIR)
	local aj = file.Read(RutaAyar(), "DATA")
	if aj and aj ~= "" then
		local t = util.JSONToTable(aj)
		if istable(t) then R.Ayar = R.AyarTemizle(t) end
	end
	local mj = file.Read(RutaMapa(), "DATA")
	if mj and mj ~= "" then
		local t = util.JSONToTable(mj)
		R.Harita = R.HaritaCoz(t) or R.Harita
	end
	if not R.Harita then R.Harita = R.HaritaVarsayilanKopya() end
end

local function Caja()
	local h = R.Harita
	if not h then return end
	local pts = {h.giris, h.pomfrey.pos, h.defter.pos, h.dolap.pos}
	for _, y in ipairs(h.yataklar) do
		pts[#pts + 1] = y.bas
		pts[#pts + 1] = y.ayak
		pts[#pts + 1] = y.yan
	end
	local min, max = Vector(pts[1]), Vector(pts[1])
	for i = 2, #pts do
		local p = pts[i]
		min.x, max.x = math.min(min.x, p.x), math.max(max.x, p.x)
		min.y, max.y = math.min(min.y, p.y), math.max(max.y, p.y)
		min.z, max.z = math.min(min.z, p.z), math.max(max.z, p.z)
	end
	h.kutu = {min = min - Vector(500, 500, 180), max = max + Vector(500, 500, 280)}
end

local function Esqueleto(pos, yaw)
	local h = {
		giris = pos + Vector(0, -220, 0),
		pomfrey = {pos = pos, yaw = yaw or 0},
		defter = {pos = pos + Vector(50, 30, 40), yaw = yaw or 0},
		dolap = {pos = pos + Vector(-50, 10, 40), yaw = yaw or 0},
		yataklar = {}
	}
	for i = 1, 6 do
		local o = Vector((i - 1) * 90, 140, 0)
		h.yataklar[i] = {
			no = i,
			bas = pos + o,
			ayak = pos + o + Vector(0, 72, 0),
			yan = pos + o + Vector(48, 36, 0),
			kapali = i > 3
		}
	end
	R.Harita = h
	Caja()
end

local function EnviarVeri(ply)
	net.Start("SardonRevir.Veri")
		net.WriteTable(R.Ayar)
		net.WriteBool(R.Harita ~= nil)
		if R.Harita then net.WriteTable(R.HaritaYaz(R.Harita)) end
	if ply then net.Send(ply) else net.Broadcast() end
end

local function TextoPlazo(char)
	local seg = R.SonrakiSifirlama()
	local min = math.floor(seg / 60)
	if min >= 60 then return math.floor(min / 60) .. " h" end
	return math.max(1, min) .. " min"
end

local function EnviarKayit(ply)
	local char = Personaje(ply)
	if not char then return end
	local k = LeerRegistro(char)
	local usado = (k.gun == R.Gun()) and (tonumber(k.gunsayi) or 0) or 0
	local quedan = math.max(0, (R.Ayar.gunluk or 1) - usado)
	local unvan = R.Unvan(k.iyilesen)
	net.Start("SardonRevir.Kayit")
		net.WriteUInt(math.max(0, tonumber(char:GetID()) or 0), 32)
		net.WriteUInt(math.Clamp(tonumber(k.deneyim) or 0, 0, 4294967295), 32)
		net.WriteUInt(math.Clamp(tonumber(k.birikim) or 0, 0, 4294967295), 32)
		net.WriteUInt(math.Clamp(tonumber(k.dalpuan) or 0, 0, 65535), 16)
		net.WriteUInt(math.Clamp(tonumber(k.iyilesen) or 0, 0, 65535), 16)
		net.WriteUInt(math.Clamp(tonumber(k.nobet) or 0, 0, 65535), 16)
		net.WriteUInt(math.Clamp(tonumber(k.dogru) or 0, 0, 65535), 16)
		net.WriteUInt(math.Clamp(quedan, 0, 255), 8)
		net.WriteUInt(math.Clamp(R.SonrakiSifirlama(), 0, 4294967295), 32)
		net.WriteTable(k.u or {})
		net.WriteTable(k.b or {})
		net.WriteTable(k.tk or {})
		net.WriteString(unvan or "")
	net.Send(ply)
end

local function EnviarActor(dest, op, a)
	net.Start("SardonRevir.Aktor")
		net.WriteUInt(op, 2)
		if op == 2 then
			net.WriteUInt(a.id, 16)
		else
			net.WriteUInt(a.id, 16)
			net.WriteString(a.tur or "hasta")
			net.WriteString(a.model or "")
			net.WriteString(a.ad or "")
			net.WriteString(a.unvan or "")
			net.WriteString(a.poz or "ayakta")
			net.WriteUInt(a.yatak or 0, 4)
			net.WriteVector(a.pos or vector_origin)
			net.WriteFloat(a.yaw or 0)
			local yol = a.yol
			local n = (yol and #yol >= 2) and math.min(#yol, 63) or 0
			net.WriteUInt(n, 6)
			for i = 1, n do net.WriteVector(yol[i]) end
			net.WriteFloat(a.yolBas or 0)
			net.WriteFloat(a.hiz or 0)
			net.WriteFloat(a.hedefYaw or 0)
			net.WriteString(a.efekt or "")
			net.WriteUInt(math.Clamp(a.siddet or 1, 0, 15), 4)
			net.WriteString(a.kalinti or "")
			net.WriteFloat(a.kalintiBitis or 0)
			net.WriteBool(a.gizli and true or false)
			net.WriteUInt(a.sahip or 0, 16)
			net.WriteBool(a.giris and true or false)
			net.WriteBool(a.cikis and true or false)
			net.WriteString(a.anim or "")
			net.WriteFloat(a.animBas or 0)
		end
	if dest then net.Send(dest) else net.Broadcast() end
end

local function PonerActor(a)
	ACTOR[a.id] = a
	EnviarActor(nil, 1, a)
end

local function QuitarActor(id)
	if not ACTOR[id] then return end
	ACTOR[id] = nil
	EnviarActor(nil, 2, {id = id})
end

local function AparecerPomfrey()
	local h = R.Harita
	if not h or not h.pomfrey then return end
	PonerActor({
		id = POMFREY, tur = "pomfrey", model = R.PomfreyModel or "models/konnie/pomfrey/pomfrey.mdl",
		ad = "Madam Pomfrey", unvan = "Enfermera de Hogwarts", poz = "ayakta", yatak = 0,
		pos = h.pomfrey.pos, yaw = h.pomfrey.yaw or 0, hiz = 0, hedefYaw = h.pomfrey.yaw or 0,
		efekt = "", siddet = 1, kalinti = "", kalintiBitis = 0, sahip = 0, anim = "", animBas = CurTime()
	})
end

local function Efecto(tur, pos, renk, extra)
	net.Start("SardonRevir.Efekt")
		net.WriteString(tur)
		net.WriteVector(pos)
		net.WriteColor(renk or Color(220, 200, 140))
		net.WriteString(extra or "")
	net.Broadcast()
end

local function Globo(id, texto, seg, dueno)
	net.Start("SardonRevir.Soz")
		net.WriteUInt(id, 16)
		net.WriteString(tostring(texto or ""))
		net.WriteFloat(seg or 4)
		net.WriteUInt(dueno or 0, 16)
	net.Broadcast()
end

local function TurnoDe(ply)
	local char = Personaje(ply)
	if not char then return end
	return TURNO[char:GetID()]
end

local function Paciente(N, id)
	for _, H in ipairs(N.pacientes) do
		if H.id == id then return H end
	end
end

local function Claves(set)
	local t = {}
	for id in pairs(set or {}) do t[#t + 1] = id end
	table.sort(t)
	return table.concat(t, ",")
end

local function EnviarNobet(ply, N)
	net.Start("SardonRevir.Nobet")
		if not N then
			net.WriteBool(false)
			net.Send(ply)
			return
		end
		net.WriteBool(true)
		net.WriteFloat(CurTime() + math.max(0, N.fin - os.time()))
		net.WriteUInt(math.Clamp(N.kazanc or 0, 0, 65535), 16)
		net.WriteBool(N.test and true or false)
		net.WriteUInt(math.min(#N.pacientes, 7), 3)
		for i = 1, math.min(#N.pacientes, 7) do
			local H = N.pacientes[i]
			net.WriteUInt(H.id, 16)
			net.WriteUInt(H.yatak, 4)
			net.WriteString(H.kimlik.ad)
			net.WriteString(H.kimlik.hane)
			net.WriteUInt(math.Clamp(tonumber(H.kimlik.yil) or 1, 0, 7), 3)
			net.WriteString(H.kimlik.kisilik or "")
			net.WriteString(H.durum)
			net.WriteString(Claves(H.acik))
			net.WriteString(H.teshis or "")
			net.WriteUInt(math.Clamp(H.gAdim or 0, 0, 15), 4)
			net.WriteUInt(math.Clamp(H.yanlis or 0, 0, 15), 4)
			net.WriteBool(H.hikaye and true or false)
			net.WriteBool(H.belirti and true or false)
			net.WriteBool(H.muayene and true or false)
			net.WriteBool(H.tarama and true or false)
			net.WriteString(H.gercek or "")
			net.WriteUInt(math.Clamp(H.deneyim or 0, 0, 4095), 12)
			net.WriteBool(H.acil and true or false)
		end
	net.Send(ply)
end

local function Diyalog(ply, actor, lineas, opciones)
	net.Start("SardonRevir.Diyalog")
		net.WriteUInt(actor or 0, 16)
		net.WriteUInt(math.min(#lineas, 31), 5)
		for i = 1, math.min(#lineas, 31) do
			local s = lineas[i]
			net.WriteString(s[1] or "anlatici")
			net.WriteString(s[2] or "")
			net.WriteString(s[3] or "")
		end
		net.WriteUInt(math.min(#(opciones or {}), 15), 4)
		for i = 1, math.min(#(opciones or {}), 15) do
			net.WriteString(opciones[i][1] or "")
			net.WriteString(opciones[i][2] or "")
		end
	net.Send(ply)
end

local function Contexto(ply, char)
	local hora = tonumber(os.date("%H")) or 12
	local b = {}
	b.gece = hora >= 22 or hora < 6
	b.sabah = hora >= 6 and hora < 11
	b.aksam = hora >= 18 and hora < 22
	b.yagmur = false
	b.kar = false
	b.dolunay = false
	local casa = R.OyuncuHane and R.OyuncuHane(char) or nil
	b.casaVol = casa
	return b
end

local function ElegirEnfermedad(char, ctx, minimo)
	local tope = 2
	if R.Beceri(char, R.BECERI.IZLER) > 0 then tope = 3 end
	if R.Beceri(char, R.BECERI.DERIN) > 0 then tope = 4 end
	local function Llenar(piso)
		local bolsa, total = {}, 0
		for _, h in ipairs(R.Hastaliklar) do
			if h.zorluk <= tope and h.zorluk >= piso then
				local peso = 1
				for k, m in pairs(h.baglam or {}) do
					if ctx[k] then peso = peso * m end
				end
				peso = math.max(0.2, peso)
				total = total + peso
				bolsa[#bolsa + 1] = {h, total}
			end
		end
		return bolsa, total
	end
	local bolsa, total = Llenar(minimo or 1)
	if #bolsa == 0 then bolsa, total = Llenar(1) end
	if #bolsa == 0 then return R.Hastaliklar[1] end
	local tiro = math.random() * total
	for _, fila in ipairs(bolsa) do
		if tiro <= fila[2] then return fila[1] end
	end
	return bolsa[#bolsa][1]
end

local function Identidad(enf)
	if R.Mudavimler and math.random() < 0.4 then
		local c = {}
		for _, m in ipairs(R.Mudavimler) do
			if istable(m.egilim) and table.HasValue(m.egilim, enf.id) then c[#c + 1] = m end
		end
		if #c > 0 then return R.HastaKimlik(math.random(1, 2000000000), c[math.random(#c)]) end
	end
	return R.HastaKimlik(math.random(1, 2000000000))
end

local function EfectosVisibles(enf)
	local t = {}
	for _, id in ipairs(enf.belirtiler) do
		local b = R.Belirtiler[id]
		if b and b.kaynak == "gorunur" and b.efekt then t[#t + 1] = b.efekt end
	end
	return table.concat(t, ",")
end

local function Revelar(H, fuente)
	local nuevos = {}
	for _, id in ipairs(H.hastalik.belirtiler) do
		local b = R.Belirtiler[id]
		if b and b.kaynak == fuente and not H.acik[id] then
			H.acik[id] = true
			nuevos[#nuevos + 1] = id
		end
	end
	return nuevos
end

local function Voluntario(N)
	return {ad = N.ad, unvan = N.unvan}
end

local function Juego(N, H)
	return R.Jeton(H, Voluntario(N)), R.GecmisSet(N.gecmis), N.gecmis
end

local function Opcion(N, id)
	local texto = R.SecenekMetin(id, R.GecmisSet(N.gecmis), N.gecmis)
	return {id, texto or id}
end

local function CamasEstado()
	local ocupada = {}
	for _, N in pairs(TURNO) do
		for _, H in ipairs(N.pacientes) do
			if H.durum == "geliyor" or H.durum == "yatiyor" or H.durum == "devrediliyor" then
				ocupada[H.yatak] = true
			end
		end
	end
	local abiertas, cerradas = {}, {}
	for _, y in ipairs(R.Harita and R.Harita.yataklar or {}) do
		if not ocupada[y.no] then
			if y.kapali then cerradas[#cerradas + 1] = y.no else abiertas[#abiertas + 1] = y.no end
		end
	end
	return abiertas, cerradas
end

local function CamasLibres()
	local abiertas = CamasEstado()
	return abiertas
end

local function BonusFuera(char)
	local reg = LeerRegistro(char)
	local grado = 0
	for _, veces in pairs(reg.u or {}) do
		local k = R.UstalikKademe(tonumber(veces) or 0)
		if k > grado then grado = k end
	end
	if grado < 1 then return 0 end
	return math.Clamp(math.floor(tonumber(R.Ayar.disBonus and R.Ayar.disBonus[grado]) or 0), 0, 15)
end

local function EngancharSifa()
	if not HpwRewrite or not HpwRewrite.Sifa or HpwRewrite._RevirSifa then return end
	local base = HpwRewrite.Sifa
	HpwRewrite._RevirSifa = true
	function HpwRewrite:Sifa(sifaci, hedef, miktar)
		miktar = tonumber(miktar) or 0
		if IsValid(sifaci) and sifaci:IsPlayer() and not (R.Harita and R.RevirdeMi(sifaci:GetPos())) then
			local char = Personaje(sifaci)
			local pct = char and BonusFuera(char) or 0
			if pct > 0 then miktar = miktar * (1 + pct / 100) end
		end
		return base(self, sifaci, hedef, miktar)
	end
end

local function NivelSanacion(char)
	local G = SardonGelisim
	if not (G and char) then return 1, 0, 0 end
	if G.DalSeviye then
		local ok, sv, ic, gerek = pcall(G.DalSeviye, char, R.Kat or "sifa")
		if ok and tonumber(sv) then
			return math.max(1, math.floor(tonumber(sv))), math.max(0, math.floor(tonumber(ic) or 0)), math.max(0, math.floor(tonumber(gerek) or 0))
		end
	end
	if G.DalXP and G.XPSeviye then
		local ok, xp = pcall(G.DalXP, char, R.Kat or "sifa")
		if ok then
			local sv, ic, gerek = G.XPSeviye(tonumber(xp) or 0)
			return math.max(1, math.floor(sv or 1)), math.max(0, math.floor(ic or 0)), math.max(0, math.floor(gerek or 0))
		end
	end
	return 1, 0, 0
end

local function ContarTurnos()
	local n = 0
	for _, T in pairs(TURNO) do
		if not T.test then n = n + 1 end
	end
	return n
end

local function ActorPaciente(N, H)
	local cama = R.Yatak(H.yatak)
	local _, yaw = R.YatakYon(cama)
	local a = ACTOR[H.id] or {id = H.id, tur = "hasta"}
	a.model = H.kimlik.model or ""
	a.ad = H.kimlik.ad
	a.unvan = (H.kimlik.hane or "") .. " · " .. (H.kimlik.yil or 1) .. ".º año"
	a.yatak = H.yatak
	a.pos = cama.yan
	a.yaw = yaw
	a.hedefYaw = yaw
	a.efekt = EfectosVisibles(H.hastalik)
	a.siddet = H.hastalik.zorluk or 1
	a.sahip = IsValid(N.ply) and N.ply:EntIndex() or 0
	a.anim = ""
	a.animBas = CurTime()
	a.gizli = false
	if H.durum == "geliyor" and a.yol then
		a.poz = "ayakta"
	elseif H.durum == "iyilesti" or H.durum == "cikti" then
		a.poz = "otur"
		a.yol = nil
	else
		a.poz = "yat"
		a.yol = nil
	end
	PonerActor(a)
end

local function HacerLlegar(N, H)
	local h = R.Harita
	local cama = R.Yatak(H.yatak)
	local a = {
		id = H.id, tur = "hasta", giris = true, poz = "ayakta",
		yol = {h.giris, cama.yan}, yolBas = CurTime(), hiz = 78
	}
	H.durum = "geliyor"
	H.llega = CurTime() + (h.giris:Distance(cama.yan) / 78) + 0.4
	ACTOR[H.id] = a
	ActorPaciente(N, H)
end

local function Acostar(N, H)
	H.durum = "yatiyor"
	Revelar(H, "gorunur")
	local a = ACTOR[H.id]
	if a then a.yol, a.giris, a.kalinti, a.kalintiBitis = nil, false, "", 0 end
	ActorPaciente(N, H)
	if IsValid(N.ply) then
		local j = R.Jeton(H, Voluntario(N))
		Aviso(N.ply, H.kimlik.ad, "Ya está en la cama " .. H.yatak .. ". Acércate y escúchale.", "bilgi")
		Globo(POMFREY, R.Doldur(R.PomfreySoz("hastaGeldi", R.GecmisSet(N.gecmis), N.gecmis, j) or "", j), 4, 0)
	end
end

local function PasoActual(H)
	local t = H.teshis ~= "" and R.Hastalik(H.teshis)
	return t and t.tedavi[H.gAdim + 1] or nil, t
end

local function Umbral(char, H)
	local esik = R.Ayar.esik
	local t = H.teshis ~= "" and R.Hastalik(H.teshis)
	if t and t.yol == "onarim" then esik = esik - 3 * R.Beceri(char, R.BECERI.NAZIK) end
	if t and t.yol == "arindirma" and R.Beceri(char, R.BECERI.BERRAK) >= 2 then esik = esik - 3 end
	return math.max(40, math.floor(esik))
end

local function Sabe(ply, nombre)
	return HpwRewrite and HpwRewrite.PlayerHasSpell and HpwRewrite:PlayerHasSpell(ply, nombre) or false
end

local function DarHechizo(N, nombre)
	local ply, char = N.ply, N.char
	if not IsValid(ply) or Sabe(ply, nombre) then return end
	local veces = tonumber(LeerRegistro(char).u[nombre]) or 0
	if R.UstalikKademe(veces) < (R.Ayar.ogrenmeKademe or 2) then return end
	local kademe, agac = R.BuyuKademe(nombre)
	local abierto, porque = true, ""
	local BA = SardonBuyuAgaci
	if BA and BA.KademeAcik and agac then
		local ok, sebep = BA.KademeAcik(char, agac, kademe)
		abierto = ok and true or false
		porque = isstring(sebep) and sebep or ""
	end
	if not abierto then
		local reg = LeerRegistro(char)
		if not table.HasValue(reg.b, nombre) then
			reg.b[#reg.b + 1] = nombre
			GuardarRegistro(char, reg)
		end
		N.kilitli[#N.kilitli + 1] = {buyu = nombre, sebep = porque ~= "" and porque or "Ese grado del árbol de hechizos sigue cerrado."}
		return
	end
	local dado = false
	if HpwRewrite and HpwRewrite.SaveAndGiveSpell then
		dado = pcall(function() HpwRewrite:SaveAndGiveSpell(ply, nombre, true) end)
	end
	if dado and Sabe(ply, nombre) then
		N.ogrenilen[#N.ogrenilen + 1] = nombre
		Aviso(ply, "Hechizo nuevo", nombre .. " queda en tu varita.", "iyi")
		Efecto("ogrendi", ply:GetPos(), R.BuyuRenk(nombre), nombre)
	else
		N.kilitli[#N.kilitli + 1] = {buyu = nombre, sebep = "La varita no tiene ese hechizo cargado. El tratamiento cuenta igual."}
	end
end

local function Practica(N, nombre)
	local reg = LeerRegistro(N.char)
	local antes = R.UstalikKademe(tonumber(reg.u[nombre]) or 0)
	reg.u[nombre] = (tonumber(reg.u[nombre]) or 0) + 1
	local despues = R.UstalikKademe(reg.u[nombre])
	GuardarRegistro(N.char, reg)
	if despues > antes then
		N.degisim[#N.degisim + 1] = {buyu = nombre, eski = antes, yeni = despues}
	end
	DarHechizo(N, nombre)
	EnviarKayit(N.ply)
end

local function CerrarTurno(N, motivo)
	if not N or N.cerrado then return end
	N.cerrado = true
	TURNO[N.charid] = nil
	local ply = N.ply
	for _, H in ipairs(N.pacientes) do
		if H.durum == "geliyor" or H.durum == "yatiyor" or H.durum == "devrediliyor" then
			H.durum = "devredildi"
		end
		timer.Simple(6, function() QuitarActor(H.id) end)
	end
	if IsValid(ply) then
		EnviarNobet(ply, nil)
		if not N.test then
			local reg = LeerRegistro(N.char)
			local curados, fallidos = 0, 0
			for _, H in ipairs(N.pacientes) do
				if H.durum == "iyilesti" then curados = curados + 1 else fallidos = fallidos + 1 end
			end
			local xp = N.kazanc or 0
			local bonus = 0
			if curados == #N.pacientes and #N.pacientes > 0 then
				bonus = math.floor(xp * 0.25)
			end
			if R.PomfreyOyuncu and R.PomfreyOyuncu() then
				xp = math.floor(xp * (1 + (R.Ayar.pomfreyBonus or 0) / 100))
			end
			xp = xp + bonus
			reg.deneyim = (tonumber(reg.deneyim) or 0) + xp
			reg.birikim = (tonumber(reg.birikim) or 0) + xp
			reg.iyilesen = (tonumber(reg.iyilesen) or 0) + curados
			reg.devredilen = (tonumber(reg.devredilen) or 0) + fallidos
			reg.nobet = (tonumber(reg.nobet) or 0) + 1
			local puntos = 0
			local cada = math.max(10, R.Ayar.dalPuaniEsik or 250)
			reg.birikim = math.min(reg.birikim, cada * 8)
			while reg.birikim >= cada do
				reg.birikim = reg.birikim - cada
				reg.dalpuan = (tonumber(reg.dalpuan) or 0) + 1
				puntos = puntos + 1
			end
			local G = SardonGelisim
			if puntos > 0 and G and G.DalPuanEkle then
				pcall(G.DalPuanEkle, N.char, R.Kat or "sifa", puntos, "revir")
			end
			local honor = (R.Ayar.onur or 0) * curados
			if honor > 0 then
				local puesto = false
				if SardonOnur and SardonOnur.Ekle then
					puesto = pcall(SardonOnur.Ekle, SardonOnur, ply, honor)
				end
				if not puesto then
					local ahora = ply:GetNWInt("sardon_onur", 0) + honor
					ply:SetNWInt("sardon_onur", ahora)
					if N.char.SetData then N.char:SetData("sardon_onur", ahora) end
				end
			end
			local antes = N.unvan
			local nuevo = R.Unvan(reg.iyilesen)
			GuardarRegistro(N.char, reg)
			EnviarKayit(ply)
			local frase
			if curados == #N.pacientes and curados > 0 then frase = R.PomfreySoz("nobetIyi", R.GecmisSet(N.gecmis), N.gecmis, R.Jeton(nil, Voluntario(N)))
			elseif curados == 0 then frase = R.PomfreySoz("nobetKotu", R.GecmisSet(N.gecmis), N.gecmis, R.Jeton(nil, Voluntario(N)))
			else frase = R.PomfreySoz("nobetOrta", R.GecmisSet(N.gecmis), N.gecmis, R.Jeton(nil, Voluntario(N))) end
			local karne = {
				test = false, pomfrey = frase or "", deneyim = xp, bonus = bonus,
				birikim = reg.birikim, esik = cada, dalSv = 0, dalPuani = puntos,
				unvan = nuevo, unvanYeni = (nuevo ~= antes) and nuevo or nil,
				pomfreyUnvan = (nuevo ~= antes) and R.PomfreySoz("unvanAtladi", R.GecmisSet(N.gecmis), N.gecmis, {oyuncu = N.ad, unvan = nuevo}) or nil,
				degisim = N.degisim, ogrenilen = N.ogrenilen, kilitli = N.kilitli, hastalar = {}
			}
			local sv, ic, gerek = NivelSanacion(N.char)
			karne.dalSv, karne.dalIc, karne.dalGerek = sv, ic, gerek
			for _, H in ipairs(N.pacientes) do
				karne.hastalar[#karne.hastalar + 1] = {
					ad = H.kimlik.ad, yol = H.hastalik.yol, hastalik = H.hastalik.ad,
					dogru = H.primer == true, teshis = H.primerNombre or "",
					deneyim = H.deneyim or 0, sonuc = H.durum, yanlis = H.yanlis or 0,
					acil = H.acil and true or false
				}
			end
			net.Start("SardonRevir.Karne")
				net.WriteTable(karne)
			net.Send(ply)
		else
			Aviso(ply, "Turno de prueba", "Termina sin premio.", "bilgi")
		end
	end
	if motivo == "dejo" and IsValid(ply) then
		Globo(POMFREY, "Me quedo con tus pacientes.", 4, 0)
	end
end

local function Curar(N, H)
	H.durum = "iyilesti"
	H.deneyim = (H.hastalik.zorluk or 1) * (R.Ayar.deneyimTaban or 30)
	if not N.test then
		N.kazanc = (N.kazanc or 0) + H.deneyim
		local reg = LeerRegistro(N.char)
		reg.tk[H.gercek] = (tonumber(reg.tk[H.gercek]) or 0) + 1
		if H.primer == true then reg.dogru = (tonumber(reg.dogru) or 0) + 1 end
		GuardarRegistro(N.char, reg)
	end
	local cama = R.Yatak(H.yatak)
	Efecto("iyilesti", R.YatakOrta(cama), R.BuyuRenk("Sanitatem"), "")
	ActorPaciente(N, H)
	local j, g, dizi = Juego(N, H)
	local frase = R.HastaSoz(H, "iyilesti", g, dizi, j)
	Globo(H.id, frase or "Gracias.", 5, N.ply:EntIndex())
	Globo(POMFREY, R.PomfreySoz("iyilesti", g, dizi, j) or "", 4, 0)
	EnviarNobet(N.ply, N)
	EnviarKayit(N.ply)
	local vivos = false
	for _, P in ipairs(N.pacientes) do
		if P.durum == "geliyor" or P.durum == "yatiyor" then vivos = true end
	end
	if not vivos then
		timer.Simple(2.5, function()
			if TURNO[N.charid] == N then CerrarTurno(N, "fin") end
		end)
	end
end

local function Entregar(N, H, razon)
	H.durum = "devredildi"
	H.deneyim = 0
	local cama = R.Yatak(H.yatak)
	Efecto("pomfrey", R.YatakOrta(cama), Color(222, 192, 120), "")
	local j, g, dizi = Juego(N, H)
	Globo(POMFREY, R.PomfreySoz(razon or "devraldi", g, dizi, j) or "Este paciente lo sigo yo.", 5, 0)
	ActorPaciente(N, H)
	Aviso(N.ply, "Madam Pomfrey", "Se queda con " .. H.kimlik.ad .. ".", "uyari")
	EnviarNobet(N.ply, N)
	local vivos = false
	for _, P in ipairs(N.pacientes) do
		if P.durum == "geliyor" or P.durum == "yatiyor" then vivos = true end
	end
	if not vivos then
		timer.Simple(2.5, function()
			if TURNO[N.charid] == N then CerrarTurno(N, "fin") end
		end)
	end
end

local function Fallo(N, H, texto)
	local gratis = R.Beceri(N.char, R.BECERI.KORUYUCU)
	if R.Beceri(N.char, R.BECERI.KORUYUCU) >= 2 then gratis = math.max(gratis, 2) end
	H.perdon = H.perdon or 0
	if H.perdon < gratis then
		H.perdon = H.perdon + 1
		Aviso(N.ply, "La mano se detiene", "Ese error no cuenta. Esta vez.", "uyari")
		Efecto("koruma", R.YatakOrta(R.Yatak(H.yatak)), Color(140, 190, 230), "")
		return
	end
	H.yanlis = (H.yanlis or 0) + 1
	local limite = R.Ayar.yanlisSiniri or 2
	if R.Beceri(N.char, R.BECERI.KALKAN) > 0 then limite = limite + 1 end
	Efecto("yanlis", R.YatakOrta(R.Yatak(H.yatak)), Color(180, 80, 80), "")
	local j, g, dizi = Juego(N, H)
	Globo(H.id, R.HastaSoz(H, "yanlis", g, dizi, j) or "", 4, 0)
	if H.yanlis >= limite then
		Entregar(N, H, "devraldi")
	else
		Globo(POMFREY, R.PomfreySoz("yanlis", g, dizi, j) or "", 4, 0)
		Aviso(N.ply, "Tratamiento incorrecto", texto or "Vuelve al cuaderno.", "kotu")
		EnviarNobet(N.ply, N)
	end
end

local function Avanzar(N, H)
	H.gAdim = (H.gAdim or 0) + 1
	local paso = H.hastalik and H.teshis == H.gercek and R.Hastalik(H.gercek)
	local real = paso and paso.tedavi[H.gAdim]
	if H.teshis == H.gercek and H.gAdim >= #H.hastalik.tedavi then
		Curar(N, H)
		return
	end
	if real == nil and H.teshis ~= H.gercek then
		-- El paso existía en el diagnóstico equivocado; no cura.
	end
	local diag = R.Hastalik(H.teshis)
	if diag and H.gAdim >= #diag.tedavi and H.teshis ~= H.gercek then
		Fallo(N, H, "El tratamiento de ese diagnóstico no era el de este paciente.")
		H.gAdim = math.max(0, H.gAdim - 1)
		return
	end
	EnviarNobet(N.ply, N)
	Aviso(N.ply, "Bien", "Sigue con el siguiente paso.", "iyi")
end

local function PuedeCurar(N, H)
	return H and H.durum == "yatiyor" and H.teshis == H.gercek
end

local function EmpezarTurno(ply, prueba)
	local char = Personaje(ply)
	if not char then return Aviso(ply, "Enfermería", "Primero elige un personaje.", "kotu") end
	if TURNO[char:GetID()] then return Aviso(ply, "Enfermería", "Ya tienes un turno abierto.", "uyari") end
	if not R.Harita then
		return Aviso(ply, "Enfermería", "El ala no está colocada. Un superadmin tiene que dejar a Pomfrey, el cuaderno, el armario y las camas.", "kotu")
	end
	if not prueba and R.Ayar.acik == false then
		return Aviso(ply, "Enfermería", "Hoy no se admiten voluntarios.", "kotu")
	end
	if not ply:Alive() then return Aviso(ply, "Enfermería", "Así no puedes atender a nadie.", "kotu") end
	local reg = LeerRegistro(char)
	if not prueba then
		local usado = (reg.gun == R.Gun()) and (tonumber(reg.gunsayi) or 0) or 0
		if usado >= (R.Ayar.gunluk or 1) then
			return Aviso(ply, "Enfermería", "Hoy ya hiciste tu turno. Vuelve en " .. TextoPlazo(char) .. ".", "uyari")
		end
		if ContarTurnos() >= (R.Ayar.eszamanli or 2) then
			return Aviso(ply, "Enfermería", "Ahora mismo no queda cama libre para otro voluntario.", "uyari")
		end
	end
	local base = math.Clamp(math.floor(R.Ayar.hastaSayisi or 3), 1, 3)
	local abiertas, cerradas = CamasEstado()
	if #abiertas < base then
		return Aviso(ply, "Enfermería", "Hacen falta " .. base .. " camas abiertas. Ahora hay " .. #abiertas .. ".", "kotu")
	end
	local camas = {}
	for i = 1, base do camas[i] = abiertas[i] end
	local faltaAcil = false
	if R.Beceri(char, R.BECERI.SAFLIK) > 0 then
		local extra = abiertas[base + 1] or cerradas[1]
		if extra then camas[#camas + 1] = extra else faltaAcil = true end
	end
	if not prueba then
		if reg.gun ~= R.Gun() then reg.gun, reg.gunsayi = R.Gun(), 0 end
		reg.gunsayi = (tonumber(reg.gunsayi) or 0) + 1
		GuardarRegistro(char, reg)
	end
	local N = {
		ply = ply, char = char, charid = char:GetID(), ad = char:GetName() or ply:Nick(),
		unvan = R.Unvan(reg.iyilesen), test = prueba and true or false,
		fin = os.time() + math.floor((R.Ayar.nobetDakika or 30) * 60),
		kazanc = 0, pacientes = {}, gecmis = {}, lejos = 0,
		degisim = {}, ogrenilen = {}, kilitli = {}
	}
	local ctx = Contexto(ply, char)
	local usadas = {}
	local tope = 2
	if R.Beceri(char, R.BECERI.IZLER) > 0 then tope = 3 end
	if R.Beceri(char, R.BECERI.DERIN) > 0 then tope = 4 end
	for i = 1, #camas do
		local acil = i > base
		local enf
		local guard = 0
		repeat
			enf = ElegirEnfermedad(char, ctx, acil and tope or 1)
			guard = guard + 1
		until not usadas[enf.id] or guard > 12
		usadas[enf.id] = true
		local casa = ctx.casaVol
		local baglam = table.Copy(ctx)
		SIGUIENTE = SIGUIENTE + 1
		local H = {
			id = SIGUIENTE, yatak = camas[i], hastalik = enf, gercek = enf.id, acil = i > base,
			kimlik = Identidad(enf), baglam = baglam, durum = "geliyor",
			acik = {}, teshis = "", gAdim = 0, yanlis = 0, deneyim = 0,
			hikaye = false, belirti = false, muayene = false, tarama = false,
			tutunma = 0, perdon = 0
		}
		if casa and casa == H.kimlik.hane then H.baglam.ayniHane = true end
		if casa and R.Rakip and R.Rakip[casa] == H.kimlik.hane then H.baglam.rakipHane = true end
		N.pacientes[#N.pacientes + 1] = H
	end
	TURNO[N.charid] = N
	for _, H in ipairs(N.pacientes) do HacerLlegar(N, H) end
	EnviarNobet(ply, N)
	EnviarKayit(ply)
	local j = {oyuncu = N.ad, unvan = N.unvan, sayi = #N.pacientes}
	Diyalog(ply, POMFREY, {
		{"pomfrey", "Madam Pomfrey", R.PomfreySoz("nobetBasla", R.GecmisSet(N.gecmis), N.gecmis, j) or "Los pacientes vienen de camino."}
	}, {Opcion(N, "tamam")})
	local texto = #N.pacientes .. " pacientes vienen de camino."
	if N.pacientes[#N.pacientes] and N.pacientes[#N.pacientes].acil then
		texto = texto .. " El último es una emergencia."
	end
	Aviso(ply, "Turno de enfermería", texto, "iyi")
	if faltaAcil then
		Aviso(ply, "Emergencia", "El cuarto paciente no cabe: coloca una cama más en el ala.", "uyari")
	end
end

local function HablarPomfrey(ply, N)
	local char = Personaje(ply)
	local reg = char and LeerRegistro(char) or NuevoRegistro()
	local j = {oyuncu = char and char:GetName() or ply:Nick(), unvan = R.Unvan(reg.iyilesen), kalan = TextoPlazo(char)}
	local g, dizi = {}, {}
	if N then g, dizi = R.GecmisSet(N.gecmis), N.gecmis end
	local saludo = R.PomfreySoz(N and "nobetVar" or "karsilama", g, dizi, j)
	local ops = {}
	if N then
		ops = {Opcion(N, "ipucu"), Opcion(N, "birak"), Opcion(N, "tamam")}
	else
		ops = {{"gonullu", R.Secenek.gonullu}, {"nasil", R.Secenek.nasil}, {"hoscakal", R.Secenek.hoscakal}}
	end
	Diyalog(ply, POMFREY, {{"pomfrey", "Madam Pomfrey", saludo or "..."}}, ops)
end

local function Pista(N)
	for _, H in ipairs(N.pacientes) do
		if H.durum == "yatiyor" then
			local j, g, dizi = Juego(N, H)
			local kat = "ciz"
			if not H.hikaye or not H.belirti then kat = "dinle"
			elseif not H.muayene then kat = "muayene"
			elseif not H.tarama then kat = "tara"
			elseif H.teshis == "" then kat = "defter"
			elseif H.gAdim >= #(R.Hastalik(H.teshis) and R.Hastalik(H.teshis).tedavi or {}) then kat = "bitti" end
			return R.PomfreySoz("ipucu." .. kat, g, dizi, j)
		end
	end
	return R.PomfreySoz("ipucu.bitti", R.GecmisSet(N.gecmis), N.gecmis, R.Jeton(nil, Voluntario(N)))
end

local function HablarPaciente(ply, N, H)
	if H.durum ~= "yatiyor" then
		return Aviso(ply, H.kimlik.ad, "Todavía no está en la cama.", "bilgi")
	end
	local j, g, dizi = Juego(N, H)
	local saludo = R.HastaSelam(H, g, dizi, j)
	local ops
	if not H.hikaye or not H.belirti then
		ops = {Opcion(N, "hikaye"), Opcion(N, "belirti"), Opcion(N, "rahatlat"), Opcion(N, "kapat")}
	else
		ops = {Opcion(N, "sohbet"), Opcion(N, "rahatlat"), Opcion(N, "kapat")}
	end
	Diyalog(ply, H.id, {{"hasta", H.kimlik.ad, saludo or "..."}}, ops)
end

local function Cerca(ply, H)
	local y = R.Yatak(H.yatak)
	if not y then return false end
	local p = ply:GetPos()
	return p:DistToSqr(y.yan) <= 260 * 260 or p:DistToSqr(R.YatakOrta(y)) <= 260 * 260
end

local ULTIMO = {}
local function Freno(ply)
	local t = CurTime()
	if ULTIMO[ply] and t - ULTIMO[ply] < 0.2 then return true end
	ULTIMO[ply] = t
	return false
end

net.Receive("SardonRevir.Islem", function(_, ply)
	if Freno(ply) then return end
	local op = net.ReadUInt(4)
	local id = net.ReadUInt(16)
	local N = TurnoDe(ply)
	if op == OP.BASLA then
		EmpezarTurno(ply, false)
		return
	end
	if op == OP.KONUS then
		if id == POMFREY or (ACTOR[id] and ACTOR[id].tur == "pomfrey") then
			HablarPomfrey(ply, N)
			return
		end
		if not N then return Aviso(ply, "Enfermería", "No estás de turno. Habla con Madam Pomfrey.", "bilgi") end
		local H = Paciente(N, id)
		if not H then return Aviso(ply, "Enfermería", "Ese paciente no es de tu turno.", "bilgi") end
		HablarPaciente(ply, N, H)
		return
	end
	if op == OP.SECIM then
		local elec = net.ReadString()
		if id == POMFREY or id == 0 then
			if elec == "gonullu" then EmpezarTurno(ply, false)
			elseif elec == "nasil" then
				Diyalog(ply, POMFREY, {
					{"pomfrey", "Madam Pomfrey", "Cuando el paciente esté en la cama, acércate y escúchale. Luego examínalo y pasa la varita: el color del residuo importa."},
					{"pomfrey", "Madam Pomfrey", "El diagnóstico se anota en el cuaderno de la mesa. El tratamiento sigue el orden de esa página."},
					{"pomfrey", "Madam Pomfrey", "Si no conoces el hechizo, copia el rúnico. Dos errores y me quedo yo con el paciente."}
				}, {{"tamam", "De acuerdo."}})
			elseif elec == "ipucu" and N then
				Diyalog(ply, POMFREY, {{"pomfrey", "Madam Pomfrey", Pista(N) or ""}}, {Opcion(N, "tamam")})
			elseif elec == "birak" and N then
				CerrarTurno(N, "dejo")
			end
			return
		end
		if not N then return end
		local H = Paciente(N, id)
		if not H or H.durum ~= "yatiyor" then return end
		local j, g, dizi = Juego(N, H)
		local dicho = R.SecenekMetin(elec, g, dizi) or ""
		local resp, extra = "", nil
		if elec == "hikaye" then
			resp = R.HastaHikaye(H, g, dizi, j)
			H.hikaye = true
		elseif elec == "belirti" then
			local texto, lista = R.HastaBelirti(H, g, dizi, j)
			resp = texto
			H.belirti = true
			for _, b in ipairs(lista or {}) do H.acik[b] = true end
		elseif elec == "rahatlat" then
			resp = R.HastaSoz(H, "rahatlat", g, dizi, j)
		elseif elec == "sohbet" then
			resp = R.HastaSoz(H, "sohbet", g, dizi, j)
		elseif elec == "kapat" or elec == "tamam" or elec == "hoscakal" then
			return
		else
			return Aviso(ply, "Enfermería", "No entiendo esa respuesta.", "bilgi")
		end
		Diyalog(ply, H.id, {
			{"oyuncu", N.ad, dicho},
			{"hasta", H.kimlik.ad, resp or "..."}
		}, {})
		Globo(H.id, resp or "", 4, ply:EntIndex())
		EnviarNobet(ply, N)
		return
	end
	if not N then return Aviso(ply, "Enfermería", "No estás de turno.", "bilgi") end
	local H = Paciente(N, id)
	if op == OP.MUAYENE then
		if not H or H.durum ~= "yatiyor" then return Aviso(ply, "Enfermería", "Ese paciente no está en la cama.", "kotu") end
		if not Cerca(ply, H) then return Aviso(ply, "Demasiado lejos", "Acércate a la cama.", "kotu") end
		local nuevos = Revelar(H, "muayene")
		H.muayene = true
		local j, g, dizi = Juego(N, H)
		local lineas = {{"anlatici", "", "Le tomas el pulso y miras lo que la ropa escondía."}}
		for _, b in ipairs(nuevos) do
			lineas[#lineas + 1] = {"anlatici", "", R.BulguMetin(b, g, dizi) or R.Belirtiler[b].ad}
		end
		if #nuevos == 0 then lineas[1][3] = "La exploración no añade nada nuevo." end
		Diyalog(ply, H.id, lineas, {})
		Efecto("muayene", R.YatakOrta(R.Yatak(H.yatak)), Color(220, 200, 160), "")
		EnviarNobet(ply, N)
		return
	end
	if op == OP.TARA then
		if not H or H.durum ~= "yatiyor" then return end
		if not Cerca(ply, H) then return Aviso(ply, "Demasiado lejos", "Acércate a la cama.", "kotu") end
		local nuevos = Revelar(H, "tarama")
		H.tarama = true
		if R.Beceri(N.char, R.BECERI.BERRAK) >= 1 then
			for _, b in ipairs(H.hastalik.belirtiler) do
				local bel = R.Belirtiler[b]
				if bel and bel.kaynak == "muayene" and not H.acik[b] then
					H.acik[b] = true
					break
				end
			end
		end
		local kal = R.HastalikKalinti(H.hastalik) or ""
		local a = ACTOR[H.id]
		if a and kal ~= "" then
			a.kalinti = kal
			a.kalintiBitis = CurTime() + 8
			PonerActor(a)
		end
		local j, g, dizi = Juego(N, H)
		local texto = kal ~= "" and (R.KalintiMetin(kal, g, dizi) or "") or "No queda residuo."
		Diyalog(ply, H.id, {{"anlatici", "", texto}}, {})
		local col = R.Kalintilar[kal] and R.Kalintilar[kal].renk or Color(200, 200, 200)
		Efecto("tara", R.YatakOrta(R.Yatak(H.yatak)), col, "")
		EnviarNobet(ply, N)
		return
	end
	if op == OP.TESHIS then
		local cual = net.ReadString()
		if not H or H.durum ~= "yatiyor" then return Aviso(ply, "Cuaderno", "Ese paciente ya no espera diagnóstico.", "kotu") end
		local enf = R.Hastalik(cual)
		if not enf then return Aviso(ply, "Cuaderno", "Esa página no existe.", "kotu") end
		if not R.RevirdeMi(ply:GetPos()) then return Aviso(ply, "Cuaderno", "El cuaderno se lee en la enfermería.", "kotu") end
		if H.teshis == cual then return end
		if H.primer == nil then
			H.primer = cual == H.gercek
			H.primerNombre = enf.ad
		end
		H.teshis = cual
		H.gAdim = 0
		EnviarNobet(ply, N)
		if cual == H.gercek then
			Aviso(ply, "Diagnóstico", enf.ad .. ". El tratamiento está en la página.", "iyi")
		else
			Aviso(ply, "Diagnóstico anotado", "Si la página no encaja con el paciente, el tratamiento fallará.", "bilgi")
		end
		return
	end
	if op == OP.ESYA then
		local indice = net.ReadUInt(4)
		if not H or H.durum ~= "yatiyor" then return end
		if not Cerca(ply, H) then return Aviso(ply, "Demasiado lejos", "Llama al frasco desde la cama.", "kotu") end
		local paso = PasoActual(H)
		local objeto = R.Esyalar[indice]
		if not objeto then return Aviso(ply, "Armario", "Ese frasco no está.", "kotu") end
		local origen = R.Harita.dolap.pos
		local destino = R.YatakOrta(R.Yatak(H.yatak)) + Vector(0, 0, 20)
		net.Start("SardonRevir.Accio")
			net.WriteUInt(indice, 4)
			net.WriteUInt(2, 6)
			net.WriteVector(origen)
			net.WriteVector(destino)
			net.WriteFloat(1.4)
			net.WriteEntity(ply)
		net.Broadcast()
		Efecto("esya", destino, objeto.renk or Color(200, 200, 160), objeto.id)
		if paso and paso[1] == "esya" and paso[2] == objeto.id and PuedeCurar(N, H) then
			Aviso(ply, objeto.ad, "Es el frasco que pedía el cuaderno.", "iyi")
			Avanzar(N, H)
		elseif not paso then
			Aviso(ply, "Armario", "Primero diagnostica en el cuaderno.", "kotu")
		elseif paso[1] ~= "esya" then
			Fallo(N, H, "Ahora no toca el armario.")
		else
			Globo(POMFREY, R.PomfreySoz("esyaYanlis", R.GecmisSet(N.gecmis), N.gecmis, R.Jeton(H, Voluntario(N))) or "", 4, 0)
			Fallo(N, H, "Ese frasco no es el de este paso.")
		end
		return
	end
	if op == OP.SEVK then
		if not H or H.durum ~= "yatiyor" then return end
		local paso = PasoActual(H)
		if paso and paso[1] == "sevk" and PuedeCurar(N, H) then
			local j, g, dizi = Juego(N, H)
			Globo(POMFREY, R.PomfreySoz("sevkAldi", g, dizi, j) or "", 4, 0)
			H.gAdim = H.gAdim + 1
			Curar(N, H)
		else
			Globo(POMFREY, R.PomfreySoz("sevkGereksiz", R.GecmisSet(N.gecmis), N.gecmis, R.Jeton(H, Voluntario(N))) or "", 4, 0)
			Aviso(ply, "Madam Pomfrey", "Este caso puedes cerrarlo tú.", "bilgi")
		end
		return
	end
	if op == OP.BIRAK then
		CerrarTurno(N, "dejo")
		return
	end
	Aviso(ply, "Enfermería", "Esa acción no está montada.", "bilgi")
end)

local function Resultado(ply, puntos, codigo, mensaje, umbral)
	net.Start("SardonRevir.CizimSonuc")
		net.WriteUInt(math.Clamp(puntos, 0, 100), 7)
		net.WriteString(codigo)
		net.WriteString(mensaje or "")
		net.WriteUInt(math.Clamp(umbral or 0, 0, 100), 7)
	net.Send(ply)
end

net.Receive("SardonRevir.Cizim", function(_, ply)
	local id = net.ReadUInt(16)
	local n = net.ReadUInt(8)
	local pts = {}
	local leer = math.min(n, 255)
	for i = 1, leer do
		local x = net.ReadInt(16) / 10
		local y = net.ReadInt(16) / 10
		if i <= 200 then pts[#pts + 1] = {x = x, y = y} end
	end
	local centro = net.ReadVector()
	local ang = net.ReadAngle()
	local N = TurnoDe(ply)
	if not N then return Resultado(ply, 0, "hata", "No estás de turno.", 0) end
	local H = Paciente(N, id)
	if not H or H.durum ~= "yatiyor" then return Resultado(ply, 0, "hata", "Ese paciente ya no espera la varita.", 0) end
	if not Cerca(ply, H) then return Resultado(ply, 0, "hata", "Acércate a la cama para trazar.", 0) end
	local paso = PasoActual(H)
	if not paso then return Resultado(ply, 0, "hata", "Primero anota el diagnóstico en el cuaderno.", R.Ayar.esik) end
	if paso[1] ~= "buyu" then return Resultado(ply, 0, "hata", "El siguiente paso no es un hechizo.", R.Ayar.esik) end
	if #pts < 8 then return Resultado(ply, 0, "hata", "El trazo es demasiado corto.", R.Ayar.esik) end
	local hechizo = paso[2]
	if not R.Sablon(hechizo) then
		return Resultado(ply, 0, "hata", "Ese rúnico no está en el cuaderno.", R.Ayar.esik)
	end
	local bruto = R.Benzerlik(pts, hechizo) or 0
	local puntos = math.floor(math.Clamp(bruto, 0, 1) * 100)
	local umbral = Umbral(N.char, H)
	local otros = {}
	for _, p in ipairs(player.GetAll()) do
		if p ~= ply then otros[#otros + 1] = p end
	end
	if #otros > 0 then
		local muestra, pasoM = {}, math.max(1, math.ceil(#pts / 100))
		for i = 1, #pts, pasoM do muestra[#muestra + 1] = pts[i] end
		if #muestra > 100 then muestra[100] = pts[#pts] end
		net.Start("SardonRevir.CizimGoster")
			net.WriteVector(centro)
			net.WriteAngle(ang)
			net.WriteBool(puntos >= umbral)
			net.WriteColor(R.BuyuRenk(hechizo))
			net.WriteUInt(math.min(#muestra, 100), 7)
			for i = 1, math.min(#muestra, 100) do
				net.WriteInt(math.Clamp(math.floor(muestra[i].x * 10), -32768, 32767), 16)
				net.WriteInt(math.Clamp(math.floor(muestra[i].y * 10), -32768, 32767), 16)
			end
		net.Send(otros)
	end
	if puntos < umbral then
		Resultado(ply, puntos, "debil", "No llega al umbral. Traza el rúnico de una sola vez.", umbral)
		Efecto("dagildi", centro, R.BuyuRenk(hechizo), "")
		return
	end
	if H.teshis ~= H.gercek then
		Resultado(ply, puntos, "uygulandi", "El rúnico sale, pero no es el de esta dolencia.", umbral)
		Fallo(N, H, "El hechizo no corresponde a lo que tiene el paciente.")
		return
	end
	local sabe = Sabe(ply, hechizo)
	if not sabe then
		local reg = LeerRegistro(N.char)
		local dominio = R.UstalikKademe(tonumber(reg.u[hechizo]) or 0)
		local prob = math.Clamp((R.Ayar.tutunma or 35) + dominio * 12 + R.Beceri(N.char, R.BECERI.USTALIK) * 15, 0, 100)
		H.tutunma = (H.tutunma or 0) + 1
		local agarra = math.random(100) <= prob or H.tutunma >= (R.Ayar.garanti or 3)
		if not agarra then
			Resultado(ply, puntos, "tutmadi", "El trazo vale, pero el hechizo aún no te obedece. Vuelve a intentarlo.", umbral)
			Efecto("tutmadi", centro, R.BuyuRenk(hechizo), "")
			local j, g, dizi = Juego(N, H)
			Globo(H.id, R.HastaSoz(H, "tutmadi", g, dizi, j) or "", 3, ply:EntIndex())
			return
		end
	end
	Resultado(ply, puntos, "uygulandi", hechizo .. " hace efecto.", umbral)
	Efecto("buyu", R.YatakOrta(R.Yatak(H.yatak)), R.BuyuRenk(hechizo), hechizo)
	if not N.test then Practica(N, hechizo) end
	local j, g, dizi = Juego(N, H)
	Globo(POMFREY, R.PomfreySoz("dogru", g, dizi, j) or "", 3, 0)
	Avanzar(N, H)
end)

local function Admin(ply)
	return IsValid(ply) and ply:IsSuperAdmin()
end

local function Punto(ply, mirada)
	if mirada then
		local tr = ply:GetEyeTrace()
		if tr and tr.Hit then return tr.HitPos, ply:EyeAngles().y end
	end
	return ply:GetPos(), ply:EyeAngles().y
end

local function DatosAdmin(ply, tur, tabla)
	net.Start("SardonRevir.YonetimVeri")
		net.WriteString(tur)
		net.WriteTable(tabla or {})
	net.Send(ply)
end

local function ListaTurnos()
	local L = {}
	for _, N in pairs(TURNO) do
		local fila = {
			oyuncu = IsValid(N.ply) and N.ply:Nick() or "?",
			ad = N.ad, test = N.test and true or false,
			kalan = math.max(0, N.fin - os.time()), kazanc = N.kazanc or 0, hastalar = {}
		}
		for _, H in ipairs(N.pacientes) do
			fila.hastalar[#fila.hastalar + 1] = {
				yatak = H.yatak, ad = H.kimlik.ad, hastalik = H.hastalik.ad,
				durum = H.durum, gAdim = H.gAdim or 0, teshis = H.teshis or "", yanlis = H.yanlis or 0
			}
		end
		L[#L + 1] = fila
	end
	return L
end

local function Ficha(charid)
	local char
	for _, ply in ipairs(player.GetAll()) do
		local c = Personaje(ply)
		if c and c:GetID() == charid then char = c end
	end
	if not char then return {charid = charid, ad = "?"} end
	local k = LeerRegistro(char)
	return {
		charid = charid, ad = char:GetName() or "?", unvan = R.Unvan(k.iyilesen),
		deneyim = k.deneyim, birikim = k.birikim, dalpuan = k.dalpuan,
		iyilesen = k.iyilesen, devredilen = k.devredilen, nobet = k.nobet, dogru = k.dogru,
		gun = k.gun or "", gunsayi = k.gunsayi or 0, u = k.u, b = k.b
	}
end

net.Receive("SardonRevir.Yonetim", function(_, ply)
	local op = net.ReadUInt(4)
	if not Admin(ply) then
		if op == 1 then net.ReadTable()
		elseif op == 4 or op == 5 then net.ReadUInt(32) if op == 5 then net.ReadString() end
		elseif op == 9 then net.ReadUInt(32) net.ReadString() net.ReadUInt(10)
		elseif op == 10 then net.ReadString() net.ReadBool() end
		return Aviso(ply, "Enfermería", "Solo un superadmin coloca el ala.", "kotu")
	end
	if op == 1 then
		local t = net.ReadTable()
		R.Ayar = R.AyarTemizle(t)
		GuardarAyar()
		EnviarVeri()
		Aviso(ply, "Enfermería", "Ajustes guardados.", "iyi")
	elseif op == 2 then
		EnviarVeri(ply)
	elseif op == 3 then
		local copia = R.HaritaVarsayilanKopya()
		if not copia then
			return Aviso(ply, "Enfermería", "Este mapa no tiene un ala medida. Coloca cada pieza a mano.", "uyari")
		end
		R.Harita = copia
		GuardarMapa()
		AparecerPomfrey()
		EnviarVeri()
		Aviso(ply, "Enfermería", "Ala devuelta a la medida de este mapa.", "iyi")
	elseif op == 4 then
		DatosAdmin(ply, "oyuncu", Ficha(net.ReadUInt(32)))
	elseif op == 5 then
		local charid = net.ReadUInt(32)
		local que = net.ReadString()
		local char
		for _, p in ipairs(player.GetAll()) do
			local c = Personaje(p)
			if c and c:GetID() == charid then char = c end
		end
		if not char then return Aviso(ply, "Enfermería", "Ese personaje no está conectado.", "kotu") end
		local k = LeerRegistro(char)
		if que == "gun" then k.gun, k.gunsayi = "", 0
		elseif que == "ustalik" then k.u = {}
		elseif que == "hepsi" then
			local puntos = k.dalpuan
			k = NuevoRegistro()
			k.dalpuan = puntos
		else
			return Aviso(ply, "Enfermería", "No conozco ese borrado.", "kotu")
		end
		GuardarRegistro(char, k)
		local dueno = char.GetPlayer and char:GetPlayer()
		if IsValid(dueno) then EnviarKayit(dueno) end
		DatosAdmin(ply, "oyuncu", Ficha(charid))
		Aviso(ply, "Enfermería", "Registro actualizado.", "iyi")
	elseif op == 6 then
		EmpezarTurno(ply, true)
		DatosAdmin(ply, "liste", ListaTurnos())
	elseif op == 7 then
		local copia = {}
		for id, N in pairs(TURNO) do copia[#copia + 1] = N end
		for _, N in ipairs(copia) do CerrarTurno(N, "admin") end
		DatosAdmin(ply, "liste", ListaTurnos())
		Aviso(ply, "Enfermería", "Turnos cerrados.", "iyi")
	elseif op == 8 then
		DatosAdmin(ply, "liste", ListaTurnos())
	elseif op == 9 then
		local charid = net.ReadUInt(32)
		local nombre = net.ReadString()
		local veces = net.ReadUInt(10)
		local char
		for _, p in ipairs(player.GetAll()) do
			local c = Personaje(p)
			if c and c:GetID() == charid then char = c end
		end
		if not char then return Aviso(ply, "Enfermería", "Ese personaje no está conectado.", "kotu") end
		local k = LeerRegistro(char)
		k.u[nombre] = veces
		GuardarRegistro(char, k)
		local dueno = char.GetPlayer and char:GetPlayer()
		if IsValid(dueno) then EnviarKayit(dueno) end
		DatosAdmin(ply, "oyuncu", Ficha(charid))
	elseif op == 10 then
		local campo = net.ReadString()
		local mirada = net.ReadBool()
		local pos, yaw = Punto(ply, mirada)
		if not R.Harita then Esqueleto(pos, yaw) end
		local h = R.Harita
		local cama = string.match(campo, "^(%a+):(%d+)$")
		if campo == "pomfrey" then h.pomfrey = {pos = pos, yaw = yaw}
		elseif campo == "defter" then h.defter = {pos = pos, yaw = yaw}
		elseif campo == "dolap" then h.dolap = {pos = pos, yaw = yaw}
		elseif campo == "giris" then h.giris = pos
		elseif campo == "kapat" or string.sub(campo, 1, 6) == "kapat:" then
			local no = tonumber(string.match(campo, "(%d+)"))
			local y = no and h.yataklar[no]
			if not y then return Aviso(ply, "Enfermería", "Esa cama no existe.", "kotu") end
			y.kapali = not y.kapali
		else
			local cual, no = string.match(campo, "^(%a+):(%d+)$")
			no = tonumber(no)
			if not cual or not no or no < 1 or no > 6 then
				return Aviso(ply, "Enfermería", "No sé qué pieza quieres mover.", "kotu")
			end
			while #h.yataklar < no do
				local i = #h.yataklar + 1
				h.yataklar[i] = {no = i, bas = pos, ayak = pos + Vector(0, 70, 0), yan = pos + Vector(40, 0, 0), kapali = true}
			end
			local y = h.yataklar[no]
			y.no = no
			if cual == "bas" then y.bas = pos
			elseif cual == "ayak" then y.ayak = pos
			elseif cual == "yan" then y.yan = pos
			else return Aviso(ply, "Enfermería", "No sé qué pieza quieres mover.", "kotu") end
		end
		Caja()
		GuardarMapa()
		AparecerPomfrey()
		EnviarVeri()
		Aviso(ply, "Enfermería", "Pieza colocada.", "iyi")
	else
		Aviso(ply, "Enfermería", "Esa orden de administración no existe.", "bilgi")
	end
end)

hook.Add("Think", "SardonRevir.Turno", function()
	if not LISTO then return end
	local ahora = CurTime()
	if (R._pulso or 0) > ahora then return end
	R._pulso = ahora + 1
	for id, N in pairs(TURNO) do
		if not IsValid(N.ply) or not N.ply:Alive() then
			CerrarTurno(N, "caida")
		else
			for _, H in ipairs(N.pacientes) do
				if H.durum == "geliyor" and H.llega and CurTime() >= H.llega then
					Acostar(N, H)
					EnviarNobet(N.ply, N)
				end
			end
			if N.fin <= os.time() then
				Aviso(N.ply, "Enfermería", "Se acabó el tiempo del turno.", "uyari")
				CerrarTurno(N, "tiempo")
			elseif R.Harita and not R.RevirdeMi(N.ply:GetPos()) then
				N.lejos = (N.lejos or 0) + 1
				if N.lejos == math.floor((R.Ayar.uzaklasma or 120) * 0.5) then
					Aviso(N.ply, "Enfermería", "Si no vuelves, Pomfrey cierra el turno.", "uyari")
				end
				if N.lejos >= (R.Ayar.uzaklasma or 120) then
					Aviso(N.ply, "Enfermería", "Te ausentaste. Pomfrey se queda con los pacientes.", "kotu")
					CerrarTurno(N, "lejos")
				end
			else
				N.lejos = 0
			end
		end
	end
end)

hook.Add("PlayerLoadedCharacter", "SardonRevir.Entrar", function(ply)
	timer.Simple(1, function()
		if not IsValid(ply) then return end
		EnviarVeri(ply)
		EnviarKayit(ply)
		for _, a in pairs(ACTOR) do EnviarActor(ply, 1, a) end
	end)
end)

hook.Add("PlayerDisconnected", "SardonRevir.Salir", function(ply)
	local N = TurnoDe(ply)
	if N then CerrarTurno(N, "salio") end
	ULTIMO[ply] = nil
end)

hook.Add("PlayerDeath", "SardonRevir.Muerte", function(ply)
	local N = TurnoDe(ply)
	if not N then return end
	Aviso(ply, "Enfermería", "El turno se corta. Pomfrey atiende a quien quedaba.", "kotu")
	CerrarTurno(N, "caida")
end)

local function Arranque()
	if LISTO then return end
	Cargar()
	if R.Harita then AparecerPomfrey() end
	LISTO = true
	timer.Simple(2, function()
		for _, ply in ipairs(player.GetAll()) do
			EnviarVeri(ply)
			EnviarKayit(ply)
		end
	end)
	EngancharSifa()
	print("[Sardon Revir] turno de enfermería listo")
end

hook.Add("InitPostEntity", "SardonRevir.Arranque", Arranque)
timer.Simple(0, Arranque)
timer.Simple(3, EngancharSifa)
